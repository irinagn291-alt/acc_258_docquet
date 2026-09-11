import Foundation

/// Role: Chain. Typed faults of fileLine and Job writes. Views map these; they never write lastEndMiles.
enum BlotterFault: Error, Equatable, Sendable {
    case unknownJob
    case invalidAmount
    case invalidMiles
    case endBelowStart
    case emptyName
    case invalidRate
}

/// Role: Chain. Recoverable load outcome. Never crash on a corrupt snapshot.
enum DaybookWarning: Equatable, Sendable {
    case recoveredFromBackup
    case startedEmpty
}
