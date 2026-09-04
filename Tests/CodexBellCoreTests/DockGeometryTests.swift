import XCTest
@testable import CodexBellCore

final class DockGeometryTests: XCTestCase {
    private let visible = BellRect(x: 100, y: 50, width: 1440, height: 900)

    func testExpandedFramesUseVisibleEdgesAndRequestedOffsets() {
        let geometry = DockGeometry(visibleFrame: visible, panelHeight: 700, verticalFraction: 0.5)
        XCTAssertEqual(geometry.expandedFrame(for: .left), BellRect(x: 100, y: 150, width: 280, height: 700))
        XCTAssertEqual(geometry.expandedFrame(for: .right), BellRect(x: 1260, y: 150, width: 280, height: 700))
    }

    func testCollapsedHandlesStayInsideVisibleFrame() {
        let geometry = DockGeometry(visibleFrame: visible, verticalFraction: 0.5)
        XCTAssertEqual(geometry.handleFrame(for: .left), BellRect(x: 100, y: 466, width: 24, height: 68))
        XCTAssertEqual(geometry.handleFrame(for: .right), BellRect(x: 1516, y: 466, width: 24, height: 68))

        for anchor in DockAnchor.allCases {
            let frame = geometry.handleFrame(for: anchor)
            XCTAssertGreaterThanOrEqual(frame.minX, visible.minX)
            XCTAssertGreaterThanOrEqual(frame.minY, visible.minY)
            XCTAssertLessThanOrEqual(frame.maxX, visible.maxX)
            XCTAssertLessThanOrEqual(frame.maxY, visible.maxY)
        }
    }

    func testUrgentPeekUsesRequiredDepth() {
        let geometry = DockGeometry(visibleFrame: visible, verticalFraction: 0.5)
        XCTAssertEqual(geometry.urgentHandleFrame(for: .left).width, 52)
        XCTAssertEqual(geometry.urgentHandleFrame(for: .right).width, 52)
    }

    func testReleaseMidpointAlwaysChoosesLeftOrRightHalf() {
        let geometry = DockGeometry(visibleFrame: visible)
        XCTAssertEqual(geometry.snapAnchor(forReleaseX: visible.midX - 1), .left)
        XCTAssertEqual(geometry.snapAnchor(forReleaseX: visible.midX), .right)
        XCTAssertEqual(geometry.snapAnchor(forReleaseX: visible.midX + 1), .right)
        XCTAssertEqual(geometry.snapAnchor(for: BellRect(x: 200, y: 330, width: 280, height: 600)), .left)
        XCTAssertEqual(geometry.snapAnchor(for: BellRect(x: 900, y: 330, width: 280, height: 600)), .right)
    }

    func testSmallScreenClampsPanelWidthAndHeight() {
        let small = BellRect(x: 0, y: 0, width: 260, height: 420)
        let geometry = DockGeometry(visibleFrame: small, panelWidth: 304, panelHeight: 700)
        XCTAssertEqual(geometry.expandedSize.width, 260)
        XCTAssertEqual(geometry.expandedSize.height, 327.6, accuracy: 0.0001)
        XCTAssertEqual(geometry.expandedFrame(for: .right).minX, 0)

    }

    func testRehomeUsesNewDisplayVisibleFrame() {
        let geometry = DockGeometry(visibleFrame: BellRect(x: 1600, y: 100, width: 1200, height: 800), verticalFraction: 1)
        let frame = geometry.rehome(anchor: .right)
        XCTAssertEqual(frame.maxX, 2800)
        XCTAssertEqual(frame.maxY, 900)
    }
}
