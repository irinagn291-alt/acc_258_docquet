import Foundation

/// Role: Rate. Cash per mile snapshotted onto a Trip at file time. Later Job rate edits never rewrite old miles.
struct Rate: Equatable, Hashable, Sendable {
    var perMile: Double

    static func make(_ perMile: Double) throws -> Rate {
        guard perMile.isFinite, perMile >= 0 else { throw BlotterFault.invalidRate }
        return Rate(perMile: perMile)
    }
}
