import Foundation

public enum CodexConfigMergeError: Error, Equatable {
    case invalidHooksJSON
    case invalidHooksShape
}

public struct NotifyMergeResult: Sendable, Equatable {
    public var text: String
    public var didInstall: Bool

    public init(text: String, didInstall: Bool) {
        self.text = text
        self.didInstall = didInstall
    }
}

public enum CodexConfigMerge {
    public static let marker = "codex-bell-hook"
    public static let hookEvents = ["UserPromptSubmit", "PermissionRequest", "PreToolUse", "PostToolUse", "Stop", "Interrupt"]

    public static func mergeHooks(_ data: Data, command: String) throws -> Data {
        var root = try rootObject(from: data)
        var hooks = (root["hooks"] as? [String: Any]) ?? [:]

        for event in hookEvents {
            var groups = (hooks[event] as? [[String: Any]]) ?? []
            groups = groups.compactMap(removingCodexBellHandlers)
            groups.append([
                "hooks": [[
                    "type": "command",
                    "command": command,
                    "statusMessage": "Codex Bell"
                ]]
            ])
            hooks[event] = groups
        }
        root["hooks"] = hooks
        return try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
    }

    public static func removeHooks(_ data: Data) throws -> Data {
        var root = try rootObject(from: data)
        guard var hooks = root["hooks"] as? [String: Any] else { return data }
        for key in Array(hooks.keys) {
            guard let groups = hooks[key] as? [[String: Any]] else { continue }
            let cleaned = groups.compactMap(removingCodexBellHandlers)
            if cleaned.isEmpty { hooks.removeValue(forKey: key) }
            else { hooks[key] = cleaned }
        }
        root["hooks"] = hooks
        return try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
    }

    public static func codexBellHookCount(_ data: Data) throws -> Int {
        try codexBellHookCommands(data).count
    }

    public static func codexBellHookCommands(_ data: Data) throws -> [String] {
        let root = try rootObject(from: data)
        guard let hooks = root["hooks"] as? [String: Any] else { return [] }
        var commands: [String] = []
        for value in hooks.values {
            guard let groups = value as? [[String: Any]] else { continue }
            for group in groups {
                guard let handlers = group["hooks"] as? [[String: Any]] else { continue }
                commands.append(contentsOf: handlers.compactMap { handler in
                    guard isCodexBellHandler(handler) else { return nil }
                    return handler["command"] as? String
                })
            }
        }
        return commands
    }

    public static func mergeNotify(_ text: String, helperPath: String, inboxPath: String? = nil) -> NotifyMergeResult {
        let line = notifyLine(helperPath: helperPath, inboxPath: inboxPath)
        var lines = splitLinesPreservingIntent(text)
        let topRange = topLevelRange(lines)

        if let index = topRange.first(where: { isTopLevelNotifyLine(lines[$0]) }) {
            if lines[index].contains(marker) {
                lines[index] = line
                return NotifyMergeResult(text: joinLines(lines, original: text), didInstall: true)
            }
            return NotifyMergeResult(text: text, didInstall: false)
        }

        let insertion = topRange.upperBound
        lines.insert(line, at: insertion)
        return NotifyMergeResult(text: joinLines(lines, original: text), didInstall: true)
    }

    public static func removeNotify(_ text: String) -> String {
        var lines = splitLinesPreservingIntent(text)
        let topRange = topLevelRange(lines)
        if let index = topRange.first(where: { isTopLevelNotifyLine(lines[$0]) && lines[$0].contains(marker) }) {
            lines.remove(at: index)
        }
        return joinLines(lines, original: text)
    }

    private static func rootObject(from data: Data) throws -> [String: Any] {
        if data.isEmpty { return [:] }
        guard let object = try? JSONSerialization.jsonObject(with: data), let root = object as? [String: Any] else {
            throw CodexConfigMergeError.invalidHooksJSON
        }
        if let hooks = root["hooks"], !(hooks is [String: Any]) {
            throw CodexConfigMergeError.invalidHooksShape
        }
        return root
    }

    private static func removingCodexBellHandlers(_ group: [String: Any]) -> [String: Any]? {
        guard var handlers = group["hooks"] as? [[String: Any]] else { return group }
        handlers.removeAll(where: isCodexBellHandler)
        guard !handlers.isEmpty else { return nil }
        var copy = group
        copy["hooks"] = handlers
        return copy
    }

    private static func isCodexBellHandler(_ handler: [String: Any]) -> Bool {
        (handler["command"] as? String)?.contains(marker) == true
    }

    private static func tomlQuoted(_ value: String) -> String {
        "\"" + value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }

    private static func notifyLine(helperPath: String, inboxPath: String?) -> String {
        let arguments: [String]
        if let inboxPath {
            arguments = ["/usr/bin/env", "CODEX_BELL_INBOX=\(inboxPath)", helperPath, "--codex-bell-notify"]
        } else {
            arguments = [helperPath, "--codex-bell-notify"]
        }
        return "notify = [\(arguments.map(tomlQuoted).joined(separator: ", "))] # codex-bell-hook"
    }

    private static func splitLinesPreservingIntent(_ text: String) -> [String] {
        if text.isEmpty { return [] }
        var lines = text.components(separatedBy: "\n")
        if text.hasSuffix("\n"), lines.last == "" { lines.removeLast() }
        return lines
    }

    private static func joinLines(_ lines: [String], original: String) -> String {
        guard !lines.isEmpty else { return "" }
        let body = lines.joined(separator: "\n")
        return original.hasSuffix("\n") || original.isEmpty ? body + "\n" : body
    }

    private static func topLevelRange(_ lines: [String]) -> Range<Int> {
        let end = lines.firstIndex { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return trimmed.hasPrefix("[") && !trimmed.hasPrefix("[[") || trimmed.hasPrefix("[[")
        } ?? lines.count
        return 0..<end
    }

    private static func isTopLevelNotifyLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.hasPrefix("#") else { return false }
        return trimmed.range(of: #"^notify\s*="# , options: .regularExpression) != nil
    }
}
