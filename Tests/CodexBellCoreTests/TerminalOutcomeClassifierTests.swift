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
    }

    func testMissingOutputIsUnconfirmedUnlessSuccessIsExplicit() {
        for message in [nil, "", " \n "] {
            XCTAssertEqual(TerminalOutcomeClassifier.classify(message), .unknown)
            XCTAssertEqual(TerminalOutcomeClassifier.classify(message, explicitlyCompleted: true), .completed)
        }
    }

    func testQuotaCapacityAndReconnectMessagesCannotBecomeSuccess() {
        for message in [
            "Selected model is at capacity. Please try a different model.",
            "You've hit your usage limit. Try again later.",
            "当前模型额度不足，请稍后再试。",
            "stream disconnected before completion: connection closed"
        ] {
            XCTAssertEqual(TerminalOutcomeClassifier.classify(message), .failed, message)
        }
        XCTAssertEqual(TerminalOutcomeClassifier.classify("Reconnecting... 1/5"), .retrying)
        XCTAssertEqual(TerminalOutcomeClassifier.classify("正在重新连接"), .retrying)
        XCTAssertEqual(TerminalOutcomeClassifier.classify("Reconnected successfully; work completed."), .completed)
    }

    func testStructuredErrorOutranksSuccessTextAndActiveRetryOutranksTerminalFailure() {
        XCTAssertEqual(TerminalOutcomeClassifier.classify("Done", hasError: true, explicitlyCompleted: true), .failed)
        XCTAssertEqual(TerminalOutcomeClassifier.classify(nil, hasError: true), .failed)
        XCTAssertEqual(TerminalOutcomeClassifier.classify(nil, hasError: true, isRetrying: true), .retrying)
    }

    func testInboxRedactionCarriesFailureAsKindWithoutStoringMessage() {
        let event = CodexEvent(kind: .stop, turnID: "turn-fail", cwd: "/tmp/sample-app", lastAssistantMessage: "Deployment failed: exit 1")
        let redacted = event.redactedForInbox()
        XCTAssertEqual(redacted.kind, .turnFailed)
        XCTAssertNil(redacted.lastAssistantMessage)
    }
}
