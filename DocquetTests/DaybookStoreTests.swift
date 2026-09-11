import XCTest
@testable import Docquet

final class DaybookStoreTests: XCTestCase {
    private var directory = FileManager.default.temporaryDirectory
    private var suiteName = ""
    private var defaults = UserDefaults.standard
    private var calendar = Calendar(identifier: .gregorian)
    private var today = Daykey(rawValue: 19700101)

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        suiteName = "dcq.test.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        utc.locale = Locale(identifier: "en_US_POSIX")
        calendar = utc
        today = Daykey.from(instant(2026, 9, 11), calendar: calendar)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
        if !suiteName.isEmpty {
            defaults.removePersistentDomain(forName: suiteName)
        }
    }

    func test_roundTrip_reloadPreservesJobsOutlaysTripsAndChainHead() async throws {
        let store = makeStore()
        _ = await store.load()
        let rate = try Rate.make(0.5)
        _ = try await store.addJob(name: "Lantern Loft", rate: rate, lastEndMiles: 0)
        let snapshot = await store.snapshot()
        let jobID = try XCTUnwrap(snapshot.jobs.first?.id)
        _ = try await store.fileLine(
            .trip(jobID: jobID, startMiles: nil, endMiles: 14, isBillable: true),
            on: today
        )
        _ = try await store.fileLine(
            .outlay(jobID: jobID, amount: 36, isBillable: false),
            on: today
        )
        _ = await store.setOnboardingComplete(true)
        try await store.flush()

        let relaunched = makeStore()
        let loaded = await relaunched.load()
        XCTAssertNil(loaded.warning)
        XCTAssertTrue(loaded.daybook.onboardingComplete)
        XCTAssertEqual(loaded.daybook.job(id: jobID)?.lastEndMiles, 14)
        XCTAssertEqual(loaded.daybook.trips.first?.distance, 14)
        XCTAssertEqual(loaded.daybook.trips.first?.billableAmount, 7)
        XCTAssertEqual(loaded.daybook.outlays.first?.billableAmount, 0)
        XCTAssertEqual(loaded.daybook.outlays.first?.personalAmount, 36)
        XCTAssertNotNil(defaults.data(forKey: DaybookKey.snapshot))
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: directory.appendingPathComponent("daybook.json").path)
        )
    }

    func test_corruptSnapshotFallsBackToBackup() async throws {
        let store = makeStore()
        _ = await store.load()
        let rate = try Rate.make(0.5)
        _ = try await store.addJob(name: "Lantern Loft", rate: rate, lastEndMiles: 0)
        let afterJob = await store.snapshot()
        let jobID = try XCTUnwrap(afterJob.jobs.first?.id)
        _ = try await store.fileLine(
            .outlay(jobID: jobID, amount: 50, isBillable: true),
            on: today
        )
        if let good = defaults.data(forKey: DaybookKey.snapshot) {
            defaults.set(good, forKey: DaybookKey.backup)
        }
        let file = directory.appendingPathComponent("daybook.json")
        let backup = directory.appendingPathComponent("daybook.json.backup")
        if FileManager.default.fileExists(atPath: file.path) {
            try? FileManager.default.removeItem(at: backup)
            try FileManager.default.copyItem(at: file, to: backup)
        }
        defaults.set(Data("{not-json".utf8), forKey: DaybookKey.snapshot)
        try Data("{not-json".utf8).write(to: file)

        let loaded = await makeStore().load()
        XCTAssertEqual(loaded.warning, .recoveredFromBackup)
        XCTAssertEqual(loaded.daybook.outlays.count, 1)
        XCTAssertEqual(loaded.daybook.outlays.first?.amount, 50)
    }

    func test_corruptSnapshotWithoutBackupStartsEmpty() async throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defaults.set(Data("nope".utf8), forKey: DaybookKey.snapshot)
        try Data("nope".utf8).write(to: directory.appendingPathComponent("daybook.json"))
        let loaded = await makeStore().load()
        XCTAssertEqual(loaded.warning, .startedEmpty)
        XCTAssertFalse(loaded.daybook.hasInk)
        XCTAssertFalse(loaded.daybook.onboardingComplete)
    }

    func test_codecSwitchesOnSchemaVersion() throws {
        let daybook = try DaybookSeed.daybook(now: instant(2026, 9, 11), calendar: calendar)
        let ledger = DaybookCodec.committed(from: daybook)
        let data = try DaybookCodec.encode(ledger)
        let decoded = try DaybookCodec.decode(data)
        XCTAssertEqual(decoded.schemaVersion, 1)
        XCTAssertEqual(decoded.daybook.jobs.count, daybook.jobs.count)
        XCTAssertEqual(decoded.daybook.trips.count, daybook.trips.count)
        XCTAssertEqual(
            decoded.daybook.job(id: DaybookSeed.lanternLoftID)?.lastEndMiles,
            daybook.job(id: DaybookSeed.lanternLoftID)?.lastEndMiles
        )

        let future = Data("{\"schemaVersion\":99}".utf8)
        XCTAssertThrowsError(try DaybookCodec.decode(future)) { error in
            XCTAssertEqual(error as? DaybookCodec.Failure, .unsupportedSchema(99))
        }
        XCTAssertThrowsError(try DaybookCodec.decode(Data("[]".utf8))) { error in
            XCTAssertEqual(error as? DaybookCodec.Failure, .corrupt)
        }
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertNil(object["billableAmount"])
        XCTAssertNil(object["monthBuckets"])
    }

    func test_resetAllDataClearsSnapshotAndFiles() async throws {
        let store = makeStore()
        _ = await store.load()
        _ = try await store.addJob(name: "Lantern Loft", rate: Rate.make(0.5), lastEndMiles: 0)
        try await store.resetAllData()
        let loaded = await store.load()
        XCTAssertEqual(loaded.daybook.jobs.count, 0)
        XCTAssertFalse(loaded.daybook.onboardingComplete)
        XCTAssertNil(defaults.data(forKey: DaybookKey.snapshot))
        XCTAssertNil(defaults.data(forKey: DaybookKey.backup))
        let leftovers = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        XCTAssertTrue(leftovers.filter { $0.pathExtension == "json" }.isEmpty)
    }

    func test_writeBooksCSVIsAtomicAndListsFiledLines() async throws {
        let store = makeStore()
        _ = await store.load()
        _ = try await store.addJob(name: "Lantern Loft", rate: Rate.make(0.5), lastEndMiles: 0)
        let afterJob = await store.snapshot()
        let jobID = try XCTUnwrap(afterJob.jobs.first?.id)
        _ = try await store.fileLine(
            .outlay(jobID: jobID, amount: 18, isBillable: true),
            on: today
        )
        let url = try await store.writeBooksCSV()
        let body = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(body.contains("outlay"))
        XCTAssertTrue(body.contains("Lantern Loft"))
        XCTAssertTrue(body.contains("18"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }

    #if targetEnvironment(simulator)
    func test_simulatorSeedWritesOnceAndLeavesFileEnabled() async throws {
        let store = makeStore()
        let first = try await store.seedDemoIfNeeded(now: instant(2026, 9, 11), calendar: calendar)
        let second = try await store.seedDemoIfNeeded(now: instant(2026, 9, 11), calendar: calendar)
        XCTAssertNil(second)
        XCTAssertEqual(first?.onboardingComplete, true)
        XCTAssertEqual(first?.jobs.count, 3)
        XCTAssertGreaterThanOrEqual(first?.outlays.count ?? 0, 3)
        XCTAssertGreaterThanOrEqual(first?.trips.count ?? 0, 3)
        XCTAssertEqual(
            first?.canFile(.outlay(jobID: DaybookSeed.lanternLoftID, amount: 10, isBillable: true)),
            true
        )
        XCTAssertTrue(defaults.bool(forKey: DaybookKey.demo))
        XCTAssertNotNil(defaults.data(forKey: DaybookKey.snapshot))
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: directory.appendingPathComponent("daybook.json").path)
        )
    }
    #endif

    private func makeStore() -> DaybookStore {
        DaybookStore(
            directory: directory,
            defaultsSuiteName: suiteName,
            writeDelayNanoseconds: 0
        )
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
