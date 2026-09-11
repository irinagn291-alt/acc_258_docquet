import Foundation

/// Role: Job. A freelance project on the blotter. lastEndMiles is the odometer-chain head. Views never write it.
struct Job: Equatable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var rate: Rate
    var lastEndMiles: Double
}
