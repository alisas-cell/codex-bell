import XCTest
@testable import CodexBellCore

final class CodexSessionEventDecoderTests: XCTestCase {
    private let identity = TaskIdentity(projectName: "codex-bell")

    func testDecodesActualGUIStartCompleteAndAbortShapes() throws {
        let start = #"{"type":"event_msg","payload":{"type":"task_started","turn_id":"turn-1","started_at":1788512400,"model_context_window":100000}}"#
        let complete = #"{"type":"event_msg","payload":{"type":"task_complete","turn_id":"turn-1","started_at":1788512400,"completed_at":1788512431,"duration_ms":31000,"last_agent_message":"Finished."}}"#
        let abort = #"{"type":"event_msg","payload":{"type":"turn_aborted","turn_id":"turn-2","started_at":1788512460,"completed_at":1788512462,"reason":"interrupted"}}"#

        let started = try XCTUnwrap(CodexSessionEventDecoder.decode(Data(start.utf8), sessionID: "session", identity: identity))
        XCTAssertEqual(started.kind, .userPromptSubmit)
        XCTAssertEqual(started.turnID, "turn-1")
        XCTAssertEqual(started.identity, identity)

        let completed = try XCTUnwrap(CodexSessionEventDecoder.decode(Data(complete.utf8), sessionID: "session", identity: identity))
        XCTAssertEqual(completed.kind, .stop)
        XCTAssertEqual(completed.occurredAt, Date(timeIntervalSince1970: 1_788_512_431))

        let interrupted = try XCTUnwrap(CodexSessionEventDecoder.decode(Data(abort.utf8), sessionID: "session", identity: identity))
        XCTAssertEqual(interrupted.kind, .interrupt)
    }

    func testTerminalMessageIsUsedOnlyForDerivedFailureKind() throws {
        let line = #"{"type":"event_msg","payload":{"type":"task_complete","turn_id":"turn-secret","completed_at":"2026-09-04T09:00:31Z","last_agent_message":"Build failed: token TEST_SECRET /Volumes/Demo/private.swift"}}"#
        let event = try XCTUnwrap(CodexSessionEventDecoder.decode(Data(line.utf8), identity: identity))
        XCTAssertEqual(event.kind, .turnFailed)
        XCTAssertNil(event.cwd)
        XCTAssertNil(event.prompt)
        XCTAssertNil(event.lastAssistantMessage)
        XCTAssertNil(event.toolName)
        let persisted = String(decoding: try PersistenceCodec.encodeEvent(event), as: UTF8.self)
        XCTAssertFalse(persisted.contains("TEST_SECRET"))
        XCTAssertFalse(persisted.contains("private.swift"))
    }

    func testIgnoresTranscriptAndToolRecords() throws {
        let message = #"{"type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"private prompt"}]}}"#
        let tool = #"{"type":"response_item","payload":{"type":"function_call","name":"exec_command","arguments":"private args"}}"#
        XCTAssertNil(try CodexSessionEventDecoder.decode(Data(message.utf8), identity: identity))
        XCTAssertNil(try CodexSessionEventDecoder.decode(Data(tool.utf8), identity: identity))
    }

    func testMetadataProducesOnlySanitizedContext() throws {
        let line = #"{"type":"session_meta","payload":{"id":"session-1","cwd":"/Volumes/Demo/codex-bell","timestamp":"2026-09-04T09:00:00Z","base_instructions":"synthetic"}}"#
        let context = try XCTUnwrap(CodexSessionEventDecoder.decodeContext(Data(line.utf8)))
        XCTAssertEqual(context.sessionID, "session-1")
        XCTAssertEqual(context.identity.projectName, "Codex Bell")
        XCTAssertNil(context.identity.taskName)
    }
}
