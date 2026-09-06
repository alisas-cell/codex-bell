import Foundation

public enum AnnouncementPolicy {
    public static func isSuperseded(_ announcement: Announcement, by task: TrackedTask?) -> Bool {
        guard !announcement.isTest, let task, task.turnID == announcement.turnID else { return false }
        return task.eventGeneration > announcement.generation
    }

    public static func shouldAnnounce(
        task _: TrackedTask,
        kind _: AnnouncementKind,
        settings: BellSettings
    ) -> Bool {
        settings.announcementsEnabled
    }
}
