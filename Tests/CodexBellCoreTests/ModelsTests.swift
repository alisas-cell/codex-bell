import XCTest
@testable import CodexBellCore

final class ModelsTests: XCTestCase {
    func testSettingsDefaults() {
        let settings = BellSettings.default
        XCTAssertTrue(settings.announcementsEnabled)
        XCTAssertEqual(settings.volume, 0.7, accuracy: 0.0001)
        XCTAssertTrue(settings.keepAwakeWhileRunning)
        XCTAssertFalse(settings.showInDock)
        XCTAssertEqual(settings.dockAnchor, .right)
        XCTAssertTrue(settings.autoHideEnabled)
        XCTAssertTrue(settings.urgentPeekEnabled)
        XCTAssertFalse(settings.panelPinned)
        XCTAssertEqual(settings.dockVerticalFraction, 0.5, accuracy: 0.0001)
        XCTAssertEqual(settings.autoHideDelay, 0.9, accuracy: 0.0001)
        XCTAssertNil(settings.selectedDisplayID)
        XCTAssertNil(settings.languageOverride)
    }

    func testLegacySettingsDecodeIgnoresObsoleteMinimumFilterKeysAndPreservesKeepAwake() throws {
        let json = #"{"announcementsEnabled":true,"volume":0.4,"minimumTaskFilterEnabled":true,"minimumTaskDuration":45,"keepAwakeWhileRunning":false,"launchAtLogin":true}"#
        let settings = try JSONDecoder().decode(BellSettings.self, from: Data(json.utf8))
        XCTAssertEqual(settings.volume, 0.4, accuracy: 0.0001)
        XCTAssertFalse(settings.keepAwakeWhileRunning)
        XCTAssertTrue(settings.launchAtLogin)
        XCTAssertFalse(settings.showInDock)
        XCTAssertEqual(settings.dockAnchor, .right)
        XCTAssertTrue(settings.autoHideEnabled)
        XCTAssertTrue(settings.urgentPeekEnabled)
        XCTAssertFalse(settings.panelPinned)
        XCTAssertNil(settings.languageOverride)
        let migrated = String(decoding: try JSONEncoder().encode(settings), as: UTF8.self)
        XCTAssertFalse(migrated.contains("minimumTaskFilterEnabled"))
        XCTAssertFalse(migrated.contains("minimumTaskDuration"))
    }

    func testSettingsRoundTripAndClamp() throws {
        let original = BellSettings(
            volume: 4,
            showInDock: true,
            dockAnchor: .left,
            autoHideEnabled: false,
            urgentPeekEnabled: false,
            panelPinned: true,
            dockVerticalFraction: 2,
            autoHideDelay: 12,
            selectedDisplayID: "display-2",
            languageOverride: .zhHans
        )
        XCTAssertEqual(original.volume, 1)
        XCTAssertEqual(original.dockVerticalFraction, 1)
        XCTAssertEqual(original.autoHideDelay, 3)

        let decoded = try JSONDecoder().decode(BellSettings.self, from: JSONEncoder().encode(original))
        XCTAssertEqual(decoded, original)
        XCTAssertEqual(decoded.languageOverride, .zhHans)
        XCTAssertTrue(decoded.showInDock)
        XCTAssertEqual(decoded.dockAnchor, .left)
    }

    func testMigratesLegacyAndUnknownDockValuesToRight() throws {
        for raw in ["topRight", "floating", "future-placement", ""] {
            let json = "{\"dockAnchor\":\"\(raw)\",\"lastDockedPlacement\":\"topRight\",\"floatingPanelFrame\":{}}"
            let settings = try JSONDecoder().decode(BellSettings.self, from: Data(json.utf8))
            XCTAssertEqual(settings.dockAnchor, .right, "Expected migration for \(raw)")
            let migrated = String(decoding: try JSONEncoder().encode(settings), as: UTF8.self)
            XCTAssertFalse(migrated.contains("topRight"))
            XCTAssertFalse(migrated.contains("floating"))
            XCTAssertFalse(migrated.contains("lastDockedPlacement"))
            XCTAssertFalse(migrated.contains("floatingPanelFrame"))
        }
    }

    func testPreservesLeftRightAndDefaultsMissingToRight() throws {
        XCTAssertEqual(try decodeDock(#"{"dockAnchor":"left"}"#), .left)
        XCTAssertEqual(try decodeDock(#"{"dockAnchor":"right"}"#), .right)
        XCTAssertEqual(try decodeDock("{}"), .right)
    }

    func testTaskDurationAndActiveClassification() {
        let start = Date(timeIntervalSince1970: 100)
        let end = Date(timeIntervalSince1970: 145)
        let task = TrackedTask(
            turnID: "turn-1",
            sessionID: "session-1",
            projectName: "Sample Workspace",
            taskName: "Run Tests",
            state: .completed,
            startedAt: start,
            endedAt: end
        )
        XCTAssertEqual(task.duration, 45)
        XCTAssertFalse(task.isActivelyRunning)

        var running = task
        running.state = .running
        running.endedAt = nil
        XCTAssertTrue(running.isActivelyRunning)
    }

    func testAnnouncementPriority() {
        XCTAssertGreaterThan(AnnouncementKind.waitingApproval.priority, AnnouncementKind.failed.priority)
        XCTAssertGreaterThan(AnnouncementKind.failed.priority, AnnouncementKind.interrupted.priority)
        XCTAssertGreaterThan(AnnouncementKind.interrupted.priority, AnnouncementKind.completed.priority)
    }

    private func decodeDock(_ json: String) throws -> DockAnchor {
        try JSONDecoder().decode(BellSettings.self, from: Data(json.utf8)).dockAnchor
    }
}
