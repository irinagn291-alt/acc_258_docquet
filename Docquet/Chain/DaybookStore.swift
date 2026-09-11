import Foundation

/// Role: Chain. The only persistence seam. Views observe the daybook; they never touch UserDefaults or files.
protocol DaybookStoring: Sendable {
    func load() async -> (daybook: Daybook, warning: DaybookWarning?)
    func snapshot() async -> Daybook
    func fileLine(_ line: BlotterLine, on daykey: Daykey) async throws -> Daybook
    func addJob(name: String, rate: Rate, lastEndMiles: Double) async throws -> Daybook
    func setRate(jobID: UUID, rate: Rate) async throws -> Daybook
    func setOnboardingComplete(_ flag: Bool) async -> Daybook
    func flush() async throws
    func resetAllData() async throws
    func seedDemoIfNeeded(now: Date, calendar: Calendar) async throws -> Daybook?
    func writeBooksCSV() async throws -> URL
}

/// Role: Chain. Memory is the source of truth. UserDefaults dcq.daybook.v1 plus an Application Support file are projections.
actor DaybookStore: DaybookStoring {
    private let directory: URL
    private let defaultsSuiteName: String?
    private let fileManager: FileManager
    private let writeDelayNanoseconds: UInt64

    private var latest: Daybook = .empty
    private var dirty = false
    private var writeTask: Task<Void, Never>?
    private(set) var warning: DaybookWarning?
    private(set) var lastWriteError: String?

    init(
        directory: URL,
        defaultsSuiteName: String? = nil,
        fileManager: FileManager = .default,
        writeDelayNanoseconds: UInt64 = 300_000_000
    ) {
        self.directory = directory
        self.defaultsSuiteName = defaultsSuiteName
        self.fileManager = fileManager
        self.writeDelayNanoseconds = writeDelayNanoseconds
    }

    static func applicationSupportDirectory(fileManager: FileManager = .default) throws -> URL {
        let root = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return root.appendingPathComponent("Docquet", isDirectory: true)
    }

    func load() async -> (daybook: Daybook, warning: DaybookWarning?) {
        warning = nil
        latest = .empty
        dirty = false
        let defaults = preferenceDefaults()
        if let data = defaults.data(forKey: DaybookKey.snapshot), let daybook = decode(data) {
            latest = daybook
            return (latest, nil)
        }
        if let daybook = decodeFile(fileURL) {
            latest = daybook
            return (latest, nil)
        }
        if let data = defaults.data(forKey: DaybookKey.backup), let daybook = decode(data) {
            latest = daybook
            warning = .recoveredFromBackup
            return (latest, warning)
        }
        if let daybook = decodeFile(backupURL) {
            latest = daybook
            warning = .recoveredFromBackup
            return (latest, warning)
        }
        let hadPayload = defaults.data(forKey: DaybookKey.snapshot) != nil
            || fileManager.fileExists(atPath: fileURL.path)
        if hadPayload {
            warning = .startedEmpty
        }
        return (latest, warning)
    }

    func snapshot() async -> Daybook {
        latest
    }

    func fileLine(_ line: BlotterLine, on daykey: Daykey) async throws -> Daybook {
        try Task.checkCancellation()
        latest = try latest.fileLine(line, on: daykey)
        try persistCommitted()
        return latest
    }

    func addJob(name: String, rate: Rate, lastEndMiles: Double = 0) async throws -> Daybook {
        try Task.checkCancellation()
        latest = try latest.addingJob(name: name, rate: rate, lastEndMiles: lastEndMiles)
        try persistCommitted()
        return latest
    }

    func setRate(jobID: UUID, rate: Rate) async throws -> Daybook {
        latest = try latest.settingRate(jobID: jobID, rate: rate)
        dirty = true
        scheduleFlush()
        return latest
    }

    func setOnboardingComplete(_ flag: Bool) async -> Daybook {
        latest = latest.settingOnboardingComplete(flag)
        dirty = true
        scheduleFlush()
        return latest
    }

    func flush() async throws {
        writeTask?.cancel()
        writeTask = nil
        if dirty {
            try persistCommitted()
        }
    }

    func resetAllData() async throws {
        writeTask?.cancel()
        writeTask = nil
        latest = .empty
        dirty = false
        warning = nil
        lastWriteError = nil
        let defaults = preferenceDefaults()
        defaults.removeObject(forKey: DaybookKey.snapshot)
        defaults.removeObject(forKey: DaybookKey.backup)
        if fileManager.fileExists(atPath: directory.path) {
            try fileManager.removeItem(at: directory)
        }
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func seedDemoIfNeeded(now: Date = Date(), calendar: Calendar = .current) async throws -> Daybook? {
        #if targetEnvironment(simulator)
        let defaults = preferenceDefaults()
        guard defaults.object(forKey: DaybookKey.demo) == nil else { return nil }
        latest = try DaybookSeed.daybook(now: now, calendar: calendar)
        try persistCommitted()
        defaults.set(true, forKey: DaybookKey.demo)
        return latest
        #else
        _ = now
        _ = calendar
        return nil
        #endif
    }

    func writeBooksCSV() async throws -> URL {
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("daybook.csv")
        let data = Data(BooksExport.csv(from: latest).utf8)
        try data.write(to: url, options: .atomic)
        return url
    }

    /// File IO stays on this actor, which is not MainActor — the main thread never waits on disk.
    private func persistCommitted() throws {
        let ledger = DaybookCodec.committed(from: latest)
        let data = try DaybookCodec.encode(ledger)
        let defaults = preferenceDefaults()
        if let previous = defaults.data(forKey: DaybookKey.snapshot) {
            defaults.set(previous, forKey: DaybookKey.backup)
        }
        defaults.set(data, forKey: DaybookKey.snapshot)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        if fileManager.fileExists(atPath: fileURL.path) {
            if fileManager.fileExists(atPath: backupURL.path) {
                try? fileManager.removeItem(at: backupURL)
            }
            try? fileManager.copyItem(at: fileURL, to: backupURL)
        }
        try data.write(to: fileURL, options: .atomic)
        dirty = false
        lastWriteError = nil
    }

    private func scheduleFlush() {
        writeTask?.cancel()
        let delay = writeDelayNanoseconds
        writeTask = Task { [weak self] in
            if delay > 0 {
                try? await Task.sleep(nanoseconds: delay)
            }
            guard !Task.isCancelled else { return }
            await self?.flushIfNeeded()
        }
    }

    private func flushIfNeeded() async {
        writeTask = nil
        do {
            if dirty {
                try persistCommitted()
            }
        } catch {
            lastWriteError = String(describing: error)
        }
    }

    private func decode(_ data: Data) -> Daybook? {
        guard let ledger = try? DaybookCodec.decode(data) else { return nil }
        return ledger.daybook
    }

    private func decodeFile(_ url: URL) -> Daybook? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return decode(data)
    }

    private var fileURL: URL {
        directory.appendingPathComponent("daybook.json")
    }

    private var backupURL: URL {
        directory.appendingPathComponent("daybook.json.backup")
    }

    private func preferenceDefaults() -> UserDefaults {
        if let defaultsSuiteName {
            return UserDefaults(suiteName: defaultsSuiteName) ?? .standard
        }
        return .standard
    }
}
