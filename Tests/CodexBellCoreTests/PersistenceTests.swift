import XCTest
@testable import CodexBellCore

final class PersistenceTests: XCTestCase {
    private func task(_ index: Int, project: String = "Sample Workspace", taskName: String? = "Run Tests") -> TrackedTask {
        let start = Date(timeIntervalSince1970: Double(index))
        return TrackedTask(
            turnID: "turn-\(index)",
            projectName: project,
            taskName: taskName,
            state: .completed,
            startedAt: start,
            endedAt: start.addingTimeInterval(42),
            eventGeneration: 1
        )
    }

    func testSnapshotRetainsOnlyTwentyMostRecentTasks() throws {
        let tasks = (0..<25).map { task($0) }
        let snapshot = PersistedSnapshot.make(settings: .default, tasks: tasks)
        XCTAssertEqual(snapshot.tasks.count, 20)
        XCTAssertEqual(snapshot.tasks.first?.turnID, "turn-24")
        XCTAssertEqual(snapshot.tasks.last?.turnID, "turn-5")
    }

    func testSnapshotRoundTrips() throws {
        let evidence = IntegrationEvidence(
            hooksInstalled: true,
            lastHookEventAt: Date(timeIntervalSince1970: 90),
            hookSelfTestPassedAt: Date(timeIntervalSince1970: 80),
            codexVersion: "codex-cli test"
        )
        let snapshot = PersistedSnapshot.make(settings: .default, tasks: [task(1)], integrationEvidence: evidence, savedAt: Date(timeIntervalSince1970: 100))
        let data = try PersistenceCodec.encode(snapshot)
        let decoded = try PersistenceCodec.decode(data)
        XCTAssertEqual(decoded, snapshot)
    }

    func testOldSnapshotWithMinimumFilterKeysStillDecodesAndMigrates() throws {
        let json = #"{"version":1,"savedAt":"1970-01-01T00:01:40Z","settings":{"announcementsEnabled":true,"volume":0.7,"minimumTaskFilterEnabled":true,"minimumTaskDuration":30,"keepAwakeWhileRunning":true,"launchAtLogin":false},"tasks":[]}"#
        let decoded = try PersistenceCodec.decode(Data(json.utf8))
        XCTAssertNil(decoded.integrationEvidence)
        XCTAssertEqual(decoded.settings.dockAnchor, .right)
        XCTAssertTrue(decoded.settings.keepAwakeWhileRunning)
        let migrated = String(decoding: try PersistenceCodec.encode(decoded), as: UTF8.self)
        XCTAssertFalse(migrated.contains("minimumTaskFilterEnabled"))
        XCTAssertFalse(migrated.contains("minimumTaskDuration"))
    }

    func testInboxWriterAtomicallyCreatesFinalJSONFile() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let event = CodexEvent(kind: .stop, turnID: "turn-atomic", occurredAt: Date(timeIntervalSince1970: 100))
        let url = try EventInboxWriter.write(event, to: root)
        XCTAssertEqual(url.pathExtension, "json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        let entries = try FileManager.default.contentsOfDirectory(atPath: root.path)
        XCTAssertEqual(entries.filter { $0.hasSuffix(".tmp") }.count, 0)
        let decoded = try PersistenceCodec.decodeEvent(Data(contentsOf: url))
        XCTAssertEqual(decoded, event)
    }
}
