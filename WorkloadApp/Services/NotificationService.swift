import Foundation
import UserNotifications

/// Manages local notification authorization, scheduling, and content for weekly training summaries.
/// Wraps UNUserNotificationCenter -- all notification operations go through this service.
@MainActor
final class NotificationService {
    private let center = UNUserNotificationCenter.current()

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

    /// Schedule (or reschedule) the weekly summary notification.
    /// Cancels any existing weekly-summary request first, then schedules a new one.
    /// - Parameters:
    ///   - weekday: 1 = Sunday, 2 = Monday, ... 7 = Saturday (per Calendar weekday convention)
    ///   - hour: Hour in 24h format (0-23). Default 19 per D-04.
    ///   - minute: Minute (0-59). Default 0 per D-04.
    ///   - body: Notification body text built from weekly summary data.
    func scheduleWeeklySummary(weekday: Int, hour: Int, minute: Int, body: String) {
        // Cancel existing first
        cancelWeeklySummary()

        let content = UNMutableNotificationContent()
        content.title = "Your Week in Review"
        content.body = body
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

    // MARK: - Content Builder

    /// Build notification body text from weekly summary data.
    /// Per D-06: include sessions, streak, PRs, and volume delta without being noisy.
    static func buildNotificationBody(
        sessionCount: Int,
        streak: Int,
        prCount: Int,
        volumeDelta: Double
    ) -> String {
        guard sessionCount > 0 else {
            return "0 sessions this week. Log a session to keep your streak alive."
        }

        var parts: [String] = []

        // Sessions + streak
        var sessionPart = "\(sessionCount) session\(sessionCount == 1 ? "" : "s") logged"
        if streak >= 1 { sessionPart += " — \(streak) week streak" }
        parts.append(sessionPart + ".")

        // PRs
        if prCount > 0 {
            parts.append("\(prCount) new PR\(prCount == 1 ? "" : "s")!")
        } else {
            parts.append("No new PRs.")
        }

        // Volume delta
        if abs(volumeDelta) >= 1 {
            let direction = volumeDelta > 0 ? "up" : "down"
            parts.append("Volume \(direction) \(Int(abs(volumeDelta)))% from last week.")
        }

        return parts.joined(separator: " ")
    }
}
