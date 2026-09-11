import Foundation

/// Role: Chain. Display and parse. Amounts, miles, rates, and month totals go through NumberFormatter.
enum BlotterFigures {
    static func money(_ value: Double, locale: Locale = .current) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = value == value.rounded() ? 0 : 2
        return formatter.string(from: NSNumber(value: value)) ?? "—"
    }

    static func compactMoney(_ value: Double, locale: Locale = .current) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = value == value.rounded() ? 0 : 2
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "—"
    }

    static func miles(_ value: Double, locale: Locale = .current) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 0
        let number = formatter.string(from: NSNumber(value: value)) ?? "—"
        return "\(number) mi"
    }

    static func rate(_ value: Double, locale: Locale = .current) -> String {
        "\(money(value, locale: locale))/mi"
    }

    static func dayNumber(_ value: Int, locale: Locale = .current) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "—"
    }

    static func parse(_ text: String, locale: Locale = .current) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        guard let number = formatter.number(from: trimmed)?.doubleValue, number.isFinite else { return nil }
        return number
    }

    static func monthTitle(_ daykey: Daykey, calendar: Calendar, locale: Locale = .current) -> String {
        guard let date = MonthLattice.date(daykey, calendar: calendar) else { return "—" }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.setLocalizedDateFormatFromTemplate("yMMMM")
        return formatter.string(from: date)
    }

    static func dayTitle(_ daykey: Daykey, calendar: Calendar, locale: Locale = .current) -> String {
        guard let date = MonthLattice.date(daykey, calendar: calendar) else { return "—" }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.setLocalizedDateFormatFromTemplate("MMMMd")
        return formatter.string(from: date)
    }

    static func weekdayLetters(calendar: Calendar, locale: Locale = .current) -> [String] {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        let symbols = formatter.veryShortWeekdaySymbols ?? ["S", "M", "T", "W", "T", "F", "S"]
        let first = max(0, calendar.firstWeekday - 1)
        return (0 ..< 7).map { symbols[(first + $0) % symbols.count] }
    }
}
