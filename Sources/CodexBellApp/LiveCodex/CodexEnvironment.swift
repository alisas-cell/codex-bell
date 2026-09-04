#if os(macOS)
import Foundation
import CodexBellCore

enum CodexEnvironment {
    static var homeDirectory: URL {
        if let custom = ProcessInfo.processInfo.environment["CODEX_HOME"], !custom.isEmpty {
            return URL(fileURLWithPath: custom, isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex", isDirectory: true)
    }

    static func executableURL() -> URL? {
        let environment = ProcessInfo.processInfo.environment
        var candidates: [String] = []
        if let configured = environment["CODEX_CLI_PATH"] { candidates.append(configured) }
        candidates.append("/Applications/ChatGPT.app/Contents/Resources/codex")
        candidates.append("/Applications/Codex.app/Contents/Resources/codex")
        if let path = environment["PATH"] {
            candidates.append(contentsOf: path.split(separator: ":").map { "\($0)/codex" })
        }
        return candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }).map(URL.init(fileURLWithPath:))
    }

    static func guiHostDescription() -> String? {
        let candidates = ["/Applications/ChatGPT.app", "/Applications/Codex.app"]
        guard let path = candidates.first(where: { FileManager.default.fileExists(atPath: $0) }),
              let bundle = Bundle(path: path) else { return nil }
        let name = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Codex Desktop"
        let identifier = bundle.bundleIdentifier ?? "unknown"
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
        return "\(name) · \(identifier) · \(version) (\(build))"
    }

    static func version() -> String? {
        guard let executable = executableURL() else { return nil }
        let process = Process()
        let output = Pipe()
        process.executableURL = executable
        process.arguments = ["--version"]
        process.standardOutput = output
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = output.fileHandleForReading.readDataToEndOfFile()
            let value = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            return value.isEmpty ? nil : PrivacySanitizer.sanitize(value)
        } catch {
            return nil
        }
    }
}
#endif
