import XCTest
@testable import Docquet

final class BlotterLaunchTests: XCTestCase {
    func test_readsOnceAfterOnboarding() {
        var consumed = false
        XCTAssertNil(
            BlotterLaunch.consume(
                arguments: ["-ReviewScreen", "log"],
                onboardingComplete: false,
                consumed: &consumed
            )
        )
        XCTAssertFalse(consumed)

        let first = BlotterLaunch.consume(
            arguments: ["app", "-ReviewScreen", "log"],
            onboardingComplete: true,
            consumed: &consumed
        )
        XCTAssertEqual(first, .log)
        XCTAssertEqual(first?.tab, .balance)
        XCTAssertTrue(consumed)
        XCTAssertNil(
            BlotterLaunch.consume(
                arguments: ["-ReviewScreen", "goals"],
                onboardingComplete: true,
                consumed: &consumed
            )
        )
    }

    func test_threeKeysAreDistinctScreens() {
        XCTAssertEqual(ReviewPane.today.rawValue, "today")
        XCTAssertEqual(ReviewPane.log.rawValue, "log")
        XCTAssertEqual(ReviewPane.goals.rawValue, "goals")
        XCTAssertNotEqual(ReviewPane.today, ReviewPane.log)
        XCTAssertNotEqual(ReviewPane.log, ReviewPane.goals)
        XCTAssertNotEqual(ReviewPane.today, ReviewPane.goals)
        XCTAssertEqual(ReviewPane.today.tab, .expenses)
        XCTAssertEqual(ReviewPane.log.tab, .balance)
        XCTAssertEqual(ReviewPane.goals.tab, .settings)
        XCTAssertNotEqual(ReviewPane.today.tab, ReviewPane.log.tab)
        XCTAssertNotEqual(ReviewPane.log.tab, ReviewPane.goals.tab)
        XCTAssertNotEqual(ReviewPane.today.tab, ReviewPane.goals.tab)
        XCTAssertEqual(BlotterTab.allCases.count, 3)
        XCTAssertFalse(BlotterTab.allCases.map(\.rawValue).contains("game"))

        var consumed = false
        XCTAssertEqual(
            BlotterLaunch.consume(
                arguments: ["-ReviewScreen", "today"],
                onboardingComplete: true,
                consumed: &consumed
            ),
            .today
        )
        consumed = false
        XCTAssertEqual(
            BlotterLaunch.consume(
                arguments: ["-ReviewScreen", "goals"],
                onboardingComplete: true,
                consumed: &consumed
            ),
            .goals
        )
    }

    func test_unknownKeyIsIgnored() {
        var consumed = false
        XCTAssertNil(
            BlotterLaunch.consume(
                arguments: ["-ReviewScreen", "aura"],
                onboardingComplete: true,
                consumed: &consumed
            )
        )
        XCTAssertTrue(consumed)
    }
}
