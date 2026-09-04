#if os(macOS)
import AppKit
import Combine
import Foundation
import CodexBellCore

@MainActor
final class AppModel: ObservableObject {
    @Published var settings: BellSettings
    @Published private(set) var activeTasks: [TrackedTask] = []
    @Published private(set) var recentTasks: [TrackedTask] = []
    @Published private(set) var integrationHealth: IntegrationHealth
    @Published private(set) var connectionTestMessage: String?
    @Published private(set) var lastIntegrationError: String?

    private var reconciler = SourceReconciler()
    private let queue = AnnouncementQueue()
    private let audio = AudioAnnouncer()
    private let notifier = SystemNotifier()
    private let power = PowerAssertionController()
    private let login = LoginItemController()
    private var volumePreviewDebouncer = VolumePreviewDebouncer()
    private var volumePreviewTask: Task<Void, Never>?
    private var liveBridge: LiveCodexBridge!
    private var isPumping = false
    private var cancellables: Set<AnyCancellable> = []

    var onUrgentTransition: ((TaskState) -> Void)?

    let appSupportDirectory: URL
    let inboxDirectory: URL
    let stateURL: URL

    init() {
        let supportName = AppSupportIdentity.supportDirectoryName(
            bundleIdentifier: Bundle.main.bundleIdentifier,
            declaredName: Bundle.main.object(forInfoDictionaryKey: "CodexBellSupportDirectoryName") as? String
        )
        let base = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent(supportName, isDirectory: true)
        appSupportDirectory = base
        inboxDirectory = base.appendingPathComponent("Inbox", isDirectory: true)
        stateURL = base.appendingPathComponent("state.json")

        let snapshot = (try? Data(contentsOf: stateURL)).flatMap { try? PersistenceCodec.decode($0) }
        settings = snapshot?.settings ?? .default
        var initialEvidence = snapshot?.integrationEvidence ?? IntegrationEvidence()
        initialEvidence.currentInstanceStartedAt = Date()
        initialEvidence.lastEventSource = nil
        integrationHealth = IntegrationHealthEvaluator.evaluate(initialEvidence)
        reconciler = SourceReconciler(
            restoring: (snapshot?.tasks ?? []).map(\.trackedTask),
            source: initialEvidence.sessionLogDetected == true
                ? .codexSessions
                : (initialEvidence.hooksInstalled ? .hooks : .legacyNotify)
        )

        liveBridge = LiveCodexBridge(
            appSupportDirectory: appSupportDirectory,
            inboxDirectory: inboxDirectory,
            initialEvidence: initialEvidence
        )
        refreshPublishedTasks()

        $settings.dropFirst().sink { [weak self] _ in
            Task { @MainActor in self?.settingsChanged() }
        }.store(in: &cancellables)

        liveBridge.onSourcedEvent = { [weak self] event in self?.consume(event) }
        liveBridge.onHealthChanged = { [weak self] health in
            self?.integrationHealth = health
            self?.persist()
        }
        liveBridge.start()
        Task { await notifier.requestAuthorization() }
        syncPowerAssertion()
    }

    var runningCount: Int { reconciler.activeTasks.filter { $0.state == .running }.count }
    var waitingCount: Int { reconciler.activeTasks.filter { $0.state == .waitingApproval || $0.state == .waitingInput }.count }
    var language: AppLanguage {
        settings.languageOverride ?? AppLanguage.systemDefault(preferredLanguages: Locale.preferredLanguages)
    }
    var copy: LocalizedCopy { LocalizedCopy(language: language) }
    var integrationStatus: String { copy.integrationMode(integrationHealth.mode) }
    func integrationStatus(at date: Date) -> String { copy.integrationSummary(integrationHealth, now: date) }
    var handleStatus: HandleStatus { HandleStatus.resolve(active: activeTasks, recent: recentTasks) }

    var hooksConfigPath: String { CodexEnvironment.homeDirectory.appendingPathComponent("hooks.json").path }
    var installedHelperPath: String { Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/codex-bell-hook").path }
    var codexGUIHost: String { CodexEnvironment.guiHostDescription() ?? copy[.unavailable] }
    var lastEventSourceName: String { integrationHealth.lastEventSource?.rawValue ?? copy[.none] }
    var targetAuditName: String { integrationHealth.targetAuditStatus?.rawValue ?? copy[.none] }
    var repairResultName: String { connectionTestMessage ?? targetAuditName }

    func setLanguage(_ language: AppLanguage) {
        settings.languageOverride = language
    }

    func consume(_ sourced: SourcedCodexEvent) {
        guard let transition = reconciler.apply(sourced) else { return }
        refreshPublishedTasks()
        syncPowerAssertion()
        persist()

        if transition.task.state == .waitingApproval
            || transition.task.state == .waitingInput
            || transition.task.state == .failed {
            onUrgentTransition?(transition.task.state)
        }

        guard let kind = transition.announcementKind,
              AnnouncementPolicy.shouldAnnounce(task: transition.task, kind: kind, settings: settings) else { return }
        let announcement = Announcement(
            turnID: transition.task.turnID,
            kind: kind,
            identity: transition.task.identity,
            generation: transition.task.eventGeneration
        )
        Task {
            await queue.enqueue(announcement)
            await pumpAnnouncements()
        }
    }

    func testAnnouncement() {
        enqueueTestAnnouncement(
            turnID: "test-\(UUID().uuidString)",
            generation: 1,
            volume: settings.volume,
            coalescingKey: nil
        )
    }

    func scheduleVolumePreview() {
        let request = volumePreviewDebouncer.schedule(volume: settings.volume)
        volumePreviewTask?.cancel()
        volumePreviewTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await queue.removePending(withCoalescingKey: "volume-preview")
            do {
                try await Task.sleep(for: .seconds(VolumePreviewDebouncer.delay))
            } catch {
                return
            }
            guard let emission = volumePreviewDebouncer.consume(request) else { return }
            enqueueTestAnnouncement(
                turnID: "volume-preview",
                generation: Int(truncatingIfNeeded: emission.generation),
                volume: emission.volume,
                coalescingKey: "volume-preview"
            )
        }
    }

    private func enqueueTestAnnouncement(
        turnID: String,
        generation: Int,
        volume: Double,
        coalescingKey: String?
    ) {
        let announcement = Announcement(
            turnID: turnID,
            kind: .completed,
            identity: TaskIdentity(projectName: "Codex Bell"),
            generation: generation,
            isTest: true,
            volumeOverride: volume
        )
        Task {
            await queue.enqueue(announcement, replacingPendingWithKey: coalescingKey)
            await pumpAnnouncements()
        }
    }

    func clearHistory() {
        reconciler.clearTerminalHistory()
        refreshPublishedTasks()
        persist()
    }

    func configureCodex() {
        do {
            _ = try liveBridge.installAndVerify()
            connectionTestMessage = copy[.hooksVerifiedMessage]
            lastIntegrationError = nil
        } catch {
            lastIntegrationError = copy[.operationFailed]
        }
        persist()
    }

    func runConnectionTest() {
        do {
            _ = try liveBridge.runConnectionTest()
            connectionTestMessage = copy[.hooksVerifiedMessage]
            lastIntegrationError = nil
        } catch {
            connectionTestMessage = nil
            lastIntegrationError = copy[.operationFailed]
        }
        persist()
    }

    func uninstallCodexIntegration() {
        do {
            try liveBridge.uninstall()
            connectionTestMessage = copy[.hooksRemovedMessage]
            lastIntegrationError = nil
        } catch {
            lastIntegrationError = copy[.operationFailed]
        }
        persist()
    }

    func copySanitizedDiagnostics() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(sanitizedDiagnostics(), forType: .string)
        connectionTestMessage = copy[.diagnosticsCopiedMessage]
    }

    func openDiagnostics() {
        do {
            try FileManager.default.createDirectory(at: appSupportDirectory, withIntermediateDirectories: true)
            let url = appSupportDirectory.appendingPathComponent("diagnostics.txt")
            try sanitizedDiagnostics().write(to: url, atomically: true, encoding: .utf8)
            NSWorkspace.shared.open(url)
        } catch {
            lastIntegrationError = copy[.operationFailed]
        }
    }

    func sanitizedDiagnostics() -> String {
        let lastEvent = integrationHealth.lastEventAt.map { ISO8601DateFormatter().string(from: $0) } ?? copy[.never]
        let lastError = lastIntegrationError.map(PrivacySanitizer.sanitize) ?? copy[.none]
        return [
            copy[.diagnosticTitle],
            "\(copy[.diagnosticMode]): \(copy.integrationMode(integrationHealth.mode))",
            "\(copy[.codexHost]): \(codexGUIHost)",
            "\(copy[.codexVersion]): \(integrationHealth.codexVersion ?? copy[.unavailable])",
            "\(copy[.diagnosticSocket]): \(integrationHealth.socketDetected ? copy[.yes] : copy[.no])",
            "\(copy[.diagnosticHooks]): \(integrationHealth.hooksInstalled ? copy[.yes] : copy[.no])",
            "\(copy[.diagnosticLastEvent]): \(lastEvent)",
            "\(copy[.diagnosticDockAnchor]): \(copy.dockAnchor(settings.dockAnchor))",
            "\(copy[.diagnosticAutoHide]): \(settings.autoHideEnabled ? copy[.on] : copy[.off])",
            "\(copy[.diagnosticPinned]): \(settings.panelPinned ? copy[.yes] : copy[.no])",
            "\(copy[.diagnosticActiveTasks]): \(activeTasks.count)",
            "\(copy[.diagnosticRecentTasks]): \(recentTasks.count)",
            "\(copy[.diagnosticLastError]): \(lastError)"
        ].joined(separator: "\n") + "\n"
    }

    private func pumpAnnouncements() async {
        guard !isPumping else { return }
        isPumping = true
        defer { isPumping = false }
        while let item = await queue.next() {
            let currentLanguage = language
            await notifier.post(item, language: currentLanguage)
            await audio.announce(item, volume: item.volumeOverride ?? settings.volume, language: currentLanguage)
            await queue.markFinished()
            try? await Task.sleep(for: .seconds(1))
        }
    }

    private func refreshPublishedTasks() {
        activeTasks = reconciler.activeTasks
        recentTasks = Array(reconciler.recentTasks.prefix(20))
    }

    private func settingsChanged() {
        syncPowerAssertion()
        do {
            try login.setEnabled(settings.launchAtLogin)
        } catch {
            lastIntegrationError = copy[.operationFailed]
        }
        persist()
    }

    private func syncPowerAssertion() {
        power.update(runningCount: runningCount, enabled: settings.keepAwakeWhileRunning)
    }

    private func persist() {
        let snapshot = PersistedSnapshot.make(
            settings: settings,
            tasks: reconciler.allTasks,
            integrationEvidence: liveBridge?.evidence
        )
        do {
            try FileManager.default.createDirectory(at: appSupportDirectory, withIntermediateDirectories: true)
            try PersistenceCodec.encode(snapshot).write(to: stateURL, options: .atomic)
        } catch {
            lastIntegrationError = copy[.operationFailed]
        }
    }
}
#endif
