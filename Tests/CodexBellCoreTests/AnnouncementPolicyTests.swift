import XCTest
@testable import CodexBellCore

final class AnnouncementPolicyTests: XCTestCase {
    private func task(state: TaskState, duration: TimeInterval) -> TrackedTask {
        TrackedTask(turnID: "t", projectName: "P", taskName: "Task", state: state, startedAt: Date(timeIntervalSince1970: 0), endedAt: Date(timeIntervalSince1970: duration))
    }

    func testEveryCompletionIsEligibleRegardlessOfDuration() {
        XCTAssertTrue(AnnouncementPolicy.shouldAnnounce(task: task(state: .completed, duration: 0.1), kind: .completed, settings: .default))
        XCTAssertTrue(AnnouncementPolicy.shouldAnnounce(task: task(state: .completed, duration: 31), kind: .completed, settings: .default))
    }

    func testUrgentStatesRemainEligible() {
        let settings = BellSettings.default
        XCTAssertTrue(AnnouncementPolicy.shouldAnnounce(task: task(state: .waitingApproval, duration: 1), kind: .waitingApproval, settings: settings))
        XCTAssertTrue(AnnouncementPolicy.shouldAnnounce(task: task(state: .waitingInput, duration: 1), kind: .waitingInput, settings: settings))
        XCTAssertTrue(AnnouncementPolicy.shouldAnnounce(task: task(state: .failed, duration: 1), kind: .failed, settings: settings))
        XCTAssertTrue(AnnouncementPolicy.shouldAnnounce(task: task(state: .interrupted, duration: 1), kind: .interrupted, settings: settings))
    }

    func testGlobalAnnouncementToggleWins() {
        let settings = BellSettings(announcementsEnabled: false)
        XCTAssertFalse(AnnouncementPolicy.shouldAnnounce(task: task(state: .failed, duration: 1), kind: .failed, settings: settings))
    }
}
