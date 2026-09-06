#if os(macOS)
import Foundation
import CodexBellCore

/// Tails the lifecycle-only records emitted by the Codex Desktop host.
/// Raw session lines are decoded in memory and never copied to Bell persistence.
@MainActor
final class SessionLogEventSource {
    private struct FileState {
        var offset: UInt64 = 0
        var partialLine = Data()
        var context = CodexSessionContext(
            sessionID: nil,
            identity: TaskIdentity(projectName: "Codex Task")
        )
    }

    private let sessionsDirectory: URL
    private let sourceStartedAt = Date()
    private var states: [URL: FileState] = [:]
    private var timer: Timer?
    private var handler: ((CodexEvent, Bool) -> Void)?
    private var excludedTurnHandler: ((String) -> Void)?
    private var availabilityHandler: ((Bool) -> Void)?

    init(codexHome: URL) {
        sessionsDirectory = codexHome.appendingPathComponent("sessions", isDirectory: true)
    }

    func start(
        handler: @escaping (CodexEvent, Bool) -> Void,
        excludedTurn: @escaping (String) -> Void,
        availabilityChanged: @escaping (Bool) -> Void
    ) {
        self.handler = handler
        excludedTurnHandler = excludedTurn
        availabilityHandler = availabilityChanged
        let initialFiles = recentSessionFiles()
        availabilityChanged(!initialFiles.isEmpty)
        for url in initialFiles { consume(url, isBackfill: true) }
        timer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.poll() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func poll() {
        let files = recentSessionFiles()
        availabilityHandler?(!files.isEmpty)
        for url in files {
            consume(url, isBackfill: states[url] == nil)
        }
    }

    private func recentSessionFiles() -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: sessionsDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }

        var values: [(URL, Date)] = []
        while let url = enumerator.nextObject() as? URL {
            guard url.pathExtension == "jsonl",
                  let resources = try? url.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey]),
                  resources.isRegularFile == true else { continue }
            values.append((url, resources.contentModificationDate ?? .distantPast))
        }
        let newest = values
            .sorted { $0.1 > $1.1 }
            .prefix(16)
        return newest.sorted { $0.1 < $1.1 }.map(\.0)
    }

    private func consume(_ url: URL, isBackfill: Bool) {
        var state = states[url] ?? FileState()
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let fileSize = attributes[.size] as? NSNumber else { return }
        if fileSize.uint64Value < state.offset { state = FileState() }
        guard fileSize.uint64Value > state.offset,
              let handle = try? FileHandle(forReadingFrom: url) else {
            states[url] = state
            return
        }
        defer { try? handle.close() }

        do {
            try handle.seek(toOffset: state.offset)
            while let chunk = try handle.read(upToCount: 64 * 1024), !chunk.isEmpty {
                state.offset += UInt64(chunk.count)
                state.partialLine.append(chunk)
                drainLines(from: &state, isBackfill: isBackfill)
            }
        } catch {
            states[url] = state
            return
        }
        states[url] = state
    }

    private func drainLines(from state: inout FileState, isBackfill: Bool) {
        while let newline = state.partialLine.firstIndex(of: 0x0A) {
            let data = Data(state.partialLine[..<newline])
            state.partialLine.removeSubrange(...newline)
            guard !data.isEmpty else { continue }
            guard mightContainSupportedRecord(data) else { continue }
            if let context = try? CodexSessionEventDecoder.decodeContext(data) {
                state.context = context
                continue
            }
            guard let event = try? CodexSessionEventDecoder.decode(
                data,
                context: state.context,
                excludedTurn: excludedTurnHandler
            ) else { continue }
            let historical = isBackfill && event.occurredAt < sourceStartedAt.addingTimeInterval(-1)
            handler?(event, historical)
        }

        // A malformed/unbounded record must not retain a transcript-sized buffer forever.
        if state.partialLine.count > 8 * 1024 * 1024 {
            state.partialLine.removeAll(keepingCapacity: false)
        }
    }

    private func mightContainSupportedRecord(_ data: Data) -> Bool {
        let needles = ["session_meta", "task_started", "task_complete", "turn_aborted",
                       "stream_error", "\"type\":\"error\"", "\"type\": \"error\""]
        return needles.contains { data.range(of: Data($0.utf8)) != nil }
    }
}
#endif
