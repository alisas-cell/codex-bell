import Foundation

#if os(macOS)
import AppKit
import Combine
import CodexBellCore
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()
    private var edgePanelController: EdgePanelController?
    private var settingsWindowController: SettingsWindowController?
    private var dockVisibilityCancellable: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        applyDockVisibility(model.settings.showInDock)
        dockVisibilityCancellable = model.$settings
            .map(\.showInDock)
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] showInDock in self?.applyDockVisibility(showInDock) }
        let controller = EdgePanelController(model: model)
        edgePanelController = controller
        controller.onOpenSettings = { [weak self] in self?.showSettings() }
        controller.revealFromDesktopActivation()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        edgePanelController?.revealFromDesktopActivation()
        return true
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        edgePanelController?.restoreIfUnavailableFromAppActivation()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    private func applyDockVisibility(_ showInDock: Bool) {
        switch DockVisibilityPolicy.activationMode(showInDock: showInDock) {
        case .accessory:
            NSApplication.shared.setActivationPolicy(.accessory)
        case .regular:
            NSApplication.shared.setActivationPolicy(.regular)
        }
    }

    func revealPanel() {
        edgePanelController?.revealFromMenuBar()
    }

    func showSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(model: model) { [weak self] in
                self?.edgePanelController?.endSettingsSession()
            }
        }
        if settingsWindowController?.isVisible != true {
            edgePanelController?.beginSettingsSession()
        }
        settingsWindowController?.show()
    }
}

@main
struct CodexBellApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(
                model: delegate.model,
                onReveal: delegate.revealPanel,
                onSettings: delegate.showSettings
            )
        } label: { MenuBarLabel(model: delegate.model) }
        .menuBarExtraStyle(.window)
    }
}

private struct MenuBarLabel: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Label(
            model.copy.appDisplayName,
            systemImage: model.waitingCount > 0 ? "bell.badge.fill" : "bell.fill"
        )
    }
}
#else
@main
enum CodexBellUnsupportedPlatform {
    static func main() {
        print("Codex Bell is a macOS app. Build this product on macOS 14 or later.")
    }
}
#endif
