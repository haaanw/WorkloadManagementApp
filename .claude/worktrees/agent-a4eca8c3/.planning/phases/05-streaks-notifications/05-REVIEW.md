---
phase: 05-streaks-notifications
reviewed: 2026-04-22T12:00:00Z
depth: standard
files_reviewed: 8
files_reviewed_list:
  - WorkloadApp/App/AppContainer.swift
  - WorkloadApp/Services/NotificationService.swift
  - WorkloadApp/Services/StreakEngine.swift
  - WorkloadApp/ViewModels/DashboardViewModel.swift
  - WorkloadApp/Views/Dashboard/DashboardView.swift
  - WorkloadApp/Views/Dashboard/NotificationPrePermissionCard.swift
  - WorkloadApp/Views/Dashboard/WeeklySummaryCard.swift
  - WorkloadApp/Views/Profile/ProfileView.swift
findings:
  critical: 0
  warning: 3
  info: 3
  total: 6
status: issues_found
---

# Phase 5: Code Review Report

**Reviewed:** 2026-04-22T12:00:00Z
**Depth:** standard
**Files Reviewed:** 8
**Status:** issues_found

## Summary

Reviewed the streaks and notifications feature set across 8 files: StreakEngine (pure computation), NotificationService (local notification scheduling), DashboardViewModel (streak/notification integration), DashboardView (pre-permission card placement), NotificationPrePermissionCard (UI), WeeklySummaryCard (streak display), ProfileView (notification settings), and AppContainer (service wiring).

The code is well-structured and follows project conventions consistently. StreakEngine is a proper pure struct with static methods. NotificationService correctly wraps UNUserNotificationCenter. The notification pre-permission flow and profile settings are logically sound. Three warnings and three informational items found -- no critical security or crash-level issues.

## Warnings

### WR-01: WeeklySummaryCard dual-state initialization causes UI flicker

**File:** `WorkloadApp/Views/Dashboard/WeeklySummaryCard.swift:9-10`
**Issue:** The card has both `@AppStorage("weeklySummaryExpanded") private var storedExpanded: Bool = true` and `@State private var isExpanded: Bool = true`. The `@State` property initializes to `true` before `.onAppear` (line 101) syncs it from `storedExpanded`. If the user previously collapsed the card (`storedExpanded = false`), there will be a single-frame flash where the card renders expanded before `.onAppear` corrects it.
**Fix:** Remove the `@State` property and use `storedExpanded` directly, or initialize `@State` from a static context. Simplest fix:
```swift
// Remove @State private var isExpanded and use storedExpanded directly:
struct WeeklySummaryCard: View {
    let summary: AnalyticsEngine.WeeklySummary
    let streak: Int
    @AppStorage("weeklySummaryExpanded") private var isExpanded: Bool = true

    // Remove .onAppear { isExpanded = storedExpanded }
    // Replace storedExpanded = isExpanded with nothing (AppStorage persists automatically)
```

### WR-02: StreakEngine uses Date.now internally, breaking engine purity convention

**File:** `WorkloadApp/Services/StreakEngine.swift:29`
**Issue:** Per project conventions, engines are "pure structs with static methods -- no state, no side effects" and "deterministic: same input -> same output always." `StreakEngine.computeStreak` uses `Date.now` on line 29, making the output depend on when it is called, not just on input. This makes the function non-deterministic and difficult to unit test (results change based on wall clock time).
**Fix:** Accept a `referenceDate` parameter with a default value:
```swift
static func computeStreak(sessions: [WorkoutSession], referenceDate: Date = .now) -> Int {
    // ...
    var checkDate = referenceDate
    // ...
}
```

### WR-03: ProfileView notification toggle has async race with visual state

**File:** `WorkloadApp/Views/Profile/ProfileView.swift:84-109`
**Issue:** The notification toggle's `set` closure spawns a `Task` for async authorization (lines 88-105). During the async `requestAuthorization()` call, the toggle visually appears ON because the `get` closure reads `notificationsEnabled` which hasn't been updated yet -- the `set` closure returns before the `Task` completes. If authorization is denied, the toggle flips back, causing a jarring visual toggle-on-then-off effect.
**Fix:** Set `notificationsEnabled = false` immediately at the start of the `set` closure, then set it to `true` only after confirmed authorization:
```swift
set: { newValue in
    if newValue {
        // Don't flip ON yet -- wait for authorization
        Task {
            let status = await container.notificationService.authorizationStatus()
            if status == .denied {
                notificationsDenied = true
                return
            }
            if status == .notDetermined {
                let granted = await container.notificationService.requestAuthorization()
                if !granted { return }
            }
            notificationsEnabled = true
            scheduleNotification()
        }
    } else {
        notificationsEnabled = false
        container.notificationService.cancelWeeklySummary()
    }
}
```

## Info

### IN-01: NotificationService does not validate weekday/hour/minute ranges

**File:** `WorkloadApp/Services/NotificationService.swift:32`
**Issue:** `scheduleWeeklySummary(weekday:hour:minute:body:)` accepts arbitrary `Int` values without validation. While callers currently pass valid values, invalid inputs (e.g., weekday 0 or hour 25) would create a `UNCalendarNotificationTrigger` that silently never fires.
**Fix:** Add a guard or assertion:
```swift
func scheduleWeeklySummary(weekday: Int, hour: Int, minute: Int, body: String) {
    guard (1...7).contains(weekday), (0...23).contains(hour), (0...59).contains(minute) else {
        print("Invalid notification schedule parameters: weekday=\(weekday) hour=\(hour) minute=\(minute)")
        return
    }
    // ...
}
```

### IN-02: ProfileView scheduleNotification uses placeholder body text

**File:** `WorkloadApp/Views/Profile/ProfileView.swift:500-509`
**Issue:** When the user changes notification day/time in ProfileView, `scheduleNotification()` is called with zeroed-out summary data (`sessionCount: 0, streak: 0, prCount: 0, volumeDelta: 0`), producing the body "0 sessions this week. Log a session to keep your streak alive." This placeholder text will be shown if the notification fires before the next `refreshNotificationContent` call from the dashboard.
**Fix:** Either fetch actual summary data in ProfileView's `scheduleNotification()`, or call `DashboardViewModel.refreshNotificationContent` after rescheduling. Alternatively, document that the dashboard refresh on next foreground will overwrite the placeholder.

### IN-03: Magic string keys for UserDefaults scattered across files

**File:** `WorkloadApp/ViewModels/DashboardViewModel.swift:221,239-240` and `WorkloadApp/Views/Dashboard/DashboardView.swift:80-82`
**Issue:** UserDefaults keys like `"notificationsEnabled"`, `"notificationDay"`, `"notificationTime"`, `"notificationPrePermissionShown"`, and `"weeklySummaryExpanded"` are string literals duplicated across DashboardViewModel, DashboardView, ProfileView, and WeeklySummaryCard. If a key is changed in one location but not another, the feature silently breaks.
**Fix:** Centralize keys in an enum or extension:
```swift
enum UserDefaultsKey {
    static let notificationsEnabled = "notificationsEnabled"
    static let notificationDay = "notificationDay"
    static let notificationTime = "notificationTime"
    static let notificationPrePermissionShown = "notificationPrePermissionShown"
    static let weeklySummaryExpanded = "weeklySummaryExpanded"
}
```

---

_Reviewed: 2026-04-22T12:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
