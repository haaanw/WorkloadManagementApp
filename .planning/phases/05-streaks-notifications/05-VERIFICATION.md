---
phase: 05-streaks-notifications
verified: 2026-04-22T00:00:00Z
status: human_needed
score: 4/4
overrides_applied: 0
human_verification:
  - test: "Streak row appears in WeeklySummaryCard when at least one session exists in the current calendar week"
    expected: "Flame icon, numeric count, and 'week streak' label are visible inside the expanded WeeklySummaryCard on the Dashboard"
    why_human: "Requires running app with seeded session data; streak row visibility depends on SwiftData query returning real sessions"
  - test: "Streak row is hidden when no session exists in the current calendar week"
    expected: "No flame row shown when streak == 0 — the 'if streak > 0' guard suppresses the row completely"
    why_human: "Requires running app with no current-week sessions to confirm conditional renders correctly"
  - test: "Pre-permission card appears on first Dashboard visit with notifications not yet determined"
    expected: "NotificationPrePermissionCard renders below WeeklySummaryCard on first launch (notificationPrePermissionShown == false)"
    why_human: "Requires fresh install or cleared UserDefaults to trigger .notDetermined state; visual layout must be confirmed"
  - test: "Tapping 'Enable Notifications' fires iOS permission dialog and card disappears permanently"
    expected: "System permission sheet appears, card is gone on subsequent visits regardless of permission outcome"
    why_human: "UNUserNotificationCenter.requestAuthorization() requires a running simulator or device; cannot be verified via grep"
  - test: "Tapping 'Not Now' dismisses card without triggering iOS permission dialog"
    expected: "Card disappears permanently; no system sheet is shown; subsequent visits do not re-show the card"
    why_human: "Requires UI interaction to verify prePermissionShown gate and absence of system dialog"
  - test: "Profile NOTIFICATIONS section: toggle on/off, day picker, time picker all function correctly"
    expected: "Toggle on requests authorization if needed and schedules weekly-summary notification; toggle off cancels it; day/time changes reschedule; pickers disabled when toggle off"
    why_human: "Interactive UX — picker state, disabled styling, and notification scheduling require running app"
  - test: "When system notification permission is denied, Profile toggle shows Settings guidance text"
    expected: "notificationsDenied == true causes guidance text to appear: 'Notifications are disabled in Settings. Go to Settings > Tonus to enable them.'"
    why_human: "Requires a device/simulator where notifications have been denied to verify the .denied state path"
  - test: "Weekly notification actually fires at scheduled day/time with correct content"
    expected: "Local notification arrives at the configured time containing session count, streak, PR count, and volume delta"
    why_human: "Requires waiting for UNCalendarNotificationTrigger to fire — not testable via static analysis"
---

# Phase 5: Streaks & Notifications — Verification Report

**Phase Goal:** Athletes can track training consistency and receive weekly summary notifications that reinforce engagement
**Verified:** 2026-04-22T00:00:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths (Roadmap Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | User sees their current workout streak count on the dashboard | VERIFIED | `DashboardViewModel.currentStreak` computed via `StreakEngine.computeStreak(sessions:)` using 365 days of SwiftData sessions; passed to `WeeklySummaryCard(summary:streak:)` at call site; row with `flame.fill` icon visible when `streak > 0` |
| 2 | User receives a weekly local notification summarizing sessions, PRs, and streak | VERIFIED | `NotificationService.scheduleWeeklySummary(weekday:hour:minute:body:)` uses `UNCalendarNotificationTrigger` with `repeats: true`; content built by `buildNotificationBody(sessionCount:streak:prCount:volumeDelta:)`; refreshed on each dashboard load via `refreshNotificationContent()` |
| 3 | User sees a pre-permission screen before the iOS notification permission dialog | VERIFIED | `NotificationPrePermissionCard` rendered in `DashboardView` when `!prePermissionShown`; `prePermissionShown` set to `true` before `requestAuthorization()` is called (prevents reappearance after denial) |
| 4 | User can toggle notifications on/off and configure day/time in Profile settings | VERIFIED | `ProfileView` NOTIFICATIONS section: `@AppStorage`-backed toggle, locale-aware day picker (`Calendar.current.weekdaySymbols`), hourly time picker (6 AM–10 PM); all wired to `container.notificationService` for schedule/cancel/authorizationStatus; denied state guidance text present |

**Score:** 4/4 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `WorkloadApp/Services/StreakEngine.swift` | Pure streak computation struct | VERIFIED | Exists, 44 lines; `struct StreakEngine` with `static func computeStreak(sessions: [WorkoutSession]) -> Int`; uses `Calendar.current`; no `@MainActor`, no `@Observable` |
| `WorkloadApp/Services/NotificationService.swift` | UNUserNotificationCenter wrapper | VERIFIED | Exists, 98 lines; `@MainActor final class`; contains `requestAuthorization`, `authorizationStatus`, `scheduleWeeklySummary`, `cancelWeeklySummary`, `static buildNotificationBody`; `UNCalendarNotificationTrigger` with identifier "weekly-summary" |
| `WorkloadApp/App/AppContainer.swift` | NotificationService registration | VERIFIED | `let notificationService: NotificationService` property present (line 15); `self.notificationService = NotificationService()` in `init()` (line 53) |
| `WorkloadApp/Views/Dashboard/NotificationPrePermissionCard.swift` | Inline pre-permission card | VERIFIED | Exists, 64 lines; `struct NotificationPrePermissionCard: View`; contains "Stay on track", "Enable Notifications", "Not Now"; uses `Rectangle().stroke`, `ColorTokens.surface`, `Font.Tokens`; no `RoundedRectangle`, no `.shadow()`; `.accessibilityElement(children: .contain)` |
| `WorkloadApp/ViewModels/DashboardViewModel.swift` | Streak computation + notification refresh | VERIFIED | `var currentStreak: Int = 0` (line 48); `StreakEngine.computeStreak` call (line 183); `func refreshNotificationContent(notificationService:modelContext:)` (line 220); `NotificationService.buildNotificationBody` called within |
| `WorkloadApp/Views/Dashboard/WeeklySummaryCard.swift` | Streak row display | VERIFIED | `let streak: Int` parameter; `if streak > 0` guard; `Image(systemName: "flame.fill")` with `.accessibilityHidden(true)`; "week streak" label; `.accessibilityLabel("\(streak) week training streak")` |
| `WorkloadApp/Views/Dashboard/DashboardView.swift` | Pre-permission card wiring + streak data flow | VERIFIED | `@AppStorage("notificationPrePermissionShown")`; `NotificationPrePermissionCard(onEnable:onDismiss:)` conditional on `!prePermissionShown`; `WeeklySummaryCard(summary: summary, streak: viewModel.currentStreak)`; `refreshNotificationContent` called after each load |
| `WorkloadApp/Views/Profile/ProfileView.swift` | NOTIFICATIONS settings section | VERIFIED | `sectionHeader("NOTIFICATIONS")`; toggle with auth-aware binding; day picker with `Calendar.current.weekdaySymbols`; time picker with hourly slots; `.disabled(!notificationsEnabled)` on pickers; denied guidance text referencing Settings; `scheduleNotification()` private helper |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `DashboardViewModel.swift` | `StreakEngine.swift` | `StreakEngine.computeStreak()` call in `load()` | WIRED | Line 183: `currentStreak = StreakEngine.computeStreak(sessions: streakSessions)` — sessions fetched from `workoutRepo.fetchSessions(last: 365)` |
| `WeeklySummaryCard.swift` | `DashboardViewModel` | `streak: Int` parameter passed from call site | WIRED | `WeeklySummaryCard(summary: summary, streak: viewModel.currentStreak)` at DashboardView line 60 |
| `DashboardView.swift` | `NotificationPrePermissionCard.swift` | Conditional rendering on `@AppStorage("notificationPrePermissionShown")` | WIRED | `if !prePermissionShown { NotificationPrePermissionCard(...) }` at line 64–88 |
| `AppContainer.swift` | `NotificationService.swift` | Property initialization in `init()` | WIRED | `self.notificationService = NotificationService()` at line 53 |
| `ProfileView.swift` | `NotificationService.swift` | `container.notificationService` calls | WIRED | Lines 89, 96, 107, 346, 350, 507 — authorizationStatus, requestAuthorization, cancelWeeklySummary, scheduleWeeklySummary all present |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|--------------|--------|-------------------|--------|
| `WeeklySummaryCard.swift` | `streak: Int` | `viewModel.currentStreak` ← `StreakEngine.computeStreak(sessions:)` ← `workoutRepo.fetchSessions(last: 365)` ← SwiftData `@Model WorkoutSession` | Yes — SwiftData fetch query with date predicate | FLOWING |
| `NotificationPrePermissionCard.swift` | Stateless — rendered when `!prePermissionShown` | `@AppStorage("notificationPrePermissionShown")` persisted in UserDefaults | Yes — `@AppStorage` bool flag | FLOWING |
| `ProfileView.swift` (NOTIFICATIONS section) | `notificationsEnabled`, `notificationDay`, `notificationTime` | `@AppStorage` keys read/written on toggle/picker change | Yes — UserDefaults persistence | FLOWING |

### Behavioral Spot-Checks

Step 7b: SKIPPED — project is an iOS app requiring a simulator or device to run. Behavioral testing (notification delivery, SwiftUI rendering) cannot be verified via command-line invocation.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|---------|
| STRK-01 | 05-01, 05-02 | User can see current workout streak on dashboard | SATISFIED | `StreakEngine.computeStreak` in `DashboardViewModel.load()`, displayed in `WeeklySummaryCard` |
| STRK-02 | 05-02 | Dashboard displays streak badge showing current streak count | SATISFIED | `WeeklySummaryCard` streak row: flame icon + count + "week streak" label, hidden when streak == 0 |
| NOTF-01 | 05-01, 05-02 | User receives weekly local push notification summarizing sessions, PRs, and streak | SATISFIED | `NotificationService` schedules `UNCalendarNotificationTrigger`; `buildNotificationBody` includes session count, streak, PR count, volume delta; content refreshed on each dashboard load |
| NOTF-02 | 05-02 | App shows pre-permission screen explaining notification value before iOS permission dialog | SATISFIED | `NotificationPrePermissionCard` shown when `!prePermissionShown`; `prePermissionShown` set before `requestAuthorization()` call |
| NOTF-03 | 05-03 | User can configure notification day/time and toggle on/off in Profile settings | SATISFIED | ProfileView NOTIFICATIONS section with toggle (auth-aware), day picker, time picker; denied state handled |

All 5 requirements assigned to Phase 5 in REQUIREMENTS.md are satisfied. No orphaned requirements.

### Anti-Patterns Found

No anti-patterns detected across all 7 modified/created files. Verified:
- No `TODO`, `FIXME`, `PLACEHOLDER` comments in any phase 5 files
- No `RoundedRectangle` or `.shadow()` in `NotificationPrePermissionCard.swift` (DESIGN.md compliance)
- No `@Observable` on `NotificationService` (correctly imperative-only)
- No `@MainActor` on `StreakEngine` (correctly pure struct)
- All colors via `ColorTokens`, all fonts via `Font.Tokens` in new view

### Human Verification Required

#### 1. Streak row visual appearance and conditional hide

**Test:** Open app with a session logged in the current calendar week. Expand WeeklySummaryCard.
**Expected:** Flame icon, numeric streak count, and "week streak" label appear as the first row inside the expanded card. Repeat with no current-week sessions — row must be absent.
**Why human:** SwiftUI conditional rendering and live SwiftData data require a running simulator.

#### 2. Pre-permission card first-visit flow

**Test:** Clear UserDefaults (or fresh install). Open Dashboard. Card should appear below WeeklySummaryCard. Tap "Not Now". Navigate away and return — card must not reappear.
**Expected:** Card visible once, permanently dismissed by either button, no system permission dialog on "Not Now".
**Why human:** `@AppStorage` state and system dialog presentation require running app.

#### 3. Enable Notifications full flow

**Test:** On a fresh install (or after clearing `notificationPrePermissionShown`), tap "Enable Notifications" on the pre-permission card.
**Expected:** iOS system permission sheet appears immediately. If granted: card disappears, `notificationsEnabled` stored as true, notification scheduled for Sunday 7 PM.
**Why human:** `UNUserNotificationCenter.requestAuthorization()` requires a running simulator or device.

#### 4. Profile NOTIFICATIONS section — toggle and picker interactions

**Test:** Open Profile tab. Find NOTIFICATIONS section between PREFERENCES and CONNECTED DEVICES. Toggle on, change day to Monday, change time to 8:00 PM. Toggle off.
**Expected:** Toggle on triggers auth check, schedules notification; day/time changes reschedule immediately; toggle off cancels the pending notification; pickers appear disabled (text3 color) when toggle is off.
**Why human:** Interactive picker and toggle state requires running app.

#### 5. Denied authorization state guidance

**Test:** On a simulator where Tonus notifications are denied in Settings, open Profile and attempt to toggle on.
**Expected:** Toggle reverts to off; guidance text "Notifications are disabled in Settings. Go to Settings > Tonus to enable them." appears below the toggle row.
**Why human:** Requires a device/simulator with notification permission already denied.

#### 6. Notification delivery verification

**Test:** Enable notifications, configure for a time 1-2 minutes in the future, lock the device/simulator, wait for the time to pass.
**Expected:** Local notification appears on lock screen with title "Your Week in Review" and body containing session count, streak, and PR data.
**Why human:** `UNCalendarNotificationTrigger` delivery requires waiting for the scheduled fire time.

### Gaps Summary

No programmatic gaps found. All 4 roadmap success criteria are verified at code level (Levels 1–4: exists, substantive, wired, data flowing). All 5 requirement IDs (STRK-01, STRK-02, NOTF-01, NOTF-02, NOTF-03) have confirmed implementation evidence. All 5 commits from the plan summaries are present in git history. All 3 new source files are registered in `project.pbxproj`.

Status is `human_needed` because notification delivery and the pre-permission card UX flow cannot be verified without running the app on a simulator or device.

---

_Verified: 2026-04-22T00:00:00Z_
_Verifier: Claude (gsd-verifier)_
