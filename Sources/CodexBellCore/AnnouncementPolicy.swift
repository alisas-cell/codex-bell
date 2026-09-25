import Foundation

public enum AnnouncementPolicy {
    public static func isSuperseded(_ announcement: Announcement, by task: TrackedTask?, isDismissed: Bool = false) -> Bool {
        guard !announcement.isTest else { return false }
        if isDismissed { return true }
        guard let task, task.turnID == announcement.turnID else { return false }
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
