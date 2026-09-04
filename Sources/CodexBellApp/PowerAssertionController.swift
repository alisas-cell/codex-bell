#if os(macOS)
import Foundation
import IOKit.pwr_mgt

@MainActor
final class PowerAssertionController {
    private var assertionID: IOPMAssertionID = 0

    func update(runningCount: Int, enabled: Bool) {
        if enabled && runningCount > 0 {
            acquireIfNeeded()
        } else {
            releaseIfNeeded()
        }
    }

    private func acquireIfNeeded() {
        guard assertionID == 0 else { return }
        var newID: IOPMAssertionID = 0
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypeNoIdleSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "Codex Bell: Codex task running" as CFString,
            &newID
        )
        if result == kIOReturnSuccess { assertionID = newID }
    }

    private func releaseIfNeeded() {
        guard assertionID != 0 else { return }
        IOPMAssertionRelease(assertionID)
        assertionID = 0
    }

}
#endif
