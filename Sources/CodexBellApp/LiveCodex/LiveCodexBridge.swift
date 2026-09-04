#if os(macOS)
import Foundation
import CodexBellCore

@MainActor
final class LiveCodexBridge {
    private let configurator: CodexConfigurator
    private let hookSource: HookEventSource
    private let sessionSource: SessionLogEventSource
    private let appServerObserver = AppServerObserver()

    private(set) var evidence: IntegrationEvidence
    var onSourcedEvent: ((SourcedCodexEvent) -> Void)?
    var onHealthChanged: ((IntegrationHealth) -> Void)?

    init(appSupportDirectory: URL, inboxDirectory: URL, initialEvidence: IntegrationEvidence?) {
        configurator = CodexConfigurator(appSupportDirectory: appSupportDirectory)
        hookSource = HookEventSource(
            appSupportDirectory: appSupportDirectory,
            inboxDirectory: inboxDirectory,
            helperURL: configurator.helperExecutableURL
        )
        sessionSource = SessionLogEventSource(codexHome: CodexEnvironment.homeDirectory)
        evidence = initialEvidence ?? IntegrationEvidence()
        evidence.appServerConnected = false
        evidence.appServerInitialized = false
        evidence.currentInstanceStartedAt = Date()
        evidence.lastEventSource = nil
        evidence.sessionBackfillEventCount = 0
        evidence.lastSessionBackfillEventAt = nil
    }

    func start() {
        refreshConfiguration()
        hookSource.start { [weak self] event, isBackfill in
            guard let self else { return }
            let observedAt = isBackfill ? event.occurredAt : Date()
            if !isBackfill, self.evidence.lastHookEventAt.map({ observedAt > $0 }) ?? true {
                self.evidence.lastHookEventAt = observedAt
                self.evidence.lastEventSource = .hooks
            }
            self.publishHealth()
            self.onSourcedEvent?(
                SourcedCodexEvent(
                    source: event.kind == .agentTurnComplete ? .legacyNotify : .hooks,
                    event: event,
                    receivedAt: Date(),
                    confidence: event.kind == .agentTurnComplete ? .inferred : .direct,
                    isBackfill: isBackfill
                )
            )
        }
        sessionSource.start { [weak self] event, isBackfill in
            guard let self else { return }
            if isBackfill {
                self.evidence.sessionBackfillEventCount = (self.evidence.sessionBackfillEventCount ?? 0) + 1
                if self.evidence.lastSessionBackfillEventAt.map({ event.occurredAt > $0 }) ?? true {
                    self.evidence.lastSessionBackfillEventAt = event.occurredAt
                }
            } else {
                self.evidence.lastSessionEventAt = Date()
                self.evidence.lastEventSource = .codexSessions
            }
            self.publishHealth()
            self.onSourcedEvent?(
                SourcedCodexEvent(
                    source: .codexSessions,
                    event: event,
                    receivedAt: Date(),
                    confidence: .authoritative,
                    isBackfill: isBackfill
                )
            )
        } availabilityChanged: { [weak self] available in
            guard let self else { return }
            self.evidence.sessionLogDetected = available
            self.publishHealth()
        }
        publishHealth()
    }

    func installAndVerify() throws -> String {
        try configurator.install()
        refreshConfiguration()
        return try runConnectionTest()
    }

    func uninstall() throws {
        try configurator.uninstall()
        evidence.lastHookEventAt = nil
        evidence.hookSelfTestPassedAt = nil
        refreshConfiguration()
    }

    func runConnectionTest() throws -> String {
        refreshConfiguration()
        guard evidence.hooksInstalled else {
            throw NSError(
                domain: "CodexBell",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Hooks are not installed for Codex Bell. Choose Install / Repair Hooks first."]
            )
        }
        evidence.hookSelfTestPassedAt = try hookSource.runSelfTest()
        publishHealth()
        return "Helper verified. Waiting for an actual current Codex event before showing Live."
    }

    func refreshConfiguration() {
        let status = configurator.installationStatus()
        evidence.hooksInstalled = status.hooksInstalledForCurrentApp
        evidence.legacyNotifyAvailable = status.legacyNotifyInstalledForCurrentApp
        evidence.targetAuditStatus = status.targetAudit.status
        evidence.integrationProblemCode = Self.problemCode(for: status.targetAudit.status)
        evidence.socketDetected = status.controlSocketDetected
        evidence.codexVersion = CodexEnvironment.version()

        appServerObserver.start()
        if case .socketAvailable = appServerObserver.status {
            evidence.socketDetected = true
        }
        // Phase-0 proved this desktop surface has no safely shareable App Server.
        // Socket presence alone must never elevate the mode to App Server Live.
        evidence.appServerConnected = false
        evidence.appServerInitialized = false
        publishHealth()
    }

    private func publishHealth() {
        onHealthChanged?(IntegrationHealthEvaluator.evaluate(evidence))
    }

    private static func problemCode(for status: IntegrationTargetStatus) -> IntegrationProblemCode? {
        switch status {
        case .current, .notInstalled: return nil
        case .missingHelper: return .missingHelper
        case .incompleteBellHooks: return .incompleteBellHooks
        case .destinationMismatch: return .destinationMismatch
        case .staleBellTarget: return .staleBellTarget
        }
    }
}
#endif
