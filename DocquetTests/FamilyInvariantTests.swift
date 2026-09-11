import XCTest
@testable import Docquet

final class FamilyInvariantTests: XCTestCase {
    func test_familyInvariant_billableAmountIsZeroWhenPersonal_mileageIsDistanceTimesRate_monthBucketsByDay() throws {
        let rate = try Rate.make(0.5)
        XCTAssertEqual(BillableFold.cash(amount: 80, isBillable: true), 80)
        XCTAssertEqual(BillableFold.cash(amount: 80, isBillable: false), 0)
        XCTAssertEqual(BillableFold.personalCash(amount: 80, isBillable: false), 80)
        XCTAssertEqual(BillableFold.personalCash(amount: 80, isBillable: true), 0)

        XCTAssertEqual(BillableFold.miles(distance: 12, rate: rate, isBillable: true), 6)
        XCTAssertEqual(BillableFold.miles(distance: 12, rate: rate, isBillable: false), 0)
        XCTAssertEqual(BillableFold.personalMiles(distance: 12, rate: rate, isBillable: false), 6)
        XCTAssertEqual(BillableFold.personalMiles(distance: 12, rate: rate, isBillable: true), 0)

        let jobID = UUID(uuidString: "AAAAAAAA-0001-4000-8000-000000000001")!
        let dayA = Daykey(rawValue: 20260903)
        let dayB = Daykey(rawValue: 20260904)
        let otherMonth = Daykey(rawValue: 20260831)
        let outlays = [
            Outlay(id: UUID(), jobID: jobID, daykey: dayA, amount: 40, isBillable: true),
            Outlay(id: UUID(), jobID: jobID, daykey: dayA, amount: 10, isBillable: false),
            Outlay(id: UUID(), jobID: jobID, daykey: otherMonth, amount: 99, isBillable: true),
        ]
        let trips = [
            Trip(
                id: UUID(),
                jobID: jobID,
                daykey: dayB,
                startMiles: 10,
                endMiles: 20,
                snapshottedRate: rate,
                isBillable: true
            ),
            Trip(
                id: UUID(),
                jobID: jobID,
                daykey: dayB,
                startMiles: 20,
                endMiles: 24,
                snapshottedRate: rate,
                isBillable: false
            ),
        ]
        let buckets = BillableFold.monthBuckets(outlays: outlays, trips: trips, around: dayA)
        XCTAssertEqual(buckets[dayA], 40)
        XCTAssertEqual(buckets[dayB], 5)
        XCTAssertNil(buckets[otherMonth])
        XCTAssertEqual(buckets.values.reduce(0, +), 45)

        XCTAssertEqual(outlays[0].billableAmount, 40)
        XCTAssertEqual(outlays[1].billableAmount, 0)
        XCTAssertEqual(trips[0].billableAmount, 5)
        XCTAssertEqual(trips[1].billableAmount, 0)
        XCTAssertEqual(trips[0].distance, 10)
    }
}
