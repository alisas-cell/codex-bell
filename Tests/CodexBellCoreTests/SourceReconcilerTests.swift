import XCTest
@testable import CodexBellCore

final class SourceReconcilerTests: XCTestCase {
    private func sourced(
        _ kind: CodexEventKind,
        source: EventSource,
        turn: String = "turn-1",
        at seconds: TimeInterval,
        backfill: Bool = false
    ) -> SourcedCodexEvent {
        SourcedCodexEvent(
            source: source,
            event: CodexEvent(kind: kind, turnID: turn, identity: TaskIdentity(projectName: "Test Project"), occurredAt: Date(timeIntervalSince1970: seconds)),
            receivedAt: Date(timeIntervalSince1970: seconds),
            confidence: source == .appServer ? .authoritative : (source == .hooks ? .direct : .inferred),
            isBackfill: backfill
        )
    }

    func testDuplicateStateAcrossSourcesProducesOneRowAndAnnouncement() {
        var reconciler = SourceReconciler()
        XCTAssertNotNil(reconciler.apply(sourced(.userPromptSubmit, source: .hooks, at: 1)))
        let hookDone = reconciler.apply(sourced(.stop, source: .hooks, at: 40))
        XCTAssertEqual(hookDone?.announcementKind, .completed)

        let authoritativeDuplicate = reconciler.apply(sourced(.stop, source: .appServer, at: 41))
        XCTAssertNil(authoritativeDuplicate?.announcementKind)
        XCTAssertEqual(reconciler.allTasks.count, 1)
        XCTAssertEqual(reconciler.allTasks.first?.state, .completed)
    }

    func testAuthoritativeTerminalStateCanCorrectHookInference() {
        var reconciler = SourceReconciler()
        _ = reconciler.apply(sourced(.userPromptSubmit, source: .hooks, at: 1))
        _ = reconciler.apply(sourced(.stop, source: .hooks, at: 40))
        let correction = reconciler.apply(sourced(.turnFailed, source: .appServer, at: 41))
        XCTAssertEqual(correction?.task.state, .failed)
        XCTAssertEqual(correction?.announcementKind, .failed)
        XCTAssertEqual(reconciler.allTasks.count, 1)
    }

    func testLowerConfidenceTerminalCannotOverrideHigherSource() {
        var reconciler = SourceReconciler()
        _ = reconciler.apply(sourced(.userPromptSubmit, source: .appServer, at: 1))
        _ = reconciler.apply(sourced(.turnFailed, source: .appServer, at: 10))
        XCTAssertNil(reconciler.apply(sourced(.stop, source: .hooks, at: 11)))
        XCTAssertEqual(reconciler.allTasks.first?.state, .failed)
    }

    func testRepeatedWaitingDoesNotReannounceButNewWaitGenerationDoes() {
        var reconciler = SourceReconciler()
        _ = reconciler.apply(sourced(.userPromptSubmit, source: .hooks, at: 1))
        XCTAssertEqual(reconciler.apply(sourced(.permissionRequest, source: .hooks, at: 2))?.announcementKind, .waitingApproval)
        XCTAssertNil(reconciler.apply(sourced(.permissionRequest, source: .hooks, at: 3)))
        _ = reconciler.apply(sourced(.preToolUse, source: .hooks, at: 4))
        XCTAssertEqual(reconciler.apply(sourced(.permissionRequest, source: .hooks, at: 5))?.announcementKind, .waitingApproval)
    }

    func testBackfillUpdatesUIWithoutAnnouncement() {
        var reconciler = SourceReconciler()
        let transition = reconciler.apply(sourced(.turnFailed, source: .appServer, at: 50, backfill: true))
        XCTAssertEqual(transition?.task.state, .failed)
        XCTAssertNil(transition?.announcementKind)
        XCTAssertEqual(reconciler.allTasks.count, 1)
    }

    func testRestoredRunningTaskStaysActiveAndCompletesWithoutDuplicateRow() {
        let restored = TrackedTask(
            turnID: "turn-restored",
            projectName: "Test Project",
            taskName: "Long task",
            state: .running,
            startedAt: Date(timeIntervalSince1970: 1),
            lastStateChangedAt: Date(timeIntervalSince1970: 2),
            eventGeneration: 1
        )
        var reconciler = SourceReconciler(restoring: [restored], source: .hooks)

        XCTAssertEqual(reconciler.activeTasks.map(\.turnID), ["turn-restored"])
        let completed = reconciler.apply(sourced(.stop, source: .hooks, turn: "turn-restored", at: 40))

        XCTAssertEqual(completed?.previousState, .running)
        XCTAssertEqual(completed?.task.state, .completed)
        XCTAssertEqual(completed?.announcementKind, .completed)
        XCTAssertEqual(reconciler.allTasks.count, 1)
    }
}
