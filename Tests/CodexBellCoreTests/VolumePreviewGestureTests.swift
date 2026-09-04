import XCTest
@testable import CodexBellCore

final class VolumePreviewGestureTests: XCTestCase {
    func testManyUpdatesProduceExactlyOnePreviewAtGestureEnd() {
        var gate = VolumePreviewGesture()
        gate.begin()
        gate.update()
        gate.update()
        XCTAssertTrue(gate.end())
        XCTAssertFalse(gate.end())
    }

    func testClickReleaseWithoutMeaningfulChangeMayPreviewOnce() {
        var gate = VolumePreviewGesture()
        gate.begin()
        XCTAssertTrue(gate.end())
        XCTAssertFalse(gate.end())
    }
}
