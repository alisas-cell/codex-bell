#if os(macOS)
import AppKit
import Combine
import SwiftUI
import CodexBellCore

@MainActor
final class EdgePanelController: NSObject, ObservableObject, NSWindowDelegate {
    @Published private(set) var visibility: PanelVisibilityState

    private let model: AppModel
    private let mainPanel: MainPanel
    private let edgeHandlePanel: EdgeHandlePanel
    private var stateMachine: PanelStateMachine
    private var mainTrackingView: PanelTrackingView!
    private var handleTrackingView: PanelTrackingView!
    private var hideTask: Task<Void, Never>?
    private var urgentTask: Task<Void, Never>?
    private var pointerReconciliationTask: Task<Void, Never>?
    private var settingsCancellable: AnyCancellable?
    private var localEventMonitor: Any?
    private var globalMouseUpMonitor: Any?
    private var globalPointerMonitor: Any?
    private var settingsSessionDepth = 0
    private var lastSettings: BellSettings

    var onOpenSettings: (() -> Void)?

    init(model: AppModel) {
        self.model = model
        self.lastSettings = model.settings
        let startsExpanded = model.settings.panelPinned
        let initialVisibility: PanelVisibilityState = startsExpanded ? .expanded : .autoHidden
        self.visibility = initialVisibility
        self.stateMachine = PanelStateMachine(
            anchor: model.settings.dockAnchor,
            visibility: initialVisibility,
            isPinned: model.settings.panelPinned
        )
        self.mainPanel = MainPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        self.edgeHandlePanel = EdgeHandlePanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        super.init()
        configurePanels()
        rebuildMainContent()
        rebuildHandleContent()
        observeEnvironment()
        renderWindows(animated: false, bringFront: false)
        model.onUrgentTransition = { [weak self] _ in self?.showUrgentStatus() }
    }

    func revealFromDesktopActivation() {
        restoreForActivation()
    }

    func revealFromMenuBar() {
        restoreForActivation()
    }

    func restoreIfUnavailableFromAppActivation() {
        guard visibility != .expanded || !mainPanel.isVisible else { return }
        restoreForActivation()
    }

    func beginSettingsSession() {
        settingsSessionDepth += 1
        if settingsSessionDepth == 1 {
            dispatch(.interactionBegan(.settings))
        }
    }

    func endSettingsSession() {
        settingsSessionDepth = max(0, settingsSessionDepth - 1)
        guard settingsSessionDepth == 0 else { return }
        dispatch(.interactionEnded(.settings))
        reconcilePointerLocation()
    }

    private func configurePanels() {
        configure(mainPanel, shadow: true)
        configure(edgeHandlePanel, shadow: true)
        edgeHandlePanel.becomesKeyOnlyIfNeeded = true

        localEventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [
                .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged,
                .leftMouseDown, .rightMouseDown, .otherMouseDown,
                .leftMouseUp, .rightMouseUp, .otherMouseUp,
            ]
        ) { [weak self] event in
            guard let self else { return event }
            let isBellWindow = event.window === self.mainPanel || event.window === self.edgeHandlePanel
            switch event.type {
            case .leftMouseDown, .rightMouseDown, .otherMouseDown:
                if isBellWindow { self.dispatch(.interactionBegan(.mouseDown)) }
            case .leftMouseUp, .rightMouseUp, .otherMouseUp:
                if self.stateMachine.interactionLocks.contains(.mouseDown) {
                    self.dispatch(.interactionEnded(.mouseDown))
                }
                self.reconcilePointerLocation()
            case .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged:
                self.reconcilePointerLocation()
            default:
                break
            }
            return event
        }

        globalMouseUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp, .rightMouseUp, .otherMouseUp]) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if self.stateMachine.interactionLocks.contains(.mouseDown) {
                    self.dispatch(.interactionEnded(.mouseDown))
                }
                self.reconcilePointerLocation()
            }
        }

        globalPointerMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
        ) { [weak self] _ in
            Task { @MainActor in
                self?.reconcilePointerLocation()
            }
        }
    }

    private func configure(_ panel: NSPanel, shadow: Bool) {
        panel.delegate = self
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = shadow
        panel.animationBehavior = .none
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovable = false
        panel.isMovableByWindowBackground = false
        panel.isReleasedWhenClosed = false
        panel.acceptsMouseMovedEvents = true
    }

    private func rebuildMainContent() {
        let view = EdgePanelView(
            model: model,
            anchor: model.settings.dockAnchor,
            onPinChanged: { [weak self] pinned in self?.setPinned(pinned) },
            onCollapseToEdge: { [weak self] in self?.collapseToEdge() },
            onDragStarted: { [weak self] in self?.dragStarted() },
            onDragEnded: { [weak self] in self?.dragEnded() },
            onInteractionActive: { [weak self] lock, active in self?.setInteraction(lock, active: active) },
            onOpenSettings: { [weak self] in self?.onOpenSettings?() }
        )
        mainTrackingView = PanelTrackingView()
        mainTrackingView.onPointerEntered = { [weak self] in self?.dispatch(.mainPointerEntered) }
        mainTrackingView.onPointerExited = { [weak self] in self?.dispatch(.mainPointerExited) }
        mainPanel.contentView = hosted(view, inside: mainTrackingView)
    }

    private func rebuildHandleContent() {
        let view = EdgeHandleView(
            model: model,
            anchor: model.settings.dockAnchor,
            isUrgent: stateMachine.isUrgent,
            onReveal: { [weak self] in self?.dispatch(.handlePointerEntered) }
        )
        handleTrackingView = PanelTrackingView()
        handleTrackingView.onPointerEntered = { [weak self] in self?.dispatch(.handlePointerEntered) }
        handleTrackingView.onPointerExited = { [weak self] in self?.dispatch(.handlePointerExited) }
        edgeHandlePanel.contentView = hosted(view, inside: handleTrackingView)
    }

    private func hosted<Content: View>(_ view: Content, inside container: PanelTrackingView) -> NSView {
        let hosting = NSHostingView(rootView: view)
        hosting.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: container.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        return container
    }

    private func observeEnvironment() {
        settingsCancellable = model.$settings.dropFirst().sink { [weak self] _ in
            // @Published publishes from willSet. Defer until model.settings contains
            // the selected value so renderWindows reads the same anchor we apply.
            Task { @MainActor [weak self] in
                self?.applyCurrentSettings()
            }
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenConfigurationChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        pointerReconciliationTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(150))
                guard !Task.isCancelled else { return }
                self?.reconcilePointerLocation()
            }
        }
    }

    private func applyCurrentSettings() {
        let settings = model.settings
        let previous = lastSettings
        lastSettings = settings

        if previous.dockAnchor != settings.dockAnchor {
            apply(stateMachine.handle(.dockChanged(settings.dockAnchor), autoHideEnabled: settings.autoHideEnabled, hideDelay: settings.autoHideDelay))
        }
        if previous.panelPinned != settings.panelPinned {
            apply(stateMachine.handle(.pinChanged(settings.panelPinned), autoHideEnabled: settings.autoHideEnabled, hideDelay: settings.autoHideDelay))
        }
        if previous.autoHideEnabled, !settings.autoHideEnabled, stateMachine.visibility == .autoHidden {
            apply(stateMachine.handle(.appActivated, autoHideEnabled: false))
        }

        visibility = stateMachine.visibility
        if previous.dockAnchor != settings.dockAnchor {
            rebuildMainContent()
            rebuildHandleContent()
        }
        renderWindows(animated: true, bringFront: false)
    }

    private func restoreForActivation() {
        cancelScheduledHide()
        let screen = selectedScreen(preferPointer: true)
        model.settings.selectedDisplayID = displayID(for: screen)
        dispatch(.dockChanged(model.settings.dockAnchor), animated: false)
        dispatch(.appActivated, animated: false, bringFront: true)
        NSApplication.shared.activate(ignoringOtherApps: true)
        mainPanel.makeKeyAndOrderFront(nil)
    }

    private func collapseToEdge() {
        let destination = CollapsePlacementPolicy.destination(current: model.settings.dockAnchor)
        dispatch(.dockChanged(destination), animated: false)
        dispatch(.collapseToEdge, animated: false)
    }

    private func setPinned(_ pinned: Bool) {
        model.settings.panelPinned = pinned
    }

    private func setInteraction(_ lock: PanelInteractionLock, active: Bool) {
        dispatch(active ? .interactionBegan(lock) : .interactionEnded(lock))
    }

    private func dragStarted() {
        dispatch(.interactionBegan(.drag), animated: false)
    }

    private func dragEnded() {
        let screen = bestScreen(for: mainPanel.frame)
        let geometry = geometry(for: screen)
        let released = BellRect(mainPanel.frame)
        let anchor = geometry.snapAnchor(forReleaseX: Double(NSEvent.mouseLocation.x))
        var settings = model.settings
        settings.selectedDisplayID = displayID(for: screen)
        settings.dockAnchor = anchor
        settings.panelPinned = false
        let available = max(1, screen.visibleFrame.height - geometry.expandedSize.height)
        settings.dockVerticalFraction = min(max((released.minY - screen.visibleFrame.minY) / available, 0), 1)
        model.settings = settings
        dispatch(.dockChanged(anchor), animated: false)
        dispatch(.interactionEnded(.drag), animated: true)
    }

    private func showUrgentStatus() {
        guard model.settings.urgentPeekEnabled else { return }
        dispatch(.urgentEvent)
    }

    private func dispatch(_ event: PanelEvent, animated: Bool = true, bringFront: Bool = false) {
        let wasUrgent = stateMachine.isUrgent
        let effects = stateMachine.handle(
            event,
            autoHideEnabled: model.settings.autoHideEnabled,
            hideDelay: model.settings.autoHideDelay,
            urgentPeekDuration: 3
        )
        visibility = stateMachine.visibility
        if wasUrgent != stateMachine.isUrgent { rebuildHandleContent() }
        renderWindows(animated: animated, bringFront: bringFront)
        apply(effects)
    }

    private func apply(_ effects: [PanelEffect]) {
        for effect in effects {
            switch effect {
            case .cancelScheduledHide:
                cancelScheduledHide()
            case let .scheduleHide(delay):
                hideTask?.cancel()
                hideTask = Task { [weak self] in
                    try? await Task.sleep(for: .seconds(delay))
                    guard !Task.isCancelled else { return }
                    self?.dispatch(.hideDelayElapsed)
                }
            case let .scheduleUrgentClear(delay):
                urgentTask?.cancel()
                urgentTask = Task { [weak self] in
                    try? await Task.sleep(for: .seconds(delay))
                    guard !Task.isCancelled else { return }
                    self?.dispatch(.urgentPeekElapsed)
                }
            }
        }
    }

    private func cancelScheduledHide() {
        hideTask?.cancel()
        hideTask = nil
    }

    private func renderWindows(animated: Bool, bringFront: Bool) {
        let screen = selectedScreen(preferPointer: false)
        let geometry = geometry(for: screen)
        let mainFrame = geometry.recoveredFrame(anchor: model.settings.dockAnchor).nsRect
        let handleFrame = (stateMachine.isUrgent
            ? geometry.urgentHandleFrame(for: model.settings.dockAnchor)
            : geometry.handleFrame(for: model.settings.dockAnchor)).nsRect
        mainPanel.setFrame(mainFrame, display: mainPanel.isVisible)
        edgeHandlePanel.setFrame(handleFrame, display: edgeHandlePanel.isVisible)

        let windows = stateMachine.windowVisibility
        if windows.mainPanel {
            mainPanel.alphaValue = 1
            edgeHandlePanel.orderOut(nil)
            if bringFront {
                mainPanel.makeKeyAndOrderFront(nil)
            } else {
                mainPanel.orderFrontRegardless()
            }
            return
        }

        if windows.edgeHandle {
            edgeHandlePanel.alphaValue = 1
            edgeHandlePanel.orderFrontRegardless()
            mainPanel.orderOut(nil)
            mainPanel.alphaValue = 1
            return
        }

        mainPanel.orderOut(nil)
        edgeHandlePanel.orderOut(nil)
        mainPanel.alphaValue = 1
        edgeHandlePanel.alphaValue = 1
    }

    private func reconcilePointerLocation() {
        let location = NSEvent.mouseLocation
        if edgeHandlePanel.isVisible, edgeHandlePanel.frame.contains(location) {
            if !stateMachine.pointerInsideHandle { dispatch(.handlePointerEntered) }
            return
        }
        if mainPanel.isVisible, mainPanel.frame.contains(location) {
            if !stateMachine.pointerInsideMain { dispatch(.mainPointerEntered) }
        } else if stateMachine.pointerInsideMain {
            dispatch(.mainPointerExited)
        }
    }

    private func geometry(for screen: NSScreen) -> DockGeometry {
        DockGeometry(
            visibleFrame: BellRect(screen.visibleFrame),
            verticalFraction: model.settings.dockVerticalFraction
        )
    }

    private func selectedScreen(preferPointer: Bool) -> NSScreen {
        if preferPointer, let screen = NSScreen.screens.first(where: { $0.visibleFrame.contains(NSEvent.mouseLocation) }) {
            return screen
        }
        if let id = model.settings.selectedDisplayID,
           let screen = NSScreen.screens.first(where: { displayID(for: $0) == id }) {
            return screen
        }
        return bestScreen(for: mainPanel.frame)
    }

    private func bestScreen(for frame: NSRect) -> NSScreen {
        NSScreen.screens.max { first, second in
            first.visibleFrame.intersection(frame).area < second.visibleFrame.intersection(frame).area
        } ?? NSScreen.main ?? NSScreen.screens[0]
    }

    private func displayID(for screen: NSScreen) -> String? {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.stringValue
    }

    @objc private func screenConfigurationChanged() {
        let screen = selectedScreen(preferPointer: true)
        model.settings.selectedDisplayID = displayID(for: screen)
        renderWindows(animated: false, bringFront: false)
    }
}

private final class MainPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

private final class EdgeHandlePanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private final class PanelTrackingView: NSView {
    var onPointerEntered: (() -> Void)?
    var onPointerExited: (() -> Void)?
    private var tracking: NSTrackingArea?

    override func updateTrackingAreas() {
        if let tracking { removeTrackingArea(tracking) }
        let next = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(next)
        tracking = next
        super.updateTrackingAreas()
    }

    override func mouseEntered(with event: NSEvent) { onPointerEntered?() }
    override func mouseExited(with event: NSEvent) { onPointerExited?() }
}

private extension BellRect {
    init(_ rect: NSRect) {
        self.init(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height)
    }

    var nsRect: NSRect { NSRect(x: origin.x, y: origin.y, width: width, height: height) }
}

private extension NSRect {
    var area: CGFloat { isNull ? 0 : width * height }
}
#endif
