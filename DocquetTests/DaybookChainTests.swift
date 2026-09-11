import XCTest
@testable import Docquet

final class DaybookChainTests: XCTestCase {
    private var calendar = Calendar(identifier: .gregorian)
    private var today = Daykey(rawValue: 20260911)
    private let loft = UUID(uuidString: "BBBBBBBB-0001-4000-8000-000000000001")!
    private let quay = UUID(uuidString: "BBBBBBBB-0001-4000-8000-000000000002")!

    override func setUpWithError() throws {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        utc.locale = Locale(identifier: "en_US_POSIX")
        calendar = utc
        today = Daykey.from(instant(2026, 9, 11), calendar: calendar)
    }

    func test_architecture_tripAdvancesLastEndMiles_outlaySkipsChain_rateIsSnapshotted() throws {
        let firstRate = try Rate.make(0.5)
        var daybook = try Daybook.empty.addingJob(name: "Lantern Loft", rate: firstRate, id: loft)
        XCTAssertEqual(daybook.nextStartMiles(for: loft), 0)

        daybook = try daybook.fileLine(
            .trip(jobID: loft, startMiles: nil, endMiles: 12, isBillable: true),
            on: today
        )
        XCTAssertEqual(daybook.job(id: loft)?.lastEndMiles, 12)
        XCTAssertEqual(daybook.trips.first?.startMiles, 0)
        XCTAssertEqual(daybook.trips.first?.distance, 12)
        XCTAssertEqual(daybook.trips.first?.billableAmount, 6)

        daybook = try daybook.fileLine(
            .outlay(jobID: loft, amount: 40, isBillable: true),
            on: today
        )
        XCTAssertEqual(daybook.job(id: loft)?.lastEndMiles, 12)
        XCTAssertEqual(daybook.outlays.count, 1)

        daybook = try daybook.settingRate(jobID: loft, rate: Rate.make(2))
        XCTAssertEqual(daybook.trips.first?.billableAmount, 6)
        XCTAssertEqual(daybook.job(id: loft)?.rate.perMile, 2)

        daybook = try daybook.fileLine(
            .trip(jobID: loft, startMiles: nil, endMiles: 16, isBillable: true),
            on: today
        )
        XCTAssertEqual(daybook.job(id: loft)?.lastEndMiles, 16)
        XCTAssertEqual(daybook.trips.last?.startMiles, 12)
        XCTAssertEqual(daybook.trips.last?.snapshottedRate.perMile, 2)
        XCTAssertEqual(daybook.trips.last?.billableAmount, 8)
        XCTAssertEqual(daybook.monthBillableTotal(around: today), 40 + 6 + 8)

        let data = try DaybookCodec.encode(DaybookCodec.committed(from: daybook))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertNil(object["billableAmount"])
        XCTAssertEqual(object["schemaVersion"] as? Int, 1)
        XCTAssertEqual((object["trips"] as? [[String: Any]])?.first?["billableAmount"] as? Double, nil)
    }

    func test_primaryVerb_emptyUnknownJob_populatedFiles_invalidEndBelowStart() throws {
        let rate = try Rate.make(0.5)
        XCTAssertFalse(
            Daybook.empty.canFile(.outlay(jobID: loft, amount: 20, isBillable: true))
        )
        XCTAssertThrowsError(
            try Daybook.empty.fileLine(.outlay(jobID: loft, amount: 20, isBillable: true), on: today)
        ) { error in
            XCTAssertEqual(error as? BlotterFault, .unknownJob)
        }

        var daybook = try Daybook.empty.addingJob(name: "Lantern Loft", rate: rate, id: loft)
        XCTAssertTrue(daybook.canFile(.outlay(jobID: loft, amount: 20, isBillable: true)))
        daybook = try daybook.fileLine(.outlay(jobID: loft, amount: 20, isBillable: true), on: today)
        XCTAssertEqual(daybook.outlays.count, 1)
        XCTAssertEqual(daybook.outlays.first?.billableAmount, 20)

        XCTAssertFalse(daybook.canFile(.outlay(jobID: loft, amount: 0, isBillable: true)))
        XCTAssertThrowsError(
            try daybook.fileLine(.outlay(jobID: loft, amount: -4, isBillable: true), on: today)
        ) { error in
            XCTAssertEqual(error as? BlotterFault, .invalidAmount)
        }

        XCTAssertThrowsError(
            try daybook.fileLine(
                .trip(jobID: loft, startMiles: 10, endMiles: 4, isBillable: true),
                on: today
            )
        ) { error in
            XCTAssertEqual(error as? BlotterFault, .endBelowStart)
        }
        XCTAssertEqual(daybook.job(id: loft)?.lastEndMiles, 0)
        XCTAssertThrowsError(try daybook.addingJob(name: "  ", rate: rate)) { error in
            XCTAssertEqual(error as? BlotterFault, .emptyName)
        }
    }

    func test_twist_odometerChainPrefillsStart_refusesEndBelowStart_cashDoesNotMoveChain() throws {
        let rate = try Rate.make(0.67)
        var daybook = try Daybook.empty
            .addingJob(name: "Lantern Loft", rate: rate, id: loft)
            .addingJob(name: "Quay Drawings", rate: try Rate.make(0.58), id: quay)

        daybook = try daybook.fileLine(
            .trip(jobID: loft, startMiles: nil, endMiles: 22, isBillable: true),
            on: today
        )
        XCTAssertEqual(daybook.nextStartMiles(for: loft), 22)
        XCTAssertEqual(daybook.nextStartMiles(for: quay), 0)

        let loftBeforeCash = daybook.job(id: loft)?.lastEndMiles
        daybook = try daybook.fileLine(
            .outlay(jobID: loft, amount: 15, isBillable: false),
            on: today
        )
        XCTAssertEqual(daybook.job(id: loft)?.lastEndMiles, loftBeforeCash)
        XCTAssertEqual(daybook.outlays.first?.billableAmount, 0)
        XCTAssertEqual(daybook.outlays.first?.personalAmount, 15)

        XCTAssertThrowsError(
            try OdometerChain.distance(startMiles: 22, endMiles: 21)
        ) { error in
            XCTAssertEqual(error as? BlotterFault, .endBelowStart)
        }

        daybook = try daybook.fileLine(
            .trip(jobID: loft, startMiles: nil, endMiles: 22, isBillable: true),
            on: today
        )
        XCTAssertEqual(daybook.trips.last?.distance, 0)
        XCTAssertEqual(daybook.job(id: loft)?.lastEndMiles, 22)

        let books = daybook.booksByJob(inMonthOf: today)
        let loftBooks = try XCTUnwrap(books.first { $0.jobID == loft })
        XCTAssertEqual(loftBooks.billed, 22 * 0.67, accuracy: 0.000_000_1)
        XCTAssertEqual(loftBooks.personal, 15, accuracy: 0.000_000_1)
        XCTAssertTrue(daybook.hasInk(inMonthOf: today))
        XCTAssertFalse(daybook.hasInk(inMonthOf: Daykey(rawValue: 20260101)))
    }

    func test_seedMarksOnboardingCompleteAndLeavesFileEnabled() throws {
        let daybook = try DaybookSeed.daybook(now: instant(2026, 9, 11), calendar: calendar)
        XCTAssertTrue(daybook.onboardingComplete)
        XCTAssertEqual(daybook.jobs.count, 3)
        XCTAssertGreaterThanOrEqual(daybook.outlays.count, 3)
        XCTAssertGreaterThanOrEqual(daybook.trips.count, 3)
        XCTAssertGreaterThan(daybook.job(id: DaybookSeed.lanternLoftID)?.lastEndMiles ?? 0, 0)
        XCTAssertTrue(
            daybook.canFile(.outlay(jobID: DaybookSeed.lanternLoftID, amount: 12, isBillable: true))
        )
        XCTAssertTrue(
            daybook.canFile(
                .trip(
                    jobID: DaybookSeed.lanternLoftID,
                    startMiles: nil,
                    endMiles: (daybook.job(id: DaybookSeed.lanternLoftID)?.lastEndMiles ?? 0) + 5,
                    isBillable: true
                )
            )
        )
        XCTAssertTrue(daybook.hasInk(inMonthOf: today))
        XCTAssertGreaterThan(daybook.monthBillableTotal(around: today), 0)
        let mix = daybook.monthMix(around: today)
        XCTAssertEqual(mix.billed, daybook.monthBillableTotal(around: today), accuracy: 0.000_000_1)
        XCTAssertEqual(mix.cashCount, daybook.outlays.count)
        XCTAssertEqual(mix.tripCount, daybook.trips.count)
        XCTAssertGreaterThan(mix.personal, 0)
        XCTAssertGreaterThan(mix.cashPersonal, 0)
        XCTAssertGreaterThan(mix.milesPersonal, 0)
        let days = daybook.dayBooks(inMonthOf: today)
        XCTAssertGreaterThanOrEqual(days.count, 3)
        XCTAssertGreaterThan(daybook.dayBook(on: today).billed, 0)
        let lines = daybook.inkLines(inMonthOf: today)
        XCTAssertEqual(lines.filter { $0.kind == .cash }.count, daybook.outlays.count)
        XCTAssertEqual(lines.filter { $0.kind == .miles }.count, daybook.trips.count)
        XCTAssertFalse(daybook.inkLines(on: today).isEmpty)
        let loftBooks = try XCTUnwrap(daybook.booksByJob(inMonthOf: today).first { $0.jobID == DaybookSeed.lanternLoftID })
        XCTAssertGreaterThan(loftBooks.cashBilled + loftBooks.milesBilled, 0)
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
