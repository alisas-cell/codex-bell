import XCTest
@testable import CodexBellCore

final class TerminalOutcomeClassifierTests: XCTestCase {
    func testStrongFailureMessagesAreClassifiedFailed() {
        XCTAssertEqual(TerminalOutcomeClassifier.classify("Deployment failed: Vercel returned an error."), .failed)
        XCTAssertEqual(TerminalOutcomeClassifier.classify("Error: could not finish the build."), .failed)
        XCTAssertEqual(TerminalOutcomeClassifier.classify("I could not complete this task because signing failed."), .failed)
        XCTAssertEqual(TerminalOutcomeClassifier.classify("It failed: touch returned Operation not permitted."), .failed)
    }

    func testSuccessReportsMentioningErrorsDoNotBecomeFailures() {
        XCTAssertEqual(TerminalOutcomeClassifier.classify("Deployment complete. 0 errors and no failures."), .completed)
        XCTAssertEqual(TerminalOutcomeClassifier.classify("All tests passed. No errors found."), .completed)
        XCTAssertEqual(TerminalOutcomeClassifier.classify(nil), .completed)
    }

    func testInboxRedactionCarriesFailureAsKindWithoutStoringMessage() {
        let event = CodexEvent(kind: .stop, turnID: "turn-fail", cwd: "/tmp/sample-app", lastAssistantMessage: "Deployment failed: exit 1")
        let redacted = event.redactedForInbox()
        XCTAssertEqual(redacted.kind, .turnFailed)
        XCTAssertNil(redacted.lastAssistantMessage)
    }
}
