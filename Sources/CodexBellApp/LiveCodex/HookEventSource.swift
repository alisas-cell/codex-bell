#if os(macOS)
import Foundation
import CodexBellCore

@MainActor
final class HookEventSource {
    enum SelfTestError: LocalizedError {
        case helperMissing
        case helperFailed
        case eventMissing
        case eventInvalid

        var errorDescription: String? {
            switch self {
            case .helperMissing: return "The bundled hook helper is unavailable. Rebuild or reinstall Codex Bell."
            case .helperFailed: return "The hook helper self-test failed. Install or repair the integration and try again."
            case .eventMissing: return "The hook helper did not create a test event. Install or repair the integration and try again."
            case .eventInvalid: return "The hook helper created an invalid test event. Rebuild Codex Bell and try again."
            }
        }
    }

    private let appSupportDirectory: URL
    private let inbox: InboxWatcher
    private let helperURL: URL

    init(appSupportDirectory: URL, inboxDirectory: URL, helperURL: URL) {
        self.appSupportDirectory = appSupportDirectory
        inbox = InboxWatcher(directory: inboxDirectory)
        self.helperURL = helperURL
    }

    func start(handler: @escaping (CodexEvent, Bool) -> Void) {
        inbox.start(handler: handler)
    }

    func stop() {
        inbox.stop()
    }

    func runSelfTest() throws -> Date {
        guard FileManager.default.isExecutableFile(atPath: helperURL.path) else {
            throw SelfTestError.helperMissing
        }

        let turnID = "codex-bell-self-test-\(UUID().uuidString.lowercased())"
        let directory = appSupportDirectory
            .appendingPathComponent("SelfTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString.lowercased(), isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let payload: [String: Any] = [
            "hook_event_name": "UserPromptSubmit",
            "turn_id": turnID,
            "session_id": "codex-bell-self-test"
        ]
        let process = Process()
        let input = Pipe()
        process.executableURL = helperURL
        process.arguments = ["--codex-bell-hook"]
        process.standardInput = input
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        var environment = ProcessInfo.processInfo.environment
        environment["CODEX_BELL_INBOX"] = directory.path
        process.environment = environment

        try process.run()
        try input.fileHandleForWriting.write(contentsOf: JSONSerialization.data(withJSONObject: payload))
        try input.fileHandleForWriting.close()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw SelfTestError.helperFailed }

        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
        guard let eventURL = files.first else { throw SelfTestError.eventMissing }
        let data = try Data(contentsOf: eventURL)
        guard let event = try? PersistenceCodec.decodeEvent(data),
              event.turnID == turnID,
              event.prompt == nil,
              event.cwd == nil,
              event.lastAssistantMessage == nil else {
            throw SelfTestError.eventInvalid
        }
        return Date()
    }
}
#endif
