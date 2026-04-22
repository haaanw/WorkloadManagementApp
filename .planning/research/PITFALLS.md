# Domain Pitfalls

**Domain:** App Store submission, push notifications, streak tracking, PDF export, and performance optimization for existing SwiftUI+SwiftData+HealthKit fitness app
**Researched:** 2026-04-22

## Critical Pitfalls

Mistakes that cause App Store rejection, compliance violations, or major rework.

### Pitfall 1: App Store Rejection for HealthKit Compliance Violations

**What goes wrong:** Apple rejects the app for violating HealthKit-specific review guidelines. The most common rejection message is: "Your app uses HealthKit, but does not appear to include any primary features that require health or fitness data." Even though Tonus uses HealthKit extensively as its core feature, reviewers may not see it if the demo account lacks HealthKit data during review.

**Why it happens:** App Review runs on real devices but cannot generate HealthKit data (no wearable attached). If the reviewer sees empty states everywhere (no HRV, no sleep, no RHR), they may conclude HealthKit is not a "primary feature" and reject under Guideline 5.1.3.

**Consequences:** Rejection delays launch by 1-2 weeks per resubmission cycle.

**Prevention:**
- Provide detailed Review Notes explaining: (1) HealthKit is the core data source for recovery scoring, (2) the app displays composite scores derived from HRV/RHR/sleep, (3) empty states appear when no wearable data exists, and this is expected behavior
- Include screenshots showing the app WITH data (use SCREENSHOT_MODE) alongside a note explaining the full data flow
- Consider adding a "sample data" onboarding option that populates mock workout/wellness data (not HealthKit data) so the reviewer sees non-empty dashboards
- Ensure the HealthKit permission dialog appears early and the purpose strings clearly explain each data type's role

**Detection:** Before submission, test the full app flow with HealthKit authorization denied and all HealthKit data empty. Verify the app still communicates what it does and why HealthKit matters.

**App Store Guidelines:** 5.1.3(i), 5.1.3(ii), 2.1

**Phase relevance:** App Store submission phase -- must address in Review Notes and metadata.

---

### Pitfall 2: HealthKit Data Leaking into PDF/CSV Exports

**What goes wrong:** PDF export for coaches accidentally includes raw HealthKit data (actual HRV values, RHR readings, sleep durations) rather than only composite scores. This violates the app's own privacy constraint and potentially Apple's HealthKit guidelines.

**Why it happens:** The existing CSVExportEngine correctly excludes raw HealthKit data, but a new PDF export engine built independently might pull from different data sources or include "helpful" raw metrics without realizing the constraint. RecoverySnapshot stores composite scores, but the underlying HealthKit queries return raw values that could be passed through.

**Consequences:** Violates Guideline 5.1.3(i) -- HealthKit data may not be shared with third parties except to improve health management. If a coach receives a PDF with raw HRV data for their athlete, that is third-party sharing of HealthKit data. Could trigger App Store rejection or post-launch removal.

**Prevention:**
- PDF export MUST use the same data boundary as CSVExportEngine: only composite scores (recovery score, ACWR, ATL, CTL), never raw HRV/RHR/sleep values
- Add a compile-time or code-review gate: any export function that touches `HKQuantityType` or raw health values is a violation
- Document the rule in the export engine's header comment (as CSVExportEngine already does)
- Coach-shared exports should only contain: session summaries, load metrics, composite recovery scores, training phase labels

**Detection:** Grep any new export code for `HKQuantity`, `heartRateVariabilitySDNN`, `restingHeartRate`, `sleepAnalysis`. If found in export path, it is a violation.

**App Store Guidelines:** 5.1.2(vi), 5.1.3(i)

**Phase relevance:** PDF export feature.

---

### Pitfall 3: Push Notification Permission Prompt at Wrong Time

**What goes wrong:** The app requests notification permission on first launch or immediately after signup. Users who are not yet invested in the app decline, and iOS does not re-prompt. The weekly summary notification feature becomes permanently unavailable without the user digging into Settings.

**Why it happens:** Developers add `UNUserNotificationCenter.requestAuthorization()` early in the app lifecycle for simplicity. Apple's guidelines (4.5.4) state push notifications must not be required for app functionality, but poor timing means the feature is silently disabled for most users.

**Consequences:** Low notification opt-in rate (industry average for poorly-timed prompts is 40-50% vs 70-80% for contextual prompts). Users never see the weekly summary feature they are paying for with Pro.

**Prevention:**
- Use a "pre-permission" pattern: show an in-app screen explaining what notifications will deliver ("Weekly training summary every Monday at 8am") with a "Turn On" button. Only call `requestAuthorization()` when the user taps that button.
- Place the prompt contextually: after the user completes their first week of training (has >= 2 sessions), offer notifications. They now understand the value.
- If the user has previously denied, detect via `UNUserNotificationCenter.current().getNotificationSettings()` and show a "Notifications are off -- go to Settings" nudge instead of silently failing.
- Never gate app functionality behind notification permission per Guideline 4.5.4.

**Detection:** Test the full flow with notifications denied. Ensure the app never crashes or shows broken UI.

**App Store Guidelines:** 4.5.4

**Phase relevance:** Push notifications feature.

---

### Pitfall 4: Missing AppDelegate for Push Notification Registration

**What goes wrong:** The app is pure SwiftUI with `@main` App struct and no AppDelegate. Push notifications require `application(_:didRegisterForRemoteNotificationsWithDeviceToken:)` and `application(_:didFailToRegisterForRemoteNotificationsWithError:)` which only exist on UIApplicationDelegate. Developers try to use only local notifications to avoid this, but the weekly summary sent from Supabase Edge Functions requires remote (APNs) push.

**Why it happens:** SwiftUI's `@main` App protocol does not expose APNs delegate methods. Adding an AppDelegate to an existing SwiftUI app requires `@UIApplicationDelegateAdaptor` which is a non-trivial retrofit that touches the app's entry point.

**Consequences:** Remote push notifications silently fail. Device tokens are never registered. The Supabase Edge Function sends notifications that never arrive.

**Prevention:**
- Add `@UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate` to `WorkloadApp.swift`
- Create an `AppDelegate` class conforming to `UIApplicationDelegate` with the three required methods: `didRegisterForRemoteNotifications`, `didFailToRegisterForRemoteNotifications`, and `didReceiveRemoteNotification`
- Store the device token in Supabase (in a user_devices table) so Edge Functions can target it
- Alternative: use only local notifications scheduled on-device (avoids APNs entirely) if the weekly summary can be computed locally. This is simpler but means notifications only fire if the app has been opened recently.

**Detection:** After implementing, test on a physical device (simulators can receive test pushes since Xcode 14 but do not register real APNs tokens).

**Phase relevance:** Push notifications feature.

---

### Pitfall 5: App Store Rejection for Incomplete Demo During Review

**What goes wrong:** The app requires Supabase authentication and the reviewer cannot create a meaningful account. They see empty dashboards, no workout history, no recovery data. They reject under Guideline 2.1 (App Completeness).

**Why it happens:** The app's value proposition requires accumulated data over days/weeks. A fresh account shows nothing. The reviewer has ~5 minutes to evaluate the app.

**Consequences:** Rejection under Guideline 2.1. Apple's message: "We were unable to review your app as it requires an account and we were not able to verify the app's features."

**Prevention:**
- Create a dedicated demo account with pre-seeded data (2-3 weeks of workouts, wellness check-ins, recovery snapshots, workload data). Provide credentials in App Store Connect Review Notes.
- Ensure the demo account's Supabase data includes: sessions across multiple sport types, at least one PR, recovery snapshots with varying scores, workload snapshots showing ACWR zones, a coach-athlete relationship (if demonstrating coach features)
- Verify the demo account credentials work before EVERY submission (sessions can expire, Supabase can have issues)
- Add a note: "Demo account pre-loaded with sample data. HealthKit integration requires Apple Watch -- screenshots of live HealthKit data included."
- SCREENSHOT_MODE is debug-only; it cannot be used for App Review. The demo account must be a real Supabase account.

**Detection:** Before each submission, log into the demo account on a clean device and walk through every tab.

**App Store Guidelines:** 2.1

**Phase relevance:** App Store submission phase.

---

### Pitfall 6: Subscription Compliance -- Not Clearly Communicating What is Free vs Pro

**What goes wrong:** Apple rejects because the app does not clearly indicate which features require a subscription before the user encounters a paywall. Or worse, the app appears to offer functionality that immediately hits a purchase gate.

**Why it happens:** Two-tier subscriptions (Athlete Pro + Coach) with feature gating across multiple screens makes it easy to present a feature and then gate it behind a paywall without prior disclosure.

**Consequences:** Rejection under Guidelines 3.1.2(a) and 2.3.2. Apple may also flag the app for "bait-and-switch" if screenshots show features that require purchase.

**Prevention:**
- In App Store metadata (description and screenshots), clearly state which features are free and which require Pro/Coach subscription
- In-app: show lock icons or "Pro" badges on gated features BEFORE the user taps them. Do not let them enter a full flow and then hit a paywall at the last step.
- Ensure the UpgradeSheet clearly states: subscription duration, price, what is included, auto-renewal terms
- Verify the free tier is genuinely usable -- Apple requires that subscription apps provide meaningful free functionality
- RevenueCat's paywall must display Apple-required terms: price, duration, auto-renewal disclosure

**Detection:** Walk through the app as a free user. Count how many times you hit a paywall. If any paywall appears without prior visual indication that the feature is paid, fix it.

**App Store Guidelines:** 3.1.2(a), 3.1.2(c), 2.3.2

**Phase relevance:** App Store submission phase.

---

## Moderate Pitfalls

### Pitfall 7: Streak Tracking Creates Toxic Anxiety Instead of Motivation

**What goes wrong:** A rigid daily streak counter (like Duolingo's) creates anxiety, guilt, and eventual app abandonment for athletes who need rest days as part of their training program. Breaking a streak after 30+ days causes users to stop opening the app entirely.

**Why it happens:** Streak mechanics are borrowed from language learning or meditation apps where daily engagement is the goal. In athletic training, rest days are physiologically necessary. A streak that demands daily workouts contradicts the app's own recovery recommendations.

**Prevention:**
- Define streaks around "training consistency" not "daily activity." A streak should survive planned rest days. Options: (a) count weeks where >= N sessions were completed, (b) count consecutive wellness check-ins (which can happen on rest days), (c) count "training blocks" where athlete stayed in their target load range.
- Implement streak freezes (1-2 per week, automatic or manual). Research shows streak freezes improve long-term retention by 40-60%.
- Never punish rest days. If the autoregulation engine recommends a rest day, the streak must not break.
- Make streaks optional/supplementary -- never the primary metric on the dashboard.
- Consider "consistency score" (percentage of target sessions completed this month) instead of binary streak.

**Detection:** Ask: "Does this streak design punish an athlete for following the app's own recovery advice?" If yes, redesign.

**Phase relevance:** Streak tracking feature.

---

### Pitfall 8: PDF Export Memory Pressure on Large Training Histories

**What goes wrong:** Generating a PDF report for an athlete with 6+ months of training data (100+ sessions, thousands of sets) loads all records into memory at once. On older iPhones, this causes memory warnings or crashes.

**Why it happens:** SwiftData's `@Query` and `FetchDescriptor` load full object graphs. A naive implementation fetches all WorkoutSessions with their ExerciseEntries and SetRecords, then renders them to a PDF context. SwiftData has known memory issues with large datasets (documented in Apple Developer Forums).

**Consequences:** App crashes during export on devices with limited RAM. Users lose trust.

**Prevention:**
- Paginate data fetching: process sessions in batches of 20-30, render each batch to the PDF context, then release
- Use `FetchDescriptor` with `fetchLimit` and `fetchOffset` for batched loading
- For PDF rendering, use `UIGraphicsPDFRenderer` which streams pages rather than building the entire document in memory
- Consider offering date-range filters (last 30 days, last 90 days, custom) to limit export scope
- Profile memory usage with Instruments before shipping; set a ceiling of 100MB for the export operation

**Detection:** Test PDF export with 200+ sessions. Monitor memory in Instruments. If peak exceeds 150MB, optimize.

**Phase relevance:** PDF export feature.

---

### Pitfall 9: SwiftUI ImageRenderer Limitations for PDF Generation

**What goes wrong:** Developers try to use SwiftUI's `ImageRenderer` (iOS 16+) to render SwiftUI views directly to PDF. This works for simple views but fails silently or produces incorrect output for views that depend on `@Environment`, `@Query`, or async data loading. Charts may render blank. Custom fonts may not load.

**Why it happens:** `ImageRenderer` captures a snapshot of the view hierarchy at render time. Views that rely on SwiftUI's runtime environment (EnvironmentValues, ModelContext) are not fully resolved during off-screen rendering. The DM Sans custom font may not be available in the render context.

**Consequences:** PDFs contain blank charts, missing fonts (falls back to system font), or incomplete data. Users receive broken exports.

**Prevention:**
- Use `UIGraphicsPDFRenderer` with manual Core Graphics drawing instead of trying to render SwiftUI views. This is more work but completely reliable.
- If using `ImageRenderer`, create self-contained views with all data passed as parameters (no @Environment, no @Query, no @Observable). Inject the font explicitly.
- Test PDF output on both simulator and physical device -- rendering differences exist.
- For charts: render chart data to Core Graphics paths directly rather than trying to snapshot a SwiftUI Charts view.

**Detection:** Generate a PDF and open it. Check: are fonts correct? Are charts populated? Is all data present? Compare against the on-screen view.

**Phase relevance:** PDF export feature.

---

### Pitfall 10: Push Notification Token Lifecycle Mismanagement

**What goes wrong:** The app registers the APNs device token once and stores it in Supabase. Over time, the token changes (device restore, OS update, app reinstall) but the stored token is never updated. Supabase Edge Functions send to stale tokens, which APNs rejects. Notifications silently stop working.

**Why it happens:** `application(_:didRegisterForRemoteNotificationsWithDeviceToken:)` is called on every app launch, but developers only store the token on first registration. Token rotation is not handled.

**Consequences:** Notifications work for early adopters but gradually stop working. No error is visible to the user or developer without APNs feedback monitoring.

**Prevention:**
- Store/update the device token in Supabase on EVERY call to `didRegisterForRemoteNotifications`, not just the first time. Use an upsert on (user_id, device_token).
- When the user logs out, delete their device token from Supabase.
- When the user logs in on a new device, register the new token.
- Handle `didFailToRegisterForRemoteNotifications` -- log the error, do not crash.
- APNs sandbox tokens do not work in production and vice versa. Ensure the Edge Function targets the correct APNs environment.

**Detection:** Log token registration events. After a month, check how many stored tokens are still valid by monitoring APNs feedback.

**Phase relevance:** Push notifications feature.

---

### Pitfall 11: Performance Regression from @Query Overuse in Complex Views

**What goes wrong:** The app already has 80+ files with heavy `@Query` usage. Adding streak tracking and enhanced dashboard views adds more queries. SwiftData re-evaluates ALL active `@Query` properties whenever the ModelContext changes. A single workout save can trigger re-evaluation of queries across Dashboard, WorkoutLog, Recovery, Workload, and now Streak views simultaneously.

**Why it happens:** SwiftData's `@Query` is reactive -- any write to the ModelContext triggers observation notifications. With 15+ active queries across tabs, a single insert causes a cascade of fetch operations. SwiftData on iOS 17 has documented memory issues with concurrent query evaluation.

**Consequences:** Jank when saving workouts (noticeable frame drops). Increased memory usage. On older devices (iPhone 12 and earlier), potential OOM kills.

**Prevention:**
- Audit active `@Query` usage across all visible views. Views in non-visible tabs should NOT have active queries (lazy loading).
- Use `FetchDescriptor` in ViewModels for one-shot data loading instead of reactive `@Query` where real-time updates are not needed (e.g., streak calculation, export data).
- Add `fetchLimit` to ALL queries that display lists -- never fetch unbounded result sets.
- Profile with Instruments (SwiftData template) before and after adding new features. Set a performance budget: main thread should not block > 16ms for any query.

**Detection:** Save a workout and monitor frame rate across all tabs using Instruments. Any frame drop > 50ms during save is a red flag.

**Phase relevance:** Performance optimization phase.

---

### Pitfall 12: Privacy Manifest Not Updated for New Features

**What goes wrong:** Adding push notifications changes the data collection profile (device tokens are PII). Adding streak tracking may use UserDefaults for persistence. The existing PrivacyInfo.xcprivacy is not updated, causing App Store rejection during the automated privacy review.

**Why it happens:** The privacy manifest was written for the current feature set and covers Health data, Fitness data, purchase history, user ID, email, and name. New features that collect or access additional data require manifest updates.

**Consequences:** Binary rejection during automated App Store processing (before human review even begins).

**Prevention:**
- If adding push notifications: no new NSPrivacyCollectedDataType needed (device tokens are not a declared category), but ensure the UserDefaults API reason (CA92.1) covers any new UserDefaults usage for notification preferences
- If storing device tokens in Supabase: this is covered under existing "UserID" collection since it is linked to the user account
- If adding any new Required Reason API usage (disk space, file timestamps, etc.), add the corresponding entry
- Review Apple's "Required Reason APIs" list before each submission: https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api

**Detection:** Before submission, diff the PrivacyInfo.xcprivacy against the feature set. Every piece of collected data must be declared.

**App Store Guidelines:** 5.1.1(i)

**Phase relevance:** App Store submission phase.

---

## Minor Pitfalls

### Pitfall 13: PDF Export File Sharing Fails Silently on iPad

**What goes wrong:** `UIActivityViewController` presentation behaves differently on iPad vs iPhone. On iPad, it requires a `popoverPresentationController` sourceView/sourceRect or it crashes. SwiftUI's `ShareLink` handles this automatically, but if using UIKit presentation (common for PDF export), the iPad crash is not caught during iPhone-only testing.

**Prevention:**
- Use SwiftUI's `ShareLink` (iOS 16+) instead of manual UIActivityViewController presentation. It handles iPad popover automatically.
- If UIKit is needed, always set `popoverPresentationController.sourceView` and `sourceRect`.
- Test on iPad simulator before submission.

**Phase relevance:** PDF export feature.

---

### Pitfall 14: Weekly Summary Notification Scheduled at Wrong Time Zone

**What goes wrong:** The weekly summary notification is scheduled for "Monday 8am" but uses UTC instead of the user's local time zone. Users in UTC-8 receive their notification at midnight Sunday. Users in UTC+12 receive it Tuesday morning.

**Prevention:**
- For local notifications: use `DateComponents` with explicit `Calendar.current` (which respects the device's time zone) when creating `UNCalendarNotificationTrigger`.
- For remote notifications from Supabase Edge Functions: store the user's timezone in Supabase (during onboarding or from device settings) and schedule the Edge Function cron job to send at the user's local 8am. Alternatively, compute the UTC offset per user.
- Test with device set to multiple time zones.

**Phase relevance:** Push notifications feature.

---

### Pitfall 15: App Store Screenshots Show Debug/Test Data

**What goes wrong:** Screenshots captured via SCREENSHOT_MODE show mock data that is obviously fake ("John Doe", perfectly round numbers, suspiciously clean charts). Apple may reject for Guideline 2.3 (Accurate Metadata) if screenshots do not represent the actual app experience.

**Prevention:**
- Use realistic mock data in SCREENSHOT_MODE: varied names, imperfect numbers, realistic date distributions.
- Ensure screenshots show the same UI the reviewer will see with the demo account (minus HealthKit data).
- Never show placeholder images or Lorem Ipsum text in screenshots.
- Include a mix of populated states and appropriate empty states (e.g., new user with welcome card).

**App Store Guidelines:** 2.3

**Phase relevance:** App Store submission phase.

---

### Pitfall 16: Streak Data Not Syncing Between Devices via Supabase

**What goes wrong:** Streak state is stored locally (UserDefaults or SwiftData) but not synced to Supabase. A user who logs workouts on their iPad does not see the streak update on their iPhone.

**Prevention:**
- Store streak data (current streak count, last qualifying date, freeze count) in the Athlete model or a dedicated SwiftData model that syncs via the existing SyncService.
- Compute streaks from the source of truth (WorkoutSession dates + WellnessCheckIn dates) rather than maintaining a separate counter that can drift.
- If computing from source data, ensure the computation handles timezone-aware day boundaries correctly.

**Phase relevance:** Streak tracking feature.

---

### Pitfall 17: App Thinning and Binary Size Bloat from PDF Resources

**What goes wrong:** Embedding large template images, fonts, or static assets for PDF generation inflates the app binary. Apple has a 200MB cellular download limit. While Tonus is unlikely to hit this, unnecessary binary growth slows downloads and updates.

**Prevention:**
- PDF templates should be generated programmatically (Core Graphics), not from embedded template files.
- DM Sans fonts are already bundled (~55KB each); do not add additional font weights for PDF generation.
- If including chart images in PDFs, render them at export time rather than bundling pre-rendered assets.

**Phase relevance:** PDF export feature.

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| App Store Submission | Rejection for empty HealthKit data during review | Pre-seed demo account, detailed Review Notes (Pitfall 1, 5) |
| App Store Submission | Subscription disclosure insufficient | Clear free vs Pro delineation in metadata and UI (Pitfall 6) |
| App Store Submission | Privacy manifest outdated | Audit PrivacyInfo.xcprivacy against new features (Pitfall 12) |
| App Store Submission | Screenshots misrepresent app | Use realistic mock data, match reviewer experience (Pitfall 15) |
| Push Notifications | Permission prompt at wrong time | Contextual pre-permission after first training week (Pitfall 3) |
| Push Notifications | No AppDelegate for APNs | Add UIApplicationDelegateAdaptor to WorkloadApp (Pitfall 4) |
| Push Notifications | Token staleness over time | Upsert token on every launch (Pitfall 10) |
| Push Notifications | Wrong timezone for weekly summary | Use Calendar.current or store user timezone (Pitfall 14) |
| Streak Tracking | Punishes rest days, contradicts recovery advice | Define streaks around consistency, not daily activity (Pitfall 7) |
| Streak Tracking | Data not syncing cross-device | Compute from source data, sync via SyncService (Pitfall 16) |
| PDF Export | Raw HealthKit data in export | Mirror CSVExportEngine's data boundary (Pitfall 2) |
| PDF Export | Memory crash on large histories | Batch fetch, stream PDF pages (Pitfall 8) |
| PDF Export | ImageRenderer fails for complex views | Use UIGraphicsPDFRenderer with manual drawing (Pitfall 9) |
| Performance | @Query cascade on ModelContext writes | Audit query count, use fetchLimit, lazy tab loading (Pitfall 11) |

## App Store Review Guidelines Quick Reference

Sections most relevant to Tonus v1.1 submission:

| Section | Topic | Risk to Tonus |
|---------|-------|---------------|
| **2.1** | App Completeness | Demo account must show full functionality |
| **2.3** | Accurate Metadata | Screenshots must reflect real app experience |
| **2.3.2** | In-App Purchase Metadata | Must clearly indicate paid features in description |
| **3.1.2(a)** | Subscriptions | Must provide ongoing value, clear terms |
| **3.1.2(c)** | Subscription Information | Must describe what user gets for the price |
| **4.5.4** | Push Notifications | Not required for function, opt-in for marketing, visible opt-out |
| **5.1.1(i)** | Privacy Policy | Must be in App Store Connect AND in-app |
| **5.1.2(vi)** | HealthKit Data Restrictions | No marketing, advertising, or data mining |
| **5.1.3(i)** | Health Data Use | No third-party sharing except for health improvement |
| **5.1.3(ii)** | HealthKit Accuracy | No false data, no iCloud storage of health data |

## Sources

- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) -- Apple (2025)
- [HealthKit Privacy Documentation](https://developer.apple.com/documentation/healthkit/protecting-user-privacy) -- Apple
- [iOS App Store Requirements for Health Apps](https://blog.dashsdk.com/app-store-requirements-for-health-apps/) -- Dash Solutions
- [App Store Review Guidelines Checklist](https://nextnative.dev/blog/app-store-review-guidelines) -- NextNative (2025)
- [The Ultimate Guide to App Store Rejections](https://www.revenuecat.com/blog/growth/the-ultimate-guide-to-app-store-rejections/) -- RevenueCat
- [High Performance SwiftData Apps](https://blog.jacobstechtavern.com/p/high-performance-swiftdata) -- Jacob's Tech Tavern
- [SwiftData Performance Optimization](https://www.hackingwithswift.com/quick-start/swiftdata/how-to-optimize-the-performance-of-your-swiftdata-apps) -- Hacking with Swift
- [How to Render a SwiftUI View to PDF](https://www.hackingwithswift.com/quick-start/swiftui/how-to-render-a-swiftui-view-to-a-pdf) -- Hacking with Swift
- [Designing Streaks for Long-Term User Growth](https://trophy.so/blog/designing-streaks-for-long-term-user-growth) -- Trophy
- [Breaking the Chain: Why Streak Features Fail ADHD Users](https://www.helloklarity.com/post/breaking-the-chain-why-streak-features-fail-adhd-users-and-how-to-design-better-alternatives/) -- Klarity Health
- [Supabase Push Notifications Documentation](https://supabase.com/docs/guides/functions/examples/push-notifications) -- Supabase
- [Sending Push Notifications from Supabase](https://www.pingram.io/blog/send-custom-notifications-from-supabase-with-examples-2025) -- Pingram (2025)
- [SwiftData Large Data Performance](https://developer.apple.com/forums/thread/742336) -- Apple Developer Forums
- [SwiftData Memory Issues iOS 18](https://developer.apple.com/forums/thread/761522) -- Apple Developer Forums
