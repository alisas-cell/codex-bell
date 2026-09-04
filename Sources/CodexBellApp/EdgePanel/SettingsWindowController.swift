#if os(macOS)
import AppKit
import Combine
import SwiftUI
import CodexBellCore

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private let onSessionEnded: () -> Void
    private var settingsCancellable: AnyCancellable?

    init(model: AppModel, onSessionEnded: @escaping () -> Void) {
        self.onSessionEnded = onSessionEnded
        let content = SettingsView(model: model)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 650, height: 540),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = model.copy[.settingsWindowTitle]
        window.contentView = NSHostingView(rootView: content)
        window.minSize = NSSize(width: 610, height: 480)
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
        settingsCancellable = model.$settings.sink { [weak window, weak model] _ in
            guard let window, let model else { return }
            window.title = model.copy[.settingsWindowTitle]
        }
    }

    required init?(coder: NSCoder) { nil }

    var isVisible: Bool { window?.isVisible == true }

    func show() {
        guard let window else { return }
        if !window.isVisible { window.center() }
        NSApplication.shared.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        onSessionEnded()
    }
}
#endif
