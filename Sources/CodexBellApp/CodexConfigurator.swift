#if os(macOS)
import Foundation
import CodexBellCore

struct CodexIntegrationInstallationStatus: Equatable {
    var hooksInstalledForCurrentApp: Bool
    var legacyNotifyInstalledForCurrentApp: Bool
    var controlSocketDetected: Bool
    var targetAudit: IntegrationTargetAudit
}

struct CodexConfigurator {
    let appSupportDirectory: URL

    private var codexHome: URL {
        if let custom = ProcessInfo.processInfo.environment["CODEX_HOME"], !custom.isEmpty {
            return URL(fileURLWithPath: custom, isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex", isDirectory: true)
    }

    private var hooksURL: URL { codexHome.appendingPathComponent("hooks.json") }
    private var configURL: URL { codexHome.appendingPathComponent("config.toml") }
    private var inboxDirectory: URL { appSupportDirectory.appendingPathComponent("Inbox", isDirectory: true) }

    var helperExecutableURL: URL {
        let bundled = Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/codex-bell-hook")
        if FileManager.default.isExecutableFile(atPath: bundled.path) { return bundled }
        if let executable = Bundle.main.executableURL {
            return executable.deletingLastPathComponent().appendingPathComponent("codex-bell-hook")
        }
        return bundled
    }

    func install() throws {
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        guard FileManager.default.isExecutableFile(atPath: helperExecutableURL.path) else {
            throw NSError(domain: "CodexBell", code: 1, userInfo: [NSLocalizedDescriptionKey: "The Codex Bell hook helper is missing from this app bundle."])
        }

        let existingHooks = (try? Data(contentsOf: hooksURL)) ?? Data("{}".utf8)
        let command = "/usr/bin/env CODEX_BELL_INBOX=\(shellQuote(inboxDirectory.path)) \(shellQuote(helperExecutableURL.path)) --codex-bell-hook"
        let mergedHooks = try CodexConfigMerge.mergeHooks(existingHooks, command: command)
        if mergedHooks != existingHooks {
            try backupIfExists(hooksURL)
            try mergedHooks.write(to: hooksURL, options: .atomic)
        }

        let existingConfig = (try? String(contentsOf: configURL, encoding: .utf8)) ?? ""
        let notify = CodexConfigMerge.mergeNotify(
            existingConfig,
            helperPath: helperExecutableURL.path,
            inboxPath: inboxDirectory.path
        )
        if notify.didInstall && notify.text != existingConfig {
            try backupIfExists(configURL)
            try notify.text.write(to: configURL, atomically: true, encoding: .utf8)
        }
    }

    func uninstall() throws {
        if let hooksData = try? Data(contentsOf: hooksURL) {
            let cleaned = try CodexConfigMerge.removeHooks(hooksData)
            if cleaned != hooksData {
                try backupIfExists(hooksURL)
                try cleaned.write(to: hooksURL, options: .atomic)
            }
        }
        if let config = try? String(contentsOf: configURL, encoding: .utf8) {
            let cleaned = CodexConfigMerge.removeNotify(config)
            if cleaned != config {
                try backupIfExists(configURL)
                try cleaned.write(to: configURL, atomically: true, encoding: .utf8)
            }
        }
    }

    func installationStatus() -> CodexIntegrationInstallationStatus {
        let hooksData = try? Data(contentsOf: hooksURL)
        let commands = hooksData.flatMap { try? CodexConfigMerge.codexBellHookCommands($0) } ?? []
        let targetAudit = IntegrationTargetAuditor.audit(
            commands: commands,
            expectedHelperPath: helperExecutableURL.path,
            expectedInboxPath: inboxDirectory.path,
            helperExecutableExists: FileManager.default.isExecutableFile(atPath: helperExecutableURL.path)
        )
        let hooksInstalled = targetAudit.status == .current

        let config = (try? String(contentsOf: configURL, encoding: .utf8)) ?? ""
        let notifyInstalled = config
            .split(separator: "\n", omittingEmptySubsequences: false)
            .contains { line in
                let value = String(line)
                return value.range(of: #"^\s*notify\s*="# , options: .regularExpression) != nil
                    && value.contains(CodexConfigMerge.marker)
                    && value.contains(helperExecutableURL.path)
                    && value.contains(inboxDirectory.path)
            }

        let socket = codexHome.appendingPathComponent("app-server-control/app-server-control.sock")
        return CodexIntegrationInstallationStatus(
            hooksInstalledForCurrentApp: hooksInstalled,
            legacyNotifyInstalledForCurrentApp: notifyInstalled,
            controlSocketDetected: FileManager.default.fileExists(atPath: socket.path),
            targetAudit: targetAudit
        )
    }

    func isInstalled() -> Bool {
        installationStatus().hooksInstalledForCurrentApp
    }

    private func backupIfExists(_ url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let stamp = formatter.string(from: Date())
        let backup = url.deletingLastPathComponent().appendingPathComponent("\(url.lastPathComponent).codex-bell-backup-\(stamp)")
        if !FileManager.default.fileExists(atPath: backup.path) {
            try FileManager.default.copyItem(at: url, to: backup)
        }
    }

    private func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
#endif
