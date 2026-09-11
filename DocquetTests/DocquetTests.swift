import XCTest
@testable import Docquet

final class DocquetTests: XCTestCase {
    func test_appModuleImports() {
        XCTAssertEqual(String(describing: DocquetApp.self), "DocquetApp")
        XCTAssertEqual(DaybookKey.snapshot, "dcq.daybook.v1")
        XCTAssertEqual(DaybookKey.demo, "dcq.demo.v1")
        XCTAssertEqual(BlotterInk.face, "SF Pro")
        XCTAssertEqual(BlotterFace.face, "SF Pro")
        XCTAssertEqual(BlotterInk.Hex.background, "#F7FCF3")
        XCTAssertEqual(BlotterInk.Hex.surface, "#FEFEFD")
        XCTAssertEqual(BlotterInk.Hex.ink, "#263918")
        XCTAssertEqual(BlotterInk.Hex.accent, "#65C322")
        XCTAssertEqual(BlotterInk.Hex.muted, "#5C7C46")
        XCTAssertEqual(BlotterFace.Step.allCases.count, 6)
        XCTAssertEqual(BlotterFace.cardRadius, 12)
        XCTAssertEqual(BlotterFace.chipRadius, 8)
    }
}
