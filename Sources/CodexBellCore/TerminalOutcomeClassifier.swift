import Foundation

public enum TerminalOutcome: Sendable, Equatable {
    case completed
    case failed
    case retrying
    case unknown

    public var eventKind: CodexEventKind {
        switch self {
        case .completed: return .stop
        case .failed: return .turnFailed
        case .retrying: return .turnRetrying
        case .unknown: return .turnUnknownFinished
        }
    }
}

public enum TerminalOutcomeClassifier {
    public static func classify(
        _ message: String?,
        hasError: Bool = false,
        isRetrying: Bool = false,
        explicitlyCompleted: Bool = false
    ) -> TerminalOutcome {
        // Active retry is not terminal. Merely being retryable does not mean a
        // retry is in progress. Structured errors outrank any leftover prose.
        if isRetrying { return .retrying }
        if hasError { return .failed }
        let text = (message ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !text.isEmpty else { return explicitlyCompleted ? .completed : .unknown }
        let reconnectPrefixes = ["reconnecting...", "reconnecting…", "正在重连", "正在重新连接"]
        if reconnectPrefixes.contains(where: { text.hasPrefix($0) }) { return .retrying }
        let strongFailurePrefixes = [
            "deployment failed", "build failed", "task failed", "failed:", "error:", "fatal:",
            "it failed", "the task failed", "the command failed", "the operation failed",
            "i could not", "i couldn't", "i was unable to", "unable to complete", "unable to finish",
            "selected model is at capacity", "the model is currently overloaded", "server overloaded",
            "you've hit your usage limit", "you have hit your usage limit", "usage limit exceeded",
            "rate limit exceeded", "quota exceeded", "insufficient quota",
            "stream disconnected before completion", "connection lost", "reconnecting failed",
            "当前模型额度不足", "当前模型额度不够", "模型额度不足", "额度已用尽", "已达到使用上限",
            "所选模型当前已满", "服务器过载", "连接已断开", "重连失败"
        ]
        if strongFailurePrefixes.contains(where: { text.hasPrefix($0) }) { return .failed }
        return .completed
    }
}
