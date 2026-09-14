import Foundation
import SwiftData
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
    /// v1.7.3 UAT round 2 (U12) → version 3: the body's `%lld` specifiers became `%@` and
    /// the request gained a `route` in its userInfo, so every pending legacy request — the
    /// ones printing raw `$lld` on live 1.7.2 — must be cancelled and reissued.
    /// Tracked under UserDefaults["notificationSchemaVersion"] (see schemaVersionKey).
    static let currentSchemaVersion = 3

    /// The `userInfo["route"]` value carried by the weekly-review request. A tap has to
    /// land on the thing the notification is about; without this the tap was a plain launch
    /// to Today and the "weekly review page" could not be found anywhere (U12).
    static let weeklySummaryRoute = "weeklySummary"
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
        // U12: `localizedUserNotificationString(forKey:arguments:)` archives its arguments as
        // OBJECTS and substitutes `%@` only — a `%1$lld` in the catalog value consumed the
        // positional prefix and shipped the residual "$lld" verbatim, character for character
        // what the device showed. The catalog now says `%1$@…%4$@` and the arguments arrive
        // pre-formatted as strings.
        content.body = NSString.localizedUserNotificationString(
            forKey: "notif.weekly.body.template",
            arguments: [
                String(sessionCount),
                String(streak),
                String(prCount),
                String(Int(abs(volumeDelta)))
            ]
        )
        content.sound = .default
        content.userInfo = ["route": Self.weeklySummaryRoute]

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

// MARK: - Tap routing (U12)

/// Turns a notification tap into a destination. Without one, tapping the weekly review
/// launched the app to Today and left the athlete hunting for a page that was scrolled off
/// the bottom of the screen.
///
/// The delegate must exist before the app finishes launching (a tap on a cold launch is
/// delivered immediately), but the `TabRouter` only exists once a scene builds a shell — so
/// a route that arrives first is BUFFERED and applied on attach rather than dropped.
@MainActor
final class NotificationRouteDelegate: NSObject, UNUserNotificationCenterDelegate {

    static let shared = NotificationRouteDelegate()

    private weak var router: TabRouter?
    private var bufferedRoute: String?

    /// Install as the notification-center delegate. Idempotent.
    static func install() {
        UNUserNotificationCenter.current().delegate = shared
    }

    /// Hand the live shell router over; flushes any route that arrived before it existed.
    func attach(router: TabRouter) {
        self.router = router
        if let bufferedRoute {
            self.bufferedRoute = nil
            apply(bufferedRoute)
        }
    }

    /// Record a route for the surface that owns it. Exposed for tests and for the
    /// delegate callback below.
    func apply(_ route: String) {
        guard let router else {
            bufferedRoute = route
            return
        }
        guard route == NotificationService.weeklySummaryRoute else { return }
        router.selection = .home
        router.pendingAnchor = route
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // Read the route off the payload BEFORE hopping actors — `userInfo` is not Sendable,
        // a String is.
        let route = response.notification.request.content.userInfo["route"] as? String
        Task { @MainActor in
            if let route { NotificationRouteDelegate.shared.apply(route) }
            completionHandler()
        }
    }
}

// MARK: - Weekly numbers (U12 freshness)

/// The four numbers the weekly-review body states, read from the store at SCHEDULE time.
///
/// The trigger repeats forever, so whatever is passed here is what the notification says
/// every week until something reschedules it. Both scheduling surfaces used to pass zeros,
/// which is how a body reading "0 sessions logged — 0 week streak" became possible.
struct WeeklyNotificationNumbers {
    var sessionCount: Int = 0
    var streak: Int = 0
    var prCount: Int = 0
    var volumeDelta: Double = 0

    /// Percentage change between two weekly volumes; 0 when the previous week has none
    /// (an infinite increase is not a number anyone wants in a notification).
    static func volumeDelta(current: Double, previous: Double) -> Double {
        guard previous > 0 else { return 0 }
        return (current - previous) / previous * 100
    }

    /// Fetch-all + Swift filter (the `#Predicate` optional-relationship idiom).
    @MainActor
    static func compute(
        modelContext: ModelContext,
        athleteId: UUID?,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> WeeklyNotificationNumbers {
        guard let athleteId else { return WeeklyNotificationNumbers() }
        let weekStart = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        let previousStart = calendar.date(byAdding: .day, value: -14, to: now) ?? now
        let yearStart = calendar.date(byAdding: .day, value: -365, to: now) ?? now

        let sessions = ((try? modelContext.fetch(FetchDescriptor<WorkoutSession>())) ?? [])
            .filter { $0.athlete?.id == athleteId }
        let thisWeek = sessions.filter { $0.sessionDate >= weekStart && $0.sessionDate <= now }
        let lastWeek = sessions.filter { $0.sessionDate >= previousStart && $0.sessionDate < weekStart }

        let records = ((try? modelContext.fetch(FetchDescriptor<PersonalRecord>())) ?? [])
            .filter { $0.achievedAt >= weekStart }

        return WeeklyNotificationNumbers(
            sessionCount: thisWeek.count,
            streak: StreakEngine.computeStreak(
                sessions: sessions.filter { $0.sessionDate >= yearStart },
                now: now,
                calendar: calendar
            ),
            prCount: records.count,
            // U22: the push says "volume vs last week", so it is a TONNAGE comparison —
            // `AnalyticsEngine.tonnage` drops the distance-mode sessions whose
            // `totalVolume` is metres. Summing raw made a walk a tonnage swing.
            volumeDelta: volumeDelta(
                current: AnalyticsEngine.tonnage(of: thisWeek),
                previous: AnalyticsEngine.tonnage(of: lastWeek)
            )
        )
    }
}
