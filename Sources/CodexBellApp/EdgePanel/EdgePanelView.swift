#if os(macOS)
import AppKit
import SwiftUI
import CodexBellCore

struct EdgePanelView: View {
    @ObservedObject var model: AppModel
    let anchor: DockAnchor
    let onPinChanged: (Bool) -> Void
    let onCollapseToEdge: () -> Void
    let onDragStarted: () -> Void
    let onDragEnded: () -> Void
    let onInteractionActive: (PanelInteractionLock, Bool) -> Void
    let onOpenSettings: () -> Void
    @State private var volumePreviewGesture = VolumePreviewGesture()
    @State private var isActiveExpanded = false

    private var copy: LocalizedCopy { model.copy }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 10)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    tasks
                    Divider()
                    controls
                }
                .padding(14)
            }
            .frame(maxHeight: .infinity)

            Divider()

            footer
                .padding(.horizontal, 14)
                .padding(.top, 10)
                .padding(.bottom, 13)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.10), lineWidth: 0.5)
        }
        .tint(BellPalette.purple)
    }

    private var header: some View {
        HStack(spacing: 9) {
            Image(systemName: "bell.and.waves.left.and.right.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(BellPalette.purple)

            VStack(alignment: .leading, spacing: 1) {
                Text(copy.appDisplayName)
                    .font(.system(size: BellTypography.brand, weight: .semibold))
                Text(copy.statusSummary(runningCount: model.runningCount, waitingCount: model.waitingCount))
                    .font(.system(size: BellTypography.taskSecondary))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            Circle()
                .fill(overallStatusColor)
                .frame(width: 7, height: 7)
                .accessibilityLabel(copy.statusSummary(runningCount: model.runningCount, waitingCount: model.waitingCount))

            Button(action: onCollapseToEdge) {
                ZStack {
                    Circle().fill(BellPalette.yellow)
                    Image(systemName: "minus")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(Color.black.opacity(0.64))
                }
                .frame(width: 13, height: 13)
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .help(copy[.collapseToEdge])
            .accessibilityLabel(copy[.collapseToEdge])

            Button {
                interact(.control) {
                    let next = !model.settings.panelPinned
                    model.settings.panelPinned = next
                    onPinChanged(next)
                }
            } label: {
                Image(systemName: model.settings.panelPinned ? "pin.fill" : "pin")
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(model.settings.panelPinned ? copy[.unpin] : copy[.pin])
        }
        .overlay {
            WindowDragRegion(onDragStarted: onDragStarted, onDragEnded: onDragEnded)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.trailing, 82)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder private var tasks: some View {
        let active = TaskPresentationPolicy.active(model.activeTasks, expanded: isActiveExpanded)
        let recent = TaskPresentationPolicy.recent(model.recentTasks)
        if active.totalCount == 0 && recent.isEmpty {
            VStack(spacing: 7) {
                Image(systemName: "bell.slash")
                    .font(.system(size: 20))
                    .foregroundStyle(.tertiary)
                Text(copy[.noActivity])
                    .font(.system(size: BellTypography.emptyState))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
        } else {
            if active.totalCount > 0 {
                sectionLabel(copy.activeSectionTitle(active.totalCount))
                if isActiveExpanded {
                    ScrollView(.vertical) {
                        VStack(spacing: 2) {
                            ForEach(active.visibleTasks) { BellTaskRow(task: $0, copy: copy) }
                        }
                    }
                    .frame(maxHeight: 260)
                    .scrollIndicators(.automatic)
                } else {
                    VStack(spacing: 2) {
                        ForEach(active.visibleTasks) { BellTaskRow(task: $0, copy: copy) }
                    }
                }
                if active.isDisclosureNeeded {
                    Button {
                        interact(.control) { isActiveExpanded.toggle() }
                    } label: {
                        HStack(spacing: 5) {
                            Text(isActiveExpanded ? copy.activeCollapseTitle : copy.activeDisclosureTitle(active.hiddenCount))
                            Image(systemName: isActiveExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 8, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: BellTypography.disclosure, weight: .medium))
                    .foregroundStyle(BellPalette.purple)
                    .padding(.top, 3)
                }
            }
            if !recent.isEmpty {
                sectionLabel(copy[.recent])
                    .padding(.top, active.totalCount == 0 ? 0 : 8)
                VStack(spacing: 2) {
                    ForEach(recent) { BellTaskRow(task: $0, copy: copy) }
                }
            }
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: BellTypography.sectionHeader, weight: .semibold))
            .foregroundStyle(.tertiary)
    }

    private var controls: some View {
        VStack(spacing: 11) {
            controlToggle(copy[.completionAlerts], isOn: $model.settings.announcementsEnabled)

            if model.settings.announcementsEnabled {
                HStack(spacing: 8) {
                    Image(systemName: model.settings.volume == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .foregroundStyle(.secondary)
                        .frame(width: 16)
                        .accessibilityLabel(copy[.volume])
                    BrandVolumeSlider(
                        value: $model.settings.volume,
                        accessibilityLabel: copy[.volume],
                        onEditingChanged: volumeEditingChanged
                    )
                    .frame(height: 18)
                    Text("\(Int(model.settings.volume * 100))%")
                        .font(.system(size: BellTypography.metadata, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 32, alignment: .trailing)
                }
            }

        }
        .font(.system(size: BellTypography.control))
    }

    private func controlToggle(_ title: String, isOn: Binding<Bool>) -> some View {
        BrandToggle(title: title, isOn: Binding(
            get: { isOn.wrappedValue },
            set: { value in interact(.control) { isOn.wrappedValue = value } }
        ))
    }

    private var footer: some View {
        VStack(spacing: 13) {
            HStack(spacing: 7) {
                Circle().fill(integrationColor).frame(width: 7, height: 7)
                TimelineView(.periodic(from: .now, by: 10)) { timeline in
                    Text(model.integrationStatus(at: timeline.date))
                        .font(.system(size: BellTypography.footer, weight: .medium))
                        .lineLimit(1)
                }
                Spacer()
                if model.integrationHealth.mode.shouldOfferRepair {
                    Button(copy[.connect]) { interact(.control) { model.configureCodex() } }
                        .buttonStyle(.plain)
                        .foregroundStyle(BellPalette.purple)
                }
            }

            BrandLanguageControl(
                selection: Binding(get: { model.language }, set: { model.setLanguage($0) }),
                accessibilityLabel: copy[.languagePickerHelp],
                onSelect: { language in
                    interact(.languagePicker) { model.setLanguage(language) }
                }
            )
            .frame(width: 154, height: 27)
            .frame(maxWidth: .infinity)

            Button(action: onOpenSettings) {
                Label(copy[.settings], systemImage: "gearshape")
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .font(.system(size: BellTypography.footer))
    }

    private var overallStatusColor: Color {
        if model.waitingCount > 0 { return .orange }
        if model.runningCount > 0 { return .blue }
        return .secondary.opacity(0.55)
    }

    private var integrationColor: Color {
        switch model.integrationHealth.mode {
        case .appServerLive, .codexSessionLive, .hooksLive: return .green
        case .installedWaiting, .legacyOnly: return .orange
        case .problem, .notInstalled: return .red
        }
    }

    private func interact(_ lock: PanelInteractionLock, _ action: () -> Void) {
        onInteractionActive(lock, true)
        action()
        DispatchQueue.main.async { onInteractionActive(lock, false) }
    }

    private func volumeEditingChanged(_ editing: Bool) {
        if editing {
            volumePreviewGesture.begin()
            onInteractionActive(.control, true)
        } else {
            onInteractionActive(.control, false)
            if volumePreviewGesture.end() { model.scheduleVolumePreview() }
        }
    }
}

private extension IntegrationMode {
    var isLive: Bool { self == .appServerLive || self == .codexSessionLive || self == .hooksLive }

    var shouldOfferRepair: Bool {
        switch self {
        case .problem, .notInstalled, .legacyOnly: return true
        case .appServerLive, .codexSessionLive, .hooksLive, .installedWaiting: return false
        }
    }
}

struct EdgeHandleView: View {
    @ObservedObject var model: AppModel
    let anchor: DockAnchor
    let isUrgent: Bool
    let onReveal: () -> Void

    private var status: HandleStatus { isUrgent ? .failed : model.handleStatus }

    var body: some View {
        Button(action: onReveal) {
            VStack(spacing: 8) {
                Image(systemName: "bell.fill")
                statusMark
            }
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(BellPalette.purple.opacity(0.94), in: handleShape)
            .overlay { handleShape.strokeBorder(Color.white.opacity(0.22), lineWidth: 0.5) }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(model.copy[.revealHelp])
        .accessibilityLabel(isUrgent ? model.copy[.handleNeedsAttention] : model.copy[.revealHelp])
    }

    @ViewBuilder private var statusMark: some View {
        switch status {
        case .completed:
            Image(systemName: "checkmark")
                .font(.system(size: 8, weight: .bold))
        case .failed:
            Image(systemName: "exclamationmark")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white)
        case .running, .waiting, .idle:
            Circle().fill(statusColor).frame(width: 7, height: 7)
        }
    }

    private var statusColor: Color {
        switch status {
        case .running: return .blue
        case .waiting: return .orange
        case .failed: return .red
        case .completed: return .green
        case .idle: return Color.white.opacity(0.62)
        }
    }

    private var handleShape: UnevenRoundedRectangle {
        switch anchor {
        case .left:
            return UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 0, bottomTrailingRadius: 12, topTrailingRadius: 12, style: .continuous)
        case .right:
            return UnevenRoundedRectangle(topLeadingRadius: 12, bottomLeadingRadius: 12, bottomTrailingRadius: 0, topTrailingRadius: 0, style: .continuous)
        }
    }
}

struct BellTaskRow: View {
    let task: TrackedTask
    let copy: LocalizedCopy

    var body: some View {
        HStack(spacing: 9) {
            Circle().fill(statusColor).frame(width: 7, height: 7)
            VStack(alignment: .leading, spacing: 1) {
                Text(task.projectName)
                    .font(.system(size: BellTypography.taskPrimary, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(task.taskName ?? copy.taskState(task.state))
                    .font(.system(size: BellTypography.taskSecondary))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if task.state == .running {
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    Text(durationText(Date().timeIntervalSince(task.startedAt)))
                }
                .font(.system(size: BellTypography.metadata, design: .monospaced))
                .foregroundStyle(.secondary)
            } else {
                Image(systemName: statusSymbol)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(statusColor)
            }
        }
        .padding(.vertical, 5)
    }

    private var statusColor: Color {
        switch task.state {
        case .running: return .blue
        case .waitingApproval, .waitingInput: return .orange
        case .failed: return .red
        case .completed, .interrupted, .unknownFinished: return .secondary
        }
    }

    private var statusSymbol: String {
        switch task.state {
        case .waitingApproval, .waitingInput: return "pause.circle.fill"
        case .completed: return "checkmark"
        case .failed: return "xmark"
        case .interrupted: return "stop.fill"
        case .unknownFinished: return "minus"
        case .running: return "circle.fill"
        }
    }

    private func durationText(_ duration: TimeInterval) -> String {
        let total = max(0, Int(duration))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}

struct BrandToggle: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Button { isOn.toggle() } label: {
            HStack {
                Text(title)
                Spacer()
                ZStack(alignment: isOn ? .trailing : .leading) {
                    Capsule().fill(isOn ? BellPalette.purple : BellPalette.controlTrack)
                    Circle()
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.18), radius: 1, y: 0.5)
                        .padding(2)
                }
                .frame(width: 31, height: 18)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(isOn ? "On" : "Off")
    }
}

struct BrandVolumeSlider: View {
    @Binding var value: Double
    let accessibilityLabel: String
    let onEditingChanged: (Bool) -> Void
    @State private var isDragging = false

    var body: some View {
        GeometryReader { proxy in
            let width = max(1, proxy.size.width)
            let thumb = 14.0
            let x = min(max(value, 0), 1) * max(0, width - thumb) + thumb / 2
            ZStack(alignment: .leading) {
                Capsule().fill(BellPalette.controlTrack).frame(height: 4)
                Capsule().fill(BellPalette.purple).frame(width: max(2, x), height: 4)
                Circle()
                    .fill(BellPalette.purple)
                    .frame(width: thumb, height: thumb)
                    .shadow(color: .black.opacity(0.18), radius: 1.5, y: 0.5)
                    .position(x: x, y: proxy.size.height / 2)
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { change in
                        if !isDragging {
                            isDragging = true
                            onEditingChanged(true)
                        }
                        value = min(max((change.location.x - thumb / 2) / max(1, width - thumb), 0), 1)
                    }
                    .onEnded { change in
                        value = min(max((change.location.x - thumb / 2) / max(1, width - thumb), 0), 1)
                        isDragging = false
                        onEditingChanged(false)
                    }
            )
        }
        .accessibilityElement()
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue("\(Int(value * 100)) percent")
        .accessibilityAdjustableAction { direction in
            onEditingChanged(true)
            switch direction {
            case .increment: value = min(1, value + 0.05)
            case .decrement: value = max(0, value - 0.05)
            @unknown default: break
            }
            onEditingChanged(false)
        }
    }
}

struct BrandLanguageControl: View {
    @Binding var selection: AppLanguage
    let accessibilityLabel: String
    let onSelect: (AppLanguage) -> Void

    var body: some View {
        HStack(spacing: 3) {
            ForEach(AppLanguage.allCases, id: \.self) { language in
                Button { onSelect(language) } label: {
                    Text(language.selectionName)
                        .font(.system(size: BellTypography.language, weight: selection == language ? .semibold : .regular))
                        .foregroundStyle(selection == language ? Color.black.opacity(0.78) : Color.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(selection == language ? BellPalette.yellow : Color.clear, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(accessibilityLabel): \(language.selectionName)")
                .accessibilityAddTraits(selection == language ? .isSelected : [])
            }
        }
        .padding(3)
        .background(Color.primary.opacity(0.07), in: Capsule())
    }
}

private struct WindowDragRegion: NSViewRepresentable {
    let onDragStarted: () -> Void
    let onDragEnded: () -> Void

    func makeNSView(context: Context) -> DragRegionView {
        let view = DragRegionView()
        view.onDragStarted = onDragStarted
        view.onDragEnded = onDragEnded
        return view
    }

    func updateNSView(_ view: DragRegionView, context: Context) {
        view.onDragStarted = onDragStarted
        view.onDragEnded = onDragEnded
    }
}

private final class DragRegionView: NSView {
    var onDragStarted: (() -> Void)?
    var onDragEnded: (() -> Void)?

    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        onDragStarted?()
        window.performDrag(with: event)
        onDragEnded?()
    }
}
#endif
