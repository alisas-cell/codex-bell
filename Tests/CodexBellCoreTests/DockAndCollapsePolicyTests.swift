import XCTest
@testable import CodexBellCore

final class DockAndCollapsePolicyTests: XCTestCase {
    func testDockVisibilityMapsOffToAccessoryAndOnToRegular() {
        XCTAssertEqual(DockVisibilityPolicy.activationMode(showInDock: false), .accessory)
        XCTAssertEqual(DockVisibilityPolicy.activationMode(showInDock: true), .regular)
    }

    func testYellowCollapseKeepsLeftOrRightPlacement() {
        XCTAssertEqual(CollapsePlacementPolicy.destination(current: .left), .left)
        XCTAssertEqual(CollapsePlacementPolicy.destination(current: .right), .right)
    }
}
