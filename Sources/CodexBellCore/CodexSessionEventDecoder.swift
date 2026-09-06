import Foundation

public struct CodexSessionContext: Sendable, Equatable {
    public var sessionID: String?
    public var identity: TaskIdentity
    public var isSubagent: Bool

    public init(sessionID: String?, identity: TaskIdentity, isSubagent: Bool = false) {
        self.sessionID = sessionID
        self.identity = identity
        self.isSubagent = isSubagent
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
        let source = payload["source"] as? [String: Any]
        let isSubagent = source?["subagent"].map { !($0 is NSNull) } == true
            || nonempty(payload["parent_thread_id"] as? String) != nil
            || payload["thread_source"] as? String == "guardian_review"
        return CodexSessionContext(
            sessionID: nonempty(payload["id"] as? String) ?? nonempty(payload["session_id"] as? String),
            identity: identity,
            isSubagent: isSubagent
        )
    }

    /// Internal agents share the parent's project directory, but their completed
    /// turns are not completion of the user's task. Only the turn ID is exposed
    /// for removing rows incorrectly persisted by older Bell versions.
    public static func decode(
        _ data: Data,
        context: CodexSessionContext,
        fallbackDate: Date = Date(),
        excludedTurn: ((String) -> Void)? = nil
    ) throws -> CodexEvent? {
        guard let event = try decode(
            data, sessionID: context.sessionID, identity: context.identity, fallbackDate: fallbackDate
        ) else { return nil }
        guard !context.isSubagent else {
            excludedTurn?(event.turnID)
            return nil
        }
        return event
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
            if payload["status"] as? String == "interrupted" {
                kind = .interrupt
            } else {
                kind = TerminalOutcomeClassifier.classify(
                    payload["last_agent_message"] as? String,
                    hasError: payload["error"].map { !($0 is NSNull) } == true
                        || payload["status"] as? String == "failed",
                    isRetrying: isActivelyRetrying(payload),
                    explicitlyCompleted: payload["status"] as? String == "completed"
                ).eventKind
            }
            occurredAt = date(payload["completed_at"]) ?? date(object["timestamp"]) ?? fallbackDate
        case "error", "stream_error":
            // An error notification without a terminal event does not establish
            // that this turn has ended. Keep it alive until its actual outcome.
            guard isActivelyRetrying(payload) else { return nil }
            kind = .turnRetrying
            occurredAt = date(object["timestamp"]) ?? fallbackDate
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

    private static func isActivelyRetrying(_ payload: [String: Any]) -> Bool {
        let error = payload["error"] as? [String: Any]
        return payload["will_retry"] as? Bool == true
            || payload["willRetry"] as? Bool == true
            || error?["will_retry"] as? Bool == true
            || error?["willRetry"] as? Bool == true
            || ["retrying", "reconnecting", "in_progress"].contains(payload["status"] as? String ?? "")
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
