import XCTest
@testable import CodexBellCore

final class PrivacyTests: XCTestCase {
    func testUniqueSyntheticPrivateMaterialNeverReachesPersistenceOrDiagnostics() throws {
        let secret = "TEST_SECRET_NEVER_PERSIST_7F3A91"
        let privateURL = "https://confidential.example.invalid/account?token=7F3A91"
        let absolutePath = "/Volumes/Demo/Confidential/secret-source.swift"
        let promptPhrase = "SYNTHETIC PRIVATE PROMPT PHRASE 7F3A91"
        let raw = CodexEvent(
            kind: .stop,
            turnID: "privacy-regression",
            cwd: absolutePath,
            prompt: "\(promptPhrase) \(privateURL) \(secret)",
            lastAssistantMessage: "Finished without retaining \(secret)."
        )
        let redacted = raw.redactedForInbox()
        var store = TaskStore()
        _ = store.apply(event: redacted)
        let persisted = String(decoding: try PersistenceCodec.encode(.make(settings: .default, tasks: store.allTasks)), as: UTF8.self)
        let diagnostics = PrivacySanitizer.sanitize(
            "turn=\(redacted.turnID) project=\(redacted.identity?.projectName ?? "Codex Task")"
        )

        for forbidden in [secret, privateURL, absolutePath, promptPhrase] {
            XCTAssertFalse(persisted.contains(forbidden))
            XCTAssertFalse(diagnostics.contains(forbidden))
        }
    }

    func testPersistedJSONExcludesSensitiveSourceMaterial() throws {
        let task = TrackedTask(
            turnID: "turn-safe",
            sessionID: "session-private",
            projectName: "/Volumes/Demo/confidential-project",
            taskName: "deploy https://confidential.example.invalid token TEST_SECRET branch codex/private 0123456789abcdef0123456789abcdef",
            state: .completed,
            startedAt: Date(timeIntervalSince1970: 10),
            endedAt: Date(timeIntervalSince1970: 80),
            eventGeneration: 3
        )
        let snapshot = PersistedSnapshot.make(settings: .default, tasks: [task])
        let data = try PersistenceCodec.encode(snapshot)
        let json = String(decoding: data, as: UTF8.self)

        XCTAssertFalse(json.contains("session-private"))
        XCTAssertFalse(json.contains("/Volumes/Demo"))
        XCTAssertFalse(json.contains("confidential.example.invalid"))
        XCTAssertFalse(json.contains("TEST_SECRET"))
        XCTAssertFalse(json.contains("codex/private"))
        XCTAssertFalse(json.contains("0123456789abcdef0123456789abcdef"))
        XCTAssertFalse(json.contains("prompt"))
        XCTAssertFalse(json.contains("assistant"))
    }

    func testFakeSecretAcceptanceMarkersAreRemovedBeforePersistence() throws {
        let task = TrackedTask(
            turnID: "turn-privacy",
            projectName: "CODEX_BELL_SECRET_9F4A2",
            taskName: "https://confidential.example.invalid/secret-path /Volumes/Demo/PrivateProject",
            state: .failed,
            startedAt: Date(timeIntervalSince1970: 1),
            endedAt: Date(timeIntervalSince1970: 2)
        )
        let json = String(decoding: try PersistenceCodec.encode(.make(settings: .default, tasks: [task])), as: UTF8.self)
        XCTAssertFalse(json.contains("CODEX_BELL_SECRET_9F4A2"))
        XCTAssertFalse(json.contains("confidential.example.invalid"))
        XCTAssertFalse(json.contains("/Volumes/Demo/PrivateProject"))
    }

    func testDiagnosticSanitizerRemovesPathsURLsAndSecrets() {
        let raw = "Failed at /Volumes/Demo/PrivateProject: https://confidential.example.invalid/secret-path token=abc CODEX_BELL_SECRET_9F4A2"
        let sanitized = PrivacySanitizer.sanitize(raw)
        XCTAssertFalse(sanitized.contains("/Volumes/Demo"))
        XCTAssertFalse(sanitized.contains("confidential.example.invalid"))
        XCTAssertFalse(sanitized.contains("abc"))
        XCTAssertFalse(sanitized.contains("CODEX_BELL_SECRET"))
        XCTAssertFalse(sanitized.isEmpty)
    }
    func testInboxEventRedactionKeepsOnlyDerivedIdentity() throws {
        let event = CodexEvent(
            kind: .userPromptSubmit,
            turnID: "turn-redact",
            sessionID: "session-ok",
            cwd: "/Volumes/Demo/sample-workspace",
            prompt: "Run release tests at https://confidential.example.invalid token TEST_SECRET",
            lastAssistantMessage: "secret output",
            occurredAt: Date(timeIntervalSince1970: 100)
        )
        let redacted = event.redactedForInbox()
        XCTAssertEqual(redacted.identity, TaskIdentity(projectName: "Sample Workspace", taskName: "测试"))
        XCTAssertNil(redacted.cwd)
        XCTAssertNil(redacted.prompt)
        XCTAssertNil(redacted.lastAssistantMessage)

        let json = String(decoding: try PersistenceCodec.encodeEvent(redacted), as: UTF8.self)
        XCTAssertFalse(json.contains("/Volumes/Demo"))
        XCTAssertFalse(json.contains("confidential.example.invalid"))
        XCTAssertFalse(json.contains("TEST_SECRET"))
        XCTAssertFalse(json.contains("secret output"))
        XCTAssertTrue(json.contains("Sample Workspace"))
    }

}
