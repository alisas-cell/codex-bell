import XCTest
@testable import CodexBellCore

final class HookPayloadDecoderTests: XCTestCase {
    func testDecodesUserPromptSubmit() throws {
        let data = Data(#"{"hook_event_name":"UserPromptSubmit","turn_id":"turn-1","session_id":"session-1","cwd":"/Volumes/Demo/sample-workspace","prompt":"Run release tests","model":"gpt","permission_mode":"default","transcript_path":null}"#.utf8)
        let event = try HookPayloadDecoder.decodeHook(data)
        XCTAssertEqual(event.kind, .userPromptSubmit)
        XCTAssertEqual(event.turnID, "turn-1")
        XCTAssertEqual(event.sessionID, "session-1")
        XCTAssertEqual(event.cwd, "/Volumes/Demo/sample-workspace")
        XCTAssertEqual(event.prompt, "Run release tests")
    }

    func testDecodesPermissionAndPreToolUse() throws {
        let permission = Data(#"{"hook_event_name":"PermissionRequest","turn_id":"turn-2","session_id":"session-2","cwd":"/tmp/sample-app","tool_name":"Bash","tool_input":{"command":"echo synthetic"},"model":"gpt","permission_mode":"default","transcript_path":null}"#.utf8)
        let waiting = try HookPayloadDecoder.decodeHook(permission)
        XCTAssertEqual(waiting.kind, .permissionRequest)
        XCTAssertEqual(waiting.toolName, "Bash")

        let pre = Data(#"{"hook_event_name":"PreToolUse","turn_id":"turn-2","session_id":"session-2","cwd":"/tmp/sample-app","tool_name":"Bash","tool_input":{"command":"echo ok"},"tool_use_id":"tool-1","model":"gpt","permission_mode":"default","transcript_path":null}"#.utf8)
        let resumed = try HookPayloadDecoder.decodeHook(pre)
        XCTAssertEqual(resumed.kind, .preToolUse)
        XCTAssertEqual(resumed.turnID, "turn-2")

        let ask = Data(#"{"hook_event_name":"PreToolUse","turn_id":"turn-2","session_id":"session-2","cwd":"/tmp/sample-app","tool_name":"request_user_input","tool_input":{"questions":[]},"tool_use_id":"tool-2","model":"gpt","permission_mode":"default","transcript_path":null}"#.utf8)
        XCTAssertEqual(try HookPayloadDecoder.decodeHook(ask).kind, .waitingInput)

        let askAsync = Data(#"{"hook_event_name":"PreToolUse","turn_id":"turn-2","session_id":"session-2","cwd":"/tmp/sample-app","tool_name":"request_user_input_async","tool_input":{"questions":[]},"tool_use_id":"tool-3"}"#.utf8)
        XCTAssertEqual(try HookPayloadDecoder.decodeHook(askAsync).kind, .waitingInput)

        let answered = Data(#"{"hook_event_name":"PostToolUse","turn_id":"turn-2","session_id":"session-2","cwd":"/tmp/sample-app","tool_name":"request_user_input","tool_input":{"questions":[]},"tool_response":{"answers":{}},"tool_use_id":"tool-2","model":"gpt","permission_mode":"default","transcript_path":null}"#.utf8)
        XCTAssertEqual(try HookPayloadDecoder.decodeHook(answered).kind, .postToolUse)
    }

    func testDecodesStopAndInterrupt() throws {
        let stop = Data(#"{"hook_event_name":"Stop","turn_id":"turn-3","session_id":"session-3","cwd":"/tmp/die","last_assistant_message":"Done","stop_hook_active":false,"model":"gpt","permission_mode":"default","transcript_path":null}"#.utf8)
        let completed = try HookPayloadDecoder.decodeHook(stop)
        XCTAssertEqual(completed.kind, .stop)
        XCTAssertEqual(completed.lastAssistantMessage, "Done")

        let interrupt = Data(#"{"hook_event_name":"Interrupt","turn_id":"turn-3","session_id":"session-3","cwd":"/tmp/die","model":"gpt","permission_mode":"default","transcript_path":null}"#.utf8)
        XCTAssertEqual(try HookPayloadDecoder.decodeHook(interrupt).kind, .interrupt)
    }

    func testDecodesLegacyNotifyArgument() throws {
        let json = #"{"type":"agent-turn-complete","thread-id":"thread-1","turn-id":"turn-4","cwd":"/Volumes/Demo/sample-workspace","client":"codex-tui","input-messages":["Update README"],"last-assistant-message":"Complete"}"#
        let event = try HookPayloadDecoder.decodeLegacyNotifyArgument(json)
        XCTAssertEqual(event.kind, .agentTurnComplete)
        XCTAssertEqual(event.turnID, "turn-4")
        XCTAssertEqual(event.sessionID, "thread-1")
        XCTAssertEqual(event.prompt, "Update README")
        XCTAssertEqual(event.lastAssistantMessage, "Complete")
    }

    func testRejectsUnknownHook() throws {
        let data = Data(#"{"hook_event_name":"SomethingNew","turn_id":"turn-x"}"#.utf8)
        XCTAssertThrowsError(try HookPayloadDecoder.decodeHook(data))
    }
}
