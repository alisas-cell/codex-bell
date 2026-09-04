import XCTest
@testable import CodexBellCore

final class TaskStoreTests: XCTestCase {
    func testNewestTerminalSurvivesOutOfOrderHistoricalBackfill() {
        let base = Date(timeIntervalSince1970: 10_000)
        let current = TrackedTask(
            turnID: "current",
            projectName: "Current",
            state: .running,
            startedAt: base
        )
        var store = TaskStore(restoring: [current], recentLimit: 3)

        for offset in [300, 200, 100, 50] {
            let old = CodexEvent(
                kind: .stop,
                turnID: "old-\(offset)",
                identity: TaskIdentity(projectName: "Old"),
                occurredAt: base.addingTimeInterval(-TimeInterval(offset))
            )
            _ = store.apply(event: old)
        }

        _ = store.apply(event: CodexEvent(kind: .stop, turnID: "current", occurredAt: base.addingTimeInterval(30)))
        XCTAssertEqual(store.task(turnID: "current")?.state, .completed)
        XCTAssertTrue(store.recentTasks.contains { $0.turnID == "current" })
        XCTAssertEqual(store.recentTasks.count, 3)
    }

    func testLifecycleStartWaitingResumeComplete() throws {
        var store = TaskStore()
        let start = Date(timeIntervalSince1970: 100)
        let created = store.apply(event: CodexEvent(kind: .userPromptSubmit, turnID: "t1", sessionID: "s1", cwd: "/tmp/sample-workspace", prompt: "Run tests", occurredAt: start), at: start)
        XCTAssertEqual(created?.task.state, .running)
        XCTAssertEqual(created?.task.projectName, "Sample Workspace")

        let wait = Date(timeIntervalSince1970: 110)
        let waiting = store.apply(event: CodexEvent(kind: .permissionRequest, turnID: "t1", sessionID: "s1", cwd: "/tmp/sample-workspace", occurredAt: wait), at: wait)
        XCTAssertEqual(waiting?.task.state, .waitingApproval)
        XCTAssertEqual(waiting?.announcementKind, .waitingApproval)

        let resume = Date(timeIntervalSince1970: 120)
        XCTAssertEqual(store.apply(event: CodexEvent(kind: .preToolUse, turnID: "t1", occurredAt: resume), at: resume)?.task.state, .running)

        let end = Date(timeIntervalSince1970: 160)
        let done = store.apply(event: CodexEvent(kind: .stop, turnID: "t1", occurredAt: end), at: end)
        XCTAssertEqual(done?.task.state, .completed)
        XCTAssertEqual(done?.task.duration, 60)
        XCTAssertEqual(done?.announcementKind, .completed)
    }

    func testInterruptAndFailureAreTerminal() {
        var store = TaskStore()
        let start = Date(timeIntervalSince1970: 1)
        _ = store.apply(event: CodexEvent(kind: .userPromptSubmit, turnID: "i", cwd: "/tmp/a", prompt: "task", occurredAt: start), at: start)
        let interrupt = store.apply(event: CodexEvent(kind: .interrupt, turnID: "i", occurredAt: Date(timeIntervalSince1970: 5)), at: Date(timeIntervalSince1970: 5))
        XCTAssertEqual(interrupt?.task.state, .interrupted)
        XCTAssertEqual(interrupt?.announcementKind, .interrupted)

        _ = store.apply(event: CodexEvent(kind: .userPromptSubmit, turnID: "f", cwd: "/tmp/b", prompt: "task", occurredAt: start), at: start)
        let failed = store.apply(event: CodexEvent(kind: .turnFailed, turnID: "f", occurredAt: Date(timeIntervalSince1970: 8)), at: Date(timeIntervalSince1970: 8))
        XCTAssertEqual(failed?.task.state, .failed)
        XCTAssertEqual(failed?.announcementKind, .failed)
    }

    func testDuplicateCompletionIsIgnored() {
        var store = TaskStore()
        let start = Date(timeIntervalSince1970: 10)
        _ = store.apply(event: CodexEvent(kind: .userPromptSubmit, turnID: "t", cwd: "/tmp/a", prompt: "task", occurredAt: start), at: start)
        XCTAssertNotNil(store.apply(event: CodexEvent(kind: .stop, turnID: "t", occurredAt: Date(timeIntervalSince1970: 50)), at: Date(timeIntervalSince1970: 50)))
        XCTAssertNil(store.apply(event: CodexEvent(kind: .agentTurnComplete, turnID: "t", occurredAt: Date(timeIntervalSince1970: 51)), at: Date(timeIntervalSince1970: 51)))
    }

    func testKeepsOnlyTwentyRecentTasks() {
        var store = TaskStore()
        for i in 0..<25 {
            let time = Date(timeIntervalSince1970: Double(i))
            _ = store.apply(event: CodexEvent(kind: .userPromptSubmit, turnID: "t\(i)", cwd: "/tmp/p\(i)", prompt: "task", occurredAt: time), at: time)
            _ = store.apply(event: CodexEvent(kind: .stop, turnID: "t\(i)", occurredAt: time.addingTimeInterval(1)), at: time.addingTimeInterval(1))
        }
        XCTAssertEqual(store.recentTasks.count, 20)
        XCTAssertEqual(store.recentTasks.first?.turnID, "t24")
        XCTAssertNil(store.task(turnID: "t0"))
    }
    func testDerivedIdentityCanDriveTaskWithoutRawPromptOrPath() {
        var store = TaskStore()
        let event = CodexEvent(
            kind: .userPromptSubmit,
            turnID: "private-turn",
            identity: TaskIdentity(projectName: "Sample Workspace", taskName: "Run Tests"),
            occurredAt: Date(timeIntervalSince1970: 10)
        )
        let transition = store.apply(event: event)
        XCTAssertEqual(transition?.task.projectName, "Sample Workspace")
        XCTAssertEqual(transition?.task.taskName, "Run Tests")
    }

    func testClearTerminalHistoryPreservesActiveTasks() {
        var store = TaskStore()
        _ = store.apply(event: CodexEvent(kind: .userPromptSubmit, turnID: "active", cwd: "/tmp/active", occurredAt: Date(timeIntervalSince1970: 1)))
        _ = store.apply(event: CodexEvent(kind: .userPromptSubmit, turnID: "done", cwd: "/tmp/done", occurredAt: Date(timeIntervalSince1970: 2)))
        _ = store.apply(event: CodexEvent(kind: .stop, turnID: "done", occurredAt: Date(timeIntervalSince1970: 12)))
        store.clearTerminalHistory()
        XCTAssertEqual(store.activeTasks.map(\.turnID), ["active"])
        XCTAssertTrue(store.recentTasks.isEmpty)
    }

}
