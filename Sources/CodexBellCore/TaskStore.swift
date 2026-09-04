import Foundation

public struct TaskTransition: Sendable, Equatable {
    public var task: TrackedTask
    public var previousState: TaskState?
    public var announcementKind: AnnouncementKind?

    public init(task: TrackedTask, previousState: TaskState?, announcementKind: AnnouncementKind?) {
        self.task = task
        self.previousState = previousState
        self.announcementKind = announcementKind
    }
}

public struct TaskStore: Sendable {
    private var tasksByID: [String: TrackedTask] = [:]
    private var order: [String] = []
    private let recentLimit: Int

    public init(recentLimit: Int = 20) {
        self.recentLimit = max(1, recentLimit)
    }

    public init(restoring tasks: [TrackedTask], recentLimit: Int = 20) {
        self.recentLimit = max(1, recentLimit)
        for task in tasks.sorted(by: { $0.startedAt < $1.startedAt }) {
            guard !task.turnID.isEmpty else { continue }
            if tasksByID[task.turnID] == nil { order.append(task.turnID) }
            tasksByID[task.turnID] = task
        }
        trimTerminalHistoryIfNeeded()
    }

    public var allTasks: [TrackedTask] {
        order.compactMap { tasksByID[$0] }.sorted { $0.lastStateChangedAt > $1.lastStateChangedAt }
    }

    public var activeTasks: [TrackedTask] {
        allTasks.filter { $0.state == .running || $0.state == .waitingApproval || $0.state == .waitingInput }
    }

    public var recentTasks: [TrackedTask] {
        allTasks.filter { $0.state == .completed || $0.state == .failed || $0.state == .interrupted || $0.state == .unknownFinished }
    }

    public func task(turnID: String) -> TrackedTask? { tasksByID[turnID] }

    public mutating func clearTerminalHistory() {
        let terminalIDs = Set(order.filter { id in
            guard let task = tasksByID[id] else { return false }
            return isTerminal(task.state)
        })
        order.removeAll { terminalIDs.contains($0) }
        for id in terminalIDs { tasksByID.removeValue(forKey: id) }
    }

    @discardableResult
    public mutating func apply(
        event: CodexEvent,
        at timestamp: Date? = nil,
        allowTerminalCorrection: Bool = false
    ) -> TaskTransition? {
        let now = timestamp ?? event.occurredAt
        if let existing = tasksByID[event.turnID], isTerminal(existing.state) {
            if event.kind == .stop || event.kind == .agentTurnComplete || event.kind == .interrupt || event.kind == .turnFailed {
                guard allowTerminalCorrection else { return nil }
            } else {
                return nil
            }
        }

        var task: TrackedTask
        let previous = tasksByID[event.turnID]?.state

        if let existing = tasksByID[event.turnID] {
            task = existing
            if let session = event.sessionID { task.sessionID = session }
            if let identity = event.identity {
                task.projectName = identity.projectName
                task.taskName = identity.taskName
            } else if (task.projectName == "Codex" || task.projectName.isEmpty), let cwd = event.cwd {
                let identity = TaskNameExtractor.extract(cwd: cwd, prompt: event.prompt)
                task.projectName = identity.projectName
                task.taskName = identity.taskName
            }
        } else {
            let identity = event.identity ?? TaskNameExtractor.extract(cwd: event.cwd, prompt: event.prompt)
            task = TrackedTask(
                turnID: event.turnID,
                sessionID: event.sessionID,
                projectName: identity.projectName,
                taskName: identity.taskName,
                state: .running,
                startedAt: now,
                lastStateChangedAt: now
            )
            order.append(event.turnID)
        }

        let targetState: TaskState
        let announcement: AnnouncementKind?
        switch event.kind {
        case .userPromptSubmit:
            targetState = .running
            announcement = nil
            if let identity = event.identity {
                task.projectName = identity.projectName
                task.taskName = identity.taskName
            } else if let prompt = event.prompt {
                let identity = TaskNameExtractor.extract(cwd: event.cwd, prompt: prompt)
                task.projectName = identity.projectName
                task.taskName = identity.taskName
            }
        case .permissionRequest:
            targetState = .waitingApproval
            announcement = previous == .waitingApproval ? nil : .waitingApproval
        case .waitingInput:
            targetState = .waitingInput
            announcement = previous == .waitingInput ? nil : .waitingInput
        case .preToolUse, .postToolUse:
            targetState = .running
            announcement = nil
        case .stop, .agentTurnComplete:
            targetState = .completed
            announcement = .completed
        case .interrupt:
            targetState = .interrupted
            announcement = .interrupted
        case .turnFailed:
            targetState = .failed
            announcement = .failed
        }

        if previous == targetState && event.kind != .userPromptSubmit {
            return nil
        }

        if previous != targetState {
            task.eventGeneration += 1
        }
        task.state = targetState
        task.lastStateChangedAt = now
        if isTerminal(targetState) { task.endedAt = now }
        else { task.endedAt = nil }

        tasksByID[event.turnID] = task
        trimTerminalHistoryIfNeeded()
        return TaskTransition(task: task, previousState: previous, announcementKind: announcement)
    }

    private func isTerminal(_ state: TaskState) -> Bool {
        state == .completed || state == .failed || state == .interrupted || state == .unknownFinished
    }

    private mutating func trimTerminalHistoryIfNeeded() {
        let terminalIDs = order.filter { id in
            guard let task = tasksByID[id] else { return false }
            return isTerminal(task.state)
        }.sorted { lhs, rhs in
            guard let left = tasksByID[lhs], let right = tasksByID[rhs] else { return false }
            if left.lastStateChangedAt != right.lastStateChangedAt {
                return left.lastStateChangedAt < right.lastStateChangedAt
            }
            return lhs < rhs
        }
        guard terminalIDs.count > recentLimit else { return }
        let removeCount = terminalIDs.count - recentLimit
        let doomed = Set(terminalIDs.prefix(removeCount))
        order.removeAll { doomed.contains($0) }
        for id in doomed { tasksByID.removeValue(forKey: id) }
    }
}
