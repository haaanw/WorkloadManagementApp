# Architecture Patterns

**Domain:** iOS fitness app — integrating push notifications, streak tracking, PDF export, and App Store compliance into existing SwiftUI+SwiftData+Supabase architecture
**Researched:** 2026-04-22

## Recommended Architecture

The existing layer stack (Views -> ViewModels -> Pipelines -> Engines -> Repositories -> Models) remains intact. New features integrate as **leaf additions** — no core refactoring required. Each feature adds 1-2 new files at the appropriate layer without modifying existing data flows.

```
                    +-------------------+
                    |     Views         |
                    +-------------------+
                    | ProfileView       |  (modify: add Export + Notification settings sections)
                    | DashboardView     |  (modify: add streak display widget)
                    | ExportSheet (NEW) |  (PDF/CSV share sheet)
                    +-------------------+
                            |
                    +-------------------+
                    |   ViewModels      |
                    +-------------------+
                    | DashboardVM       |  (modify: add streak data)
                    +-------------------+
                            |
          +-----------------+-----------------+
          |                 |                 |
  +---------------+ +---------------+ +------------------+
  |   Engines     | |  Services     | |   Repositories   |
  +---------------+ +---------------+ +------------------+
  | PDFExport     | | Notification  | | (no new repos)   |
  | Engine (NEW)  | | Service (NEW) | |                  |
  | StreakEngine  | |               | |                  |
  | (NEW)         | |               | |                  |
  +---------------+ +---------------+ +------------------+
          |                 |                 |
  +---------------+ +---------------+ +------------------+
  |   Models      | |  AppContainer | |   Entitlements   |
  +---------------+ +---------------+ +------------------+
  | (no new       | | (add          | | (NO changes for  |
  |  @Model)      | |  notification | |  local notifs)   |
  |               | |  service ref) | |                  |
  +---------------+ +---------------+ +------------------+
```

### Component Boundaries

| Component | Responsibility | Communicates With | New/Modified |
|-----------|---------------|-------------------|--------------|
| `NotificationService` | Request permission, schedule local notifications | AppContainer, UNUserNotificationCenter | **NEW** service |
| `StreakEngine` | Compute current workout/check-in streaks from dates | WorkoutSession dates, WellnessCheckIn dates | **NEW** pure engine |
| `PDFExportEngine` | Generate PDF report from athlete data (recovery, workload, sessions) | Models (read-only), UIGraphicsPDFRenderer | **NEW** pure engine |
| `ExportSheet` | Present share sheet for PDF/CSV files | PDFExportEngine, CSVExportEngine, UIActivityViewController | **NEW** view |
| `AppContainer` | Hold NotificationService reference | NotificationService | **MODIFY** -- add property |
| `ProfileView` | Notification preferences toggle, export trigger | NotificationService, ExportSheet | **MODIFY** -- add sections |
| `DashboardView` | Display streak count | StreakEngine | **MODIFY** -- add widget |
| `DashboardViewModel` | Compute and expose streak data | StreakEngine | **MODIFY** -- add properties |

### Data Flow

**Push Notifications (Local-only approach):**
```
App Launch
  -> AppRouter.task (after auth succeeds)
    -> NotificationService.requestAuthorization()
    -> NotificationService.scheduleWeeklySummary()
       (UNCalendarNotificationTrigger, repeating weekly)

User opens notification
  -> App activates
  -> DashboardView loads normally (no deep linking needed for v1.1)
```

**Why local-only, not Supabase Edge Functions + APNs:**
- Weekly summary is time-based, not event-based -- no server trigger needed
- Avoids APNs certificate management, .p8 key provisioning, Supabase Edge Function deployment
- Avoids creating a `device_tokens` table in Supabase and managing token rotation
- Local `UNCalendarNotificationTrigger` with `repeats: true` handles weekly scheduling natively
- If future features need server-pushed notifications (coach assigns workout), upgrade then
- Confidence: HIGH -- Apple documentation explicitly supports this pattern

**Streak Tracking:**
```
DashboardViewModel.load()
  -> Fetch WorkoutSession dates via @Query (already available in DashboardView)
  -> Fetch WellnessCheckIn dates via @Query (already available in DashboardView)
  -> StreakEngine.computeStreak(dates:, frequency:) -> StreakResult
  -> Expose streakCount, streakType to DashboardView
```

**No new SwiftData model needed.** Streaks are computed from existing `WorkoutSession.sessionDate` and `WellnessCheckIn.date` arrays. This follows the existing engine pattern (pure struct, static methods, no state). The athlete's `trainingFrequency` property (already on the Athlete model) provides the expected sessions-per-week for streak calculation.

**PDF Export:**
```
User taps "Export Report" in ProfileView or WorkloadView
  -> Fetch athlete, sessions, snapshots, PRs from @Query
  -> PDFExportEngine.generateReport(athlete:, sessions:, snapshots:, prs:)
     -> UIGraphicsPDFRenderer draws pages
     -> Returns Data
  -> Write Data to temp file
  -> Present UIActivityViewController via .sheet
```

**Critical constraint:** PDF must NOT include raw HealthKit data (HRV values, RHR values, sleep duration). Only composite scores (recovery score, ACWR, TSB) are permitted. This matches the existing CSVExportEngine approach and the HealthKit compliance requirement already enforced in the codebase.

## New Components Detail

### 1. NotificationService (NEW)

**Layer:** Services (stateful, like HealthKitService)
**Type:** `@MainActor @Observable final class` -- needs to be observable for permission state
**Location:** `WorkloadApp/Services/NotificationService.swift`

```swift
@MainActor
@Observable
final class NotificationService {
    private(set) var isAuthorized: Bool = false

    func requestAuthorization() async {
        let center = UNUserNotificationCenter.current()
        let granted = try? await center.requestAuthorization(options: [.alert, .badge, .sound])
        isAuthorized = granted ?? false
    }

    func scheduleWeeklySummary(dayOfWeek: Int = 2, hour: Int = 9) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["weekly-summary"])

        let content = UNMutableNotificationContent()
        content.title = "Weekly Training Summary"
        content.body = "Check your training load trends and recovery this week."
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.weekday = dayOfWeek  // Monday = 2
        dateComponents.hour = hour
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents, repeats: true
        )

        let request = UNNotificationRequest(
            identifier: "weekly-summary",
            content: content,
            trigger: trigger
        )
        center.add(request)
    }

    func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
```

**Integration point:** Add `let notificationService: NotificationService` to `AppContainer.init()`. Request authorization in `AppRouter.task` after authentication succeeds -- but only after showing a pre-permission explanation screen.

**No entitlement changes needed.** `UNUserNotificationCenter` for local notifications does not require the Push Notifications capability in the entitlements file. That capability is only required for remote APNs notifications.

**Confidence:** HIGH -- Apple documentation, well-established pattern.

### 2. StreakEngine (NEW)

**Layer:** Engines (pure struct, static methods)
**Type:** `struct` with static methods -- matches WorkloadCalculator, RecoveryScoreEngine, PRDetector
**Location:** `WorkloadApp/Services/StreakEngine.swift`

```swift
struct StreakEngine {
    struct StreakResult {
        let currentStreak: Int          // consecutive periods with activity
        let longestStreak: Int          // all-time best
        let lastActivityDate: Date?     // most recent session/check-in
        let streakType: StreakType      // .daily or .weekly
    }

    enum StreakType {
        case daily
        case weekly
    }

    /// Compute streak from a list of activity dates.
    /// For weekly streaks: each calendar week with >= 1 activity counts.
    /// For daily streaks: each calendar day with >= 1 activity counts.
    static func computeStreak(
        activityDates: [Date],
        type: StreakType = .weekly
    ) -> StreakResult {
        // Bucket dates by week/day, count consecutive buckets from today backwards
    }
}
```

**Design decision: Weekly streaks, not daily.** Fitness apps with daily streak requirements punish rest days and cause user frustration. Weekly streaks (at least 1 workout OR wellness check-in per calendar week) align with the app's recovery-first philosophy. The athlete's `trainingFrequency` is already stored on the Athlete model, providing natural context for what "consistent" means.

**No new @Model needed.** Computed from existing `WorkoutSession.sessionDate` and `WellnessCheckIn.date` arrays, which are already fetched by `@Query` in DashboardView.

**Confidence:** HIGH -- pure computation, no external dependencies.

### 3. PDFExportEngine (NEW)

**Layer:** Engines (pure struct, static methods)
**Type:** `struct` with static methods -- matches CSVExportEngine pattern exactly
**Location:** `WorkloadApp/Services/PDFExportEngine.swift`

```swift
struct PDFExportEngine {
    /// Generate a multi-page training report PDF.
    /// Page 1: Athlete info + current status (recovery score, ACWR, recommendation)
    /// Page 2: Session history table (date, sport, RPE, volume, load)
    /// Page 3: PR summary table
    ///
    /// IMPORTANT: No raw HealthKit data (HRV, RHR, sleep duration).
    /// Only composite scores (recovery score, ACWR, TSB).
    static func generateReport(
        athlete: Athlete,
        sessions: [WorkoutSession],
        workloadSnapshots: [WorkloadSnapshot],
        recoverySnapshots: [RecoverySnapshot],
        personalRecords: [PersonalRecord],
        dateRange: ClosedRange<Date>? = nil
    ) -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        return renderer.pdfData { context in
            // Page 1: Summary header, current metrics
            // Page 2: Session history table
            // Page 3: Personal records
        }
    }
}
```

**Why UIGraphicsPDFRenderer over ImageRenderer:**
- ImageRenderer (iOS 16+) captures SwiftUI views as rasterized images -- text is not selectable, looks blurry when zoomed
- UIGraphicsPDFRenderer produces vector PDF with selectable, searchable text
- For a data report (tables, numbers), vector is strongly preferred
- UIGraphicsPDFRenderer is UIKit but works fine from SwiftUI context via `@MainActor`
- DM Sans font can be drawn via `NSAttributedString` with `UIFont(name: "DMSans-Regular", size:)`

**Confidence:** HIGH -- UIGraphicsPDFRenderer is stable Apple API available since iOS 10.

### 4. ExportSheet (NEW)

**Layer:** Views
**Type:** SwiftUI View presenting format picker + share sheet
**Location:** `WorkloadApp/Views/Profile/ExportSheet.swift`

The existing WorkloadView already has CSV export via temp file + `UIActivityViewController`. The new ExportSheet follows the same pattern but adds PDF option. Can be triggered from ProfileView (for full athlete report) or WorkloadView (for workload-specific export).

**Subscription gating:** PDF export should be gated behind `isPro`, matching how CSV export is already gated in WorkloadView (`UpgradeSheet(trigger: .export)` pattern applies directly).

### 5. AppContainer Modifications

Add one property:

```swift
let notificationService: NotificationService
```

Initialize in `init()`:

```swift
self.notificationService = NotificationService()
```

This follows the exact pattern used for `healthKitService`. No other changes to AppContainer needed.

## Patterns to Follow

### Pattern 1: Pure Engine for New Computation
**What:** StreakEngine and PDFExportEngine follow the established engine pattern.
**When:** Any new business logic or data transformation.
**Why:** Matches WorkloadCalculator, RecoveryScoreEngine, CSVExportEngine -- all pure structs with static methods, no state, no dependencies beyond Models.
**Rule:** If it computes something, it goes in an engine. If it talks to an OS API, it goes in a service.

### Pattern 2: Service for OS API Integration
**What:** NotificationService wraps UNUserNotificationCenter, same as HealthKitService wraps HealthKit.
**When:** Interfacing with system frameworks that require authorization or have lifecycle.
**Why:** Keeps OS coupling isolated. AppContainer owns the service instance. Views access via `@Environment(AppContainer.self)`.

### Pattern 3: Export via Temp File + UIActivityViewController
**What:** Generate file data -> write to temp directory -> present system share sheet.
**When:** Any export feature (CSV already works this way in WorkloadView).
**Why:** System share sheet handles AirDrop, Mail, Files, Messages without custom UI.

**Existing implementation reference (WorkloadView lines 188-208):**
```swift
let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
try csvData.write(to: tempURL, atomically: true, encoding: .utf8)
exportFileURL = tempURL
// Then present via .sheet with ActivityViewController
```

### Pattern 4: Computed Values Over Stored State
**What:** Streak counts computed from existing session/check-in dates, not stored as separate model.
**When:** Derived metrics that can be recomputed cheaply from source data.
**Why:** Avoids sync complexity (no new Supabase table), no data staleness, follows how ACWR/TSB are computed from snapshots on-the-fly.

### Pattern 5: Pre-Permission Screen Before System Prompt
**What:** Show custom UI explaining notification value before triggering the system permission dialog.
**When:** First time requesting notification authorization.
**Why:** Apple rejects apps that immediately show system permission prompts without context. Users who dismiss without understanding cannot easily re-enable. A custom screen explaining "Get a weekly training summary every Monday" with a "Turn on" button improves opt-in rates and avoids App Review rejection.

## Anti-Patterns to Avoid

### Anti-Pattern 1: Remote Push for Time-Based Notifications
**What:** Setting up APNs certificates, Supabase Edge Functions, device token storage for weekly summary.
**Why bad:** Massive infrastructure complexity (certificate management, token rotation, Edge Function deployment, Supabase `device_tokens` table) for a notification that fires at a fixed time.
**Instead:** Use `UNCalendarNotificationTrigger` with `repeats: true`. Upgrade to remote push only when event-driven notifications are needed (coach assigns workout, PR achieved during background sync).

### Anti-Pattern 2: New SwiftData @Model for Streaks
**What:** Creating a `StreakRecord` @Model class to persist streak state.
**Why bad:** Adds a new table to SwiftData schema, requires migration, needs Supabase table + sync, introduces staleness (streak computed at save time may not match current reality).
**Instead:** Compute streak on-the-fly from existing WorkoutSession and WellnessCheckIn date arrays. The computation is O(n) on session count, trivially fast for hundreds of sessions.

### Anti-Pattern 3: ImageRenderer for PDF Reports
**What:** Using SwiftUI's `ImageRenderer` to capture a view as PDF pages.
**Why bad:** Produces rasterized content -- text is not selectable, looks blurry at zoom, file size is larger.
**Instead:** Use `UIGraphicsPDFRenderer` with `NSAttributedString` for text drawing. Produces vector PDF with selectable text, smaller file size, professional appearance.

### Anti-Pattern 4: Requesting Notification Permission at App Launch
**What:** Calling `requestAuthorization()` immediately in `AppRouter.task`.
**Why bad:** System prompt appears without context. User likely denies. App Review may reject for poor UX.
**Instead:** Show a pre-permission screen first, then trigger system prompt only after user taps "Enable".

## Files Changed Summary

### New Files (5)

| File | Layer | Type | Purpose |
|------|-------|------|---------|
| `Services/NotificationService.swift` | Service | `@MainActor @Observable final class` | Local notification scheduling + permission |
| `Services/StreakEngine.swift` | Engine | `struct` (static methods) | Streak computation from activity dates |
| `Services/PDFExportEngine.swift` | Engine | `struct` (static methods) | PDF report generation via UIGraphicsPDFRenderer |
| `Views/Profile/ExportSheet.swift` | View | `struct View` | Export format picker + share sheet |
| `Views/Dashboard/StreakBadge.swift` | View | `struct View` | Streak count display component |

### Modified Files (4)

| File | Change | Risk |
|------|--------|------|
| `App/AppContainer.swift` | Add `notificationService` property + init | LOW -- additive only |
| `App/AppRouter.swift` | Trigger notification authorization after auth (via pre-permission flow) | LOW -- one conditional in `.task` |
| `ViewModels/DashboardViewModel.swift` | Add `streakCount`, `longestStreak` properties + compute in `load()` | LOW -- additive properties |
| `Views/Profile/ProfileView.swift` | Add Notifications toggle section + Export Report button | LOW -- additive UI sections |

### Xcode Project Changes

| Change | Details |
|--------|---------|
| Add new .swift files to target | 5 new files must be added to Xcode project build target |
| No new entitlements | Local notifications do not require Push Notification capability |
| No Info.plist changes | `UNUserNotificationCenter` does not require a usage description |
| No new frameworks | UserNotifications is an Apple system framework, auto-linked |

**No new SwiftData models. No schema migration. No new Supabase tables. No new entitlements.**

## Build Order (Dependency-Aware)

The features have minimal interdependencies. Optimal sequencing:

1. **StreakEngine + StreakBadge + DashboardViewModel changes** -- Zero dependencies on other new features. Pure computation + pure view. Can be tested immediately with existing data.

2. **NotificationService + AppContainer modification + pre-permission UI** -- Independent of streaks/export. Requires testing on physical device (simulator notifications have limitations). Pre-permission screen is a new view that should be reviewed for design system compliance.

3. **PDFExportEngine + ExportSheet + ProfileView export section** -- Most complex new code (PDF layout with DM Sans, tables, HealthKit compliance). Benefits from having streak data available to include in reports. Depends on existing CSVExportEngine pattern for reference.

4. **App Store compliance audit + QA** -- Must happen last, after all features are implemented, as it validates the complete app state. Includes: restore purchases verification, demo account setup, privacy policy link check, PrivacyInfo.xcprivacy update, notification permission flow review.

## App Store Compliance Architecture Considerations

These are architectural/configuration items, not feature code:

| Requirement | Current Status | Action Needed |
|-------------|---------------|---------------|
| Restore Purchases button | Exists in UpgradeSheet | Verify visible and functional -- Apple tests this |
| Privacy Policy link | Exists (Phase 5) | Verify accessible from ProfileView |
| Terms of Service link | Exists (Phase 5) | Verify accessible |
| PrivacyInfo.xcprivacy | Exists in Resources | Verify it covers any new API usage (UserNotifications) |
| Demo account for review | Not configured | Create test Supabase account; provide credentials in App Review notes |
| HealthKit usage description | Exists in Info.plist | No change needed |
| Notification permission UX | Not yet implemented | Pre-permission screen required before system prompt |
| Subscription terms display | Exists in UpgradeSheet | Verify shows price, duration, auto-renewal terms per Apple guidelines |
| "Sign in with Apple" | Not implemented | Not required if email/password auth is sole method -- but Apple may suggest it |
| Minimum functionality without subscription | App works (limited history) | Verify free tier is not "too limited" per Apple guidelines |

**Demo account is critical.** Apple reviewers must be able to test the full app. Since Tonus uses Supabase Auth, a pre-created test account with seeded data is necessary. Include credentials in App Review Notes field. Ensure the account has sufficient data to see dashboard, workload charts, and recovery scores.

## Scalability Considerations

| Concern | At 100 users | At 10K users | At 1M users |
|---------|--------------|--------------|-------------|
| Notifications | Local only, zero server cost | Local only, zero server cost | Consider server-push for coach notifications |
| Streak computation | O(n) on ~50 sessions, instant | Same, per-device | Cache last-computed streak in UserDefaults |
| PDF generation | <100ms | <100ms (client-side) | No scaling concern |
| Export file size | ~50KB PDF | ~50KB PDF | No scaling concern |

All features are client-side. No server infrastructure changes needed for v1.1.

## Sources

- [Apple: Scheduling a notification locally from your app](https://developer.apple.com/documentation/usernotifications/scheduling-a-notification-locally-from-your-app) -- HIGH confidence
- [Apple: UNUserNotificationCenter](https://developer.apple.com/documentation/usernotifications/unusernotificationcenter) -- HIGH confidence
- [Apple: UIGraphicsPDFRenderer](https://developer.apple.com/documentation/uikit/uigraphicspdfrenderer) -- HIGH confidence
- [Apple: App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) -- HIGH confidence
- [Hacking with Swift: Render PDFs using UIGraphicsPDFRenderer](https://www.hackingwithswift.com/example-code/uikit/how-to-render-pdfs-using-uigraphicspdfrenderer) -- MEDIUM confidence
- [Hacking with Swift: Scheduling local notifications](https://www.hackingwithswift.com/books/ios-swiftui/scheduling-local-notifications) -- MEDIUM confidence
- [iOS App Store Review Guidelines 2026](https://theapplaunchpad.com/blog/ios-app-store-review-guidelines/) -- MEDIUM confidence
- [Top Reasons iOS Apps Get Rejected 2026](https://www.eitbiz.com/blog/top-reasons-ios-apps-get-rejected-by-the-app-store-and-fixes/) -- MEDIUM confidence
- [RevenueCat: Gamification in apps guide](https://www.revenuecat.com/blog/growth/gamification-in-apps-complete-guide/) -- MEDIUM confidence (streak design)
- Existing codebase: CSVExportEngine.swift, HealthKitService.swift, AppContainer.swift, WorkloadView.swift export pattern, DashboardViewModel.swift

---

*Architecture research: 2026-04-22 -- v1.1 App Store Launch milestone*
