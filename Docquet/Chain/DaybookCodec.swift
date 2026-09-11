import Foundation

/// Role: Chain. Preference keys. Snapshot is JSON Data under dcq.daybook.v1. Demo is Simulator-only.
enum DaybookKey {
    static let snapshot = "dcq.daybook.v1"
    static let backup = "dcq.daybook.v1.backup"
    static let demo = "dcq.demo.v1"
}

/// Role: Chain. Codable root document. schemaVersion from 1. billableAmount and month buckets are never stored.
struct DaybookLedger: Equatable, Sendable {
    var schemaVersion: Int
    var daybook: Daybook
}

/// Role: Chain. schemaVersion switch and daybook ↔ JSON mapping. UserDefaults never sees Job raw.
enum DaybookCodec {
    static let currentSchema = 1

    enum Failure: Error, Equatable {
        case unsupportedSchema(Int)
        case corrupt
    }

    static func encode(_ ledger: DaybookLedger) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(RootDocument.from(ledger))
    }

    static func decode(_ data: Data) throws -> DaybookLedger {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .useDefaultKeys
        let probe: SchemaProbe
        do {
            probe = try decoder.decode(SchemaProbe.self, from: data)
        } catch {
            throw Failure.corrupt
        }
        switch probe.schemaVersion {
        case 1:
            do {
                return try decoder.decode(RootDocument.self, from: data).asLedger()
            } catch let failure as Failure {
                throw failure
            } catch {
                throw Failure.corrupt
            }
        default:
            throw Failure.unsupportedSchema(probe.schemaVersion)
        }
    }

    static func committed(from daybook: Daybook) -> DaybookLedger {
        DaybookLedger(schemaVersion: currentSchema, daybook: daybook)
    }
}

private struct SchemaProbe: Decodable {
    var schemaVersion: Int
}

private struct RootDocument: Codable {
    var schemaVersion: Int
    var onboardingComplete: Bool
    var jobs: [JobDocument]
    var outlays: [OutlayDocument]
    var trips: [TripDocument]

    static func from(_ ledger: DaybookLedger) -> RootDocument {
        RootDocument(
            schemaVersion: DaybookCodec.currentSchema,
            onboardingComplete: ledger.daybook.onboardingComplete,
            jobs: ledger.daybook.jobs.map(JobDocument.init(job:)),
            outlays: ledger.daybook.outlays.map(OutlayDocument.init(outlay:)),
            trips: ledger.daybook.trips.map(TripDocument.init(trip:))
        )
    }

    func asLedger() throws -> DaybookLedger {
        DaybookLedger(
            schemaVersion: schemaVersion,
            daybook: Daybook(
                onboardingComplete: onboardingComplete,
                jobs: try jobs.map { try $0.asJob() },
                outlays: try outlays.map { try $0.asOutlay() },
                trips: try trips.map { try $0.asTrip() }
            )
        )
    }
}

private struct JobDocument: Codable {
    var id: UUID
    var name: String
    var ratePerMile: Double
    var lastEndMiles: Double

    init(job: Job) {
        id = job.id
        name = job.name
        ratePerMile = job.rate.perMile
        lastEndMiles = job.lastEndMiles
    }

    func asJob() throws -> Job {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw DaybookCodec.Failure.corrupt }
        let rate: Rate
        do {
            rate = try Rate.make(ratePerMile)
        } catch {
            throw DaybookCodec.Failure.corrupt
        }
        guard lastEndMiles.isFinite, lastEndMiles >= 0 else { throw DaybookCodec.Failure.corrupt }
        return Job(id: id, name: trimmed, rate: rate, lastEndMiles: lastEndMiles)
    }
}

private struct OutlayDocument: Codable {
    var id: UUID
    var jobID: UUID
    var daykey: Int
    var amount: Double
    var isBillable: Bool

    init(outlay: Outlay) {
        id = outlay.id
        jobID = outlay.jobID
        daykey = outlay.daykey.rawValue
        amount = outlay.amount
        isBillable = outlay.isBillable
    }

    func asOutlay() throws -> Outlay {
        guard amount.isFinite, amount > 0 else { throw DaybookCodec.Failure.corrupt }
        return Outlay(
            id: id,
            jobID: jobID,
            daykey: Daykey(rawValue: daykey),
            amount: amount,
            isBillable: isBillable
        )
    }
}

private struct TripDocument: Codable {
    var id: UUID
    var jobID: UUID
    var daykey: Int
    var startMiles: Double
    var endMiles: Double
    var snapshottedRate: Double
    var isBillable: Bool

    init(trip: Trip) {
        id = trip.id
        jobID = trip.jobID
        daykey = trip.daykey.rawValue
        startMiles = trip.startMiles
        endMiles = trip.endMiles
        snapshottedRate = trip.snapshottedRate.perMile
        isBillable = trip.isBillable
    }

    func asTrip() throws -> Trip {
        let rate: Rate
        do {
            rate = try Rate.make(snapshottedRate)
        } catch {
            throw DaybookCodec.Failure.corrupt
        }
        do {
            _ = try OdometerChain.distance(startMiles: startMiles, endMiles: endMiles)
        } catch {
            throw DaybookCodec.Failure.corrupt
        }
        return Trip(
            id: id,
            jobID: jobID,
            daykey: Daykey(rawValue: daykey),
            startMiles: startMiles,
            endMiles: endMiles,
            snapshottedRate: rate,
            isBillable: isBillable
        )
    }
}
