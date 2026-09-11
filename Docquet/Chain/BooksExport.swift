import Foundation

/// Role: Chain. Local CSV of the books. FileManager writes atomically; there is no network client.
enum BooksExport {
    static func csv(from daybook: Daybook) -> String {
        var rows = ["daykey,kind,job,amount,distance,rate,billable,billableAmount,startMiles,endMiles"]
        let names = Dictionary(uniqueKeysWithValues: daybook.jobs.map { ($0.id, $0.name) })
        let outlays = daybook.outlays.sorted { lhs, rhs in
            if lhs.daykey != rhs.daykey { return lhs.daykey < rhs.daykey }
            return lhs.id.uuidString < rhs.id.uuidString
        }
        let trips = daybook.trips.sorted { lhs, rhs in
            if lhs.daykey != rhs.daykey { return lhs.daykey < rhs.daykey }
            return lhs.id.uuidString < rhs.id.uuidString
        }
        for outlay in outlays {
            let job = names[outlay.jobID] ?? ""
            rows.append(
                [
                    "\(outlay.daykey.rawValue)",
                    "outlay",
                    field(job),
                    figure(outlay.amount),
                    "",
                    "",
                    outlay.isBillable ? "1" : "0",
                    figure(outlay.billableAmount),
                    "",
                    "",
                ].joined(separator: ",")
            )
        }
        for trip in trips {
            let job = names[trip.jobID] ?? ""
            rows.append(
                [
                    "\(trip.daykey.rawValue)",
                    "trip",
                    field(job),
                    "",
                    figure(trip.distance),
                    figure(trip.snapshottedRate.perMile),
                    trip.isBillable ? "1" : "0",
                    figure(trip.billableAmount),
                    figure(trip.startMiles),
                    figure(trip.endMiles),
                ].joined(separator: ",")
            )
        }
        return rows.joined(separator: "\n") + "\n"
    }

    private static func field(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return value
    }

    private static func figure(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 8
        formatter.minimumFractionDigits = 0
        formatter.usesGroupingSeparator = false
        return formatter.string(from: NSNumber(value: value)) ?? "0"
    }
}
