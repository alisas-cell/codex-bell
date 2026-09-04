import XCTest
@testable import CodexBellCore

final class SupportDirectoryIdentityTests: XCTestCase {
    func testExplicitSafeSupportIdentityWins() {
        XCTAssertEqual(
            AppSupportIdentity.supportDirectoryName(
                bundleIdentifier: "com.codexbell.app",
                declaredName: "Codex Bell Test Data"
            ),
            "Codex Bell Test Data"
        )
    }

    func testProductionAndUnsafeDeclaredNameFallbacks() {
        XCTAssertEqual(AppSupportIdentity.supportDirectoryName(bundleIdentifier: "com.codexbell.app", declaredName: nil), "Codex Bell")
        XCTAssertEqual(AppSupportIdentity.supportDirectoryName(bundleIdentifier: nil, declaredName: nil), "Codex Bell")
        XCTAssertEqual(AppSupportIdentity.supportDirectoryName(bundleIdentifier: nil, declaredName: "../bad"), "Codex Bell")
    }
}
