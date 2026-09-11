import Foundation

/// Role: Chain. Simulator demo daybook. Device never writes this. Key: dcq.demo.v1.
enum DaybookSeed {
    static let lanternLoftID = UUID(uuidString: "11111111-0DC0-4000-8000-000000000001")!
    static let quayDrawingsID = UUID(uuidString: "11111111-0DC0-4000-8000-000000000002")!
    static let ridgeSurveyID = UUID(uuidString: "11111111-0DC0-4000-8000-000000000003")!

    private static func fixed(_ value: String) -> UUID {
        UUID(uuidString: value) ?? UUID()
    }

    static func daybook(now: Date = Date(), calendar: Calendar = .current) throws -> Daybook {
        let today = Daykey.from(now, calendar: calendar)
        let lanternRate = try Rate.make(0.67)
        let quayRate = try Rate.make(0.58)
        let ridgeRate = try Rate.make(0.72)

        var next = try Daybook.empty
            .addingJob(name: "Lantern Loft", rate: lanternRate, id: lanternLoftID)
            .addingJob(name: "Quay Drawings", rate: quayRate, id: quayDrawingsID)
            .addingJob(name: "Ridge Survey", rate: ridgeRate, id: ridgeSurveyID)
            .settingOnboardingComplete(true)

        next = try next.fileLine(
            .outlay(jobID: lanternLoftID, amount: 126, isBillable: true),
            on: today.adding(days: -6, calendar: calendar),
            id: fixed("22222222-0DC0-4000-8000-000000000001")
        )
        next = try next.fileLine(
            .trip(jobID: lanternLoftID, startMiles: nil, endMiles: 18, isBillable: true),
            on: today.adding(days: -5, calendar: calendar),
            id: fixed("22222222-0DC0-4000-8000-000000000002")
        )
        next = try next.fileLine(
            .outlay(jobID: quayDrawingsID, amount: 42.5, isBillable: false),
            on: today.adding(days: -4, calendar: calendar),
            id: fixed("22222222-0DC0-4000-8000-000000000003")
        )
        next = try next.fileLine(
            .trip(jobID: ridgeSurveyID, startMiles: nil, endMiles: 31, isBillable: true),
            on: today.adding(days: -3, calendar: calendar),
            id: fixed("22222222-0DC0-4000-8000-000000000004")
        )
        next = try next.fileLine(
            .outlay(jobID: lanternLoftID, amount: 88, isBillable: true),
            on: today.adding(days: -2, calendar: calendar),
            id: fixed("22222222-0DC0-4000-8000-000000000005")
        )
        next = try next.fileLine(
            .trip(jobID: lanternLoftID, startMiles: nil, endMiles: 41, isBillable: false),
            on: today.adding(days: -1, calendar: calendar),
            id: fixed("22222222-0DC0-4000-8000-000000000006")
        )
        next = try next.fileLine(
            .outlay(jobID: quayDrawingsID, amount: 60, isBillable: true),
            on: today,
            id: fixed("22222222-0DC0-4000-8000-000000000007")
        )
        next = try next.fileLine(
            .trip(jobID: ridgeSurveyID, startMiles: nil, endMiles: 44, isBillable: true),
            on: today,
            id: fixed("22222222-0DC0-4000-8000-000000000008")
        )

        let ready = next.canFile(
            .outlay(jobID: lanternLoftID, amount: 24, isBillable: true)
        )
        guard ready else { return next }
        return next
    }
}
