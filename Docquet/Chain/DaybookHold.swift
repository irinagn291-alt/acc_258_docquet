import Foundation

/// Role: Chain. In-memory daybook for tests. Views never see this type.
actor DaybookHold: DaybookStoring {
    private var latest: Daybook
    private var warning: DaybookWarning?
    private let csvDirectory: URL

    init(
        daybook: Daybook = .empty,
        warning: DaybookWarning? = nil,
        csvDirectory: URL = FileManager.default.temporaryDirectory
    ) {
        self.latest = daybook
        self.warning = warning
        self.csvDirectory = csvDirectory
    }

    func load() async -> (daybook: Daybook, warning: DaybookWarning?) {
        (latest, warning)
    }

    func snapshot() async -> Daybook {
        latest
    }

    func fileLine(_ line: BlotterLine, on daykey: Daykey) async throws -> Daybook {
        latest = try latest.fileLine(line, on: daykey)
        return latest
    }

    func addJob(name: String, rate: Rate, lastEndMiles: Double) async throws -> Daybook {
        latest = try latest.addingJob(name: name, rate: rate, lastEndMiles: lastEndMiles)
        return latest
    }

    func setRate(jobID: UUID, rate: Rate) async throws -> Daybook {
        latest = try latest.settingRate(jobID: jobID, rate: rate)
        return latest
    }

    func setOnboardingComplete(_ flag: Bool) async -> Daybook {
        latest = latest.settingOnboardingComplete(flag)
        return latest
    }

    func flush() async throws {}

    func resetAllData() async throws {
        latest = .empty
        warning = nil
    }

    func seedDemoIfNeeded(now: Date, calendar: Calendar) async throws -> Daybook? {
        _ = now
        _ = calendar
        return nil
    }

    func writeBooksCSV() async throws -> URL {
        let url = csvDirectory.appendingPathComponent("daybook-hold.csv")
        try Data(BooksExport.csv(from: latest).utf8).write(to: url, options: .atomic)
        return url
    }
}
