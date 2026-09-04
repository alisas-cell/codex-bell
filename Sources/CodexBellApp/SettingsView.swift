#if os(macOS)
import SwiftUI
import CodexBellCore

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @State private var showAdvancedDockOptions = false
    @State private var volumePreviewGesture = VolumePreviewGesture()

    private var copy: LocalizedCopy { model.copy }

    var body: some View {
        TabView {
            general.tabItem { Label(copy[.general], systemImage: "gearshape") }
            dock.tabItem { Label(copy[.dock], systemImage: "rectangle.rightthird.inset.filled") }
            audio.tabItem { Label(copy[.audio], systemImage: "speaker.wave.2") }
            integration.tabItem { Label(copy[.integration], systemImage: "point.3.connected.trianglepath.dotted") }
            privacy.tabItem { Label(copy[.privacy], systemImage: "hand.raised") }
            about.tabItem { Label(copy[.about], systemImage: "info.circle") }
        }
        .frame(minWidth: 610, minHeight: 480)
        .padding(12)
        .tint(BellPalette.purple)
    }

    private var general: some View {
        SettingsForm {
            Section(copy[.general]) {
                Toggle(copy[.launchAtLogin], isOn: $model.settings.launchAtLogin)
                Toggle(copy[.showInDock], isOn: $model.settings.showInDock)
                Toggle(copy[.keepAwakeDetail], isOn: $model.settings.keepAwakeWhileRunning)
                Text(copy[.sleepNote]).settingsNote()
            }
            Section(copy[.history]) {
                LabeledContent(copy[.storedRecentTasks], value: copy.taskCount(model.recentTasks.count))
                Button(copy[.clearHistory], role: .destructive) { model.clearHistory() }
            }
        }
    }

    private var dock: some View {
        SettingsForm {
            Section(copy[.dockAutoHide]) {
                Picker(copy[.dockPosition], selection: $model.settings.dockAnchor) {
                    ForEach(DockAnchor.allCases, id: \.self) { anchor in
                        Text(copy.dockAnchor(anchor)).tag(anchor)
                    }
                }
                .pickerStyle(.segmented)
                Toggle(copy[.autoHidePanel], isOn: $model.settings.autoHideEnabled)
                Toggle(copy[.pinPanel], isOn: $model.settings.panelPinned)
                Toggle(copy[.urgentReveal], isOn: $model.settings.urgentPeekEnabled)
            }
            Section(copy[.advanced]) {
                DisclosureGroup(copy[.timing], isExpanded: $showAdvancedDockOptions) {
                    HStack {
                        Text(copy[.hideDelay])
                        Slider(value: $model.settings.autoHideDelay, in: 0.2...3, step: 0.1)
                        Text(model.settings.autoHideDelay.formatted(.number.precision(.fractionLength(1))) + " " + copy[.seconds])
                            .monospacedDigit()
                            .frame(width: 64, alignment: .trailing)
                    }
                }
            }
        }
    }

    private var audio: some View {
        SettingsForm {
            Section(copy[.audioNotifications]) {
                Toggle(copy[.completionAnnouncements], isOn: $model.settings.announcementsEnabled)
                HStack {
                    Image(systemName: model.settings.volume == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .frame(width: 20)
                        .accessibilityLabel(copy[.volume])
                    BrandVolumeSlider(
                        value: $model.settings.volume,
                        accessibilityLabel: copy[.volume],
                        onEditingChanged: settingsVolumeEditingChanged
                    )
                    .frame(height: 20)
                    Text("\(Int(model.settings.volume * 100))%")
                        .monospacedDigit()
                        .frame(width: 42, alignment: .trailing)
                }
            }
        }
    }

    private var integration: some View {
        SettingsForm {
            Section(copy[.codexIntegration]) {
                LabeledContent(copy[.currentMode], value: copy.integrationMode(model.integrationHealth.mode))
                LabeledContent(copy[.codexHost], value: model.codexGUIHost)
                LabeledContent(copy[.codexVersion], value: model.integrationHealth.codexVersion ?? copy[.unavailable])
                LabeledContent(copy[.controlSocketDetected], value: model.integrationHealth.socketDetected ? copy[.yes] : copy[.no])
                LabeledContent(copy[.hooksInstalled], value: model.integrationHealth.hooksInstalled ? copy[.yes] : copy[.no])
                LabeledContent(copy[.sessionSource], value: model.integrationHealth.sessionLogDetected ? copy[.yes] : copy[.no])
                LabeledContent(copy[.lastEvent], value: lastEventText)
                LabeledContent(copy[.lastEventSource], value: model.lastEventSourceName)
                LabeledContent(copy[.targetAudit], value: model.targetAuditName)
                LabeledContent(copy[.repairResult], value: model.repairResultName)
                LabeledContent(copy[.diagnosticLastError], value: model.lastIntegrationError.map(PrivacySanitizer.sanitize) ?? copy[.none])
                pathRow(copy[.hooksConfigPath], model.hooksConfigPath)
                pathRow(copy[.installedHelperPath], model.installedHelperPath)
                pathRow(copy[.inboxPath], model.inboxDirectory.path)
            }
            Section {
                HStack {
                    Button(copy[.runConnectionTest]) { model.runConnectionTest() }
                    Button(copy[.installRepairHooks]) { model.configureCodex() }
                    Button(copy[.openDiagnostics]) { model.openDiagnostics() }
                }
                Button(copy[.copySanitizedDiagnostics]) { model.copySanitizedDiagnostics() }
                if let message = model.connectionTestMessage {
                    Text(message).foregroundStyle(.secondary).textSelection(.enabled)
                }
                if let error = model.lastIntegrationError {
                    Text(error).foregroundStyle(.red).textSelection(.enabled)
                }
            }
            Section(copy[.removal]) {
                Button(copy[.removeHooks], role: .destructive) { model.uninstallCodexIntegration() }
                Text(copy[.removalNote]).settingsNote()
            }
        }
    }

    private var privacy: some View {
        SettingsForm {
            Section(copy[.privacy]) {
                Label(copy[.localFirst], systemImage: "checkmark.shield")
                Text(copy[.privacyDescription]).settingsNote()
                Text(copy[.diagnosticsDescription]).settingsNote()
            }
        }
    }

    private var about: some View {
        SettingsForm {
            Section(copy.appDisplayName) {
                LabeledContent(copy[.version], value: "1.0.0")
                Text(copy[.appDescription]).settingsNote()
            }
            Section(copy[.project]) {
                Text(copy[.author]).settingsNote()
                Text(copy[.unofficial]).settingsNote()
            }
        }
    }

    private var lastEventText: String {
        guard let date = model.integrationHealth.lastEventAt else { return copy[.never] }
        return date.formatted(date: .abbreviated, time: .standard)
    }

    private func pathRow(_ label: String, _ path: String) -> some View {
        LabeledContent(label) {
            Text(path)
                .font(.system(size: BellTypography.settingsNote, design: .monospaced))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .lineLimit(2)
                .multilineTextAlignment(.trailing)
        }
    }

    private func settingsVolumeEditingChanged(_ editing: Bool) {
        if editing {
            volumePreviewGesture.begin()
        } else if volumePreviewGesture.end() {
            model.scheduleVolumePreview()
        }
    }
}

private struct SettingsForm<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        Form { content }
            .formStyle(.grouped)
            .font(.system(size: BellTypography.settingsBody))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private extension View {
    func settingsNote() -> some View {
        font(.system(size: BellTypography.settingsNote))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
#endif
