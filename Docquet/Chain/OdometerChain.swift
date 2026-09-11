import Foundation

/// Role: Chain. Distance is end minus start. End below start is refused. A cash Outlay never calls this.
enum OdometerChain {
    static func distance(startMiles: Double, endMiles: Double) throws -> Double {
        guard startMiles.isFinite, endMiles.isFinite else { throw BlotterFault.invalidMiles }
        guard endMiles >= startMiles else { throw BlotterFault.endBelowStart }
        return endMiles - startMiles
    }
}
