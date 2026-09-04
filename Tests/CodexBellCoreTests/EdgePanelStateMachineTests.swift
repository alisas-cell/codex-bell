import XCTest
@testable import CodexBellCore

final class EdgePanelStateMachineTests: XCTestCase {
    func testAutoHiddenDockedModeAlwaysExposesHandle() {
        for anchor in DockAnchor.allCases {
            let machine = PanelStateMachine(anchor: anchor, visibility: .autoHidden)
            XCTAssertEqual(machine.windowVisibility, PanelWindowVisibility(mainPanel: false, edgeHandle: true))
        }
    }

    func testExplicitCollapseAndTimedAutoHideConvergeOnPersistentHandle() {
        var explicit = PanelStateMachine(anchor: .right, visibility: .expanded, isPinned: true)
        XCTAssertEqual(explicit.handle(.collapseToEdge), [.cancelScheduledHide])
        XCTAssertEqual(explicit.visibility, .autoHidden)
        XCTAssertEqual(explicit.windowVisibility, PanelWindowVisibility(mainPanel: false, edgeHandle: true))

        var automatic = PanelStateMachine(anchor: .right, visibility: .expanded)
        _ = automatic.handle(.mainPointerExited)
        XCTAssertEqual(automatic.handle(.hideDelayElapsed), [])
        XCTAssertEqual(automatic.visibility, explicit.visibility)
        XCTAssertEqual(automatic.windowVisibility, explicit.windowVisibility)
    }

    func testHandleHoverExpandsImmediatelyAndMainReentryCancelsHide() {
        var machine = PanelStateMachine(anchor: .left, visibility: .autoHidden)
        XCTAssertEqual(machine.handle(.handlePointerEntered), [.cancelScheduledHide])
        XCTAssertEqual(machine.visibility, .expanded)
        XCTAssertTrue(machine.pointerInsideMain)
        XCTAssertEqual(machine.handle(.mainPointerExited, hideDelay: 0.9), [.scheduleHide(after: 0.9)])
        XCTAssertEqual(machine.handle(.mainPointerEntered), [.cancelScheduledHide])
        XCTAssertEqual(machine.visibility, .expanded)
    }

    func testAllInteractionLocksCancelAndBlockAutoHide() {
        for lock in PanelInteractionLock.allCases {
            var machine = PanelStateMachine(anchor: .right, visibility: .expanded)
            _ = machine.handle(.mainPointerExited)
            XCTAssertEqual(machine.handle(.interactionBegan(lock)), [.cancelScheduledHide])
            XCTAssertFalse(machine.isAutoHideEligible(autoHideEnabled: true), "Lock must block hide: \(lock)")
            XCTAssertEqual(machine.handle(.hideDelayElapsed), [])
            XCTAssertEqual(machine.visibility, .expanded)
            XCTAssertEqual(machine.handle(.interactionEnded(lock), hideDelay: 0.9), [.scheduleHide(after: 0.9)])
        }
    }

    func testPinAndDockModeGateAutoHide() {
        var machine = PanelStateMachine(anchor: .right, visibility: .expanded)
        _ = machine.handle(.mainPointerExited)
        XCTAssertEqual(machine.handle(.pinChanged(true)), [.cancelScheduledHide])
        XCTAssertFalse(machine.isAutoHideEligible(autoHideEnabled: true))
        _ = machine.handle(.pinChanged(false))
        XCTAssertTrue(machine.isAutoHideEligible(autoHideEnabled: true))
        _ = machine.handle(.mainPointerEntered)

        XCTAssertEqual(machine.handle(.dockChanged(.left)), [.cancelScheduledHide])
        XCTAssertEqual(machine.windowVisibility, PanelWindowVisibility(mainPanel: true, edgeHandle: false))
    }

    func testHideOccursOnlyAfterFullyEligibleDelay() {
        var machine = PanelStateMachine(anchor: .right, visibility: .expanded)
        XCTAssertEqual(machine.handle(.mainPointerExited, hideDelay: 0.9), [.scheduleHide(after: 0.9)])
        XCTAssertEqual(machine.handle(.hideDelayElapsed), [])
        XCTAssertEqual(machine.visibility, .autoHidden)
        XCTAssertEqual(machine.windowVisibility, PanelWindowVisibility(mainPanel: false, edgeHandle: true))
    }

    func testActivationRestoresCollapsedHandleToExpandedMainPanel() {
        var machine = PanelStateMachine(anchor: .right, visibility: .autoHidden)
        XCTAssertEqual(machine.handle(.appActivated), [.cancelScheduledHide])
        XCTAssertEqual(machine.visibility, .expanded)
        XCTAssertEqual(machine.windowVisibility, PanelWindowVisibility(mainPanel: true, edgeHandle: false))
    }

    func testUrgentStatePreservesHandleRecovery() {
        var machine = PanelStateMachine(anchor: .right, visibility: .autoHidden)
        XCTAssertEqual(machine.handle(.urgentEvent, urgentPeekDuration: 3), [.scheduleUrgentClear(after: 3)])
        XCTAssertTrue(machine.isUrgent)
        XCTAssertEqual(machine.windowVisibility, PanelWindowVisibility(mainPanel: false, edgeHandle: true))
        XCTAssertEqual(machine.handle(.urgentPeekElapsed), [])
        XCTAssertFalse(machine.isUrgent)
    }

    func testHandleStatusMapsAggregateTaskState() {
        let now = Date(timeIntervalSince1970: 100)
        XCTAssertEqual(HandleStatus.resolve(active: [], recent: [], now: now), .idle)
        XCTAssertEqual(HandleStatus.resolve(active: [task(.running, at: now)], recent: [], now: now), .running)
        XCTAssertEqual(HandleStatus.resolve(active: [task(.waitingInput, at: now)], recent: [], now: now), .waiting)
        XCTAssertEqual(HandleStatus.resolve(active: [], recent: [task(.failed, at: now)], now: now), .failed)
        XCTAssertEqual(HandleStatus.resolve(active: [], recent: [task(.completed, at: now)], now: now), .completed)
        XCTAssertEqual(HandleStatus.resolve(active: [], recent: [task(.completed, at: now.addingTimeInterval(-4))], now: now), .idle)
    }

    private func task(_ state: TaskState, at date: Date) -> TrackedTask {
        TrackedTask(
            turnID: UUID().uuidString,
            projectName: "Project",
            state: state,
            startedAt: date.addingTimeInterval(-30),
            endedAt: state == .running || state == .waitingApproval || state == .waitingInput ? nil : date,
            lastStateChangedAt: date
        )
    }
}
