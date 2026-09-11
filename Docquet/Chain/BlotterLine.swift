import Foundation

/// Role: Chain. The ink a blotter files. Cash writes amount. Miles write an odometer pair.
enum BlotterLine: Equatable, Sendable {
    case outlay(jobID: UUID, amount: Double, isBillable: Bool)
    case trip(jobID: UUID, startMiles: Double?, endMiles: Double, isBillable: Bool)
}

/// Role: Chain. What File will write. Shown on the fused blotter so the next tap sits on content.
struct DraftReady: Equatable, Sendable {
    var figure: String
    var title: String
    var consequence: String
    var chainLine: String
}
