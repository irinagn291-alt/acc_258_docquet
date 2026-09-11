import Foundation

/// Role: Chain. One cell on the Expenses month grid. Identity is the daykey, never a row index.
struct MonthCell: Identifiable, Equatable, Sendable {
    var daykey: Daykey
    var weekdayColumn: Int
    var isToday: Bool
    var isFuture: Bool
    var billable: Double
    var hasInk: Bool

    var id: Int { daykey.rawValue }
}

/// Role: Chain. Builds the calendar-first month from Daykey Int YYYYMMDD and Calendar.startOfDay.
enum MonthLattice {
    static func date(_ daykey: Daykey, calendar: Calendar) -> Date? {
        var parts = DateComponents()
        parts.year = daykey.year
        parts.month = daykey.month
        parts.day = daykey.day
        return calendar.date(from: parts).map { calendar.startOfDay(for: $0) }
    }

    static func shifted(_ daykey: Daykey, months: Int, calendar: Calendar) -> Daykey {
        guard let start = date(Daykey(rawValue: daykey.year * 10_000 + daykey.month * 100 + 1), calendar: calendar),
              let next = calendar.date(byAdding: .month, value: months, to: start)
        else { return daykey }
        return Daykey.from(next, calendar: calendar)
    }

    static func cells(
        monthOf: Daykey,
        today: Daykey,
        buckets: [Daykey: Double],
        ink: Set<Int>,
        calendar: Calendar
    ) -> [MonthCell] {
        let firstKey = Daykey(rawValue: monthOf.year * 10_000 + monthOf.month * 100 + 1)
        guard let start = date(firstKey, calendar: calendar),
              let range = calendar.range(of: .day, in: .month, for: start)
        else { return [] }
        let weekday = calendar.component(.weekday, from: start)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        return range.map { day in
            let key = Daykey(rawValue: monthOf.year * 10_000 + monthOf.month * 100 + day)
            return MonthCell(
                daykey: key,
                weekdayColumn: (leading + day - 1) % 7,
                isToday: key == today,
                isFuture: key > today,
                billable: buckets[key] ?? 0,
                hasInk: ink.contains(key.rawValue)
            )
        }
    }

    static func weeks(_ cells: [MonthCell]) -> [[MonthCell?]] {
        guard let first = cells.first else { return [] }
        var slots: [MonthCell?] = Array(repeating: nil, count: first.weekdayColumn)
        slots.append(contentsOf: cells.map { Optional($0) })
        while slots.count % 7 != 0 {
            slots.append(nil)
        }
        return stride(from: 0, to: slots.count, by: 7).map { index in
            Array(slots[index ..< (index + 7)])
        }
    }

    static func inkDays(in daybook: Daybook, monthOf: Daykey) -> Set<Int> {
        var days = Set<Int>()
        for outlay in daybook.outlays where outlay.daykey.sameMonth(as: monthOf) {
            days.insert(outlay.daykey.rawValue)
        }
        for trip in daybook.trips where trip.daykey.sameMonth(as: monthOf) {
            days.insert(trip.daykey.rawValue)
        }
        return days
    }
}
