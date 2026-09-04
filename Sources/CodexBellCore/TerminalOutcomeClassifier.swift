import Foundation

public enum TerminalOutcome: Sendable, Equatable {
    case completed
    case failed
}

public enum TerminalOutcomeClassifier {
    public static func classify(_ message: String?) -> TerminalOutcome {
        guard let message else { return .completed }
        let text = message.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let strongFailurePrefixes = [
            "deployment failed", "build failed", "task failed", "failed:", "error:", "fatal:",
            "it failed", "the task failed", "the command failed", "the operation failed",
            "i could not", "i couldn't", "i was unable to", "unable to complete", "unable to finish"
        ]
        if strongFailurePrefixes.contains(where: { text.hasPrefix($0) }) { return .failed }
        return .completed
    }
}
