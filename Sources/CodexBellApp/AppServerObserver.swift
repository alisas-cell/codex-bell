#if os(macOS)
import Foundation
import CodexBellCore

/// Capability boundary for Codex app-server terminal notifications.
///
/// V1's reliable transport is the Codex hook bridge. This object probes the
/// standard local app-server control socket and provides a parser entry point
/// for authoritative `turn/completed` notifications when a future/stable
/// companion subscription transport is available. It deliberately does not
/// spawn or take ownership of a second app-server, which could observe a
/// different process-local turn set.
@MainActor
final class AppServerObserver {
    enum Status: Equatable {
        case unavailable
        case socketAvailable(URL)
        case stopped
    }

    private(set) var status: Status = .unavailable
    var onTerminalEvent: ((CodexEvent) -> Void)?

    private var socketCandidates: [URL] {
        var values: [URL] = []
        if let explicit = ProcessInfo.processInfo.environment["CODEX_APP_SERVER_SOCKET"], !explicit.isEmpty {
            values.append(URL(fileURLWithPath: explicit))
        }
        let codexHome: URL
        if let custom = ProcessInfo.processInfo.environment["CODEX_HOME"], !custom.isEmpty {
            codexHome = URL(fileURLWithPath: custom, isDirectory: true)
        } else {
            codexHome = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex", isDirectory: true)
        }
        values.append(codexHome.appendingPathComponent("app-server-control/app-server-control.sock"))
        return values
    }

    func start() {
        if let socket = socketCandidates.first(where: { FileManager.default.fileExists(atPath: $0.path) }) {
            status = .socketAvailable(socket)
        } else {
            status = .unavailable
        }
    }

    func stop() {
        status = .stopped
    }

    /// Accepts an already-received app-server JSON notification. This keeps the
    /// authoritative status adapter tested and isolated from transport details.
    func ingest(_ data: Data) {
        guard let event = try? AppServerNotificationDecoder.decode(data) else { return }
        onTerminalEvent?(event)
    }
}
#endif
