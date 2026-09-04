import Foundation

public enum AnnouncementPolicy {
    public static func shouldAnnounce(
        task _: TrackedTask,
        kind _: AnnouncementKind,
        settings: BellSettings
    ) -> Bool {
        settings.announcementsEnabled
    }
}
