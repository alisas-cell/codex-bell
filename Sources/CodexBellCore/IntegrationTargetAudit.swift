import Foundation

public enum IntegrationTargetStatus: String, Codable, Sendable, Equatable {
    case current
    case staleBellTarget
    case destinationMismatch
    case missingHelper
    case incompleteBellHooks
    case notInstalled
}

public struct IntegrationTargetAudit: Sendable, Equatable {
    public var status: IntegrationTargetStatus
    public var ownedCommandCount: Int
    public var expectedCommandCount: Int

    public init(status: IntegrationTargetStatus, ownedCommandCount: Int, expectedCommandCount: Int) {
        self.status = status
        self.ownedCommandCount = ownedCommandCount
        self.expectedCommandCount = expectedCommandCount
    }
}

public enum IntegrationTargetAuditor {
    public static func audit(
        commands: [String],
        expectedHelperPath: String,
        expectedInboxPath: String,
        helperExecutableExists: Bool
    ) -> IntegrationTargetAudit {
        let expectedCount = CodexConfigMerge.hookEvents.count
        let status: IntegrationTargetStatus
        if commands.isEmpty {
            status = .notInstalled
        } else if !helperExecutableExists {
            status = .missingHelper
        } else if commands.count != expectedCount {
            status = .incompleteBellHooks
        } else {
            let helperMatches = commands.allSatisfy { $0.contains(expectedHelperPath) }
            let inboxMatches = commands.allSatisfy { $0.contains(expectedInboxPath) }
            if helperMatches && inboxMatches {
                status = .current
            } else if helperMatches {
                status = .destinationMismatch
            } else {
                status = .staleBellTarget
            }
        }
        return IntegrationTargetAudit(
            status: status,
            ownedCommandCount: commands.count,
            expectedCommandCount: expectedCount
        )
    }
}
