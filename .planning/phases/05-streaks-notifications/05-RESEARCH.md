# Phase 5: Streaks & Notifications - Research

**Researched:** 2026-04-22
**Domain:** iOS local notifications (UserNotifications framework), streak calculation, SwiftUI dashboard integration
**Confidence:** HIGH

## Summary

This phase adds two features to the existing Tonus iOS app: (1) a weekly workout streak counter displayed inside the existing WeeklySummaryCard on the dashboard, and (2) weekly local push notifications summarizing training activity. Both features are local-only with no server component, using Apple's UserNotifications framework (UNCalendarNotificationTrigger) for scheduling and pure computation for streak logic.

The implementation surface is well-constrained. Streak calculation is a pure function over WorkoutSession dates, fitting the established engine pattern (StreakEngine as a pure struct with static methods). Notification scheduling uses UNUserNotificationCenter with calendar-based triggers -- no APNs, no server infrastructure, no new SPM dependencies. The pre-permission UX follows the existing WelcomeActionCard inline-card pattern on the dashboard.

**Primary recommendation:** Build StreakEngine as a pure struct (matching WorkloadCalculator/RecoveryScoreEngine pattern), NotificationService as an @MainActor service registered in AppContainer, and integrate both into existing views (WeeklySummaryCard, DashboardView, ProfileView) with minimal structural changes.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- D-01: Streak count appears as a row inside the existing WeeklySummaryCard -- no standalone badge or new component
- D-02: When streak is 0, hide the streak row entirely -- don't show "0 weeks" or a CTA
- D-03: Streak unit is weeks (consecutive weeks with 1+ logged session)
- D-04: Default notification day/time is Sunday 7 PM
- D-05: User can change day and time in Profile settings (NOTF-03)

### Claude's Discretion
- D-06: Notification content density -- use data from AnalyticsEngine.WeeklySummary
- D-07: Pre-permission screen design -- inline card on dashboard (decided in UI spec)
- D-08: Notification settings placement in ProfileView -- new NOTIFICATIONS section (decided in UI spec)

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| STRK-01 | User can see current workout streak (consecutive weeks with 1+ logged session) on dashboard | StreakEngine computes from WorkoutRepository.fetchSessions(); result displayed in WeeklySummaryCard |
| STRK-02 | Dashboard displays streak badge showing current streak count | Streak row added to WeeklySummaryCard with flame.fill icon, count, and "week streak" label |
| NOTF-01 | User receives weekly local push notification summarizing sessions, PRs, and streak | NotificationService schedules UNCalendarNotificationTrigger; content built from AnalyticsEngine.WeeklySummary + StreakEngine |
| NOTF-02 | App shows pre-permission screen explaining notification value before iOS permission dialog | NotificationPrePermissionCard (inline card) shown on first dashboard visit when auth status is .notDetermined |
| NOTF-03 | User can configure notification day/time and toggle on/off in Profile settings | NOTIFICATIONS section in ProfileView with Toggle + day/time pickers, persisted via @AppStorage |
</phase_requirements>

## Project Constraints (from CLAUDE.md)

- Zero new SPM packages for v1.1 -- all Apple-native frameworks [VERIFIED: CLAUDE.md, STATE.md]
- Engines are pure structs with static methods -- no state, no dependencies [VERIFIED: codebase pattern]
- ViewModels are @MainActor @Observable final class [VERIFIED: codebase pattern]
- All colors via ColorTokens, all fonts via Font.Tokens (DM Sans only) [VERIFIED: DESIGN.md]
- 0pt border radius, no shadows, 8pt spacing grid [VERIFIED: DESIGN.md]
- Accent color only on hero readiness score number [VERIFIED: DESIGN.md]
- After every 3-5 files modified, run build check [VERIFIED: CLAUDE.md]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Streak calculation | Engine (pure struct) | -- | Pure computation over session dates, no side effects |
| Streak display | View (WeeklySummaryCard) | ViewModel (DashboardViewModel) | View renders, ViewModel orchestrates computation in load() |
| Notification scheduling | Service (NotificationService) | -- | Wraps UNUserNotificationCenter, manages system interaction |
| Notification content | Engine (pure struct) | Service (NotificationService) | Content is computed from WeeklySummary data, formatted by service |
| Pre-permission UX | View (NotificationPrePermissionCard) | Service (NotificationService) | Card triggers auth request via service |
| Notification settings | View (ProfileView) | Service (NotificationService) | Profile UI triggers reschedule via service |
| Settings persistence | @AppStorage (UserDefaults) | -- | Per-device preference, no Supabase sync needed |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| UserNotifications | iOS 17+ built-in | Local notification scheduling and authorization | Apple's notification framework; the only option for local notifications [VERIFIED: Apple docs] |
| SwiftUI | iOS 17+ built-in | UI for streak display, pre-permission card, settings | Already in use throughout the app [VERIFIED: codebase] |
| SwiftData | iOS 17+ built-in | Query session history for streak calculation | Already in use for all persistence [VERIFIED: codebase] |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Foundation (Calendar, DateComponents) | iOS 17+ built-in | Week boundary calculation for streaks, notification trigger scheduling | Streak week alignment and UNCalendarNotificationTrigger date components |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| UNCalendarNotificationTrigger | UNTimeIntervalNotificationTrigger | Calendar trigger is correct for "every Sunday at 7pm" repeating; time interval can't express day-of-week |
| @AppStorage for settings | Athlete model properties | AppStorage is per-device which is correct for notification preferences; Athlete model would sync to Supabase unnecessarily |

**Installation:**
```bash
# No installation needed -- all Apple-native frameworks already available
```

## Architecture Patterns

### System Architecture Diagram

```
User opens Dashboard
        |
        v
DashboardViewModel.load()
        |
        +---> WorkoutRepository.fetchSessions(last: N)
        |            |
        |            v
        +---> StreakEngine.computeStreak(sessions:) --> streak count (Int)
        |            |
        |            v
        +---> WeeklySummaryCard displays streak row (if > 0)
        |
        +---> AnalyticsEngine.computeWeeklySummary() --> WeeklySummary
                     |
                     v (on notification trigger fire)
              NotificationService.buildContent(summary:, streak:)
                     |
                     v
              UNUserNotificationCenter.add(request)
                     |
                     v
              iOS delivers notification at scheduled day/time
```

```
User visits Profile > NOTIFICATIONS section
        |
        v
Toggle on/off, Day picker, Time picker
        |
        v
@AppStorage persists preferences
        |
        v
NotificationService.reschedule(enabled:, day:, time:)
        |
        +---> Cancel existing pending requests
        +---> Schedule new UNCalendarNotificationTrigger (if enabled)
```

### Recommended Project Structure
```
WorkloadApp/
├── Services/
│   ├── StreakEngine.swift          # Pure streak computation
│   └── NotificationService.swift  # UNUserNotificationCenter wrapper
├── Views/
│   └── Dashboard/
│       └── NotificationPrePermissionCard.swift  # Inline pre-permission card
```

Modified files (no new directories):
- `Views/Dashboard/WeeklySummaryCard.swift` -- add streak row
- `Views/Dashboard/DashboardView.swift` -- add pre-permission card trigger
- `ViewModels/DashboardViewModel.swift` -- add streak property + computation
- `Views/Profile/ProfileView.swift` -- add NOTIFICATIONS section
- `App/AppContainer.swift` -- (optional) register NotificationService

### Pattern 1: Pure Engine for Streak Calculation
**What:** StreakEngine as a `struct` with a single `static func computeStreak(sessions:) -> Int`
**When to use:** Always -- matches WorkloadCalculator, RecoveryScoreEngine, PRDetector patterns
**Example:**
```swift
// Source: Established codebase pattern (WorkloadCalculator.swift, RecoveryScoreEngine.swift)
struct StreakEngine {
    /// Compute consecutive weeks with at least one logged session, counting backward from current week.
    static func computeStreak(sessions: [WorkoutSession]) -> Int {
        let calendar = Calendar.current
        // Group sessions by ISO week-year week number
        // Walk backward from current week, counting consecutive weeks with 1+ session
        // Return count (0 if current week has no sessions)
    }
}
```

### Pattern 2: NotificationService as @MainActor Service
**What:** Wraps UNUserNotificationCenter for authorization, scheduling, and cancellation
**When to use:** All notification operations -- keeps UNUserNotificationCenter usage centralized
**Example:**
```swift
// Source: Apple Developer Documentation (UNUserNotificationCenter)
@MainActor
final class NotificationService {
    private let center = UNUserNotificationCenter.current()

    func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound])
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    func scheduleWeeklySummary(day: Int, hour: Int, minute: Int) {
        // Cancel existing, create new UNCalendarNotificationTrigger
        var components = DateComponents()
        components.weekday = day  // 1 = Sunday
        components.hour = hour
        components.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let content = UNMutableNotificationContent()
        content.title = "Your Week in Review"
        content.body = "Open Tonus to see your weekly summary."
        // Note: actual content is a placeholder; real content is computed at delivery time
        // via notification service extension OR pre-computed when scheduling
        let request = UNNotificationRequest(
            identifier: "weekly-summary",
            content: content,
            trigger: trigger
        )
        center.add(request)
    }

    func cancelWeeklySummary() {
        center.removePendingNotificationRequests(withIdentifiers: ["weekly-summary"])
    }
}
```

### Pattern 3: @AppStorage for Notification Preferences
**What:** Store notification toggle, day, and time in UserDefaults via @AppStorage
**When to use:** Per-device settings that don't need Supabase sync
**Example:**
```swift
// Source: Established codebase pattern (WeeklySummaryCard @AppStorage usage)
@AppStorage("notificationsEnabled") private var notificationsEnabled: Bool = false
@AppStorage("notificationDay") private var notificationDay: Int = 1  // 1 = Sunday
@AppStorage("notificationTime") private var notificationTime: String = "19:00"
@AppStorage("notificationPrePermissionShown") private var prePermissionShown: Bool = false
```

### Anti-Patterns to Avoid
- **Storing streak in SwiftData model:** Streak is a derived value from session dates. Persisting it creates staleness risk. Compute on every dashboard load (fast -- only needs session dates, not full session data). [ASSUMED]
- **Using UNTimeIntervalNotificationTrigger for weekly repeats:** Cannot express "every Sunday at 7pm". Must use UNCalendarNotificationTrigger with DateComponents specifying weekday + hour + minute. [VERIFIED: Apple docs]
- **Requesting notification permission during onboarding:** D-07 specifies first dashboard visit, not onboarding. Pre-permission card shown when auth status is `.notDetermined`. [VERIFIED: CONTEXT.md]
- **Computing notification content at scheduling time:** The notification is scheduled to repeat weekly. Content must be refreshed before each delivery. Since this is a local notification (no Notification Service Extension), the simplest approach is to reschedule the notification weekly with fresh content. DashboardViewModel.load() already runs on each app foreground -- it can refresh notification content then. [ASSUMED]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Week boundary calculation | Custom week logic | `Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)` | Handles locale-specific week start days, year boundaries, leap years [VERIFIED: Foundation docs] |
| Notification scheduling | Raw timer-based approach | `UNCalendarNotificationTrigger` with repeating DateComponents | System-managed delivery, survives app termination, respects Do Not Disturb [VERIFIED: Apple docs] |
| Permission state checking | Manual boolean tracking | `UNUserNotificationCenter.current().notificationSettings()` | Authoritative system state, reflects changes made in Settings.app [VERIFIED: Apple docs] |
| Day-of-week picker options | Hardcoded English day names | `Calendar.current.weekdaySymbols` | Locale-aware day names [VERIFIED: Foundation docs] |

**Key insight:** All notification lifecycle management (scheduling, delivery, cancellation, permission) is handled by UNUserNotificationCenter. The only custom code needed is (1) computing what content to show and (2) wiring UI preferences to trigger rescheduling.

## Common Pitfalls

### Pitfall 1: Notification Content Staleness
**What goes wrong:** Local notification content is set at scheduling time. If scheduled to repeat weekly, the same body text repeats every week regardless of actual training data.
**Why it happens:** UNCalendarNotificationTrigger with `repeats: true` delivers the same UNNotificationContent every time.
**How to avoid:** Reschedule the notification with fresh content whenever the app enters foreground (in DashboardViewModel.load()). The notification fires with the most recently scheduled content. Alternatively, schedule a non-repeating notification for the next occurrence only, and reschedule on each app open.
**Warning signs:** Users report seeing the same notification text week after week.

### Pitfall 2: Week Boundary Mismatch
**What goes wrong:** Streak calculation uses a different week definition than Calendar locale settings. User in locale where week starts Monday gets different streak than expected.
**Why it happens:** `Calendar.current.weekOfYear` depends on locale. Some locales start weeks on Monday, others Sunday.
**How to avoid:** Use `Calendar.current` consistently for all week-boundary calculations. The streak counts "consecutive calendar weeks with 1+ session" per the user's locale. Document this behavior. Do not hardcode Sunday as week start for streak calculation (note: notification day is a separate concern -- Sunday default for D-04 is the notification delivery day, not the streak week boundary).
**Warning signs:** Tests pass in one locale but fail in another.

### Pitfall 3: Authorization Status Not Rechecked
**What goes wrong:** User enables notifications in-app, then disables them in iOS Settings. App still shows toggle as "on" and tries to schedule.
**Why it happens:** @AppStorage stores the in-app preference but doesn't reflect system authorization state.
**How to avoid:** On ProfileView appear and when toggling on, check `UNUserNotificationCenter.current().notificationSettings().authorizationStatus`. If `.denied`, show a message directing user to Settings.app. The toggle should reflect both the user's preference AND system authorization. [VERIFIED: Apple docs pattern]
**Warning signs:** Scheduled notifications never fire despite toggle being on.

### Pitfall 4: Pre-Permission Card Shows After Denial
**What goes wrong:** User sees pre-permission card, taps "Enable", system dialog shows, user denies. Next time they visit dashboard, card appears again.
**Why it happens:** `@AppStorage("notificationPrePermissionShown")` wasn't set before the system dialog result came back.
**How to avoid:** Set the `@AppStorage` flag immediately when either button is tapped, before checking the authorization result. The card is a one-time prompt regardless of outcome. [VERIFIED: UI spec interaction contract]
**Warning signs:** Card reappears after user explicitly dismissed it.

### Pitfall 5: PR Count Not Available in AnalyticsEngine.WeeklySummary
**What goes wrong:** Notification body references PR count but WeeklySummary struct doesn't include it.
**Why it happens:** Current WeeklySummary has sessionCount, totalVolume, avgRecoveryScore, deltas, zone distribution -- but no PR count field.
**How to avoid:** Either (a) add a `prCount: Int` field to WeeklySummary and compute it in `computeWeeklySummary()` by querying PersonalRecord, or (b) query PR count separately when building notification content. Option (a) is cleaner since notification and card both need the same data. [VERIFIED: AnalyticsEngine.swift -- prCount is absent from WeeklySummary struct]
**Warning signs:** Notification body always says "No new PRs" because the data isn't being fetched.

## Code Examples

### Streak Computation Algorithm
```swift
// Source: Established engine pattern (WorkloadCalculator.swift)
struct StreakEngine {
    /// Returns the number of consecutive calendar weeks (including current) with at least one session.
    /// Returns 0 if no session exists in the current week.
    static func computeStreak(sessions: [WorkoutSession]) -> Int {
        guard !sessions.isEmpty else { return 0 }
        let calendar = Calendar.current

        // Group sessions by (yearForWeekOfYear, weekOfYear)
        var weekSet = Set<String>()
        for session in sessions {
            let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: session.sessionDate)
            if let y = comps.yearForWeekOfYear, let w = comps.weekOfYear {
                weekSet.insert("\(y)-\(w)")
            }
        }

        // Walk backward from current week
        var streak = 0
        var checkDate = Date.now
        while true {
            let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: checkDate)
            guard let y = comps.yearForWeekOfYear, let w = comps.weekOfYear else { break }
            let key = "\(y)-\(w)"
            if weekSet.contains(key) {
                streak += 1
                // Move to previous week
                checkDate = calendar.date(byAdding: .weekOfYear, value: -1, to: checkDate)!
            } else {
                break
            }
        }
        return streak
    }
}
```

### UNCalendarNotificationTrigger Setup
```swift
// Source: Apple Developer Documentation (https://developer.apple.com/documentation/usernotifications/uncalendarnotificationtrigger)
func scheduleWeeklyNotification(weekday: Int, hour: Int, minute: Int, body: String) {
    let content = UNMutableNotificationContent()
    content.title = "Your Week in Review"
    content.body = body
    content.sound = .default

    var dateComponents = DateComponents()
    dateComponents.weekday = weekday  // 1 = Sunday, 2 = Monday, etc.
    dateComponents.hour = hour
    dateComponents.minute = minute

    let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
    let request = UNNotificationRequest(identifier: "weekly-summary", content: content, trigger: trigger)

    UNUserNotificationCenter.current().add(request) { error in
        if let error { print("Notification scheduling error: \(error)") }
    }
}
```

### Authorization Request (async/await)
```swift
// Source: Apple Developer Documentation (https://developer.apple.com/documentation/usernotifications/unusernotificationcenter/requestauthorization(options:completionhandler:))
func requestNotificationPermission() async -> Bool {
    do {
        return try await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])
    } catch {
        print("Notification authorization error: \(error)")
        return false
    }
}
```

### Notification Content Builder
```swift
// Source: UI spec copywriting contract + AnalyticsEngine.swift patterns
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
    var sessionPart = "\(sessionCount) sessions logged"
    if streak >= 1 { sessionPart += " -- \(streak) week streak" }
    parts.append(sessionPart + ".")

    // PRs
    if prCount > 0 {
        parts.append("\(prCount) new PRs!")
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
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| UILocalNotification | UNUserNotificationCenter | iOS 10 (2016) | UILocalNotification deprecated; UNUserNotificationCenter is the only supported API [VERIFIED: Apple docs] |
| Completion handler authorization | async/await authorization | iOS 15 / Swift 5.5 (2021) | Cleaner code; both APIs still available but async is preferred [VERIFIED: Apple docs] |

**Deprecated/outdated:**
- UILocalNotification: Fully deprecated since iOS 10. Use UNUserNotificationCenter exclusively. [VERIFIED: Apple docs]
- Provisional authorization (UNAuthorizationOptions.provisional): Available since iOS 12, delivers notifications quietly without explicit permission. Not needed here since D-07 specifies an explicit pre-permission screen. [VERIFIED: Apple docs]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Streak should be computed on every dashboard load rather than persisted | Anti-Patterns | LOW -- computation is O(n) on session count, which is small; if performance becomes an issue, caching is trivial to add |
| A2 | Notification content should be refreshed on each app foreground to avoid staleness | Pitfalls | MEDIUM -- if user doesn't open app for weeks, stale content fires; reschedule-on-foreground mitigates this |

## Open Questions

1. **PR count in notification: query strategy**
   - What we know: AnalyticsEngine.WeeklySummary lacks a prCount field. PersonalRecord model has achievedAt date that can be filtered by week.
   - What's unclear: Whether to extend WeeklySummary or query PersonalRecords separately in NotificationService.
   - Recommendation: Extend WeeklySummary with prCount since both the notification and potential future card enhancements need it. This keeps data sourcing in the engine layer.

2. **Notification content refresh timing**
   - What we know: UNCalendarNotificationTrigger with repeats=true fires the same content. App foreground triggers DashboardViewModel.load().
   - What's unclear: If user doesn't open the app for 2+ weeks, the notification content is stale.
   - Recommendation: Use repeats=true for scheduling reliability, and refresh content in DashboardViewModel.load(). Accept that if the user never opens the app, content may be slightly stale -- this is an acceptable tradeoff for local-only notifications.

## Sources

### Primary (HIGH confidence)
- [Apple Developer Documentation: UNCalendarNotificationTrigger](https://developer.apple.com/documentation/usernotifications/uncalendarnotificationtrigger) - trigger API, DateComponents usage
- [Apple Developer Documentation: UNUserNotificationCenter](https://developer.apple.com/documentation/usernotifications/unusernotificationcenter) - authorization, scheduling, cancellation
- [Apple Developer Documentation: requestAuthorization](https://developer.apple.com/documentation/usernotifications/unusernotificationcenter/requestauthorization(options:completionhandler:)) - async/await authorization pattern
- Codebase files: AnalyticsEngine.swift, WeeklySummaryCard.swift, DashboardViewModel.swift, ProfileView.swift, DashboardView.swift, AppContainer.swift, WelcomeActionCard.swift, WorkoutRepository.swift, PersonalRecord.swift

### Secondary (MEDIUM confidence)
- [Hacking with Swift: Scheduling notifications](https://www.hackingwithswift.com/read/21/2/scheduling-notifications-unusernotificationcenter-and-unnotificationrequest) - practical patterns
- [createwithswift.com: Notifications with async/await](https://www.createwithswift.com/notifications-tutorial-creating-and-scheduling-user-notifications-with-async-await/) - modern Swift patterns
- [Donny Wals: Scheduling daily notifications](https://www.donnywals.com/scheduling-daily-notifications-on-ios-using-calendar-and-datecomponents/) - DateComponents patterns for recurring triggers

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - all Apple-native frameworks, well-documented, already used in project
- Architecture: HIGH - follows established codebase patterns exactly (pure engines, @MainActor services, @Observable VMs)
- Pitfalls: HIGH - common iOS notification pitfalls are well-documented; PR count gap verified by reading AnalyticsEngine.swift

**Research date:** 2026-04-22
**Valid until:** 2026-05-22 (stable -- Apple frameworks, no fast-moving dependencies)
