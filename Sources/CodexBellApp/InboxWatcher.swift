#if os(macOS)
import Foundation
import CodexBellCore

@MainActor
final class InboxWatcher {
    private let directory: URL
    private var timer: Timer?
    private var handler: ((CodexEvent, Bool) -> Void)?

    init(directory: URL) {
        self.directory = directory
    }

    func start(handler: @escaping (CodexEvent, Bool) -> Void) {
        self.handler = handler
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        drain(isBackfill: true)
        timer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.drain(isBackfill: false) }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func drain(isBackfill: Bool) {
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        let files = urls.filter { $0.pathExtension == "json" }.sorted { lhs, rhs in
            let l = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let r = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return l < r
        }
        for url in files {
            defer { try? FileManager.default.removeItem(at: url) }
            guard let data = try? Data(contentsOf: url), let event = try? PersistenceCodec.decodeEvent(data) else { continue }
            handler?(event, isBackfill)
        }
    }
}
#endif
