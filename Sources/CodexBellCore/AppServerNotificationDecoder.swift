import Foundation

public enum AppServerNotificationDecoderError: Error, Equatable {
    case invalidJSON
    case malformedTurnCompleted
    case unknownTurnStatus(String)
}

public enum AppServerNotificationDecoder {
    public static func decode(_ data: Data, occurredAt: Date = Date()) throws -> CodexEvent? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AppServerNotificationDecoderError.invalidJSON
        }
        guard object["method"] as? String == "turn/completed" else { return nil }
        guard let params = object["params"] as? [String: Any],
              let threadID = params["threadId"] as? String,
              let turn = params["turn"] as? [String: Any],
              let turnID = turn["id"] as? String,
              let status = turn["status"] as? String else {
            throw AppServerNotificationDecoderError.malformedTurnCompleted
        }
        let kind: CodexEventKind
        switch status {
        case "completed": kind = .stop
        case "failed": kind = .turnFailed
        case "interrupted": kind = .interrupt
        default: throw AppServerNotificationDecoderError.unknownTurnStatus(status)
        }
        return CodexEvent(kind: kind, turnID: turnID, sessionID: threadID, occurredAt: occurredAt)
    }
}
