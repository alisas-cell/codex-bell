import Foundation

public actor AnnouncementQueue {
    private struct Entry: Sendable {
        var announcement: Announcement
        var sequence: UInt64
        var coalescingKey: String?
    }

    private var pending: [Entry] = []
    private var seenIDs: Set<String> = []
    private var inFlight = false
    private var sequence: UInt64 = 0

    public init() {}

    public var pendingCount: Int { pending.count }

    public func enqueue(_ announcement: Announcement, replacingPendingWithKey coalescingKey: String? = nil) {
        if let coalescingKey,
           let index = pending.firstIndex(where: { $0.coalescingKey == coalescingKey }) {
            seenIDs.remove(pending[index].announcement.id)
            guard seenIDs.insert(announcement.id).inserted else { return }
            sequence &+= 1
            pending[index] = Entry(
                announcement: announcement,
                sequence: sequence,
                coalescingKey: coalescingKey
            )
            return
        }
        guard seenIDs.insert(announcement.id).inserted else { return }
        sequence &+= 1
        pending.append(Entry(
            announcement: announcement,
            sequence: sequence,
            coalescingKey: coalescingKey
        ))
    }

    public func next() -> Announcement? {
        guard !inFlight, !pending.isEmpty else { return nil }
        let bestIndex = pending.indices.max { lhs, rhs in
            let l = pending[lhs]
            let r = pending[rhs]
            if l.announcement.kind.priority != r.announcement.kind.priority {
                return l.announcement.kind.priority < r.announcement.kind.priority
            }
            return l.sequence > r.sequence
        }!
        let item = pending.remove(at: bestIndex).announcement
        inFlight = true
        return item
    }

    public func removePending(withCoalescingKey coalescingKey: String) {
        let removedIDs = pending
            .filter { $0.coalescingKey == coalescingKey }
            .map(\.announcement.id)
        pending.removeAll { $0.coalescingKey == coalescingKey }
        seenIDs.subtract(removedIDs)
    }

    public func markFinished() {
        inFlight = false
    }

    public func resetSeen() {
        seenIDs.removeAll()
    }
}
