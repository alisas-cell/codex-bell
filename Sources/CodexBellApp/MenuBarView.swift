#if os(macOS)
import AppKit
import SwiftUI
import CodexBellCore

struct MenuBarView: View {
    @ObservedObject var model: AppModel
    let onReveal: () -> Void
    let onSettings: () -> Void

    private var copy: LocalizedCopy { model.copy }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 9) {
                Image(systemName: "bell.and.waves.left.and.right.fill")
                    .foregroundStyle(BellPalette.purple)
                VStack(alignment: .leading, spacing: 1) {
                    Text(copy.appDisplayName).font(.system(size: 13, weight: .semibold))
                    Text(statusSummary).font(.system(size: 10.5)).foregroundStyle(.secondary)
                }
                Spacer()
                Circle().fill(statusColor).frame(width: 7, height: 7)
            }
            .padding(14)

            Divider()

            if let task = model.activeTasks.first {
                BellTaskRow(task: task, copy: copy)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                Divider()
            }

            VStack(alignment: .leading, spacing: 11) {
                Button(action: onReveal) {
                    Label(copy[.reveal], systemImage: "rectangle.rightthird.inset.filled")
                }
                Button { model.testAnnouncement() } label: {
                    Label(copy[.testAnnouncement], systemImage: "play.fill")
                }
                Button(action: onSettings) {
                    Label(copy[.settings], systemImage: "gearshape")
                }
                Divider()
                Button { NSApplication.shared.terminate(nil) } label: {
                    Label(copy[.quit], systemImage: "power")
                }
            }
            .buttonStyle(.plain)
            .font(.system(size: 12))
            .padding(14)
        }
        .frame(width: 270)
        .background(.ultraThinMaterial)
        .tint(BellPalette.purple)
    }

    private var statusSummary: String {
        if model.waitingCount > 0 || model.runningCount > 0 {
            return copy.statusSummary(runningCount: model.runningCount, waitingCount: model.waitingCount)
        }
        return model.integrationStatus
    }

    private var statusColor: Color {
        if model.waitingCount > 0 { return .orange }
        if model.runningCount > 0 { return .blue }
        switch model.integrationHealth.mode {
        case .appServerLive, .codexSessionLive, .hooksLive: return .green
        case .installedWaiting, .legacyOnly: return .orange
        case .problem, .notInstalled: return .red
        }
    }
}
#endif
