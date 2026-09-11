import Foundation

/// Role: Trip. An odometer pair. Distance is end minus start. The Job Rate is snapshotted at file. billableAmount is derived.
struct Trip: Equatable, Identifiable, Sendable {
    var id: UUID
    var jobID: UUID
    var daykey: Daykey
    var startMiles: Double
    var endMiles: Double
    var snapshottedRate: Rate
    var isBillable: Bool

    var distance: Double {
        endMiles - startMiles
    }

    var billableAmount: Double {
        BillableFold.miles(distance: distance, rate: snapshottedRate, isBillable: isBillable)
    }

    var personalAmount: Double {
        BillableFold.personalMiles(distance: distance, rate: snapshottedRate, isBillable: isBillable)
    }
}
