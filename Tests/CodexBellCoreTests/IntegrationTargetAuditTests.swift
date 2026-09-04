import XCTest
@testable import CodexBellCore

final class IntegrationTargetAuditTests: XCTestCase {
    private let helper = "/Volumes/Demo/Codex Bell Current.app/Contents/MacOS/codex-bell-hook"
    private let inbox = "/Volumes/Demo/Codex Bell Current Data/Inbox"

    func testRecognizesCurrentExactTarget() {
        let commands = Array(repeating: command(helper: helper, inbox: inbox), count: CodexConfigMerge.hookEvents.count)
        XCTAssertEqual(IntegrationTargetAuditor.audit(commands: commands, expectedHelperPath: helper, expectedInboxPath: inbox, helperExecutableExists: true).status, .current)
    }

    func testDistinguishesStaleDestinationAndMissingHelper() {
        let oldHelper = helper.replacingOccurrences(of: "Current", with: "Legacy")
        let oldInbox = inbox.replacingOccurrences(of: "Current", with: "Legacy")
        let stale = Array(repeating: command(helper: oldHelper, inbox: oldInbox), count: CodexConfigMerge.hookEvents.count)
        XCTAssertEqual(IntegrationTargetAuditor.audit(commands: stale, expectedHelperPath: helper, expectedInboxPath: inbox, helperExecutableExists: true).status, .staleBellTarget)

        let wrongDestination = Array(repeating: command(helper: helper, inbox: oldInbox), count: CodexConfigMerge.hookEvents.count)
        XCTAssertEqual(IntegrationTargetAuditor.audit(commands: wrongDestination, expectedHelperPath: helper, expectedInboxPath: inbox, helperExecutableExists: true).status, .destinationMismatch)

        let current = Array(repeating: command(helper: helper, inbox: inbox), count: CodexConfigMerge.hookEvents.count)
        XCTAssertEqual(IntegrationTargetAuditor.audit(commands: current, expectedHelperPath: helper, expectedInboxPath: inbox, helperExecutableExists: false).status, .missingHelper)
    }

    func testNoOwnedOrIncompleteHooksAreNotCurrent() {
        XCTAssertEqual(IntegrationTargetAuditor.audit(commands: [], expectedHelperPath: helper, expectedInboxPath: inbox, helperExecutableExists: true).status, .notInstalled)
        XCTAssertEqual(IntegrationTargetAuditor.audit(commands: [command(helper: helper, inbox: inbox)], expectedHelperPath: helper, expectedInboxPath: inbox, helperExecutableExists: true).status, .incompleteBellHooks)
    }

    private func command(helper: String, inbox: String) -> String {
        "/usr/bin/env CODEX_BELL_INBOX='\(inbox)' '\(helper)' --codex-bell-hook"
    }
}
