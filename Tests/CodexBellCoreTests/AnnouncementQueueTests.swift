import XCTest
@testable import CodexBellCore

final class AnnouncementQueueTests: XCTestCase {
    private func a(_ turn: String, _ kind: AnnouncementKind, _ generation: Int = 1, at: TimeInterval = 0) -> Announcement {
        Announcement(turnID: turn, kind: kind, identity: TaskIdentity(projectName: turn), generation: generation, createdAt: Date(timeIntervalSince1970: at))
    }

    func testPriorityOrdering() async {
        let queue = AnnouncementQueue()
        await queue.enqueue(a("complete", .completed, at: 1))
        await queue.enqueue(a("failed", .failed, at: 2))
        await queue.enqueue(a("wait", .waitingApproval, at: 3))
        let first = await queue.next()
        XCTAssertEqual(first?.turnID, "wait")
        await queue.markFinished()
        let second = await queue.next()
        XCTAssertEqual(second?.turnID, "failed")
        await queue.markFinished()
        let third = await queue.next()
        XCTAssertEqual(third?.turnID, "complete")
    }

    func testFIFOWithinSamePriority() async {
        let queue = AnnouncementQueue()
        await queue.enqueue(a("one", .completed, at: 1))
        await queue.enqueue(a("two", .completed, at: 2))
        let first = await queue.next()
        XCTAssertEqual(first?.turnID, "one")
        await queue.markFinished()
        let second = await queue.next()
        XCTAssertEqual(second?.turnID, "two")
    }

    func testNextReturnsNilWhileAnotherAnnouncementIsInFlight() async {
        let queue = AnnouncementQueue()
        await queue.enqueue(a("one", .completed))
        await queue.enqueue(a("two", .failed))
        let first = await queue.next()
        XCTAssertNotNil(first)
        let blocked = await queue.next()
        XCTAssertNil(blocked)
        await queue.markFinished()
        let second = await queue.next()
        XCTAssertNotNil(second)
    }

    func testDuplicateStableIDIsSuppressed() async {
        let queue = AnnouncementQueue()
        let item = a("same", .failed, 4)
        await queue.enqueue(item)
        await queue.enqueue(item)
        let count = await queue.pendingCount
        XCTAssertEqual(count, 1)
    }

    func testPendingVolumePreviewIsReplacedWithoutDroppingOrOverlappingRealAlert() async throws {
        let queue = AnnouncementQueue()
        let firstPreview = Announcement(
            turnID: "volume-preview",
            kind: .completed,
            identity: TaskIdentity(projectName: "Codex Bell"),
            generation: 1,
            isTest: true,
            volumeOverride: 0.4
        )
        let finalPreview = Announcement(
            turnID: "volume-preview",
            kind: .completed,
            identity: TaskIdentity(projectName: "Codex Bell"),
            generation: 2,
            isTest: true,
            volumeOverride: 0.8
        )
        await queue.enqueue(firstPreview, replacingPendingWithKey: "volume-preview")
        await queue.enqueue(a("urgent", .waitingApproval))
        await queue.enqueue(finalPreview, replacingPendingWithKey: "volume-preview")
        let pendingCount = await queue.pendingCount
        XCTAssertEqual(pendingCount, 2)

        let realAlert = await queue.next()
        XCTAssertEqual(realAlert?.turnID, "urgent")
        let overlapping = await queue.next()
        XCTAssertNil(overlapping, "A second item must not overlap the in-flight real alert")
        await queue.markFinished()

        let preview = await queue.next()
        XCTAssertEqual(preview?.generation, 2)
        XCTAssertEqual(try XCTUnwrap(preview?.volumeOverride), 0.8, accuracy: 0.0001)
        await queue.markFinished()
        let remaining = await queue.next()
        XCTAssertNil(remaining)
    }
}
