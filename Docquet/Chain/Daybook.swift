import Foundation

/// Role: Chain. One Daybook owns mutation. Views call fileLine(_:) and never write lastEndMiles or UserDefaults.
struct Daybook: Equatable, Sendable {
    var onboardingComplete: Bool
    var jobs: [Job]
    var outlays: [Outlay]
    var trips: [Trip]

    static let empty = Daybook(
        onboardingComplete: false,
        jobs: [],
        outlays: [],
        trips: []
    )

    var hasJobs: Bool { !jobs.isEmpty }

    var hasInk: Bool { !outlays.isEmpty || !trips.isEmpty }

    func job(id: UUID) -> Job? {
        jobs.first { $0.id == id }
    }

    func nextStartMiles(for jobID: UUID) -> Double {
        job(id: jobID)?.lastEndMiles ?? 0
    }

    func canFile(_ line: BlotterLine) -> Bool {
        do {
            _ = try resolved(line)
            return true
        } catch {
            return false
        }
    }

    /// Files cash or miles. A Trip advances that Job's lastEndMiles. An Outlay skips the chain.
    func fileLine(_ line: BlotterLine, on daykey: Daykey, id: UUID = UUID()) throws -> Daybook {
        let prepared = try resolved(line)
        var next = self
        switch prepared {
        case .outlay(let jobID, let amount, let isBillable):
            next.outlays.append(
                Outlay(id: id, jobID: jobID, daykey: daykey, amount: amount, isBillable: isBillable)
            )
        case .trip(let jobID, let startMiles, let endMiles, let isBillable, let rate):
            next.trips.append(
                Trip(
                    id: id,
                    jobID: jobID,
                    daykey: daykey,
                    startMiles: startMiles,
                    endMiles: endMiles,
                    snapshottedRate: rate,
                    isBillable: isBillable
                )
            )
            if let index = next.jobs.firstIndex(where: { $0.id == jobID }) {
                next.jobs[index].lastEndMiles = endMiles
            }
        }
        return next
    }

    func addingJob(
        name: String,
        rate: Rate,
        id: UUID = UUID(),
        lastEndMiles: Double = 0
    ) throws -> Daybook {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw BlotterFault.emptyName }
        guard lastEndMiles.isFinite, lastEndMiles >= 0 else { throw BlotterFault.invalidMiles }
        var next = self
        next.jobs.append(Job(id: id, name: trimmed, rate: rate, lastEndMiles: lastEndMiles))
        return next
    }

    func settingRate(jobID: UUID, rate: Rate) throws -> Daybook {
        guard let index = jobs.firstIndex(where: { $0.id == jobID }) else {
            throw BlotterFault.unknownJob
        }
        var next = self
        next.jobs[index].rate = rate
        return next
    }

    func settingOnboardingComplete(_ flag: Bool) -> Daybook {
        var next = self
        next.onboardingComplete = flag
        return next
    }

    func monthBuckets(around daykey: Daykey) -> [Daykey: Double] {
        BillableFold.monthBuckets(outlays: outlays, trips: trips, around: daykey)
    }

    func monthBillableTotal(around daykey: Daykey) -> Double {
        monthBuckets(around: daykey).values.reduce(0, +)
    }

    func hasInk(inMonthOf daykey: Daykey) -> Bool {
        outlays.contains { $0.daykey.sameMonth(as: daykey) }
            || trips.contains { $0.daykey.sameMonth(as: daykey) }
    }

    func booksByJob(inMonthOf daykey: Daykey? = nil) -> [JobBooks] {
        jobs.map { job in
            let jobOutlays = outlays.filter { outlay in
                outlay.jobID == job.id && matchesMonth(outlay.daykey, daykey)
            }
            let jobTrips = trips.filter { trip in
                trip.jobID == job.id && matchesMonth(trip.daykey, daykey)
            }
            let cashBilled = jobOutlays.reduce(0) { $0 + $1.billableAmount }
            let cashPersonal = jobOutlays.reduce(0) { $0 + $1.personalAmount }
            let milesBilled = jobTrips.reduce(0) { $0 + $1.billableAmount }
            let milesPersonal = jobTrips.reduce(0) { $0 + $1.personalAmount }
            return JobBooks(
                jobID: job.id,
                billed: cashBilled + milesBilled,
                personal: cashPersonal + milesPersonal,
                cashBilled: cashBilled,
                cashPersonal: cashPersonal,
                milesBilled: milesBilled,
                milesPersonal: milesPersonal
            )
        }
    }

    func outlays(on daykey: Daykey) -> [Outlay] {
        outlays.filter { $0.daykey == daykey }
    }

    func trips(on daykey: Daykey) -> [Trip] {
        trips.filter { $0.daykey == daykey }
    }

    func dayBook(on daykey: Daykey) -> MonthDayBook {
        let dayOutlays = outlays(on: daykey)
        let dayTrips = trips(on: daykey)
        let cashBilled = dayOutlays.reduce(0) { $0 + $1.billableAmount }
        let cashPersonal = dayOutlays.reduce(0) { $0 + $1.personalAmount }
        let milesBilled = dayTrips.reduce(0) { $0 + $1.billableAmount }
        let milesPersonal = dayTrips.reduce(0) { $0 + $1.personalAmount }
        return MonthDayBook(
            daykey: daykey,
            billed: cashBilled + milesBilled,
            personal: cashPersonal + milesPersonal,
            cashBilled: cashBilled,
            cashPersonal: cashPersonal,
            milesBilled: milesBilled,
            milesPersonal: milesPersonal
        )
    }

    func dayBooks(inMonthOf daykey: Daykey) -> [MonthDayBook] {
        var keys = Set<Daykey>()
        for outlay in outlays where outlay.daykey.sameMonth(as: daykey) {
            keys.insert(outlay.daykey)
        }
        for trip in trips where trip.daykey.sameMonth(as: daykey) {
            keys.insert(trip.daykey)
        }
        return keys.sorted().map { dayBook(on: $0) }
    }

    func monthMix(around daykey: Daykey) -> MonthMix {
        let monthOutlays = outlays.filter { $0.daykey.sameMonth(as: daykey) }
        let monthTrips = trips.filter { $0.daykey.sameMonth(as: daykey) }
        let cashBilled = monthOutlays.reduce(0) { $0 + $1.billableAmount }
        let cashPersonal = monthOutlays.reduce(0) { $0 + $1.personalAmount }
        let milesBilled = monthTrips.reduce(0) { $0 + $1.billableAmount }
        let milesPersonal = monthTrips.reduce(0) { $0 + $1.personalAmount }
        return MonthMix(
            billed: cashBilled + milesBilled,
            personal: cashPersonal + milesPersonal,
            cashBilled: cashBilled,
            cashPersonal: cashPersonal,
            milesBilled: milesBilled,
            milesPersonal: milesPersonal,
            cashCount: monthOutlays.count,
            tripCount: monthTrips.count
        )
    }

    func inkLines(inMonthOf daykey: Daykey) -> [BlotterInkLine] {
        let cash = outlays.filter { $0.daykey.sameMonth(as: daykey) }.map { inkLine(from: $0) }
        let miles = trips.filter { $0.daykey.sameMonth(as: daykey) }.map { inkLine(from: $0) }
        return (cash + miles).sorted { lhs, rhs in
            if lhs.daykey != rhs.daykey { return lhs.daykey < rhs.daykey }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    func inkLines(on daykey: Daykey) -> [BlotterInkLine] {
        outlays(on: daykey).map { inkLine(from: $0) } + trips(on: daykey).map { inkLine(from: $0) }
    }

    private func inkLine(from outlay: Outlay) -> BlotterInkLine {
        BlotterInkLine(
            id: outlay.id,
            daykey: outlay.daykey,
            jobID: outlay.jobID,
            kind: .cash,
            isBillable: outlay.isBillable,
            billed: outlay.billableAmount,
            personal: outlay.personalAmount,
            startMiles: nil,
            endMiles: nil,
            distance: nil,
            ratePerMile: nil
        )
    }

    private func inkLine(from trip: Trip) -> BlotterInkLine {
        BlotterInkLine(
            id: trip.id,
            daykey: trip.daykey,
            jobID: trip.jobID,
            kind: .miles,
            isBillable: trip.isBillable,
            billed: trip.billableAmount,
            personal: trip.personalAmount,
            startMiles: trip.startMiles,
            endMiles: trip.endMiles,
            distance: trip.distance,
            ratePerMile: trip.snapshottedRate.perMile
        )
    }

    private func matchesMonth(_ candidate: Daykey, _ month: Daykey?) -> Bool {
        guard let month else { return true }
        return candidate.sameMonth(as: month)
    }

    private enum Prepared: Equatable {
        case outlay(jobID: UUID, amount: Double, isBillable: Bool)
        case trip(jobID: UUID, startMiles: Double, endMiles: Double, isBillable: Bool, rate: Rate)
    }

    private func resolved(_ line: BlotterLine) throws -> Prepared {
        switch line {
        case .outlay(let jobID, let amount, let isBillable):
            guard jobs.contains(where: { $0.id == jobID }) else { throw BlotterFault.unknownJob }
            guard amount.isFinite, amount > 0 else { throw BlotterFault.invalidAmount }
            return .outlay(jobID: jobID, amount: amount, isBillable: isBillable)
        case .trip(let jobID, let startMiles, let endMiles, let isBillable):
            guard let job = job(id: jobID) else { throw BlotterFault.unknownJob }
            let start = startMiles ?? job.lastEndMiles
            _ = try OdometerChain.distance(startMiles: start, endMiles: endMiles)
            return .trip(
                jobID: jobID,
                startMiles: start,
                endMiles: endMiles,
                isBillable: isBillable,
                rate: job.rate
            )
        }
    }
}
