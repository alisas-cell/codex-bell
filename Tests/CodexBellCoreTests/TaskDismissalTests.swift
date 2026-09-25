import XCTest
@testable import CodexBellCore

final class TaskDismissalTests: XCTestCase {
    private func event(_ kind: CodexEventKind, turn: String = "stuck-turn", source: EventSource = .codexSessions, backfill: Bool = false) -> SourcedCodexEvent {
        SourcedCodexEvent(source: source,
                          event: CodexEvent(kind: kind, turnID: turn, identity: TaskIdentity(projectName: "Sample Project")),
                          confidence: .authoritative, isBackfill: backfill)
    }

    func testDismissActiveStatesWithoutCreatingFalseCompletionOrAffectingOtherRows() {
        for kind: CodexEventKind in [.userPromptSubmit, .permissionRequest, .waitingInput] {
            var reconciler = SourceReconciler()
            _ = reconciler.apply(event(kind))
            _ = reconciler.apply(event(.userPromptSubmit, turn: "other-turn"))
            XCTAssertTrue(reconciler.dismissActiveTask(turnID: "stuck-turn"))
            XCTAssertFalse(reconciler.dismissActiveTask(turnID: "stuck-turn"))
            XCTAssertEqual(reconciler.activeTasks.map(\.turnID), ["other-turn"])
            XCTAssertTrue(reconciler.recentTasks.isEmpty)
            XCTAssertEqual(reconciler.dismissedTurnIDs, ["stuck-turn"])
        }
    }

    func testAllSourcesAndReplayCannotReviveDismissedTurnButNewTurnWorksExactlyOnce() {
        var reconciler = SourceReconciler()
        _ = reconciler.apply(event(.userPromptSubmit))
        _ = reconciler.dismissActiveTask(turnID: "stuck-turn")
        for source: EventSource in [.appServer, .codexSessions, .hooks, .legacyNotify] {
            for kind: CodexEventKind in [.userPromptSubmit, .turnRetrying, .waitingInput, .stop, .turnFailed] {
                for backfill in [true, false] {
                    XCTAssertNil(reconciler.apply(event(kind, source: source, backfill: backfill)))
                }
            }
        }
        XCTAssertTrue(reconciler.allTasks.isEmpty)
        XCTAssertNotNil(reconciler.apply(event(.userPromptSubmit, turn: "new-turn")))
        XCTAssertEqual(reconciler.apply(event(.stop, turn: "new-turn"))?.announcementKind, .completed)
        XCTAssertNil(reconciler.apply(event(.stop, turn: "new-turn")))
    }

    func testDismissalPersistsAcrossRestartAndHistoryClearWithoutTaskContent() throws {
        var reconciler = SourceReconciler()
        _ = reconciler.apply(event(.userPromptSubmit))
        let staleTasks = reconciler.allTasks
        _ = reconciler.dismissActiveTask(turnID: "stuck-turn")
        reconciler.clearTerminalHistory()
        let snapshot = PersistedSnapshot.make(settings: .default, tasks: staleTasks,
                                               dismissedTurnIDs: reconciler.dismissedTurnIDs)
        let data = try PersistenceCodec.encode(snapshot)
        XCTAssertFalse(String(decoding: data, as: UTF8.self).contains("Sample Project"))
        let decoded = try PersistenceCodec.decode(data)
        XCTAssertEqual(decoded.dismissedTurnIDs, ["stuck-turn"])
        XCTAssertTrue(decoded.tasks.isEmpty)
        var restored = SourceReconciler(restoring: staleTasks, source: .codexSessions,
                                         dismissedTurnIDs: Set(decoded.dismissedTurnIDs))
        XCTAssertTrue(restored.activeTasks.isEmpty)
        XCTAssertNil(restored.apply(event(.userPromptSubmit, backfill: true)))
        XCTAssertNil(restored.apply(event(.stop)))
    }

    func testLegacySnapshotDefaultsToNoDismissals() throws {
        let old = #"{"version":2,"savedAt":"2026-09-01T00:00:00Z","settings":{"volume":0.4},"tasks":[]}"#
        let decoded = try PersistenceCodec.decode(Data(old.utf8))
        XCTAssertTrue(decoded.dismissedTurnIDs.isEmpty)
        XCTAssertEqual(decoded.settings.volume, 0.4)
    }

    func testTerminalAndUnknownRowsCannotBeDismissedAsActive() {
        var reconciler = SourceReconciler()
        XCTAssertFalse(reconciler.dismissActiveTask(turnID: "missing"))
        for kind: CodexEventKind in [.stop, .turnFailed, .interrupt, .turnUnknownFinished] {
            let turn = kind.rawValue
            _ = reconciler.apply(event(kind, turn: turn))
            XCTAssertFalse(reconciler.dismissActiveTask(turnID: turn))
        }
        XCTAssertEqual(reconciler.recentTasks.count, 4)
        XCTAssertTrue(reconciler.dismissedTurnIDs.isEmpty)
    }

    func testDismissedQueuedAlertsAreSkippedButOtherAlertsAndPreviewsArePreserved() {
        for kind: AnnouncementKind in [.completed, .failed, .waitingInput, .waitingApproval, .interrupted] {
            let item = Announcement(turnID: "stuck-turn", kind: kind, identity: TaskIdentity(projectName: "P"), generation: 1)
            XCTAssertTrue(AnnouncementPolicy.isSuperseded(item, by: nil, isDismissed: true))
            XCTAssertFalse(AnnouncementPolicy.isSuperseded(item, by: nil, isDismissed: false))
        }
        let preview = Announcement(turnID: "preview", kind: .completed, identity: TaskIdentity(projectName: "P"), generation: 1, isTest: true)
        XCTAssertFalse(AnnouncementPolicy.isSuperseded(preview, by: nil, isDismissed: true))
        XCTAssertEqual(LocalizedCopy(language: .zhHans)[.dismissTask], "从 Bell 移除")
        XCTAssertEqual(LocalizedCopy(language: .en)[.dismissTask], "Dismiss from Bell")
        XCTAssertTrue(LocalizedCopy(language: .zhHans)[.dismissTaskHelp].contains("不会终止"))
        XCTAssertTrue(LocalizedCopy(language: .en)[.dismissTaskHelp].contains("keep running"))
    }
}
