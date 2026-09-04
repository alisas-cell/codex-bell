import XCTest
@testable import CodexBellCore

final class CodexConfigMergeTests: XCTestCase {
    let command = "\"/Applications/Codex Bell.app/Contents/MacOS/codex-bell-hook\" --codex-bell-hook"

    func testHooksMergePreservesUnrelatedEntriesAndAddsRequiredEvents() throws {
        let original = #"{"hooks":{"PreToolUse":[{"matcher":"^Bash$","hooks":[{"type":"command","command":"echo existing"}]}],"PostToolUse":[{"hooks":[{"type":"command","command":"echo post"}]}]}}"#.data(using: .utf8)!
        let merged = try CodexConfigMerge.mergeHooks(original, command: command)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: merged) as? [String: Any])
        let hooks = try XCTUnwrap(object["hooks"] as? [String: Any])
        XCTAssertNotNil(hooks["PostToolUse"])
        for name in ["UserPromptSubmit", "PermissionRequest", "PreToolUse", "PostToolUse", "Stop", "Interrupt"] {
            let groups = try XCTUnwrap(hooks[name] as? [[String: Any]])
            XCTAssertTrue(groups.contains { group in
                (group["hooks"] as? [[String: Any]])?.contains { ($0["command"] as? String)?.contains("--codex-bell-hook") == true } == true
            }, "missing Codex Bell hook for \(name)")
        }
        let pre = try XCTUnwrap(hooks["PreToolUse"] as? [[String: Any]])
        XCTAssertTrue(pre.contains { ($0["matcher"] as? String) == "^Bash$" })
    }

    func testHooksMergeIsIdempotentAndUninstallRemovesOnlyCodexBell() throws {
        let original = #"{"hooks":{"Stop":[{"hooks":[{"type":"command","command":"echo existing"}]}]}}"#.data(using: .utf8)!
        let once = try CodexConfigMerge.mergeHooks(original, command: command)
        let twice = try CodexConfigMerge.mergeHooks(once, command: command)
        let count = try CodexConfigMerge.codexBellHookCount(twice)
        XCTAssertEqual(count, 6)
        let uninstalled = try CodexConfigMerge.removeHooks(twice)
        XCTAssertEqual(try CodexConfigMerge.codexBellHookCount(uninstalled), 0)
        XCTAssertTrue(String(decoding: uninstalled, as: UTF8.self).contains("echo existing"))
    }

    func testHookCommandsAreReadFromParsedJSONRatherThanEscapedSourceText() throws {
        let helper = "/Volumes/Demo/Codex Bell Test.app/Contents/MacOS/codex-bell-hook"
        let inbox = "/Volumes/Demo/Codex Bell Test Data/Inbox"
        let installed = try CodexConfigMerge.mergeHooks(
            Data("{}".utf8),
            command: "/usr/bin/env CODEX_BELL_INBOX='\(inbox)' '\(helper)' --codex-bell-hook"
        )
        XCTAssertTrue(String(decoding: installed, as: UTF8.self).contains(#"\/Volumes\/Demo"#))
        let commands = try CodexConfigMerge.codexBellHookCommands(installed)
        XCTAssertEqual(commands.count, CodexConfigMerge.hookEvents.count)
        XCTAssertTrue(commands.allSatisfy { $0.contains(helper) && $0.contains(inbox) })
    }

    func testNotifyMergePreservesUnrelatedConfigAndDoesNotOverwriteForeignNotify() {
        let existing = "model = \"gpt-5\"\nnotify = [\"python3\", \"/opt/example/other.py\"]\napproval_policy = \"on-request\"\n"
        let result = CodexConfigMerge.mergeNotify(existing, helperPath: "/Applications/Codex Bell.app/Contents/MacOS/codex-bell-hook")
        XCTAssertFalse(result.didInstall)
        XCTAssertEqual(result.text, existing)
    }

    func testNotifyInstallIsIdempotentAndUninstallKeepsOtherLines() {
        let existing = "model = \"gpt-5\"\napproval_policy = \"on-request\"\n"
        let once = CodexConfigMerge.mergeNotify(existing, helperPath: "/Applications/Codex Bell.app/Contents/MacOS/codex-bell-hook")
        XCTAssertTrue(once.didInstall)
        let twice = CodexConfigMerge.mergeNotify(once.text, helperPath: "/Applications/Codex Bell.app/Contents/MacOS/codex-bell-hook")
        XCTAssertTrue(twice.didInstall)
        XCTAssertEqual(twice.text.components(separatedBy: "notify =").count - 1, 1)
        let removed = CodexConfigMerge.removeNotify(twice.text)
        XCTAssertTrue(removed.contains("model = \"gpt-5\""))
        XCTAssertTrue(removed.contains("approval_policy = \"on-request\""))
        XCTAssertFalse(removed.contains("codex-bell-hook"))
    }

    func testNotifyCanRouteToAnIndependentInbox() {
        let result = CodexConfigMerge.mergeNotify(
            "",
            helperPath: "/Volumes/Demo/Codex Bell Test.app/Contents/MacOS/codex-bell-hook",
            inboxPath: "/Volumes/Demo/Codex Bell Test Data/Inbox"
        )
        XCTAssertTrue(result.didInstall)
        XCTAssertTrue(result.text.contains(#""/usr/bin/env""#))
        XCTAssertTrue(result.text.contains("CODEX_BELL_INBOX="))
        XCTAssertTrue(result.text.contains("Codex Bell Test"))
        XCTAssertEqual(result.text.components(separatedBy: "notify =").count - 1, 1)
    }
}
