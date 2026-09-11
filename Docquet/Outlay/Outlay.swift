import Foundation

/// Role: Outlay. A cash line. Writes amount only. Never moves lastEndMiles. billableAmount is derived at read.
struct Outlay: Equatable, Identifiable, Sendable {
    var id: UUID
    var jobID: UUID
    var daykey: Daykey
    var amount: Double
    var isBillable: Bool

    var billableAmount: Double {
        BillableFold.cash(amount: amount, isBillable: isBillable)
    }

    var personalAmount: Double {
        BillableFold.personalCash(amount: amount, isBillable: isBillable)
    }
}
