import Foundation

public struct CodexSessionContext: Sendable, Equatable {
    public var sessionID: String?
    public var identity: TaskIdentity

    public init(sessionID: String?, identity: TaskIdentity) {
        self.sessionID = sessionID
        self.identity = identity
    }
}

public enum CodexSessionEventDecoderError: Error, Equatable {
    case invalidJSON
}

/// Decodes only privacy-safe lifecycle metadata from Codex Desktop's local session stream.
/// Transcript content and tool arguments are never copied into the returned event.
public enum CodexSessionEventDecoder {
    public static func decodeContext(_ data: Data) throws -> CodexSessionContext? {
        let object = try object(from: data)
        guard object["type"] as? String == "session_meta",
              let payload = object["payload"] as? [String: Any] else { return nil }
        let cwd = payload["cwd"] as? String
        let identity = TaskNameExtractor.extract(cwd: cwd, prompt: nil)
        return CodexSessionContext(
            sessionID: nonempty(payload["id"] as? String) ?? nonempty(payload["session_id"] as? String),
            identity: identity
        )
    }

    public static func decode(
        _ data: Data,
        sessionID: String? = nil,
        identity: TaskIdentity,
        fallbackDate: Date = Date()
    ) throws -> CodexEvent? {
        let object = try object(from: data)
        guard object["type"] as? String == "event_msg",
              let payload = object["payload"] as? [String: Any],
              let payloadType = payload["type"] as? String,
              let turnID = nonempty(payload["turn_id"] as? String) else { return nil }

        let kind: CodexEventKind
        let occurredAt: Date
        switch payloadType {
        case "task_started":
            kind = .userPromptSubmit
            occurredAt = date(payload["started_at"]) ?? fallbackDate
        case "task_complete":
            kind = TerminalOutcomeClassifier.classify(payload["last_agent_message"] as? String) == .failed
                ? .turnFailed
                : .stop
            occurredAt = date(payload["completed_at"]) ?? fallbackDate
        case "turn_aborted":
            kind = .interrupt
            occurredAt = date(payload["completed_at"]) ?? fallbackDate
        default:
            return nil
        }

        return CodexEvent(
            kind: kind,
            turnID: turnID,
            sessionID: sessionID,
            identity: identity,
            occurredAt: occurredAt
        )
    }

    private static func object(from data: Data) throws -> [String: Any] {
        guard let value = try? JSONSerialization.jsonObject(with: data),
              let object = value as? [String: Any] else {
            throw CodexSessionEventDecoderError.invalidJSON
        }
        return object
    }

    private static func nonempty(_ value: String?) -> String? {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return value
    }

    private static func date(_ value: Any?) -> Date? {
        if let seconds = value as? NSNumber {
            return Date(timeIntervalSince1970: seconds.doubleValue)
        }
        guard let value = value as? String else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }
}
