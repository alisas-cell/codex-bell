import XCTest
@testable import CodexBellCore

final class VolumePreviewDebouncerTests: XCTestCase {
    func testFiveRapidInteractionsProduceOneLatestPreview() throws {
        var debouncer = VolumePreviewDebouncer()
        let requests = [0.50, 0.60, 0.72, 0.80, 0.75].map { debouncer.schedule(volume: $0) }

        for request in requests.dropLast() {
            XCTAssertNil(debouncer.consume(request))
        }
        let emission = try XCTUnwrap(debouncer.consume(requests.last!))
        XCTAssertEqual(emission.volume, 0.75, accuracy: 0.0001)
        XCTAssertFalse(debouncer.hasPendingPreview)
    }

    func testSingleInteractionProducesOnePreview() throws {
        var debouncer = VolumePreviewDebouncer()
        let request = debouncer.schedule(volume: 0.64)
        let emission = try XCTUnwrap(debouncer.consume(request))
        XCTAssertEqual(emission.volume, 0.64, accuracy: 0.0001)
        XCTAssertNil(debouncer.consume(request))
    }

    func testTwoSeparatedBurstsProduceTwoPreviews() {
        var debouncer = VolumePreviewDebouncer()
        let first = debouncer.schedule(volume: 0.4)
        XCTAssertNotNil(debouncer.consume(first))
        let second = debouncer.schedule(volume: 0.9)
        XCTAssertNotNil(debouncer.consume(second))
    }

    func testDebounceDurationIsHalfASecond() {
        XCTAssertEqual(VolumePreviewDebouncer.delay, 0.5, accuracy: 0.0001)
    }
}
