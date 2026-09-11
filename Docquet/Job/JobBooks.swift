import Foundation

/// Role: Job. Billed versus personal for one Job. Derived at read; never stored.
struct JobBooks: Equatable, Identifiable, Sendable {
    var jobID: UUID
    var billed: Double
    var personal: Double
    var cashBilled: Double
    var cashPersonal: Double
    var milesBilled: Double
    var milesPersonal: Double

    var id: UUID { jobID }
}

/// Role: Job. One day's billed versus personal fold. Derived at read.
struct MonthDayBook: Equatable, Identifiable, Sendable {
    var daykey: Daykey
    var billed: Double
    var personal: Double
    var cashBilled: Double
    var cashPersonal: Double
    var milesBilled: Double
    var milesPersonal: Double

    var id: Int { daykey.rawValue }
}

/// Role: Job. Cash versus miles billed for one month. Derived at read.
struct MonthMix: Equatable, Sendable {
    var billed: Double
    var personal: Double
    var cashBilled: Double
    var cashPersonal: Double
    var milesBilled: Double
    var milesPersonal: Double
    var cashCount: Int
    var tripCount: Int
}

/// Role: Job. One filed cash or miles line, ready for books ink. Derived at read.
struct BlotterInkLine: Equatable, Identifiable, Sendable {
    enum Kind: String, Sendable {
        case cash
        case miles
    }

    var id: UUID
    var daykey: Daykey
    var jobID: UUID
    var kind: Kind
    var isBillable: Bool
    var billed: Double
    var personal: Double
    var startMiles: Double?
    var endMiles: Double?
    var distance: Double?
    var ratePerMile: Double?
}

/// Role: Job. Next tap from a books row. Opens a day, cash, miles, or a project chain.
enum BooksTap: Equatable, Sendable {
    case day(Daykey)
    case cash
    case miles
    case job(UUID)
}
