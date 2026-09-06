import Foundation

public struct ReconciledTransition: Sendable, Equatable {
    public var task: TrackedTask
    public var previousState: TaskState?
    public var announcementKind: AnnouncementKind?
    public var source: EventSource

    public init(task: TrackedTask, previousState: TaskState?, announcementKind: AnnouncementKind?, source: EventSource) {
        self.task = task
        self.previousState = previousState
        self.announcementKind = announcementKind
        self.source = source
    }
}

public struct SourceReconciler: Sendable {
    private var store: TaskStore
    private var strongestSourceByTurn: [String: EventSource] = [:]
    private var excludedTurnIDs: Set<String> = []

    public init(recentLimit: Int = 20) {
        store = TaskStore(recentLimit: recentLimit)
    }

    public init(restoring tasks: [TrackedTask], source: EventSource, recentLimit: Int = 20) {
        store = TaskStore(restoring: tasks, recentLimit: recentLimit)
        strongestSourceByTurn = Dictionary(
            uniqueKeysWithValues: store.allTasks.map { ($0.turnID, source) }
        )
    }

    public var allTasks: [TrackedTask] { store.allTasks }
    public var activeTasks: [TrackedTask] { store.activeTasks }
    public var recentTasks: [TrackedTask] { store.recentTasks }

    public func task(turnID: String) -> TrackedTask? {
        store.task(turnID: turnID)
    }

    @discardableResult
    public mutating func excludeSubagentTurn(_ turnID: String) -> Bool {
        excludedTurnIDs.insert(turnID)
        strongestSourceByTurn.removeValue(forKey: turnID)
        return store.removeTask(turnID: turnID)
    }

    public mutating func clearTerminalHistory() {
        let terminalIDs = Set(store.recentTasks.map(\.turnID))
        store.clearTerminalHistory()
        for id in terminalIDs { strongestSourceByTurn.removeValue(forKey: id) }
    }

    @discardableResult
    public mutating func apply(_ sourced: SourcedCodexEvent) -> ReconciledTransition? {
        var event = sourced.event
        if event.turnID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            guard let sessionID = event.sessionID, !sessionID.isEmpty else { return nil }
            event.turnID = "session:\(sessionID)"
        }
        guard !excludedTurnIDs.contains(event.turnID) else { return nil }

        let currentSource = strongestSourceByTurn[event.turnID]
        if let currentSource, currentSource.precedence > sourced.source.precedence {
            return nil
        }

        let existing = store.task(turnID: event.turnID)
        let isAuthoritativeCorrection = currentSource.map { sourced.source.precedence > $0.precedence } == true
            && existing.map { Self.isTerminal($0.state) } == true
            && Self.isTerminal(event.kind)
        // Re-read exact historical outcomes to repair older success-by-default
        // records, without replaying audio or letting stale records undo a later success.
        let isHistoricalCorrection = sourced.source == .codexSessions && sourced.isBackfill
            && existing?.state == .completed
            && existing.map { event.occurredAt >= $0.lastStateChangedAt } == true
            && [.turnFailed, .interrupt, .turnUnknownFinished, .turnRetrying].contains(event.kind)
        let isUnknownResolution = existing?.state == .unknownFinished && Self.isTerminal(event.kind)
            && existing.map { event.occurredAt >= $0.lastStateChangedAt } == true
        let isExplicitResume = sourced.source == .codexSessions
            && existing.map { Self.isTerminal($0.state) && $0.state != .completed
                && event.occurredAt > $0.lastStateChangedAt } == true
            && [.userPromptSubmit, .turnRetrying].contains(event.kind)

        if currentSource == nil || sourced.source.precedence > currentSource!.precedence {
            strongestSourceByTurn[event.turnID] = sourced.source
        }

        guard var transition = store.apply(
            event: event,
            at: event.occurredAt,
            allowTerminalCorrection: isAuthoritativeCorrection || isHistoricalCorrection
                || isUnknownResolution || isExplicitResume
        ) else { return nil }

        if sourced.isBackfill {
            transition.announcementKind = nil
        }
        return ReconciledTransition(
            task: transition.task,
            previousState: transition.previousState,
            announcementKind: transition.announcementKind,
            source: sourced.source
        )
    }

    private static func isTerminal(_ state: TaskState) -> Bool {
        state == .completed || state == .failed || state == .interrupted || state == .unknownFinished
    }

    private static func isTerminal(_ kind: CodexEventKind) -> Bool {
        kind == .stop || kind == .agentTurnComplete || kind == .interrupt || kind == .turnFailed
            || kind == .turnUnknownFinished
    }
}
