#if os(macOS)
import Foundation
import UserNotifications
import CodexBellCore

final class SystemNotifier: @unchecked Sendable {
    func requestAuthorization() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    }

    func post(_ announcement: Announcement, language: AppLanguage) async {
        let copy = LocalizedCopy(language: language)
        let content = UNMutableNotificationContent()
        content.title = copy.notificationTitle(for: announcement)
        content.body = copy.notificationBody(for: announcement)
        let request = UNNotificationRequest(identifier: announcement.id, content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }
}
#endif
