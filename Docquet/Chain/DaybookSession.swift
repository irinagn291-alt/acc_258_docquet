import Combine
import Foundation
import UIKit

/// Role: Chain. Presentation seam. Views call fileLine through this type and never write lastEndMiles or UserDefaults.
@MainActor
final class DaybookSession: ObservableObject {
    enum InkKind: String, CaseIterable, Identifiable, Sendable {
        case cash
        case miles

        var id: String { rawValue }

        var title: String {
            switch self {
            case .cash: "Cash"
            case .miles: "Miles"
            }
        }
    }

    @Published private(set) var daybook: Daybook = .empty
    @Published private(set) var warning: DaybookWarning?
    @Published private(set) var fault: BlotterFault?
    @Published private(set) var loadFailed = false
    @Published private(set) var exportFailed = false
    @Published private(set) var isBusy = false
    @Published private(set) var showSpinner = false
    @Published private(set) var filedPulse = false
    @Published private(set) var exportURL: URL?
    @Published var selectedTab: BlotterTab = .expenses
    @Published var visibleMonth: Daykey
    @Published var selectedDay: Daykey?
    @Published var kind: InkKind = .cash
    @Published var jobID: UUID?
    @Published var amountText = ""
    @Published var endMilesText = ""
    @Published var isBillable = true
    @Published var jobNameText = ""
    @Published var jobRateText = ""
    @Published var jobStartText = ""
    @Published var showJobDraft = false
    @Published var showOnboarding = false
    @Published var showChain = false

    private let store: any DaybookStoring
    private let calendar: Calendar
    private let now: @Sendable () -> Date
    private let arguments: [String]
    private var reviewConsumed = false
    private var spinnerTask: Task<Void, Never>?
    private var didLoad = false

    init(
        store: any DaybookStoring,
        calendar: Calendar = .current,
        now: @escaping @Sendable () -> Date = { Date() },
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) {
        self.store = store
        self.calendar = calendar
        self.now = now
        self.arguments = arguments
        visibleMonth = Daykey.from(now(), calendar: calendar)
    }

    var today: Daykey { Daykey.from(now(), calendar: calendar) }

    var selectedJob: Job? {
        guard let jobID else { return nil }
        return daybook.job(id: jobID)
    }

    var startMiles: Double {
        guard let jobID else { return 0 }
        return daybook.nextStartMiles(for: jobID)
    }

    var monthTotal: Double {
        daybook.monthBillableTotal(around: visibleMonth)
    }

    var monthBuckets: [Daykey: Double] {
        daybook.monthBuckets(around: visibleMonth)
    }

    var monthCells: [MonthCell] {
        MonthLattice.cells(
            monthOf: visibleMonth,
            today: today,
            buckets: monthBuckets,
            ink: MonthLattice.inkDays(in: daybook, monthOf: visibleMonth),
            calendar: calendar
        )
    }

    var books: [JobBooks] {
        daybook.booksByJob(inMonthOf: visibleMonth)
    }

    var monthMix: MonthMix {
        daybook.monthMix(around: visibleMonth)
    }

    var monthDayBooks: [MonthDayBook] {
        daybook.dayBooks(inMonthOf: visibleMonth)
    }

    var selectedDayBook: MonthDayBook? {
        guard let selectedDay else { return nil }
        return daybook.dayBook(on: selectedDay)
    }

    var monthInkLines: [BlotterInkLine] {
        daybook.inkLines(inMonthOf: visibleMonth)
    }

    var selectedInkLines: [BlotterInkLine] {
        guard let selectedDay else { return [] }
        return daybook.inkLines(on: selectedDay)
    }

    var draftReady: DraftReady? {
        guard let job = selectedJob else { return nil }
        switch kind {
        case .cash:
            guard let amount = BlotterFigures.parse(amountText), amount > 0 else { return nil }
            let billed = BillableFold.cash(amount: amount, isBillable: isBillable)
            let personal = BillableFold.personalCash(amount: amount, isBillable: isBillable)
            let split = isBillable ? "Billable cash" : "Personal cash"
            let consequence = isBillable
                ? "File adds \(BlotterFigures.money(billed)) to this month billed."
                : "File keeps \(BlotterFigures.money(personal)) personal, off the billed total."
            return DraftReady(
                figure: BlotterFigures.money(amount),
                title: "\(job.name) · \(split)",
                consequence: consequence,
                chainLine: "\(job.name) chain stays at \(BlotterFigures.miles(job.lastEndMiles)). Cash does not move it."
            )
        case .miles:
            guard let end = BlotterFigures.parse(endMilesText) else { return nil }
            guard let distance = try? OdometerChain.distance(startMiles: startMiles, endMiles: end) else { return nil }
            let billed = BillableFold.miles(distance: distance, rate: job.rate, isBillable: isBillable)
            let personal = BillableFold.personalMiles(distance: distance, rate: job.rate, isBillable: isBillable)
            let split = isBillable ? "Billable miles" : "Personal miles"
            let consequence = isBillable
                ? "File adds \(BlotterFigures.money(billed)) at \(BlotterFigures.rate(job.rate.perMile))."
                : "File keeps \(BlotterFigures.money(personal)) personal, off the billed total."
            return DraftReady(
                figure: BlotterFigures.miles(distance),
                title: "\(job.name) · \(split)",
                consequence: consequence,
                chainLine: "Chain moves from \(BlotterFigures.miles(startMiles)) to \(BlotterFigures.miles(end))."
            )
        }
    }

    var hasMonthInk: Bool {
        daybook.hasInk(inMonthOf: visibleMonth)
    }

    var chainCards: [ChainCard] {
        daybook.jobs.map { job in
            ChainCard(
                job: job,
                lastTrip: daybook.trips.last(where: { $0.jobID == job.id })
            )
        }
    }

    var selectedOutlays: [Outlay] {
        guard let selectedDay else { return [] }
        return daybook.outlays(on: selectedDay)
    }

    var selectedTrips: [Trip] {
        guard let selectedDay else { return [] }
        return daybook.trips(on: selectedDay)
    }

    var draftLine: BlotterLine? {
        guard let jobID else { return nil }
        switch kind {
        case .cash:
            guard let amount = BlotterFigures.parse(amountText), amount > 0 else { return nil }
            return .outlay(jobID: jobID, amount: amount, isBillable: isBillable)
        case .miles:
            guard let end = BlotterFigures.parse(endMilesText) else { return nil }
            return .trip(jobID: jobID, startMiles: nil, endMiles: end, isBillable: isBillable)
        }
    }

    var canFileDraft: Bool {
        guard let line = draftLine, selectedDay != nil, !isBusy else { return false }
        return daybook.canFile(line)
    }

    var canAddJob: Bool {
        let name = jobNameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !isBusy else { return false }
        guard let rate = BlotterFigures.parse(jobRateText), (try? Rate.make(rate)) != nil else { return false }
        if jobStartText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return true }
        guard let start = BlotterFigures.parse(jobStartText), start >= 0 else { return false }
        return true
    }

    var homeHeadline: String {
        "Tap a day to file cash or miles"
    }

    var nextTapCopy: String {
        let job = selectedJob?.name ?? "a project"
        switch kind {
        case .cash:
            return "File cash for \(job)."
        case .miles:
            return "File miles for \(job). The chain starts at \(BlotterFigures.miles(startMiles))."
        }
    }

    var expensesAreEmpty: Bool {
        selectedDay == nil && !hasMonthInk && !daybook.hasJobs
    }

    var balanceIsEmpty: Bool {
        !daybook.hasInk && !daybook.hasJobs
    }

    func bootstrap() async {
        if didLoad { return }
        didLoad = true
        await loadAndPrepare(seed: true)
    }

    func reload() async {
        didLoad = false
        await bootstrap()
    }

    func flush() async {
        do {
            try await store.flush()
        } catch {
            loadFailed = true
        }
    }

    private func loadAndPrepare(seed: Bool) async {
        loadFailed = false
        armSpinner()
        defer { clearSpinner() }
        let loaded = await store.load()
        apply(loaded.daybook, warning: loaded.warning)
        if seed {
            do {
                if let seeded = try await store.seedDemoIfNeeded(now: now(), calendar: calendar) {
                    apply(seeded, warning: nil)
                }
            } catch {
                loadFailed = true
                return
            }
        }
        prepareAfterLoad()
    }

    func finishOnboarding() async {
        let next = await store.setOnboardingComplete(true)
        apply(next)
        showOnboarding = false
        applyReview()
    }

    func rerunOnboarding() {
        showOnboarding = true
        selectedTab = .expenses
    }

    func selectDay(_ daykey: Daykey) {
        guard daykey <= today else { return }
        resignKeyboard()
        visibleMonth = daykey
        selectedDay = daykey
        fault = nil
        if daybook.hasJobs {
            prepareReadyDraft()
        } else {
            showJobDraft = true
        }
    }

    func pageMonth(_ delta: Int) {
        resignKeyboard()
        visibleMonth = MonthLattice.shifted(visibleMonth, months: delta, calendar: calendar)
        if let selectedDay, !selectedDay.sameMonth(as: visibleMonth) {
            self.selectedDay = nil
        }
    }

    func selectKind(_ kind: InkKind) {
        resignKeyboard()
        self.kind = kind
        fault = nil
        if kind == .miles {
            prefillEndMilesIfNeeded()
        }
    }

    func selectJob(_ id: UUID) {
        resignKeyboard()
        jobID = id
        fault = nil
        if kind == .miles {
            prefillEndMilesIfNeeded(force: true)
        }
    }

    func openTodayBlotter() {
        openDayBlotter(today)
    }

    func openDayBlotter(_ day: Daykey) {
        selectedTab = .expenses
        selectDay(day)
        visibleMonth = day
    }

    func openCashOnToday() {
        selectKind(.cash)
        openTodayBlotter()
    }

    func openMilesOnToday() {
        selectKind(.miles)
        openTodayBlotter()
    }

    func openChain() {
        showChain = true
    }

    func openBooksTap(_ tap: BooksTap) {
        switch tap {
        case .day(let day):
            openDayBlotter(day)
        case .cash:
            openCashOnToday()
        case .miles:
            openMilesOnToday()
        case .job(let id):
            selectJob(id)
            openChain()
        }
    }

    func fileDraft() async {
        await performFile()
    }

    func addJob() async {
        await performAddJob()
    }

    func exportBooks() async {
        await performExport()
    }

    func resetAll() async {
        await performReset()
    }

    func clearPulse() {
        filedPulse = false
    }

    func noteBecameActive() {
        if let selectedDay, selectedDay > today {
            self.selectedDay = today
            visibleMonth = today
        }
        objectWillChange.send()
    }

    func rejectNegativeDrafts() {
        if let value = BlotterFigures.parse(amountText), value < 0 {
            amountText = ""
            fault = .invalidAmount
        }
        if let value = BlotterFigures.parse(endMilesText), value < 0 {
            endMilesText = ""
            fault = .invalidMiles
        }
        if let value = BlotterFigures.parse(jobRateText), value < 0 {
            jobRateText = ""
            fault = .invalidRate
        }
        if let value = BlotterFigures.parse(jobStartText), value < 0 {
            jobStartText = ""
            fault = .invalidMiles
        }
    }

    private func performFile() async {
        guard !isBusy, let line = draftLine, let day = selectedDay else { return }
        isBusy = true
        fault = nil
        defer { isBusy = false }
        do {
            let next = try await store.fileLine(line, on: day)
            apply(next)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            filedPulse = true
            amountText = ""
            endMilesText = ""
            prepareReadyDraft()
        } catch let blotter as BlotterFault {
            fault = blotter
        } catch is CancellationError {
            return
        } catch {
            loadFailed = true
        }
    }

    private func performAddJob() async {
        guard !isBusy else { return }
        let name = jobNameText
        guard let rateValue = BlotterFigures.parse(jobRateText), let rate = try? Rate.make(rateValue) else {
            fault = .invalidRate
            return
        }
        let start: Double
        if jobStartText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            start = 0
        } else if let parsed = BlotterFigures.parse(jobStartText), parsed >= 0 {
            start = parsed
        } else {
            fault = .invalidMiles
            return
        }
        isBusy = true
        fault = nil
        defer { isBusy = false }
        do {
            let next = try await store.addJob(name: name, rate: rate, lastEndMiles: start)
            apply(next)
            jobID = next.jobs.last?.id
            showJobDraft = false
            jobNameText = ""
            jobRateText = ""
            jobStartText = ""
            prepareReadyDraft()
        } catch let blotter as BlotterFault {
            fault = blotter
        } catch is CancellationError {
            return
        } catch {
            loadFailed = true
        }
    }

    private func performExport() async {
        exportFailed = false
        do {
            exportURL = try await store.writeBooksCSV()
        } catch {
            exportFailed = true
        }
    }

    private func performReset() async {
        isBusy = true
        defer { isBusy = false }
        do {
            try await store.resetAllData()
            apply(.empty, warning: nil)
            amountText = ""
            endMilesText = ""
            jobNameText = ""
            jobRateText = ""
            jobStartText = ""
            jobID = nil
            selectedDay = nil
            showJobDraft = false
            exportURL = nil
            showOnboarding = true
            selectedTab = .expenses
            visibleMonth = today
        } catch {
            loadFailed = true
        }
    }

    private func apply(_ daybook: Daybook, warning: DaybookWarning? = nil) {
        self.daybook = daybook
        self.warning = warning
        if let jobID, daybook.job(id: jobID) != nil {
            return
        }
        self.jobID = daybook.jobs.first?.id
    }

    private func prepareAfterLoad() {
        showOnboarding = !daybook.onboardingComplete
        if daybook.hasJobs {
            visibleMonth = today
            selectedDay = today
            prepareReadyDraft()
        }
        applyReview()
    }

    private func prepareReadyDraft() {
        if jobID == nil {
            jobID = daybook.jobs.first?.id
        }
        if amountText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            amountText = "24"
        }
        prefillEndMilesIfNeeded()
        if !daybook.hasJobs {
            showJobDraft = true
        }
    }

    private func prefillEndMilesIfNeeded(force: Bool = false) {
        if force || endMilesText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let next = startMiles + 10
            endMilesText = plainNumber(next)
        }
    }

    private func plainNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = .current
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 0
        formatter.usesGroupingSeparator = false
        return formatter.string(from: NSNumber(value: value)) ?? "0"
    }

    private func applyReview() {
        guard let pane = BlotterLaunch.consume(
            arguments: arguments,
            onboardingComplete: daybook.onboardingComplete,
            consumed: &reviewConsumed
        ) else { return }
        selectedTab = pane.tab
        if pane == .today {
            selectedDay = today
            visibleMonth = today
        }
    }

    private func resignKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }

    private func armSpinner() {
        isBusy = true
        showSpinner = false
        spinnerTask?.cancel()
        spinnerTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 150_000_000)
            guard !Task.isCancelled, let self, self.isBusy else { return }
            self.showSpinner = true
        }
    }

    private func clearSpinner() {
        spinnerTask?.cancel()
        spinnerTask = nil
        isBusy = false
        showSpinner = false
    }
}

/// Role: Trip. One Job's chain head plus the last filed odometer pair.
struct ChainCard: Identifiable, Equatable, Sendable {
    var job: Job
    var lastTrip: Trip?

    var id: UUID { job.id }
}
