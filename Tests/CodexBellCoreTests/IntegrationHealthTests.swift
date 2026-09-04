import XCTest
@testable import CodexBellCore

final class IntegrationHealthTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 10_000)

    func testAppServerLiveRequiresInitializedConnectionAndRecentResponse() {
        var evidence = IntegrationEvidence(
            appServerConnected: true,
            appServerInitialized: true,
            socketDetected: true,
            lastAppServerResponseAt: now.addingTimeInterval(-5),
            currentInstanceStartedAt: now.addingTimeInterval(-20)
        )
        XCTAssertEqual(IntegrationHealthEvaluator.evaluate(evidence, now: now).mode, .appServerLive)
        evidence.lastAppServerResponseAt = now.addingTimeInterval(-60)
        XCTAssertNotEqual(IntegrationHealthEvaluator.evaluate(evidence, now: now).mode, .appServerLive)
    }

    func testHooksLiveRequiresARealEventFromTheCurrentBellInstance() {
        var evidence = IntegrationEvidence(
            hooksInstalled: true,
            lastHookEventAt: now.addingTimeInterval(-10),
            currentInstanceStartedAt: now.addingTimeInterval(-20)
        )
        XCTAssertEqual(IntegrationHealthEvaluator.evaluate(evidence, now: now).mode, .hooksLive)

        evidence = IntegrationEvidence(
            hooksInstalled: true,
            hookSelfTestPassedAt: now.addingTimeInterval(-10),
            currentInstanceStartedAt: now.addingTimeInterval(-20)
        )
        XCTAssertEqual(IntegrationHealthEvaluator.evaluate(evidence, now: now).mode, .installedWaiting)

        evidence = IntegrationEvidence(
            hooksInstalled: true,
            lastHookEventAt: now.addingTimeInterval(-30),
            currentInstanceStartedAt: now.addingTimeInterval(-20)
        )
        XCTAssertEqual(IntegrationHealthEvaluator.evaluate(evidence, now: now).mode, .installedWaiting)
    }

    func testSupportedGUISessionSourceBecomesLiveOnlyAfterCurrentInstanceEvent() {
        var evidence = IntegrationEvidence(
            sessionLogDetected: true,
            lastSessionEventAt: now.addingTimeInterval(-30),
            currentInstanceStartedAt: now.addingTimeInterval(-20)
        )
        XCTAssertEqual(IntegrationHealthEvaluator.evaluate(evidence, now: now).mode, .installedWaiting)

        evidence.lastSessionEventAt = now.addingTimeInterval(-5)
        XCTAssertEqual(IntegrationHealthEvaluator.evaluate(evidence, now: now).mode, .codexSessionLive)
    }

    func testWaitingProblemAndNotInstalledFallbacksAreTruthful() {
        let legacy = IntegrationHealthEvaluator.evaluate(IntegrationEvidence(legacyNotifyAvailable: true), now: now)
        XCTAssertEqual(legacy.mode, .legacyOnly)

        let notInstalled = IntegrationHealthEvaluator.evaluate(IntegrationEvidence(), now: now)
        XCTAssertEqual(notInstalled.mode, .notInstalled)

        let problem = IntegrationHealthEvaluator.evaluate(
            IntegrationEvidence(integrationProblemCode: .missingHelper),
            now: now
        )
        XCTAssertEqual(problem.mode, .problem(.missingHelper))
    }

    func testModeLabelsMatchProductCopy() {
        XCTAssertEqual(IntegrationMode.appServerLive.displayName, "Live · App Server")
        XCTAssertEqual(IntegrationMode.hooksLive.displayName, "Live · Hooks")
        XCTAssertEqual(IntegrationMode.codexSessionLive.displayName, "Live · Codex")
        XCTAssertEqual(IntegrationMode.installedWaiting.displayName, "Installed · Waiting for event")
        XCTAssertEqual(IntegrationMode.problem(.missingHelper).displayName, "Integration problem")
        XCTAssertEqual(IntegrationMode.notInstalled.displayName, "Not installed")
        XCTAssertEqual(IntegrationMode.legacyOnly.displayName, "Completion only · Legacy notify")
    }
}
