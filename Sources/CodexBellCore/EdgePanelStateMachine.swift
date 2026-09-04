import Foundation

public enum PanelVisibilityState: Sendable, Equatable {
    case expanded
    case autoHidden
}

public struct PanelWindowVisibility: Sendable, Equatable {
    public var mainPanel: Bool
    public var edgeHandle: Bool

    public init(mainPanel: Bool, edgeHandle: Bool) {
        self.mainPanel = mainPanel
        self.edgeHandle = edgeHandle
    }
}

public enum PanelInteractionLock: String, CaseIterable, Sendable, Equatable, Hashable {
    case mouseDown
    case drag
    case control
    case languagePicker
    case dockSelection
    case settings
}

public enum PanelEvent: Sendable, Equatable {
    case mainPointerEntered
    case mainPointerExited
    case handlePointerEntered
    case handlePointerExited
    case interactionBegan(PanelInteractionLock)
    case interactionEnded(PanelInteractionLock)
    case hideDelayElapsed
    case pinChanged(Bool)
    case dockChanged(DockAnchor)
    case collapseToEdge
    case appActivated
    case urgentEvent
    case urgentPeekElapsed
}

public enum PanelEffect: Sendable, Equatable {
    case cancelScheduledHide
    case scheduleHide(after: TimeInterval)
    case scheduleUrgentClear(after: TimeInterval)
}

public struct PanelStateMachine: Sendable, Equatable {
    public private(set) var anchor: DockAnchor
    public private(set) var visibility: PanelVisibilityState
    public private(set) var pointerInsideMain: Bool
    public private(set) var pointerInsideHandle: Bool
    public private(set) var interactionLocks: Set<PanelInteractionLock>
    public private(set) var isPinned: Bool
    public private(set) var isUrgent: Bool

    public init(
        anchor: DockAnchor,
        visibility: PanelVisibilityState,
        pointerInsideMain: Bool = false,
        pointerInsideHandle: Bool = false,
        interactionLocks: Set<PanelInteractionLock> = [],
        isPinned: Bool = false,
        isUrgent: Bool = false
    ) {
        self.anchor = anchor
        self.visibility = visibility
        self.pointerInsideMain = pointerInsideMain
        self.pointerInsideHandle = pointerInsideHandle
        self.interactionLocks = interactionLocks
        self.isPinned = isPinned
        self.isUrgent = isUrgent
    }

    public var windowVisibility: PanelWindowVisibility {
        if visibility == .expanded {
            return PanelWindowVisibility(mainPanel: true, edgeHandle: false)
        }
        return PanelWindowVisibility(mainPanel: false, edgeHandle: true)
    }

    public func isAutoHideEligible(autoHideEnabled: Bool) -> Bool {
        autoHideEnabled
            && visibility == .expanded
            && !isPinned
            && !pointerInsideMain
            && !pointerInsideHandle
            && interactionLocks.isEmpty
    }

    @discardableResult
    public mutating func handle(
        _ event: PanelEvent,
        autoHideEnabled: Bool = true,
        hideDelay: TimeInterval = 0.9,
        urgentPeekDuration: TimeInterval = 3
    ) -> [PanelEffect] {
        switch event {
        case .mainPointerEntered:
            pointerInsideMain = true
            pointerInsideHandle = false
            if visibility == .autoHidden { visibility = .expanded }
            return [.cancelScheduledHide]

        case .mainPointerExited:
            pointerInsideMain = false
            return scheduleHideIfEligible(autoHideEnabled: autoHideEnabled, hideDelay: hideDelay)

        case .handlePointerEntered:
            pointerInsideHandle = false
            pointerInsideMain = true
            visibility = .expanded
            return [.cancelScheduledHide]

        case .handlePointerExited:
            pointerInsideHandle = false
            return scheduleHideIfEligible(autoHideEnabled: autoHideEnabled, hideDelay: hideDelay)

        case let .interactionBegan(lock):
            interactionLocks.insert(lock)
            return [.cancelScheduledHide]

        case let .interactionEnded(lock):
            interactionLocks.remove(lock)
            return scheduleHideIfEligible(autoHideEnabled: autoHideEnabled, hideDelay: hideDelay)

        case .hideDelayElapsed:
            guard isAutoHideEligible(autoHideEnabled: autoHideEnabled) else { return [] }
            visibility = .autoHidden
            return []

        case let .pinChanged(pinned):
            isPinned = pinned
            if pinned { visibility = .expanded }
            if pinned { return [.cancelScheduledHide] }
            return scheduleHideIfEligible(autoHideEnabled: autoHideEnabled, hideDelay: hideDelay)

        case let .dockChanged(nextAnchor):
            anchor = nextAnchor
            visibility = .expanded
            return [.cancelScheduledHide]

        case .collapseToEdge:
            visibility = .autoHidden
            pointerInsideMain = false
            pointerInsideHandle = false
            interactionLocks.removeAll()
            return [.cancelScheduledHide]

        case .appActivated:
            visibility = .expanded
            pointerInsideMain = true
            pointerInsideHandle = false
            return [.cancelScheduledHide]

        case .urgentEvent:
            isUrgent = true
            return [.scheduleUrgentClear(after: max(0, urgentPeekDuration))]

        case .urgentPeekElapsed:
            isUrgent = false
            return []
        }
    }

    private func scheduleHideIfEligible(autoHideEnabled: Bool, hideDelay: TimeInterval) -> [PanelEffect] {
        isAutoHideEligible(autoHideEnabled: autoHideEnabled)
            ? [.scheduleHide(after: max(0, hideDelay))]
            : []
    }
}

public enum HandleStatus: String, Sendable, Equatable {
    case idle
    case running
    case waiting
    case failed
    case completed

    public static func resolve(
        active: [TrackedTask],
        recent: [TrackedTask],
        now: Date = Date(),
        failureWindow: TimeInterval = 300,
        completionWindow: TimeInterval = 3
    ) -> HandleStatus {
        if recent.contains(where: { $0.state == .failed && now.timeIntervalSince($0.lastStateChangedAt) <= failureWindow }) {
            return .failed
        }
        if active.contains(where: { $0.state == .waitingApproval || $0.state == .waitingInput }) {
            return .waiting
        }
        if active.contains(where: { $0.state == .running }) {
            return .running
        }
        if recent.contains(where: { $0.state == .completed && now.timeIntervalSince($0.lastStateChangedAt) <= completionWindow }) {
            return .completed
        }
        return .idle
    }
}
