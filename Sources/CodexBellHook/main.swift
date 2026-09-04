import Foundation
import CodexBellCore
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

private func inboxURL() -> URL {
    if let override = ProcessInfo.processInfo.environment["CODEX_BELL_INBOX"], !override.isEmpty {
        return URL(fileURLWithPath: override, isDirectory: true)
    }
    return FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library", isDirectory: true)
        .appendingPathComponent("Application Support", isDirectory: true)
        .appendingPathComponent("Codex Bell", isDirectory: true)
        .appendingPathComponent("Inbox", isDirectory: true)
}

private func decodeInvocation() throws -> CodexEvent {
    if let legacy = CommandLine.arguments.dropFirst().last(where: { $0.contains("\"agent-turn-complete\"") }) {
        return try HookPayloadDecoder.decodeLegacyNotifyArgument(legacy)
    }
    let data = FileHandle.standardInput.readDataToEndOfFile()
    return try HookPayloadDecoder.decodeHook(data)
}

do {
    let event = try decodeInvocation().redactedForInbox()
    try EventInboxWriter.write(event, to: inboxURL())
    // A valid no-op hook response. Codex keeps its normal permission/turn behavior.
    FileHandle.standardOutput.write(Data("{}\n".utf8))
} catch {
    FileHandle.standardError.write(Data("Codex Bell hook error: \(error)\n".utf8))
    exit(2)
}
