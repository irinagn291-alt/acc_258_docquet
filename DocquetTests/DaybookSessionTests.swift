import XCTest
@testable import Docquet

final class DaybookSessionTests: XCTestCase {
    private var calendar = Calendar(identifier: .gregorian)
    private var now = Date(timeIntervalSince1970: 0)

    override func setUpWithError() throws {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        utc.locale = Locale(identifier: "en_US_POSIX")
        calendar = utc
        now = instant(2026, 9, 11)
    }

    @MainActor
    func test_reviewScreen_threeKeysOpenThreeTabs_afterOnboarding() async throws {
        let today = try await session(arguments: ["-ReviewScreen", "today"])
        XCTAssertEqual(today.selectedTab, .expenses)
        XCTAssertFalse(today.showOnboarding)
        XCTAssertTrue(today.canFileDraft)
        XCTAssertEqual(today.selectedDay, Daykey.from(now, calendar: calendar))

        let log = try await session(arguments: ["-ReviewScreen", "log"])
        XCTAssertEqual(log.selectedTab, .balance)
        XCTAssertNotEqual(log.selectedTab, today.selectedTab)

        let goals = try await session(arguments: ["-ReviewScreen", "goals"])
        XCTAssertEqual(goals.selectedTab, .settings)
        XCTAssertNotEqual(goals.selectedTab, log.selectedTab)
        XCTAssertNotEqual(goals.selectedTab, today.selectedTab)
    }

    @MainActor
    func test_openBooksTap_opensDayOnExpenses() async throws {
        let session = try await session(arguments: ["-ReviewScreen", "log"])
        XCTAssertEqual(session.selectedTab, .balance)
        let day = try XCTUnwrap(session.monthInkLines.first?.daykey)
        session.openBooksTap(.day(day))
        XCTAssertEqual(session.selectedTab, .expenses)
        XCTAssertEqual(session.selectedDay, day)
        session.openBooksTap(.miles)
        XCTAssertEqual(session.kind, .miles)
        XCTAssertEqual(session.selectedDay, session.today)
    }

    @MainActor
    func test_openDayBlotter_opensExpensesOnThatDay() async throws {
        let session = try await session(arguments: ["-ReviewScreen", "log"])
        XCTAssertEqual(session.selectedTab, .balance)
        let day = try XCTUnwrap(session.monthDayBooks.first?.daykey)
        session.openDayBlotter(day)
        XCTAssertEqual(session.selectedTab, .expenses)
        XCTAssertEqual(session.selectedDay, day)
    }

    @MainActor
    func test_reviewScreen_ignoredUntilOnboardingCompletes() async {
        let hold = DaybookHold(daybook: .empty)
        let session = DaybookSession(
            store: hold,
            calendar: calendar,
            now: { [now] in now },
            arguments: ["-ReviewScreen", "log"]
        )
        await session.bootstrap()
        XCTAssertTrue(session.showOnboarding)
        XCTAssertEqual(session.selectedTab, .expenses)
        await session.finishOnboarding()
        XCTAssertFalse(session.showOnboarding)
        XCTAssertEqual(session.selectedTab, .balance)
    }

    @MainActor
    func test_seededHome_fileIsEnabled_andNamesTheJob() async throws {
        let session = try await session(arguments: [])
        XCTAssertTrue(session.daybook.hasJobs)
        XCTAssertTrue(session.canFileDraft)
        XCTAssertFalse(session.expensesAreEmpty)
        XCTAssertEqual(session.homeHeadline, "Tap a day to file cash or miles")
        XCTAssertTrue(session.nextTapCopy.contains("File"))
        XCTAssertNotNil(session.selectedJob)
        XCTAssertTrue(session.nextTapCopy.contains(session.selectedJob?.name ?? "missing"))
        XCTAssertFalse(session.homeHeadline.localizedCaseInsensitiveContains("swiftui"))
        XCTAssertFalse(session.nextTapCopy.localizedCaseInsensitiveContains("encoding"))
        let ready = try XCTUnwrap(session.draftReady)
        XCTAssertTrue(ready.title.contains(session.selectedJob?.name ?? "missing"))
        XCTAssertTrue(ready.consequence.localizedCaseInsensitiveContains("file"))
        XCTAssertTrue(session.canFileDraft)
    }

    @MainActor
    func test_rejectNegativeDrafts_clearsAmountAndMiles() async throws {
        let session = try await blankSession()
        session.amountText = "-4"
        session.endMilesText = "-1"
        session.rejectNegativeDrafts()
        XCTAssertEqual(session.amountText, "")
        XCTAssertEqual(session.endMilesText, "")
        XCTAssertEqual(session.fault, .invalidMiles)
    }

    @MainActor
    func test_fileDraft_tripAdvancesChain_cashDoesNot() async throws {
        let session = try await blankSession()
        session.jobNameText = "Lantern Loft"
        session.jobRateText = "0.5"
        session.jobStartText = "10"
        await session.addJob()
        let jobID = try XCTUnwrap(session.jobID)
        XCTAssertEqual(session.daybook.job(id: jobID)?.lastEndMiles, 10)

        session.selectDay(Daykey.from(now, calendar: calendar))
        session.selectKind(.miles)
        session.endMilesText = "18"
        session.isBillable = true
        XCTAssertTrue(session.canFileDraft)
        await session.fileDraft()
        XCTAssertNil(session.fault)
        XCTAssertEqual(session.daybook.job(id: jobID)?.lastEndMiles, 18)
        XCTAssertEqual(session.daybook.trips.last?.startMiles, 10)
        XCTAssertEqual(session.daybook.trips.last?.distance, 8)
        XCTAssertEqual(session.daybook.trips.last?.billableAmount, 4)

        let chainHead = session.daybook.job(id: jobID)?.lastEndMiles
        session.selectKind(.cash)
        session.amountText = "40"
        session.isBillable = false
        await session.fileDraft()
        XCTAssertEqual(session.daybook.job(id: jobID)?.lastEndMiles, chainHead)
        XCTAssertEqual(session.daybook.outlays.last?.billableAmount, 0)
        XCTAssertEqual(session.daybook.outlays.last?.personalAmount, 40)
        XCTAssertEqual(session.daybook.monthBillableTotal(around: Daykey.from(now, calendar: calendar)), 4)
    }

    @MainActor
    func test_fileDraft_endBelowStartSetsFault_andLeavesChain() async throws {
        let session = try await blankSession()
        session.jobNameText = "Quay Drawings"
        session.jobRateText = "0.58"
        session.jobStartText = "20"
        await session.addJob()
        let jobID = try XCTUnwrap(session.jobID)
        session.selectDay(Daykey.from(now, calendar: calendar))
        session.selectKind(.miles)
        session.endMilesText = "10"
        await session.fileDraft()
        XCTAssertEqual(session.fault, .endBelowStart)
        XCTAssertEqual(session.daybook.job(id: jobID)?.lastEndMiles, 20)
        XCTAssertTrue(session.daybook.trips.isEmpty)
        XCTAssertFalse(session.canFileDraft)
    }

    @MainActor
    func test_invalidCashAmount_cannotFile() async throws {
        let session = try await blankSession()
        session.jobNameText = "Ridge Survey"
        session.jobRateText = "0.72"
        await session.addJob()
        session.selectDay(Daykey.from(now, calendar: calendar))
        session.selectKind(.cash)
        session.amountText = "0"
        XCTAssertFalse(session.canFileDraft)
        session.amountText = "-4"
        XCTAssertFalse(session.canFileDraft)
        session.amountText = "abc"
        XCTAssertFalse(session.canFileDraft)
        session.amountText = "12"
        XCTAssertTrue(session.canFileDraft)
    }

    func test_monthLattice_usesDaykeyAndMarksToday() {
        let today = Daykey.from(now, calendar: calendar)
        let cells = MonthLattice.cells(
            monthOf: today,
            today: today,
            buckets: [today: 60],
            ink: [today.rawValue],
            calendar: calendar
        )
        XCTAssertEqual(cells.count, 30)
        let match = cells.first { $0.daykey == today }
        XCTAssertEqual(match?.isToday, true)
        XCTAssertEqual(match?.billable, 60)
        XCTAssertEqual(match?.hasInk, true)
        XCTAssertEqual(today.rawValue, 20260911)
        let weeks = MonthLattice.weeks(cells)
        XCTAssertGreaterThanOrEqual(weeks.count, 5)
        XCTAssertTrue(weeks.allSatisfy { $0.count == 7 })
    }

    func test_figuresParseLocaleDecimal() {
        let locale = Locale(identifier: "en_US_POSIX")
        XCTAssertEqual(BlotterFigures.parse("24", locale: locale), 24)
        XCTAssertEqual(BlotterFigures.parse("12.5", locale: locale), 12.5)
        XCTAssertNil(BlotterFigures.parse("", locale: locale))
        XCTAssertNil(BlotterFigures.parse("nope", locale: locale))
        XCTAssertFalse(BlotterFigures.money(60, locale: Locale(identifier: "en_US")).isEmpty)
        XCTAssertTrue(BlotterFigures.miles(41, locale: locale).contains("41"))
    }

    @MainActor
    func test_emptyDaybookShowsEmptyExpenses_untilTodayOpens() async throws {
        let opened = try await blankSession()
        XCTAssertTrue(opened.expensesAreEmpty)
        XCTAssertTrue(opened.balanceIsEmpty)
        opened.openTodayBlotter()
        XCTAssertFalse(opened.expensesAreEmpty)
        XCTAssertEqual(opened.selectedTab, .expenses)
        XCTAssertEqual(opened.selectedDay, Daykey.from(now, calendar: calendar))
    }

    @MainActor
    func test_resetClearsInkAndReopensOnboarding() async throws {
        let session = try await session(arguments: [])
        XCTAssertTrue(session.daybook.hasInk)
        await session.resetAll()
        XCTAssertFalse(session.daybook.hasInk)
        XCTAssertTrue(session.showOnboarding)
        XCTAssertEqual(session.selectedTab, .expenses)
    }

    @MainActor
    func test_warningFromHoldSurfacesOnLoad() async {
        let hold = DaybookHold(daybook: .empty, warning: .startedEmpty)
        let session = DaybookSession(
            store: hold,
            calendar: calendar,
            now: { [now] in now },
            arguments: []
        )
        await session.bootstrap()
        XCTAssertEqual(session.warning, .startedEmpty)
        XCTAssertTrue(session.expensesAreEmpty)
    }

    @MainActor
    private func session(arguments: [String]) async throws -> DaybookSession {
        let daybook = try DaybookSeed.daybook(now: now, calendar: calendar)
        let session = DaybookSession(
            store: DaybookHold(daybook: daybook),
            calendar: calendar,
            now: { [now] in now },
            arguments: arguments
        )
        await session.bootstrap()
        return session
    }

    @MainActor
    private func blankSession() async throws -> DaybookSession {
        let session = DaybookSession(
            store: DaybookHold(daybook: .empty),
            calendar: calendar,
            now: { [now] in now },
            arguments: []
        )
        await session.bootstrap()
        await session.finishOnboarding()
        return session
    }

    private func instant(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var parts = DateComponents()
        parts.year = year
        parts.month = month
        parts.day = day
        parts.hour = 12
        return calendar.date(from: parts) ?? Date(timeIntervalSince1970: 0)
    }
}
