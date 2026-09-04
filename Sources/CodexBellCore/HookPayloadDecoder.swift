import Foundation

public enum HookPayloadDecoderError: Error, Equatable {
    case invalidJSON
    case missingTurnID
    case unknownHook(String)
    case invalidLegacyNotify
}

public enum HookPayloadDecoder {
    public static func decodeHook(_ data: Data, occurredAt: Date = Date()) throws -> CodexEvent {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw HookPayloadDecoderError.invalidJSON
        }
        guard let turnID = object["turn_id"] as? String, !turnID.isEmpty else {
            throw HookPayloadDecoderError.missingTurnID
        }
        let name = object["hook_event_name"] as? String ?? ""
        let kind: CodexEventKind
        switch name {
        case "UserPromptSubmit": kind = .userPromptSubmit
        case "PermissionRequest": kind = .permissionRequest
        case "PreToolUse":
            if ["request_user_input", "request_user_input_async"].contains(object["tool_name"] as? String) { kind = .waitingInput }
            else { kind = .preToolUse }
        case "PostToolUse": kind = .postToolUse
        case "Stop": kind = .stop
        case "Interrupt": kind = .interrupt
        default: throw HookPayloadDecoderError.unknownHook(name)
        }
        return CodexEvent(
            kind: kind,
            turnID: turnID,
            sessionID: object["session_id"] as? String,
            cwd: object["cwd"] as? String,
            prompt: object["prompt"] as? String,
            lastAssistantMessage: object["last_assistant_message"] as? String,
            toolName: object["tool_name"] as? String,
            occurredAt: occurredAt
        )
    }

    public static func decodeLegacyNotifyArgument(_ argument: String, occurredAt: Date = Date()) throws -> CodexEvent {
        guard let data = argument.data(using: .utf8),
              let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              object["type"] as? String == "agent-turn-complete",
              let turnID = object["turn-id"] as? String,
              !turnID.isEmpty else {
            throw HookPayloadDecoderError.invalidLegacyNotify
        }
        let messages = object["input-messages"] as? [String]
        return CodexEvent(
            kind: .agentTurnComplete,
            turnID: turnID,
            sessionID: object["thread-id"] as? String,
            cwd: object["cwd"] as? String,
            prompt: messages?.first,
            lastAssistantMessage: object["last-assistant-message"] as? String,
            occurredAt: occurredAt
        )
    }
}
