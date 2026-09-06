import Foundation

public struct ActiveTaskPresentation: Sendable, Equatable {
    public let totalCount: Int
    public let orderedTasks: [TrackedTask]
    public let visibleTasks: [TrackedTask]
    public let hiddenCount: Int
    public let isDisclosureNeeded: Bool

    public init(
        totalCount: Int,
        orderedTasks: [TrackedTask],
        visibleTasks: [TrackedTask],
        hiddenCount: Int,
        isDisclosureNeeded: Bool
    ) {
        self.totalCount = totalCount
        self.orderedTasks = orderedTasks
        self.visibleTasks = visibleTasks
        self.hiddenCount = hiddenCount
        self.isDisclosureNeeded = isDisclosureNeeded
    }
}

public enum TaskPresentationPolicy {
    public static let collapsedActiveLimit = 4
    public static let recentVisibleLimit = 3

    public static func active(_ tasks: [TrackedTask], expanded: Bool) -> ActiveTaskPresentation {
        let ordered = tasks
            .filter { isActive($0.state) }
            .sorted(by: activePrecedes)
        let hiddenCount = max(0, ordered.count - collapsedActiveLimit)
        let visible = expanded ? ordered : Array(ordered.prefix(collapsedActiveLimit))
        return ActiveTaskPresentation(
            totalCount: ordered.count,
            orderedTasks: ordered,
            visibleTasks: visible,
            hiddenCount: hiddenCount,
            isDisclosureNeeded: hiddenCount > 0
        )
    }

    public static func recent(_ tasks: [TrackedTask]) -> [TrackedTask] {
        Array(tasks
            .filter { isTerminal($0.state) }
            .sorted {
                if $0.lastStateChangedAt != $1.lastStateChangedAt {
                    return $0.lastStateChangedAt > $1.lastStateChangedAt
                }
                return $0.turnID < $1.turnID
            }
            .prefix(recentVisibleLimit))
    }

    private static func activePrecedes(_ lhs: TrackedTask, _ rhs: TrackedTask) -> Bool {
        let lhsRank = activeRank(lhs.state)
        let rhsRank = activeRank(rhs.state)
        if lhsRank != rhsRank { return lhsRank < rhsRank }

        if lhs.state == .running, rhs.state == .running {
            if lhs.startedAt != rhs.startedAt { return lhs.startedAt < rhs.startedAt }
        } else if lhs.lastStateChangedAt != rhs.lastStateChangedAt {
            return lhs.lastStateChangedAt > rhs.lastStateChangedAt
        }

        return lhs.turnID < rhs.turnID
    }

    private static func activeRank(_ state: TaskState) -> Int {
        switch state {
        case .waitingApproval: return 0
        case .waitingInput: return 1
        case .running: return 2
        case .completed, .failed, .interrupted, .unknownFinished: return 3
        }
    }

    private static func isActive(_ state: TaskState) -> Bool {
        state == .running || state == .waitingApproval || state == .waitingInput
    }

    private static func isTerminal(_ state: TaskState) -> Bool {
        state == .completed || state == .failed || state == .interrupted || state == .unknownFinished
    }
}
