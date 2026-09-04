import Foundation

public enum EventSource: String, Codable, Sendable, Equatable {
    case appServer
    case codexSessions
    case hooks
    case legacyNotify

    public var precedence: Int {
        switch self {
        case .appServer: return 300
        case .codexSessions: return 250
        case .hooks: return 200
        case .legacyNotify: return 100
        }
    }
}

public enum EventConfidence: String, Codable, Sendable, Equatable {
    case authoritative
    case direct
    case inferred
}

public struct SourcedCodexEvent: Sendable, Equatable {
    public var source: EventSource
    public var event: CodexEvent
    public var receivedAt: Date
    public var confidence: EventConfidence
    public var isBackfill: Bool

    public init(
        source: EventSource,
        event: CodexEvent,
        receivedAt: Date = Date(),
        confidence: EventConfidence,
        isBackfill: Bool = false
    ) {
        self.source = source
        self.event = event
        self.receivedAt = receivedAt
        self.confidence = confidence
        self.isBackfill = isBackfill
    }
}

public enum IntegrationMode: Sendable, Equatable {
    case appServerLive
    case codexSessionLive
    case hooksLive
    case installedWaiting
    case problem(IntegrationProblemCode)
    case notInstalled
    case legacyOnly

    public var displayName: String {
        switch self {
        case .appServerLive: return "Live · App Server"
        case .codexSessionLive: return "Live · Codex"
        case .hooksLive: return "Live · Hooks"
        case .installedWaiting: return "Installed · Waiting for event"
        case .problem: return "Integration problem"
        case .notInstalled: return "Not installed"
        case .legacyOnly: return "Completion only · Legacy notify"
        }
    }
}

public enum IntegrationProblemCode: String, Codable, Sendable, Equatable {
    case missingHelper
    case incompleteBellHooks
    case destinationMismatch
    case staleBellTarget
    case configurationWriteFailed
    case sessionSourceUnavailable
    case unknown
}

public struct IntegrationEvidence: Codable, Sendable, Equatable {
    public var appServerConnected: Bool
    public var appServerInitialized: Bool
    public var socketDetected: Bool
    public var lastAppServerResponseAt: Date?
    public var hooksInstalled: Bool
    public var lastHookEventAt: Date?
    public var hookSelfTestPassedAt: Date?
    public var legacyNotifyAvailable: Bool
    public var codexVersion: String?
    public var sessionLogDetected: Bool?
    public var lastSessionEventAt: Date?
    public var currentInstanceStartedAt: Date?
    public var lastEventSource: EventSource?
    public var integrationProblemCode: IntegrationProblemCode?
    public var targetAuditStatus: IntegrationTargetStatus?
    public var sessionBackfillEventCount: Int?
    public var lastSessionBackfillEventAt: Date?

    public init(
        appServerConnected: Bool = false,
        appServerInitialized: Bool = false,
        socketDetected: Bool = false,
        lastAppServerResponseAt: Date? = nil,
        hooksInstalled: Bool = false,
        lastHookEventAt: Date? = nil,
        hookSelfTestPassedAt: Date? = nil,
        legacyNotifyAvailable: Bool = false,
        codexVersion: String? = nil,
        sessionLogDetected: Bool? = nil,
        lastSessionEventAt: Date? = nil,
        currentInstanceStartedAt: Date? = nil,
        lastEventSource: EventSource? = nil,
        integrationProblemCode: IntegrationProblemCode? = nil,
        targetAuditStatus: IntegrationTargetStatus? = nil,
        sessionBackfillEventCount: Int? = nil,
        lastSessionBackfillEventAt: Date? = nil
    ) {
        self.appServerConnected = appServerConnected
        self.appServerInitialized = appServerInitialized
        self.socketDetected = socketDetected
        self.lastAppServerResponseAt = lastAppServerResponseAt
        self.hooksInstalled = hooksInstalled
        self.lastHookEventAt = lastHookEventAt
        self.hookSelfTestPassedAt = hookSelfTestPassedAt
        self.legacyNotifyAvailable = legacyNotifyAvailable
        self.codexVersion = codexVersion
        self.sessionLogDetected = sessionLogDetected
        self.lastSessionEventAt = lastSessionEventAt
        self.currentInstanceStartedAt = currentInstanceStartedAt
        self.lastEventSource = lastEventSource
        self.integrationProblemCode = integrationProblemCode
        self.targetAuditStatus = targetAuditStatus
        self.sessionBackfillEventCount = sessionBackfillEventCount
        self.lastSessionBackfillEventAt = lastSessionBackfillEventAt
    }
}

public struct IntegrationHealth: Sendable, Equatable {
    public var mode: IntegrationMode
    public var codexVersion: String?
    public var socketDetected: Bool
    public var hooksInstalled: Bool
    public var lastEventAt: Date?
    public var lastError: String?
    public var sessionLogDetected: Bool
    public var lastEventSource: EventSource?
    public var targetAuditStatus: IntegrationTargetStatus?

    public init(
        mode: IntegrationMode,
        codexVersion: String?,
        socketDetected: Bool,
        hooksInstalled: Bool,
        lastEventAt: Date?,
        lastError: String?,
        sessionLogDetected: Bool = false,
        lastEventSource: EventSource? = nil,
        targetAuditStatus: IntegrationTargetStatus? = nil
    ) {
        self.mode = mode
        self.codexVersion = codexVersion
        self.socketDetected = socketDetected
        self.hooksInstalled = hooksInstalled
        self.lastEventAt = lastEventAt
        self.lastError = lastError
        self.sessionLogDetected = sessionLogDetected
        self.lastEventSource = lastEventSource
        self.targetAuditStatus = targetAuditStatus
    }
}

public enum IntegrationHealthEvaluator {
    public static let appServerFreshness: TimeInterval = 30
    public static func evaluate(_ evidence: IntegrationEvidence, now: Date = Date()) -> IntegrationHealth {
        let lastEvent = latest(
            evidence.lastAppServerResponseAt,
            latest(evidence.lastSessionEventAt, evidence.lastHookEventAt)
        )

        if let problem = evidence.integrationProblemCode {
            return health(.problem(problem), evidence: evidence, lastEvent: lastEvent, error: problem.rawValue)
        }

        if evidence.appServerConnected,
           evidence.appServerInitialized,
           isFresh(evidence.lastAppServerResponseAt, within: appServerFreshness, now: now),
           isCurrentInstanceEvent(evidence.lastAppServerResponseAt, instanceStartedAt: evidence.currentInstanceStartedAt) {
            return health(.appServerLive, evidence: evidence, lastEvent: lastEvent, error: nil)
        }
        if evidence.sessionLogDetected == true,
           isCurrentInstanceEvent(evidence.lastSessionEventAt, instanceStartedAt: evidence.currentInstanceStartedAt) {
            return health(.codexSessionLive, evidence: evidence, lastEvent: lastEvent, error: nil)
        }
        if evidence.hooksInstalled,
           isCurrentInstanceEvent(evidence.lastHookEventAt, instanceStartedAt: evidence.currentInstanceStartedAt) {
            return health(.hooksLive, evidence: evidence, lastEvent: lastEvent, error: nil)
        }
        if evidence.hooksInstalled || evidence.sessionLogDetected == true {
            return health(.installedWaiting, evidence: evidence, lastEvent: lastEvent, error: nil)
        }
        if evidence.legacyNotifyAvailable {
            return health(.legacyOnly, evidence: evidence, lastEvent: lastEvent, error: nil)
        }
        return health(.notInstalled, evidence: evidence, lastEvent: lastEvent, error: nil)
    }

    private static func health(
        _ mode: IntegrationMode,
        evidence: IntegrationEvidence,
        lastEvent: Date?,
        error: String?
    ) -> IntegrationHealth {
        IntegrationHealth(
            mode: mode,
            codexVersion: evidence.codexVersion,
            socketDetected: evidence.socketDetected,
            hooksInstalled: evidence.hooksInstalled,
            lastEventAt: lastEvent,
            lastError: error,
            sessionLogDetected: evidence.sessionLogDetected == true,
            lastEventSource: evidence.lastEventSource,
            targetAuditStatus: evidence.targetAuditStatus
        )
    }

    private static func isCurrentInstanceEvent(_ event: Date?, instanceStartedAt: Date?) -> Bool {
        guard let event, let instanceStartedAt else { return false }
        return event >= instanceStartedAt.addingTimeInterval(-1)
    }

    private static func isFresh(_ date: Date?, within interval: TimeInterval, now: Date) -> Bool {
        guard let date else { return false }
        let age = now.timeIntervalSince(date)
        return age >= -5 && age <= interval
    }

    private static func latest(_ lhs: Date?, _ rhs: Date?) -> Date? {
        switch (lhs, rhs) {
        case let (l?, r?): return max(l, r)
        case let (l?, nil): return l
        case let (nil, r?): return r
        case (nil, nil): return nil
        }
    }
}
