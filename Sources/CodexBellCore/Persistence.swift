import Foundation

public struct PersistedTask: Codable, Sendable, Equatable, Identifiable {
    public var turnID: String
    public var projectName: String
    public var taskName: String?
    public var state: TaskState
    public var startedAt: Date
    public var endedAt: Date?
    public var lastStateChangedAt: Date
    public var eventGeneration: Int

    public var id: String { turnID }

    public init(task: TrackedTask) {
        self.turnID = task.turnID
        let safeProject = TaskNameExtractor.sanitizeForSpeech(task.projectName)
        self.projectName = safeProject.isEmpty ? "Codex Task" : safeProject
        if let taskName = task.taskName {
            let safeTask = TaskNameExtractor.sanitizeForSpeech(taskName)
            self.taskName = safeTask.isEmpty ? nil : safeTask
        } else {
            self.taskName = nil
        }
        self.state = task.state
        self.startedAt = task.startedAt
        self.endedAt = task.endedAt
        self.lastStateChangedAt = task.lastStateChangedAt
        self.eventGeneration = task.eventGeneration
    }

    public var trackedTask: TrackedTask {
        TrackedTask(
            turnID: turnID,
            projectName: projectName,
            taskName: taskName,
            state: state,
            startedAt: startedAt,
            endedAt: endedAt,
            lastStateChangedAt: lastStateChangedAt,
            eventGeneration: eventGeneration
        )
    }
}

public struct PersistedSnapshot: Codable, Sendable, Equatable {
    public var version: Int
    public var savedAt: Date
    public var settings: BellSettings
    public var tasks: [PersistedTask]
    public var integrationEvidence: IntegrationEvidence?

    public init(
        version: Int = 2,
        savedAt: Date = Date(),
        settings: BellSettings,
        tasks: [PersistedTask],
        integrationEvidence: IntegrationEvidence? = nil
    ) {
        self.version = version
        self.savedAt = savedAt
        self.settings = settings
        self.tasks = tasks
        self.integrationEvidence = integrationEvidence
    }

    public static func make(
        settings: BellSettings,
        tasks: [TrackedTask],
        integrationEvidence: IntegrationEvidence? = nil,
        savedAt: Date = Date()
    ) -> PersistedSnapshot {
        let recent = tasks
            .sorted { $0.lastStateChangedAt > $1.lastStateChangedAt }
            .prefix(20)
            .map(PersistedTask.init(task:))
        return PersistedSnapshot(savedAt: savedAt, settings: settings, tasks: Array(recent), integrationEvidence: integrationEvidence)
    }
}

public enum PersistenceCodec {
    public static func encode(_ snapshot: PersistedSnapshot) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(snapshot)
    }

    public static func decode(_ data: Data) throws -> PersistedSnapshot {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(PersistedSnapshot.self, from: data)
    }

    public static func encodeEvent(_ event: CodexEvent) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(event)
    }

    public static func decodeEvent(_ data: Data) throws -> CodexEvent {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(CodexEvent.self, from: data)
    }
}

public extension CodexEvent {
    func redactedForInbox() -> CodexEvent {
        var copy = self
        // Raw hooks classify missing output at decode time. Already-redacted
        // authoritative completion events have no message and retain their kind.
        if (kind == .stop || kind == .agentTurnComplete), let lastAssistantMessage {
            let outcome = TerminalOutcomeClassifier.classify(lastAssistantMessage)
            if outcome != .completed { copy.kind = outcome.eventKind }
        }
        copy.identity = identity ?? TaskNameExtractor.extract(cwd: cwd, prompt: prompt)
        copy.cwd = nil
        copy.prompt = nil
        copy.lastAssistantMessage = nil
        copy.toolName = nil
        return copy
    }
}

public enum EventInboxWriter {
    @discardableResult
    public static func write(_ event: CodexEvent, to directory: URL) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let base = UUID().uuidString.lowercased()
        let temporary = directory.appendingPathComponent("\(base).json.tmp")
        let final = directory.appendingPathComponent("\(base).json")
        let data = try PersistenceCodec.encodeEvent(event)
        try data.write(to: temporary, options: .atomic)
        try FileManager.default.moveItem(at: temporary, to: final)
        return final
    }
}
