import Foundation

public struct LocalizedCopy: Sendable, Equatable {
    public enum Key: String, CaseIterable, Sendable {
        case general, dock, audio, integration, privacy, about
        case settings, language, active, waiting, recent, connectionStatus
        case noActivity, completionAlerts, volume
        case connect, testAnnouncement, pin, unpin, collapseToEdge, reveal, quit, ready, running
        case failed, completed, interrupted, previousSession, waitingApproval, waitingInput
        case launchAtLogin, showInDock, keepAwakeDetail, sleepNote, history, storedRecentTasks, clearHistory
        case dockAutoHide, dockPosition, left, right, autoHidePanel, pinPanel
        case urgentReveal, advanced, timing, hideDelay, seconds
        case audioNotifications, completionAnnouncements
        case codexIntegration, currentMode, codexHost, codexVersion, controlSocketDetected, hooksInstalled, lastEvent
        case hooksConfigPath, installedHelperPath, inboxPath, lastEventSource, targetAudit, repairResult, sessionSource
        case unavailable, yes, no, never, runConnectionTest, installRepairHooks, openDiagnostics
        case copySanitizedDiagnostics, removal, removeHooks, removalNote
        case localFirst, privacyDescription, diagnosticsDescription
        case version, appDescription, project, author, unofficial, settingsWindowTitle
        case revealHelp, handleNeedsAttention, languagePickerHelp
        case hooksVerifiedMessage, hooksRemovedMessage, diagnosticsCopiedMessage, operationFailed
        case diagnosticTitle, diagnosticMode, diagnosticSocket, diagnosticHooks, diagnosticLastEvent
        case diagnosticDockAnchor, diagnosticAutoHide, diagnosticPinned, diagnosticActiveTasks
        case diagnosticRecentTasks, diagnosticLastError, none, on, off
    }

    public let language: AppLanguage

    public init(language: AppLanguage) {
        self.language = language
    }

    public var appDisplayName: String {
        language == .zhHans ? "Codex 叮铃铃" : "Codex Bell"
    }

    public subscript(key: Key) -> String {
        let table = language == .zhHans ? Self.chinese : Self.english
        return table[key] ?? key.rawValue
    }

    public func speech(for announcement: Announcement) -> String {
        if announcement.isTest {
            return language == .zhHans ? "Codex 叮铃铃已准备就绪。" : "Codex Bell is ready."
        }
        let name = TaskNameExtractor.sanitizeForSpeech(announcement.identity.spokenName)
        if language == .zhHans {
            switch announcement.kind {
            case .completed: return "\(name) 任务已完成。"
            case .failed: return "\(name) 任务运行失败，请回来查看。"
            case .interrupted: return "\(name) 任务已中断。"
            case .waitingApproval: return "\(name) 正在等待你的操作。"
            case .waitingInput: return "\(name) 有问题需要你确认。"
            }
        }
        switch announcement.kind {
        case .completed: return "\(name) is complete."
        case .failed: return "\(name) failed. Please come back and check."
        case .interrupted: return "\(name) was interrupted."
        case .waitingApproval: return "\(name) is waiting for your approval."
        case .waitingInput: return "\(name) needs your input."
        }
    }

    public func notificationTitle(for announcement: Announcement) -> String {
        let name = announcement.isTest
            ? (language == .zhHans ? "Codex 叮铃铃测试任务" : "Codex Bell test task")
            : TaskNameExtractor.sanitizeForSpeech(announcement.identity.spokenName)
        let state: String
        if language == .zhHans {
            switch announcement.kind {
            case .completed: state = "已完成"
            case .failed: state = "失败"
            case .interrupted: state = "已中断"
            case .waitingApproval: state = "等待批准"
            case .waitingInput: state = "等待输入"
            }
        } else {
            switch announcement.kind {
            case .completed: state = "Completed"
            case .failed: state = "Failed"
            case .interrupted: state = "Interrupted"
            case .waitingApproval: state = "Waiting for Approval"
            case .waitingInput: state = "Waiting for Input"
            }
        }
        return "\(name) · \(state)"
    }

    public func notificationBody(for announcement: Announcement) -> String {
        if language == .zhHans {
            switch announcement.kind {
            case .completed: return "Codex 任务已完成。"
            case .failed: return "Codex 任务运行失败，请回来查看。"
            case .interrupted: return "Codex 任务已中断。"
            case .waitingApproval: return "Codex 正在等待你的批准。"
            case .waitingInput: return "Codex 正在等待你的输入。"
            }
        }
        switch announcement.kind {
        case .completed: return "Codex task completed."
        case .failed: return "Codex task failed. Please come back and check."
        case .interrupted: return "Codex task was interrupted."
        case .waitingApproval: return "Codex is waiting for approval."
        case .waitingInput: return "Codex is waiting for your input."
        }
    }

    public func taskState(_ state: TaskState) -> String {
        switch state {
        case .running: return self[.running]
        case .waitingApproval: return self[.waitingApproval]
        case .waitingInput: return self[.waitingInput]
        case .completed: return self[.completed]
        case .failed: return self[.failed]
        case .interrupted: return self[.interrupted]
        case .unknownFinished: return self[.previousSession]
        }
    }

    public func dockAnchor(_ anchor: DockAnchor) -> String {
        switch anchor {
        case .left: return self[.left]
        case .right: return self[.right]
        }
    }

    public func integrationMode(_ mode: IntegrationMode) -> String {
        if language == .zhHans {
            switch mode {
            case .appServerLive: return "实时 · App Server"
            case .codexSessionLive: return "实时 · Codex"
            case .hooksLive: return "实时 · Hooks"
            case .installedWaiting: return "已安装 · 等待事件"
            case .problem: return "连接异常"
            case .notInstalled: return "未安装"
            case .legacyOnly: return "兼容模式"
            }
        }
        return mode.displayName
    }

    public func integrationSummary(_ health: IntegrationHealth, now: Date) -> String {
        switch health.mode {
        case .appServerLive, .codexSessionLive, .hooksLive:
            let source: String
            switch health.mode {
            case .appServerLive: source = "App Server"
            case .hooksLive: source = "Hooks"
            default: source = "Codex"
            }
            let age = max(0, Int(now.timeIntervalSince(health.lastEventAt ?? now)))
            if language == .zhHans {
                if age < 10 { return "实时 · \(source) · 刚刚" }
                if age < 60 { return "实时 · \(source) · \(age) 秒前" }
                return "实时 · \(source) · \(age / 60) 分钟前"
            }
            if age < 10 { return "Live · \(source) · just now" }
            if age < 60 { return "Live · \(source) · \(age)s ago" }
            return "Live · \(source) · \(age / 60)m ago"
        case .installedWaiting:
            if language == .zhHans {
                return health.sessionLogDetected ? "Codex 已检测 · 等待事件" : "Hooks 已安装 · 等待事件"
            }
            return health.sessionLogDetected ? "Codex detected · Waiting for event" : "Hooks installed · Waiting for event"
        case .problem:
            return language == .zhHans ? "Codex 连接异常" : "Codex integration problem"
        case .notInstalled:
            return language == .zhHans ? "Codex 连接未安装" : "Codex integration not installed"
        case .legacyOnly:
            return language == .zhHans ? "仅完成事件 · 兼容模式" : "Completion only · Legacy notify"
        }
    }

    public func statusSummary(runningCount: Int, waitingCount: Int) -> String {
        if language == .zhHans {
            if waitingCount > 0 { return "\(runningCount) 个运行中 · \(waitingCount) 个等待你" }
            if runningCount > 0 { return "\(runningCount) 个任务正在运行" }
            return self[.ready]
        }
        if waitingCount > 0 { return "\(runningCount) running · \(waitingCount) waiting" }
        if runningCount > 0 { return "\(runningCount) task\(runningCount == 1 ? "" : "s") running" }
        return self[.ready]
    }

    public func activeSectionTitle(_ count: Int) -> String {
        language == .zhHans ? "正在运行 · \(count)" : "Active · \(count)"
    }

    public func activeDisclosureTitle(_ hiddenCount: Int) -> String {
        language == .zhHans ? "还有 \(hiddenCount) 个正在运行" : "\(hiddenCount) more active"
    }

    public var activeCollapseTitle: String {
        language == .zhHans ? "收起" : "Show less"
    }

    public func taskCount(_ count: Int) -> String {
        language == .zhHans ? "\(count) 个" : "\(count)"
    }

    private static let english: [Key: String] = [
        .general: "General", .dock: "Dock", .audio: "Audio", .integration: "Integration", .privacy: "Privacy", .about: "About",
        .settings: "Settings", .language: "Language", .active: "Active", .waiting: "Waiting", .recent: "Recent", .connectionStatus: "Connection Status",
        .noActivity: "No Codex activity yet", .completionAlerts: "Enable Voice Announcements", .volume: "Announcement Volume",
        .connect: "Connect", .testAnnouncement: "Test Announcement",
        .pin: "Pin Panel", .unpin: "Unpin Panel", .collapseToEdge: "Collapse to Edge", .reveal: "Reveal Codex Bell", .quit: "Quit Codex Bell",
        .ready: "Ready", .running: "Running", .failed: "Failed", .completed: "Completed", .interrupted: "Interrupted",
        .previousSession: "Previous Session", .waitingApproval: "Waiting for Approval", .waitingInput: "Waiting for Input",
        .launchAtLogin: "Launch Codex Bell at Login", .showInDock: "Show Codex Bell in Dock", .keepAwakeDetail: "Keep Mac awake while tasks are running",
        .sleepNote: "The screen may still turn off. Normal sleep behavior resumes when no task is running.", .history: "History",
        .storedRecentTasks: "Stored Recent Tasks", .clearHistory: "Clear History", .dockAutoHide: "Dock & Auto-Hide", .dockPosition: "Dock Position",
        .left: "Left", .right: "Right", .autoHidePanel: "Auto-hide Panel", .pinPanel: "Pin Panel",
        .urgentReveal: "Reveal briefly for waiting or failure", .advanced: "Advanced", .timing: "Timing", .hideDelay: "Hide Delay", .seconds: "sec",
        .audioNotifications: "Audio & Notifications", .completionAnnouncements: "Enable Voice Announcements",
        .codexIntegration: "Codex Integration", .currentMode: "Current Mode", .codexHost: "Codex GUI Host", .codexVersion: "Codex Version", .controlSocketDetected: "Control Socket Detected",
        .hooksInstalled: "Hooks Installed", .lastEvent: "Last Event", .unavailable: "Unavailable", .yes: "Yes", .no: "No", .never: "Never",
        .hooksConfigPath: "Hooks Config Path", .installedHelperPath: "Installed Bell Helper", .inboxPath: "Current Inbox", .lastEventSource: "Last Event Source",
        .targetAudit: "Target Audit", .repairResult: "Repair Result", .sessionSource: "Codex Session Source",
        .runConnectionTest: "Run Connection Test", .installRepairHooks: "Install / Repair Hooks", .openDiagnostics: "Open Diagnostics",
        .copySanitizedDiagnostics: "Copy Redacted Diagnostics", .removal: "Removal", .removeHooks: "Remove Codex Bell Hooks",
        .removalNote: "Only Codex Bell hook entries are removed. Unrelated Codex settings are preserved.",
        .localFirst: "Local-first Event Processing", .privacyDescription: "Codex Bell stores only task identifiers, short labels, states, timestamps, and durations. It does not keep full prompts, assistant replies, source code, URLs, tokens, or transcripts in history.",
        .diagnosticsDescription: "Diagnostics redact paths and secret-like values by default.", .version: "Version",
        .appDescription: "A native macOS edge companion for Codex task state and completion announcements.", .project: "Project",
        .author: "Author: 森虫虫进化中 (same handle across platforms)",
        .unofficial: "Unofficial community project. Not affiliated with or endorsed by OpenAI.", .settingsWindowTitle: "Codex Bell Settings",
        .revealHelp: "Reveal Codex Bell", .handleNeedsAttention: "Codex Bell needs attention", .languagePickerHelp: "Choose App Language",
        .hooksVerifiedMessage: "Helper verified. Waiting for an actual Codex event before showing Live.",
        .hooksRemovedMessage: "Codex Bell hook entries were removed. Unrelated Codex configuration was preserved.",
        .diagnosticsCopiedMessage: "Sanitized diagnostics copied.", .operationFailed: "The operation failed. Review Diagnostics and try again.",
        .diagnosticTitle: "Codex Bell Diagnostics", .diagnosticMode: "Mode", .diagnosticSocket: "App Server Control Socket Detected",
        .diagnosticHooks: "Hooks Installed for Codex Bell", .diagnosticLastEvent: "Last Verified Event", .diagnosticDockAnchor: "Dock Anchor",
        .diagnosticAutoHide: "Auto-hide", .diagnosticPinned: "Pinned", .diagnosticActiveTasks: "Active Task Count",
        .diagnosticRecentTasks: "Recent Task Count", .diagnosticLastError: "Last Sanitized Error", .none: "None", .on: "On", .off: "Off"
    ]

    private static let chinese: [Key: String] = [
        .general: "通用", .dock: "停靠", .audio: "音频", .integration: "连接", .privacy: "隐私", .about: "关于",
        .settings: "设置", .language: "语言", .active: "正在运行", .waiting: "等待你", .recent: "最近完成", .connectionStatus: "连接状态",
        .noActivity: "暂无 Codex 活动", .completionAlerts: "开启语音播报", .volume: "播报音量",
        .connect: "连接", .testAnnouncement: "测试播报",
        .pin: "固定", .unpin: "取消固定", .collapseToEdge: "收起到边缘", .reveal: "显示 Codex 叮铃铃", .quit: "退出 Codex 叮铃铃",
        .ready: "准备就绪", .running: "正在运行", .failed: "失败", .completed: "已完成", .interrupted: "已中断",
        .previousSession: "上次会话", .waitingApproval: "等待批准", .waitingInput: "等待输入",
        .launchAtLogin: "开机自动启动 Codex Bell", .showInDock: "在程序坞中显示图标", .keepAwakeDetail: "任务运行时保持 Mac 唤醒",
        .sleepNote: "屏幕仍可关闭；没有任务运行时会恢复正常睡眠行为。", .history: "历史记录",
        .storedRecentTasks: "已存储的最近任务", .clearHistory: "清除历史", .dockAutoHide: "停靠与自动隐藏", .dockPosition: "停靠位置",
        .left: "左侧", .right: "右侧", .autoHidePanel: "自动隐藏面板", .pinPanel: "固定面板",
        .urgentReveal: "等待或失败时短暂提示", .advanced: "高级", .timing: "计时", .hideDelay: "隐藏延迟", .seconds: "秒",
        .audioNotifications: "音频与通知", .completionAnnouncements: "开启语音播报",
        .codexIntegration: "Codex 连接", .currentMode: "当前模式", .codexHost: "Codex GUI 宿主", .codexVersion: "Codex 版本", .controlSocketDetected: "检测到控制套接字",
        .hooksInstalled: "Hooks 已安装", .lastEvent: "最近事件", .unavailable: "不可用", .yes: "是", .no: "否", .never: "从未",
        .hooksConfigPath: "Hooks 配置路径", .installedHelperPath: "已安装的 Bell 辅助程序", .inboxPath: "当前 Inbox", .lastEventSource: "最近事件来源",
        .targetAudit: "目标审计", .repairResult: "修复结果", .sessionSource: "Codex 会话来源",
        .runConnectionTest: "运行连接测试", .installRepairHooks: "安装 / 修复 Codex 连接", .openDiagnostics: "打开诊断信息",
        .copySanitizedDiagnostics: "复制脱敏诊断信息", .removal: "删除连接", .removeHooks: "删除 Codex Bell 连接",
        .removalNote: "只会删除 Codex Bell 的连接项；其他 Codex 设置将保留。",
        .localFirst: "本地优先的事件处理", .privacyDescription: "Codex Bell 只存储任务标识、短标签、状态、时间戳和时长，不会在历史记录中保存完整提示词、回复、源代码、网址、令牌或对话记录。",
        .diagnosticsDescription: "诊断信息默认会隐藏路径和类似密钥的内容。", .version: "版本",
        .appDescription: "用于查看 Codex 任务状态和完成播报的原生 macOS 边缘伴侣。", .project: "项目",
        .author: "作者：森虫虫进化中（全网同名）",
        .unofficial: "非官方社区项目，与 OpenAI 无隶属或认可关系。", .settingsWindowTitle: "Codex 叮铃铃设置",
        .revealHelp: "显示 Codex 叮铃铃", .handleNeedsAttention: "Codex 叮铃铃需要你处理", .languagePickerHelp: "选择应用语言",
        .hooksVerifiedMessage: "辅助程序已验证；收到当前 Codex 的真实事件后才会显示实时。",
        .hooksRemovedMessage: "Codex Bell 连接项已删除，其他 Codex 配置已保留。",
        .diagnosticsCopiedMessage: "已复制脱敏诊断信息。", .operationFailed: "操作失败。请查看诊断信息后重试。",
        .diagnosticTitle: "Codex Bell 诊断信息", .diagnosticMode: "模式", .diagnosticSocket: "检测到 App Server 控制套接字",
        .diagnosticHooks: "Codex Bell Hooks 已安装", .diagnosticLastEvent: "最近验证事件", .diagnosticDockAnchor: "停靠位置",
        .diagnosticAutoHide: "自动隐藏", .diagnosticPinned: "固定", .diagnosticActiveTasks: "活跃任务数",
        .diagnosticRecentTasks: "最近任务数", .diagnosticLastError: "最近脱敏错误", .none: "无", .on: "开启", .off: "关闭"
    ]
}
