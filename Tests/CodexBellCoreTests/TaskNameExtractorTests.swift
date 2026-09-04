import XCTest
@testable import CodexBellCore

final class TaskNameExtractorTests: XCTestCase {
    func testGenericProjectAndConciseTask() {
        let identity = TaskNameExtractor.extract(
            cwd: "/Volumes/Demo/sample-workspace",
            prompt: "Run release tests"
        )
        XCTAssertEqual(identity.projectName, "Sample Workspace")
        XCTAssertEqual(identity.taskName, "测试")
    }

    func testGenericEnglishAndChineseNames() {
        XCTAssertEqual(TaskNameExtractor.extract(cwd: "/tmp/sample-app", prompt: "Run tests").spokenName, "Sample App 测试")
        XCTAssertEqual(TaskNameExtractor.extract(cwd: "/tmp/sample-site.example", prompt: "做全站 SEO 升级，刷新旧页").spokenName, "Sample Site 全站 SEO 升级")
    }

    func testGenericRepoFallbackIsReadable() {
        let identity = TaskNameExtractor.extract(cwd: "/Volumes/Demo/my-cool_project", prompt: "Please verify it")
        XCTAssertEqual(identity.projectName, "My Cool Project")
    }

    func testSanitizerRemovesNeverSpeakMaterial() {
        let raw = "branch codex/seo SHA 57320b6b94af6d3ce06f93c4dadc2aef27c378b2 https://example.invalid /Volumes/Demo/project token=secret port 3000 Release Tests"
        let clean = TaskNameExtractor.sanitizeForSpeech(raw)
        XCTAssertFalse(clean.localizedCaseInsensitiveContains("codex/seo"))
        XCTAssertFalse(clean.contains("57320b6"))
        XCTAssertFalse(clean.contains("https://"))
        XCTAssertFalse(clean.contains("/Volumes/Demo"))
        XCTAssertFalse(clean.localizedCaseInsensitiveContains("token"))
        XCTAssertFalse(clean.contains("3000"))
        XCTAssertTrue(clean.contains("Release Tests"))
    }

    func testSpeechNameIsCapped() {
        let identity = TaskNameExtractor.extract(cwd: "/tmp/repository-name", prompt: String(repeating: "verylong ", count: 50))
        XCTAssertLessThanOrEqual(identity.spokenName.count, 64)
    }
}
