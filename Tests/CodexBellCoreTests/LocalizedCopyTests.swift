import XCTest
@testable import CodexBellCore

final class LocalizedCopyTests: XCTestCase {
    private let identity = TaskIdentity(projectName: "Sample Workspace", taskName: "Run Tests")

    func testSystemLanguageDefaultAndExplicitNames() {
        XCTAssertEqual(AppLanguage.systemDefault(preferredLanguages: ["zh-Hans-CN"]), .zhHans)
        XCTAssertEqual(AppLanguage.systemDefault(preferredLanguages: ["en-US"]), .en)
        XCTAssertEqual(AppLanguage.systemDefault(preferredLanguages: []), .en)
        XCTAssertEqual(AppLanguage.zhHans.selectionName, "中文")
        XCTAssertEqual(AppLanguage.en.selectionName, "English")
    }

    func testEveryStaticCopyKeyExistsInBothLanguages() {
        for key in LocalizedCopy.Key.allCases {
            XCTAssertFalse(LocalizedCopy(language: .zhHans)[key].isEmpty, "Missing Chinese copy for \(key)")
            XCTAssertFalse(LocalizedCopy(language: .en)[key].isEmpty, "Missing English copy for \(key)")
        }
    }

    func testLocalizedProductAndPrimaryLabels() {
        let chinese = LocalizedCopy(language: .zhHans)
        XCTAssertEqual(chinese.appDisplayName, "Codex 叮铃铃")
        XCTAssertEqual(chinese[.language], "语言")
        XCTAssertEqual(chinese[.settings], "设置")
        XCTAssertEqual(chinese[.active], "正在运行")
        XCTAssertEqual(chinese[.waiting], "等待你")
        XCTAssertEqual(chinese[.recent], "最近完成")
        XCTAssertEqual(chinese[.connectionStatus], "连接状态")

        let english = LocalizedCopy(language: .en)
        XCTAssertEqual(english.appDisplayName, "Codex Bell")
        XCTAssertEqual(english[.language], "Language")
        XCTAssertEqual(english[.settings], "Settings")
    }

    func testActiveDisclosureDockCollapseVoiceAndAboutCopy() {
        let chinese = LocalizedCopy(language: .zhHans)
        XCTAssertEqual(chinese.activeSectionTitle(12), "正在运行 · 12")
        XCTAssertEqual(chinese.activeDisclosureTitle(8), "还有 8 个正在运行")
        XCTAssertEqual(chinese.activeCollapseTitle, "收起")
        XCTAssertEqual(chinese[.copySanitizedDiagnostics], "复制脱敏诊断信息")
        XCTAssertEqual(chinese[.showInDock], "在程序坞中显示图标")
        XCTAssertEqual(chinese[.collapseToEdge], "收起到边缘")
        XCTAssertEqual(chinese[.completionAlerts], "开启语音播报")
        XCTAssertEqual(chinese[.completionAnnouncements], "开启语音播报")
        XCTAssertEqual(chinese[.author], "作者：森虫虫进化中（全网同名）")
        XCTAssertEqual(chinese[.unofficial], "非官方社区项目，与 OpenAI 无隶属或认可关系。")

        let english = LocalizedCopy(language: .en)
        XCTAssertEqual(english.activeSectionTitle(12), "Active · 12")
        XCTAssertEqual(english.activeDisclosureTitle(8), "8 more active")
        XCTAssertEqual(english.activeCollapseTitle, "Show less")
        XCTAssertEqual(english[.copySanitizedDiagnostics], "Copy Redacted Diagnostics")
        XCTAssertEqual(english[.showInDock], "Show Codex Bell in Dock")
        XCTAssertEqual(english[.collapseToEdge], "Collapse to Edge")
        XCTAssertEqual(english[.completionAlerts], "Enable Voice Announcements")
        XCTAssertEqual(english[.completionAnnouncements], "Enable Voice Announcements")
        XCTAssertEqual(english[.author], "Author: 森虫虫进化中 (same handle across platforms)")
        XCTAssertEqual(english[.unofficial], "Unofficial community project. Not affiliated with or endorsed by OpenAI.")
    }

    func testExactChineseSpeechForEveryLifecycleKind() {
        let copy = LocalizedCopy(language: .zhHans)
        XCTAssertEqual(copy.speech(for: announcement(.completed)), "Sample Workspace Run Tests 任务已完成。")
        XCTAssertEqual(copy.speech(for: announcement(.failed)), "Sample Workspace Run Tests 任务运行失败，请回来查看。")
        XCTAssertEqual(copy.speech(for: announcement(.interrupted)), "Sample Workspace Run Tests 任务已中断。")
        XCTAssertEqual(copy.speech(for: announcement(.waitingApproval)), "Sample Workspace Run Tests 正在等待你的操作。")
        XCTAssertEqual(copy.speech(for: announcement(.waitingInput)), "Sample Workspace Run Tests 有问题需要你确认。")
        XCTAssertEqual(copy.speech(for: announcement(.completed, isTest: true)), "Codex 叮铃铃已准备就绪。")
    }

    func testExactEnglishSpeechForEveryLifecycleKind() {
        let copy = LocalizedCopy(language: .en)
        XCTAssertEqual(copy.speech(for: announcement(.completed)), "Sample Workspace Run Tests is complete.")
        XCTAssertEqual(copy.speech(for: announcement(.failed)), "Sample Workspace Run Tests failed. Please come back and check.")
        XCTAssertEqual(copy.speech(for: announcement(.interrupted)), "Sample Workspace Run Tests was interrupted.")
        XCTAssertEqual(copy.speech(for: announcement(.waitingApproval)), "Sample Workspace Run Tests is waiting for your approval.")
        XCTAssertEqual(copy.speech(for: announcement(.waitingInput)), "Sample Workspace Run Tests needs your input.")
        XCTAssertEqual(copy.speech(for: announcement(.completed, isTest: true)), "Codex Bell is ready.")
    }

    func testNotificationsUseSelectedLanguageButPreserveDynamicName() {
        let item = announcement(.failed)
        let chinese = LocalizedCopy(language: .zhHans)
        XCTAssertEqual(chinese.notificationTitle(for: item), "Sample Workspace Run Tests · 失败")
        XCTAssertEqual(chinese.notificationBody(for: item), "Codex 任务运行失败，请回来查看。")

        let english = LocalizedCopy(language: .en)
        XCTAssertEqual(english.notificationTitle(for: item), "Sample Workspace Run Tests · Failed")
        XCTAssertEqual(english.notificationBody(for: item), "Codex task failed. Please come back and check.")
    }

    func testDynamicTaskAndProjectNamesAreNotTranslated() {
        let chinese = LocalizedCopy(language: .zhHans)
        XCTAssertEqual(chinese.speech(for: announcement(.completed)), "Sample Workspace Run Tests 任务已完成。")
    }

    private func announcement(_ kind: AnnouncementKind, isTest: Bool = false) -> Announcement {
        Announcement(turnID: "turn", kind: kind, identity: identity, generation: 1, isTest: isTest)
    }
}
