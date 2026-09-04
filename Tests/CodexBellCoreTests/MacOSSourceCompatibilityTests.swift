import XCTest

final class MacOSSourceCompatibilityTests: XCTestCase {
    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func source(_ name: String) throws -> String {
        let url = repoRoot.appendingPathComponent("Sources/CodexBellApp/\(name)")
        return try String(contentsOf: url, encoding: .utf8)
    }

    func testAppModelDoesNotCallMainActorWatcherFromDeinit() throws {
        let text = try source("AppModel.swift")
        XCTAssertFalse(text.contains("deinit { inbox.stop() }"))
    }

    func testAppServerObserverDoesNotDoubleBindFlattenedTryOptional() throws {
        let text = try source("AppServerObserver.swift")
        XCTAssertFalse(text.contains("let event = try? AppServerNotificationDecoder.decode(data), let event"))
    }

    func testPowerControllerDoesNotUseActorIsolatedCleanupFromDeinit() throws {
        let text = try source("PowerAssertionController.swift")
        XCTAssertFalse(text.contains("deinit {"))
    }

    func testSpeechDelegateCallbacksHopBackToMainActor() throws {
        let text = try source("AudioAnnouncer.swift")
        XCTAssertTrue(text.contains("nonisolated func speechSynthesizer"))
        XCTAssertTrue(text.contains("Task { @MainActor"))
    }

    func testProductionOwnsIndependentMainAndSideHandlePanels() throws {
        let text = try source("EdgePanel/EdgePanelController.swift")
        XCTAssertTrue(text.contains("private let mainPanel: MainPanel"))
        XCTAssertTrue(text.contains("private let edgeHandlePanel: EdgeHandlePanel"))
        XCTAssertTrue(text.contains("stateMachine.windowVisibility"))
        XCTAssertTrue(text.contains("snapAnchor(forReleaseX:"))
        XCTAssertFalse(text.contains("floatingPanelFrame"))
        XCTAssertFalse(text.contains("topRightInset"))
        XCTAssertFalse(text.contains("collapsedHitTargetFrame"))
        XCTAssertFalse(text.contains("EdgePanelPresentation"))
    }

    func testRuntimeCopyIsNotHardCodedInSwiftUIViews() throws {
        for file in ["EdgePanel/EdgePanelView.swift", "SettingsView.swift", "MenuBarView.swift"] {
            let text = try source(file)
            XCTAssertFalse(text.contains("Text(\"Codex Bell\"") , "Hard-coded product title in \(file)")
            XCTAssertFalse(text.contains("Label(\"Settings"), "Hard-coded settings label in \(file)")
            XCTAssertFalse(text.contains("Button(\"Test announcement"), "Hard-coded announcement label in \(file)")
        }
    }

    func testProductionBundleKeepsOneProductNameAndExactSupportIdentity() throws {
        let script = try String(contentsOf: repoRoot.appendingPathComponent("scripts/build-app.sh"), encoding: .utf8)
        XCTAssertTrue(script.contains("Codex Bell.app"))
        XCTAssertTrue(script.contains("<key>CodexBellSupportDirectoryName</key><string>Codex Bell</string>"))
        XCTAssertTrue(script.contains("com.codexbell.app"))
        XCTAssertTrue(script.contains("<key>CFBundleShortVersionString</key><string>$VERSION</string>"))
        XCTAssertTrue(script.contains("--options runtime"))
        XCTAssertTrue(script.contains("CodexBellSupportDirectoryName"))
        XCTAssertTrue(script.contains("<key>LSUIElement</key><true/>"))
        XCTAssertTrue(script.contains("<key>LSMultipleInstancesProhibited</key><true/>"))
        XCTAssertTrue(script.contains("<key>CFBundleDisplayName</key><string>Codex Bell</string>"))
        XCTAssertTrue(script.contains("<key>CFBundleName</key><string>Codex Bell</string>"))
        XCTAssertFalse(script.contains("Codex叮铃铃.app"))
    }

    func testProductionYellowControlUsesSharedSideCollapseAndNeverSystemMinimize() throws {
        let controller = try source("EdgePanel/EdgePanelController.swift")
        let view = try source("EdgePanel/EdgePanelView.swift")
        XCTAssertTrue(controller.contains("dispatch(.collapseToEdge"))
        XCTAssertTrue(controller.contains("CollapsePlacementPolicy.destination"))
        XCTAssertFalse(controller.contains("NSApplication.shared.hide"))
        XCTAssertFalse(controller.contains("miniaturize"))
        XCTAssertTrue(view.contains("onCollapseToEdge"))
        XCTAssertTrue(view.contains("copy[.collapseToEdge]"))
        XCTAssertFalse(view.contains("onMinimize"))
    }

    func testProductionDockPreferenceDrivesRuntimeActivationPolicy() throws {
        let app = try source("CodexBellApp.swift")
        let settings = try source("SettingsView.swift")
        XCTAssertTrue(app.contains("DockVisibilityPolicy.activationMode"))
        XCTAssertTrue(app.contains("setActivationPolicy(.accessory)"))
        XCTAssertTrue(app.contains("setActivationPolicy(.regular)"))
        XCTAssertTrue(settings.contains("Toggle(copy[.showInDock]"))
    }

    func testProductionReopenRoutesToTheExistingPanelController() throws {
        let app = try source("CodexBellApp.swift")
        XCTAssertEqual(app.components(separatedBy: "EdgePanelController(model: model)").count - 1, 1)
        XCTAssertTrue(app.contains("edgePanelController?.revealFromDesktopActivation()"))
        XCTAssertTrue(app.contains("edgePanelController?.revealFromMenuBar()"))
    }

    func testProductionTypographyTokensKeepReadableHierarchyAndNarrowPanel() throws {
        let typography = try source("BellTypography.swift")
        let panel = try source("EdgePanel/EdgePanelView.swift")
        let settings = try source("SettingsView.swift")
        let geometry = try String(contentsOf: repoRoot.appendingPathComponent("Sources/CodexBellCore/DockGeometry.swift"), encoding: .utf8)
        XCTAssertTrue(typography.contains("brand: CGFloat = 15.5"))
        XCTAssertTrue(typography.contains("sectionHeader: CGFloat = 12.5"))
        XCTAssertTrue(typography.contains("taskPrimary: CGFloat = 14"))
        XCTAssertTrue(typography.contains("taskSecondary: CGFloat = 12.5"))
        XCTAssertTrue(typography.contains("metadata: CGFloat = 11.5"))
        XCTAssertTrue(typography.contains("control: CGFloat = 13"))
        XCTAssertTrue(typography.contains("language: CGFloat = 13"))
        XCTAssertTrue(typography.contains("settingsBody: CGFloat = 13"))
        XCTAssertTrue(panel.contains(".truncationMode(.tail)"))
        XCTAssertTrue(panel.contains(".lineLimit(1)"))
        XCTAssertFalse(panel.contains("ScrollView(.horizontal)"))
        XCTAssertTrue(settings.contains("BellTypography.settingsBody"))
        XCTAssertTrue(geometry.contains("defaultPanelWidth = 280.0"))
    }

    func testProductionUIAndControllerContainNoObsoleteRestingPlacement() throws {
        let controller = try source("EdgePanel/EdgePanelController.swift")
        let panel = try source("EdgePanel/EdgePanelView.swift")
        let settings = try source("SettingsView.swift")
        for text in [panel, settings] {
            XCTAssertFalse(text.contains(".topRight"))
            XCTAssertFalse(text.contains(".floating"))
        }
        XCTAssertFalse(controller.contains("dockAnchor == .floating"))
        XCTAssertFalse(controller.contains("case .floating"))
        XCTAssertFalse(controller.contains("floatingPanelFrame"))
        XCTAssertFalse(controller.contains("topRightInset"))
    }

    func testDockSelectionIsAppliedAfterPublishedSettingsStorageUpdates() throws {
        let controller = try source("EdgePanel/EdgePanelController.swift")
        XCTAssertTrue(controller.contains("Task { @MainActor [weak self] in"))
        XCTAssertTrue(controller.contains("self?.applyCurrentSettings()"))
        XCTAssertTrue(controller.contains("let settings = model.settings"))
        XCTAssertFalse(controller.contains("sink { [weak self] settings in"))
    }

    func testPrimaryPanelUsesCustomBrandControlsAndNoTestButton() throws {
        let text = try source("EdgePanel/EdgePanelView.swift")
        XCTAssertTrue(text.contains("BrandVolumeSlider"))
        XCTAssertTrue(text.contains("BrandToggle"))
        XCTAssertTrue(text.contains("BrandLanguageControl"))
        XCTAssertFalse(text.contains("copy[.testAnnouncement]"))
        XCTAssertFalse(text.contains("Text(copy[.language])"))
        XCTAssertFalse(text.contains("minimumTaskFilter"))
        XCTAssertFalse(text.contains("keepAwakeWhileRunning"))
        XCTAssertTrue(text.contains("TaskPresentationPolicy.active"))
        XCTAssertTrue(text.contains(".frame(maxHeight: 260)"))
    }

    func testDiagnosticsActionsHaveOneSettingsOwnerAndOneOutputContract() throws {
        let settings = try source("SettingsView.swift")
        let model = try source("AppModel.swift")
        XCTAssertEqual(settings.components(separatedBy: "copy[.openDiagnostics]").count - 1, 1)
        XCTAssertEqual(settings.components(separatedBy: "copy[.copySanitizedDiagnostics]").count - 1, 1)
        XCTAssertTrue(model.contains("setString(sanitizedDiagnostics()"))
        XCTAssertTrue(model.contains("try sanitizedDiagnostics().write"))
    }
}
