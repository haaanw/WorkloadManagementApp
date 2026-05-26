import Foundation
import UserNotifications

/// Manages local notification authorization, scheduling, and content for weekly training summaries.
/// Wraps UNUserNotificationCenter -- all notification operations go through this service.
///
/// Localization model (Phase 23 P2):
/// - `scheduleWeeklySummary` builds UNMutableNotificationContent using
///   `.localizedUserNotificationString(forKey:arguments:)` so iOS resolves the title and body
///   at DELIVER time against the current device language, not at schedule time. This is the only
///   way a notification scheduled in English can fire in Chinese after the user flips language
///   (RESEARCH §"Pattern 4 deliver-time localization").
/// - A schema-version migration cancels and reschedules any pre-Phase-23 weekly-summary requests
///   on first launch after this version ships, so legacy English-baked payloads are purged.
@MainActor
final class NotificationService {
    private let center = UNUserNotificationCenter.current()

    /// Bump when the notification content format changes in a way that requires
    /// reissuing pending UNNotificationRequest objects. Phase 23 P2 → version 2.
    /// Tracked under UserDefaults["notificationSchemaVersion"] (see schemaVersionKey).
    private static let currentSchemaVersion = 2
    /// UserDefaults key for the persisted notificationSchemaVersion. Bumping
    /// `currentSchemaVersion` above the stored value triggers `migrateWeeklySummaryIfNeeded()`
    /// to cancel the pending UNNotificationRequest so the next schedule call reissues it.
    private static let schemaVersionKey = "notificationSchemaVersion"

    /// Request notification authorization. Returns true if granted.
    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            print("Notification authorization error: \(error)")
            return false
        }
    }

    /// Check current authorization status from the system (not from @AppStorage).
    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    /// Schedule (or reschedule) the weekly summary notification using deliver-time localization.
    /// Title and body are resolved by iOS from `Localizable.xcstrings` at delivery, so the
    /// notification fires in the device's current language even if scheduling happened months
    /// earlier under a different locale (RESEARCH Pitfall 8).
    /// - Parameters:
    ///   - weekday: 1 = Sunday ... 7 = Saturday (Calendar weekday convention)
    ///   - hour: 0–23
    ///   - minute: 0–59
    ///   - sessionCount: structured arg passed to `notif.weekly.body.template`
    ///   - streak: structured arg
    ///   - prCount: structured arg
    ///   - volumeDelta: % delta from last week; abs value passed as 4th arg
    func scheduleWeeklySummary(
        weekday: Int,
        hour: Int,
        minute: Int,
        sessionCount: Int,
        streak: Int,
        prCount: Int,
        volumeDelta: Double
    ) {
        cancelWeeklySummary()

        let content = UNMutableNotificationContent()
        content.title = NSString.localizedUserNotificationString(
            forKey: "notif.weekly.title",
            arguments: nil
        )
        content.body = NSString.localizedUserNotificationString(
            forKey: "notif.weekly.body.template",
            arguments: [sessionCount, streak, prCount, Int(abs(volumeDelta))]
        )
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.weekday = weekday
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: "weekly-summary",
            content: content,
            trigger: trigger
        )
        center.add(request) { error in
            if let error { print("Notification scheduling error: \(error)") }
        }
    }

    /// Cancel the pending weekly summary notification.
    func cancelWeeklySummary() {
        center.removePendingNotificationRequests(withIdentifiers: ["weekly-summary"])
    }

    // MARK: - Schema migration

    /// Idempotent migration. If the persisted notification schema version is below the current
    /// version, cancel any legacy weekly-summary request so the next scheduleWeeklySummary call
    /// will reissue under the deliver-time-localization format. Stamps UserDefaults with the
    /// current version so subsequent launches no-op.
    /// Safe to call multiple times; second invocation reads version == current and returns.
    func migrateWeeklySummaryIfNeeded() {
        let stored = UserDefaults.standard.integer(forKey: Self.schemaVersionKey)
        guard stored < Self.currentSchemaVersion else { return }
        cancelWeeklySummary()
        UserDefaults.standard.set(Self.currentSchemaVersion, forKey: Self.schemaVersionKey)
    }
}
