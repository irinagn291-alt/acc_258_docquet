import Foundation

/// Role: Chain. Day key as Int YYYYMMDD from Calendar.startOfDay. Never a Date dictionary key.
struct Daykey: RawRepresentable, Hashable, Sendable, Comparable {
    let rawValue: Int

    init(rawValue: Int) {
        self.rawValue = rawValue
    }

    var year: Int { rawValue / 10_000 }
    var month: Int { (rawValue / 100) % 100 }
    var day: Int { rawValue % 100 }

    static func from(_ date: Date, calendar: Calendar) -> Daykey {
        let start = calendar.startOfDay(for: date)
        let parts = calendar.dateComponents([.year, .month, .day], from: start)
        let year = parts.year ?? 1970
        let month = parts.month ?? 1
        let day = parts.day ?? 1
        return Daykey(rawValue: year * 10_000 + month * 100 + day)
    }

    static func < (lhs: Daykey, rhs: Daykey) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    func sameMonth(as other: Daykey) -> Bool {
        year == other.year && month == other.month
    }

    func adding(days: Int, calendar: Calendar) -> Daykey {
        var parts = DateComponents()
        parts.year = year
        parts.month = month
        parts.day = day
        let base = calendar.date(from: parts) ?? Date(timeIntervalSince1970: 0)
        let shifted = calendar.date(byAdding: .day, value: days, to: base) ?? base
        return Daykey.from(shifted, calendar: calendar)
    }
}
