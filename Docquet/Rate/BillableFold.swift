import Foundation

/// Role: Rate. Family invariant. billableAmount is never stored; month buckets fold it by daykey.
enum BillableFold {
    static func cash(amount: Double, isBillable: Bool) -> Double {
        isBillable ? amount : 0
    }

    static func miles(distance: Double, rate: Rate, isBillable: Bool) -> Double {
        isBillable ? distance * rate.perMile : 0
    }

    static func personalCash(amount: Double, isBillable: Bool) -> Double {
        isBillable ? 0 : amount
    }

    static func personalMiles(distance: Double, rate: Rate, isBillable: Bool) -> Double {
        isBillable ? 0 : distance * rate.perMile
    }

    static func monthBuckets(outlays: [Outlay], trips: [Trip], around daykey: Daykey) -> [Daykey: Double] {
        var buckets: [Daykey: Double] = [:]
        for outlay in outlays where outlay.daykey.sameMonth(as: daykey) {
            buckets[outlay.daykey, default: 0] += outlay.billableAmount
        }
        for trip in trips where trip.daykey.sameMonth(as: daykey) {
            buckets[trip.daykey, default: 0] += trip.billableAmount
        }
        return buckets
    }
}
