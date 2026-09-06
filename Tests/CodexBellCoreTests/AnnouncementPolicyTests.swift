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

    func testCorrectedOrResumedTaskCannotPlayItsQueuedOldCompletion() {
        let announcement = Announcement(turnID: "t", kind: .completed, identity: TaskIdentity(projectName: "P"), generation: 2)
        var latest = task(state: .completed, duration: 1)
        latest.eventGeneration = 2
        XCTAssertFalse(AnnouncementPolicy.isSuperseded(announcement, by: latest))
        for state: TaskState in [.failed, .running, .unknownFinished] {
            latest.state = state
            latest.eventGeneration = 3
            XCTAssertTrue(AnnouncementPolicy.isSuperseded(announcement, by: latest))
        }
        // Pruning older history must not drop unrelated queued real alerts.
        XCTAssertFalse(AnnouncementPolicy.isSuperseded(announcement, by: nil))
    }
}
