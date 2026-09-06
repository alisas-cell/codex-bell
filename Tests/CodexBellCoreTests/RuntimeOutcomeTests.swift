import XCTest
@testable import CodexBellCore

final class RuntimeOutcomeTests: XCTestCase {
    private let identity = TaskIdentity(projectName: "Sample Project")

    private func event(_ type: String, at time: Int, fields: [String: Any] = [:]) throws -> CodexEvent {
        var payload: [String: Any] = [
            "type": type, "turn_id": "runtime-turn", "started_at": time, "completed_at": time
        ]
        payload.merge(fields) { _, new in new }
        let data = try JSONSerialization.data(withJSONObject: ["type": "event_msg", "payload": payload])
        return try XCTUnwrap(CodexSessionEventDecoder.decode(data, identity: identity, fallbackDate: Date(timeIntervalSince1970: Double(time))))
    }

    private func apply(_ event: CodexEvent, to reconciler: inout SourceReconciler, backfill: Bool = false) -> ReconciledTransition? {
        reconciler.apply(SourcedCodexEvent(source: .codexSessions, event: event, confidence: .authoritative, isBackfill: backfill))
    }

    func testStructuredTerminalErrorsOverrideNullOrStaleSuccessAndRemainPrivate() throws {
        // The capacity fixture matches the observed runtime record's shape.
        let messages: [Any] = [NSNull(), "All done."]
        for code in ["server_overloaded", "usage_limit_reached", "stream_disconnected", "future_error_code"] {
            for message in messages {
                var reconciler = SourceReconciler()
                _ = apply(try event("task_started", at: 100), to: &reconciler)
                let failed = try event("task_complete", at: 120, fields: [
                    "error": ["codex_error_info": code, "message": "TEST_SECRET /Volumes/Demo/private"],
                    "last_agent_message": message, "status": "completed", "retryable": true
                ])
                let transition = try XCTUnwrap(apply(failed, to: &reconciler))
                XCTAssertEqual(transition.task.state, .failed)
                XCTAssertEqual(transition.announcementKind, .failed)
                XCTAssertNil(apply(failed, to: &reconciler))
                let encoded = String(decoding: try PersistenceCodec.encodeEvent(failed), as: UTF8.self)
                XCTAssertFalse(encoded.contains("TEST_SECRET"))
                XCTAssertFalse(encoded.contains("/Volumes/Demo"))
                XCTAssertFalse(encoded.contains(code))
            }
        }
    }

    func testActiveRetryStaysRunningUntilOneRealSuccessOrFailure() throws {
        for succeeds in [true, false] {
            var reconciler = SourceReconciler()
            _ = apply(try event("task_started", at: 100), to: &reconciler)
            for type in ["stream_error", "error", "task_complete"] {
                let retry = try event(type, at: 110, fields: [
                    "will_retry": true,
                    "error": ["codex_error_info": "stream_disconnected"],
                    "last_agent_message": NSNull()
                ])
                XCTAssertEqual(retry.kind, .turnRetrying)
                XCTAssertNil(apply(retry, to: &reconciler)?.announcementKind)
                XCTAssertEqual(reconciler.activeTasks.count, 1)
                XCTAssertTrue(reconciler.recentTasks.isEmpty)
            }
            let outcome: [String: Any] = succeeds
                ? ["last_agent_message": "All done."]
                : ["error": ["codex_error_info": "server_overloaded"], "will_retry": false]
            let terminal = try event("task_complete", at: 120, fields: outcome)
            XCTAssertEqual(apply(terminal, to: &reconciler)?.announcementKind, succeeds ? .completed : .failed)
            XCTAssertNil(apply(terminal, to: &reconciler))
            XCTAssertEqual(reconciler.allTasks.count, 1)
        }
    }

    func testUnknownOutputIsSilentAndLaterConfirmedOutcomeCanResolveIt() throws {
        var reconciler = SourceReconciler()
        _ = apply(try event("task_started", at: 100), to: &reconciler)
        let unknown = try event("task_complete", at: 120)
        let transition = try XCTUnwrap(apply(unknown, to: &reconciler))
        XCTAssertEqual(transition.task.state, .unknownFinished)
        XCTAssertNil(transition.announcementKind)
        XCTAssertEqual(LocalizedCopy(language: .zhHans).taskState(.unknownFinished), "结果未确认")
        XCTAssertEqual(LocalizedCopy(language: .en).taskState(.unknownFinished), "Result unconfirmed")
        let done = try event("task_complete", at: 130, fields: ["status": "completed"])
        XCTAssertEqual(apply(done, to: &reconciler)?.announcementKind, .completed)
        XCTAssertNil(apply(unknown, to: &reconciler, backfill: true))
        XCTAssertEqual(reconciler.allTasks.first?.state, .completed)
    }

    func testHistoricalErrorCorrectsOldSuccessSilentlyAndExplicitRetryCanResume() throws {
        let old = TrackedTask(turnID: "runtime-turn", projectName: "Sample Project", state: .completed,
                              startedAt: Date(timeIntervalSince1970: 100), endedAt: Date(timeIntervalSince1970: 120),
                              lastStateChangedAt: Date(timeIntervalSince1970: 120), eventGeneration: 2)
        var reconciler = SourceReconciler(restoring: [old], source: .codexSessions)
        let error = try event("task_complete", at: 120, fields: ["error": ["codex_error_info": "server_overloaded"]])
        let correction = try XCTUnwrap(apply(error, to: &reconciler, backfill: true))
        XCTAssertEqual(correction.task.state, .failed)
        XCTAssertNil(correction.announcementKind)
        XCTAssertNil(apply(error, to: &reconciler, backfill: true))
        XCTAssertEqual(apply(try event("task_started", at: 130), to: &reconciler)?.task.state, .running)
        let success = try event("task_complete", at: 140, fields: ["last_agent_message": "Done"])
        XCTAssertEqual(apply(success, to: &reconciler)?.announcementKind, .completed)
        XCTAssertNil(apply(error, to: &reconciler, backfill: true))
        XCTAssertEqual(reconciler.allTasks.count, 1)
        XCTAssertEqual(reconciler.allTasks.first?.state, .completed)
    }

    func testExplicitInterruptAndTextOnlyReconnectRemainDistinct() throws {
        XCTAssertEqual(try event("turn_aborted", at: 120).kind, .interrupt)
        XCTAssertEqual(try event("task_complete", at: 120, fields: ["status": "interrupted"]).kind, .interrupt)
        XCTAssertEqual(try event("task_complete", at: 120, fields: ["last_agent_message": "Reconnecting... 1/5"]).kind, .turnRetrying)
        XCTAssertEqual(try event("task_complete", at: 120, fields: ["error": "transport failed"]).kind, .turnFailed)
    }

    func testRawHookAndLegacyIngressCannotTurnMissingOrErrorOutputIntoSuccess() throws {
        let cases: [(Any, CodexEventKind)] = [
            (NSNull(), .turnUnknownFinished),
            ("You've hit your usage limit. Try again later.", .turnFailed),
            ("Reconnecting... 1/5", .turnRetrying),
            ("Done", .stop)
        ]
        for (message, expected) in cases {
            let hook = try JSONSerialization.data(withJSONObject: [
                "hook_event_name": "Stop", "turn_id": "hook-turn", "last_assistant_message": message
            ])
            let decoded = try HookPayloadDecoder.decodeHook(hook).redactedForInbox()
            XCTAssertEqual(decoded.kind, expected)
            XCTAssertEqual(decoded.redactedForInbox().kind, expected)
            XCTAssertNil(decoded.lastAssistantMessage)
            let legacy = try JSONSerialization.data(withJSONObject: [
                "type": "agent-turn-complete", "turn-id": "legacy-turn", "last-assistant-message": message
            ])
            XCTAssertEqual(try HookPayloadDecoder.decodeLegacyNotifyArgument(String(decoding: legacy, as: UTF8.self)).redactedForInbox().kind,
                           expected == .stop ? .agentTurnComplete : expected)
        }
    }
}
