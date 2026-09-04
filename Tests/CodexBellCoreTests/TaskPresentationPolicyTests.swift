import XCTest
@testable import CodexBellCore

final class TaskPresentationPolicyTests: XCTestCase {
    func testOneAndFourActiveTasksNeedNoDisclosure() {
        let one = TaskPresentationPolicy.active(makeRunningTasks(1), expanded: false)
        XCTAssertEqual(one.visibleTasks.count, 1)
        XCTAssertEqual(one.hiddenCount, 0)
        XCTAssertFalse(one.isDisclosureNeeded)

        let four = TaskPresentationPolicy.active(makeRunningTasks(4), expanded: false)
        XCTAssertEqual(four.visibleTasks.count, 4)
        XCTAssertEqual(four.hiddenCount, 0)
        XCTAssertFalse(four.isDisclosureNeeded)
    }

    func testFiveActiveTasksShowFourAndOneHidden() {
        let presentation = TaskPresentationPolicy.active(makeRunningTasks(5), expanded: false)
        XCTAssertEqual(presentation.totalCount, 5)
        XCTAssertEqual(presentation.visibleTasks.count, 4)
        XCTAssertEqual(presentation.hiddenCount, 1)
        XCTAssertTrue(presentation.isDisclosureNeeded)
    }

    func testTwelveAndThirtyStayCollapsedButExpandedExposesEveryTask() {
        for count in [12, 30] {
            let tasks = makeRunningTasks(count)
            let collapsed = TaskPresentationPolicy.active(tasks, expanded: false)
            XCTAssertEqual(collapsed.visibleTasks.count, 4)
            XCTAssertEqual(collapsed.hiddenCount, count - 4)

            let expanded = TaskPresentationPolicy.active(tasks, expanded: true)
            XCTAssertEqual(expanded.visibleTasks.count, count)
            XCTAssertEqual(expanded.hiddenCount, count - 4)
        }
    }

    func testWaitingTasksRankAboveRunningAndHiddenTaskReranksImmediately() {
        var tasks = makeRunningTasks(6)
        tasks[5].state = .waitingInput
        tasks[5].lastStateChangedAt = Date(timeIntervalSince1970: 500)
        tasks[4].state = .waitingApproval
        tasks[4].lastStateChangedAt = Date(timeIntervalSince1970: 400)

        let presentation = TaskPresentationPolicy.active(tasks, expanded: false)
        XCTAssertEqual(presentation.visibleTasks.map(\.turnID).prefix(2), ["running-4", "running-5"])
        XCTAssertEqual(presentation.visibleTasks[0].state, .waitingApproval)
        XCTAssertEqual(presentation.visibleTasks[1].state, .waitingInput)
    }

    func testNormalRunningTasksSortLongestRunningFirst() {
        let tasks = makeRunningTasks(5).reversed()
        let presentation = TaskPresentationPolicy.active(Array(tasks), expanded: true)
        XCTAssertEqual(presentation.orderedTasks.map(\.turnID), (0..<5).map { "running-\($0)" })
    }

    func testRecentShowsOnlyFiveNewestTerminalTasks() {
        let tasks = (0..<12).map { index in
            task(
                id: "recent-\(index)",
                state: index.isMultiple(of: 3) ? .failed : .completed,
                startedAt: TimeInterval(index),
                changedAt: TimeInterval(index + 100)
            )
        }
        let visible = TaskPresentationPolicy.recent(tasks.shuffled())
        XCTAssertEqual(visible.count, 5)
        XCTAssertEqual(visible.map(\.turnID), ["recent-11", "recent-10", "recent-9", "recent-8", "recent-7"])
    }

    private func makeRunningTasks(_ count: Int) -> [TrackedTask] {
        (0..<count).map { index in
            task(id: "running-\(index)", state: .running, startedAt: TimeInterval(index), changedAt: TimeInterval(index))
        }
    }

    private func task(id: String, state: TaskState, startedAt: TimeInterval, changedAt: TimeInterval) -> TrackedTask {
        TrackedTask(
            turnID: id,
            projectName: "Project",
            state: state,
            startedAt: Date(timeIntervalSince1970: startedAt),
            endedAt: state == .running || state == .waitingApproval || state == .waitingInput ? nil : Date(timeIntervalSince1970: changedAt),
            lastStateChangedAt: Date(timeIntervalSince1970: changedAt)
        )
    }
}
