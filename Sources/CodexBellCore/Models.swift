import Foundation

public enum AppLanguage: String, Codable, CaseIterable, Sendable, Equatable {
    case zhHans
    case en

    public static func systemDefault(preferredLanguages: [String]) -> AppLanguage {
        preferredLanguages.first?.lowercased().hasPrefix("zh") == true ? .zhHans : .en
    }

    public var selectionName: String {
        switch self {
        case .zhHans: return "中文"
        case .en: return "English"
        }
    }
}

public enum TaskState: String, Codable, Sendable, Equatable {
    case running
    case waitingApproval
    case waitingInput
    case completed
    case failed
    case interrupted
    case unknownFinished
}

public enum CodexEventKind: String, Codable, Sendable, Equatable {
    case userPromptSubmit
    case permissionRequest
    case preToolUse
    case postToolUse
    case stop
    case interrupt
    case agentTurnComplete
    case turnFailed
    case turnRetrying
    case turnUnknownFinished
    case waitingInput
}

public struct CodexEvent: Codable, Sendable, Equatable {
    public var kind: CodexEventKind
    public var turnID: String
    public var sessionID: String?
    public var cwd: String?
    public var prompt: String?
    public var lastAssistantMessage: String?
    public var toolName: String?
    public var identity: TaskIdentity?
    public var occurredAt: Date

    public init(
        kind: CodexEventKind,
        turnID: String,
        sessionID: String? = nil,
        cwd: String? = nil,
        prompt: String? = nil,
        lastAssistantMessage: String? = nil,
        toolName: String? = nil,
        identity: TaskIdentity? = nil,
        occurredAt: Date = Date()
    ) {
        self.kind = kind
        self.turnID = turnID
        self.sessionID = sessionID
        self.cwd = cwd
        self.prompt = prompt
        self.lastAssistantMessage = lastAssistantMessage
        self.toolName = toolName
        self.identity = identity
        self.occurredAt = occurredAt
    }
}

public struct TaskIdentity: Codable, Sendable, Equatable {
    public var projectName: String
    public var taskName: String?

    public init(projectName: String, taskName: String? = nil) {
        self.projectName = projectName
        self.taskName = taskName
    }

    public var spokenName: String {
        if let taskName, !taskName.isEmpty {
            return "\(projectName) \(taskName)"
        }
        return projectName
    }
}

public struct TrackedTask: Codable, Sendable, Equatable, Identifiable {
    public var turnID: String
    public var sessionID: String?
    public var projectName: String
    public var taskName: String?
    public var state: TaskState
    public var startedAt: Date
    public var endedAt: Date?
    public var lastStateChangedAt: Date
    public var eventGeneration: Int

    public var id: String { turnID }

    public init(
        turnID: String,
        sessionID: String? = nil,
        projectName: String,
        taskName: String? = nil,
        state: TaskState,
        startedAt: Date,
        endedAt: Date? = nil,
        lastStateChangedAt: Date? = nil,
        eventGeneration: Int = 0
    ) {
        self.turnID = turnID
        self.sessionID = sessionID
        self.projectName = projectName
        self.taskName = taskName
        self.state = state
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.lastStateChangedAt = lastStateChangedAt ?? startedAt
        self.eventGeneration = eventGeneration
    }

    public var duration: TimeInterval? {
        guard let endedAt else { return nil }
        return max(0, endedAt.timeIntervalSince(startedAt))
    }

    public var isActivelyRunning: Bool { state == .running }

    public var identity: TaskIdentity {
        TaskIdentity(projectName: projectName, taskName: taskName)
    }
}

public struct BellSettings: Codable, Sendable, Equatable {
    public var announcementsEnabled: Bool
    public var volume: Double
    public var keepAwakeWhileRunning: Bool
    public var launchAtLogin: Bool
    public var showInDock: Bool
    public var dockAnchor: DockAnchor
    public var autoHideEnabled: Bool
    public var urgentPeekEnabled: Bool
    public var panelPinned: Bool
    public var dockVerticalFraction: Double
    public var autoHideDelay: TimeInterval
    public var selectedDisplayID: String?
    public var languageOverride: AppLanguage?

    public init(
        announcementsEnabled: Bool = true,
        volume: Double = 0.7,
        keepAwakeWhileRunning: Bool = true,
        launchAtLogin: Bool = false,
        showInDock: Bool = false,
        dockAnchor: DockAnchor = .right,
        autoHideEnabled: Bool = true,
        urgentPeekEnabled: Bool = true,
        panelPinned: Bool = false,
        dockVerticalFraction: Double = 0.5,
        autoHideDelay: TimeInterval = 0.9,
        selectedDisplayID: String? = nil,
        languageOverride: AppLanguage? = nil
    ) {
        self.announcementsEnabled = announcementsEnabled
        self.volume = min(max(volume, 0), 1)
        self.keepAwakeWhileRunning = keepAwakeWhileRunning
        self.launchAtLogin = launchAtLogin
        self.showInDock = showInDock
        self.dockAnchor = dockAnchor
        self.autoHideEnabled = autoHideEnabled
        self.urgentPeekEnabled = urgentPeekEnabled
        self.panelPinned = panelPinned
        self.dockVerticalFraction = min(max(dockVerticalFraction, 0), 1)
        self.autoHideDelay = min(max(autoHideDelay, 0.2), 3)
        self.selectedDisplayID = selectedDisplayID
        self.languageOverride = languageOverride
    }

    public static let `default` = BellSettings()

    private enum CodingKeys: String, CodingKey {
        case announcementsEnabled, volume, keepAwakeWhileRunning, launchAtLogin, showInDock, dockAnchor, autoHideEnabled
        case urgentPeekEnabled, panelPinned, dockVerticalFraction
        case autoHideDelay, selectedDisplayID, languageOverride
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            announcementsEnabled: try values.decodeIfPresent(Bool.self, forKey: .announcementsEnabled) ?? true,
            volume: try values.decodeIfPresent(Double.self, forKey: .volume) ?? 0.7,
            keepAwakeWhileRunning: try values.decodeIfPresent(Bool.self, forKey: .keepAwakeWhileRunning) ?? true,
            launchAtLogin: try values.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false,
            showInDock: try values.decodeIfPresent(Bool.self, forKey: .showInDock) ?? false,
            dockAnchor: try values.decodeIfPresent(DockAnchor.self, forKey: .dockAnchor) ?? .right,
            autoHideEnabled: try values.decodeIfPresent(Bool.self, forKey: .autoHideEnabled) ?? true,
            urgentPeekEnabled: try values.decodeIfPresent(Bool.self, forKey: .urgentPeekEnabled) ?? true,
            panelPinned: try values.decodeIfPresent(Bool.self, forKey: .panelPinned) ?? false,
            dockVerticalFraction: try values.decodeIfPresent(Double.self, forKey: .dockVerticalFraction) ?? 0.5,
            autoHideDelay: try values.decodeIfPresent(TimeInterval.self, forKey: .autoHideDelay) ?? 0.9,
            selectedDisplayID: try values.decodeIfPresent(String.self, forKey: .selectedDisplayID),
            languageOverride: try values.decodeIfPresent(AppLanguage.self, forKey: .languageOverride)
        )
    }
}

public enum AnnouncementKind: String, Codable, Sendable, Equatable {
    case completed
    case failed
    case interrupted
    case waitingApproval
    case waitingInput

    public var priority: Int {
        switch self {
        case .waitingApproval, .waitingInput: return 400
        case .failed: return 300
        case .interrupted: return 200
        case .completed: return 100
        }
    }
}

public struct Announcement: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public var turnID: String
    public var kind: AnnouncementKind
    public var identity: TaskIdentity
    public var generation: Int
    public var createdAt: Date
    public var isTest: Bool
    public var volumeOverride: Double?

    public init(
        turnID: String,
        kind: AnnouncementKind,
        identity: TaskIdentity,
        generation: Int,
        createdAt: Date = Date(),
        isTest: Bool = false,
        volumeOverride: Double? = nil
    ) {
        self.turnID = turnID
        self.kind = kind
        self.identity = identity
        self.generation = generation
        self.createdAt = createdAt
        self.isTest = isTest
        self.volumeOverride = volumeOverride.map { min(max($0, 0), 1) }
        self.id = "\(turnID):\(kind.rawValue):\(generation)"
    }
}
