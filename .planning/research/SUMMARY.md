# Project Research Summary

**Project:** Tonus v1.1 — App Store Launch
**Domain:** iOS fitness/training app (SwiftUI + SwiftData + HealthKit)
**Researched:** 2026-04-22
**Confidence:** HIGH

## Executive Summary

Tonus is a functionally complete iOS athlete workload management app entering its App Store launch preparation milestone. The codebase already ships auth, sync, subscriptions, training load analytics, recovery scoring, coach-athlete relationships, and onboarding. The v1.1 milestone adds three engagement features (streak tracking, weekly push notifications, PDF export) and then completes the submission pipeline (ASO metadata, QA, performance audit, App Review compliance). All three features integrate cleanly as leaf additions to the existing Views → ViewModels → Pipelines → Engines → Repositories → Models stack with no core refactoring — five new files, four modified files, zero new SPM packages, zero new SwiftData models.

The recommended approach keeps third-party dependencies at zero: notifications use Apple's `UserNotifications` framework with local scheduling, streaks use a new pure-struct engine computed from existing `WorkoutSession` and `WellnessCheckIn` dates, and PDF export uses `UIGraphicsPDFRenderer` drawing against the already-bundled DM Sans fonts. The deliberate no-new-SPM-packages stance eliminates binary bloat, App Review risk from third-party SDKs, and privacy manifest complexity. Development tooling adds only `fastlane` (not compiled into the app) for screenshot upload automation to App Store Connect.

The dominant risks are App Store-facing, not engineering. The four highest-probability rejection causes are: HealthKit compliance failure when the App Review demo account lacks wearable data, an incomplete demo account that makes the app appear non-functional, raw HealthKit values leaking into PDF exports (violating Guideline 5.1.3(i)), and a notification permission prompt triggered before users understand the value. All four have known, straightforward mitigations that are configuration and process work, not engineering work.

## Key Findings

### Recommended Stack

The existing stack (SwiftUI, SwiftData, HealthKit, Supabase Swift SDK, RevenueCat, Accelerate, Swift Charts) requires no changes. The only new Apple framework is `UserNotifications` for local notification scheduling; `MetricKit` is added for post-launch production performance telemetry. Both are available on iOS 17+ with no entitlement additions. `fastlane deliver` is the only new dev tooling, used exclusively for automating ASO metadata and screenshot uploads to App Store Connect.

**Core technologies:**
- `UserNotifications` (Apple): local weekly summary notifications — avoids APNs infrastructure entirely; weekly summary computes from on-device SwiftData, no server-side trigger needed
- `UIGraphicsPDFRenderer` (UIKit): vector PDF generation — produces selectable text, smaller files, professional quality vs rasterized `ImageRenderer`
- `MetricKit` (Apple): production performance telemetry — zero-dependency alternative to Firebase Performance, receives aggregated reports from real user devices
- `fastlane deliver`: ASO metadata + screenshot upload pipeline — wraps App Store Connect API; integrates with the existing `ScreenshotTests` XCUITest target

### Expected Features

**Must have (table stakes):**
- App Store metadata (title 30 chars, subtitle 30 chars, keyword field 100 chars, description) — required for submission; primary discovery mechanism; description is NOT indexed but is human-facing
- Marketing-quality screenshots (6.7" and 6.5" device sizes with benefit-oriented captions) — most influential conversion factor; framework already exists
- App Review compliance pass (PrivacyInfo.xcprivacy, demo account, subscription terms, HealthKit descriptions, all links working) — one rejection costs 1-2 weeks per resubmission cycle
- Systematic QA pass across all features and edge states — crashes during review cause automatic rejection
- Performance audit (cold launch < 2s, 60fps scroll, no memory leaks, profile on oldest supported device)

**Should have (competitive differentiators):**
- Streak tracking (workout + wellness check-in streaks) — behavioral retention hook; Athlytic and Duolingo-validated mechanic; ships fast as a pure engine with no infrastructure
- Weekly push notification summary — retention driver; 1 notification/week is the safe range for fitness apps; local-only via `UNCalendarNotificationTrigger` with no server dependency
- PDF report export (gated Pro/Coach) — coaches expect formatted reports at this price point; TrainingPeaks and TeamBuildr offer this; builds on existing `CSVExportEngine` data queries

**Defer (post-launch):**
- Share cards (social summaries via `ImageRenderer`) — low effort but not blocking submission; safe for post-launch
- Remote push notifications (coach-assigns-workout events) — warranted at v1.2 when event-driven coach actions require server-side triggers
- Custom Product Pages (CPPs) for athlete vs coach search intents — good ASO strategy but non-blocking for initial launch

### Architecture Approach

All new features integrate as leaf additions at the appropriate layer with no changes to existing data flows. Five new files are added (NotificationService, StreakEngine, PDFExportEngine, ExportSheet view, StreakBadge component) and four existing files are lightly modified (AppContainer adds `notificationService`, AppRouter adds contextual permission flow, DashboardViewModel adds streak computation, ProfileView adds export and notification sections). Critically: no new SwiftData `@Model` classes, no schema migration, no new Supabase tables, and no new entitlements.

**Major new components:**
1. `NotificationService` — `@MainActor @Observable final class` wrapping `UNUserNotificationCenter`; schedules weekly `UNCalendarNotificationTrigger`; mirrors `HealthKitService` pattern in `Services/`
2. `StreakEngine` — pure `struct` with static methods; computes current and longest streak from `[Date]` arrays using weekly cadence (not daily, to respect rest days); follows `WorkloadCalculator` pattern
3. `PDFExportEngine` — pure `struct` with static methods; uses `UIGraphicsPDFRenderer` + `NSAttributedString` with DM Sans; mirrors `CSVExportEngine` HealthKit data boundary (composite scores only, never raw HRV/RHR/sleep values)

### Critical Pitfalls

1. **HealthKit review rejection (Pitfall 1)** — Apple reviewer sees empty dashboards because no wearable is attached to their test device. Mitigation: detailed App Review Notes explaining the data flow, screenshots from `SCREENSHOT_MODE` showing populated state, and a "sample data" option so reviewers see non-empty dashboards.

2. **Incomplete demo account causing Guideline 2.1 rejection (Pitfall 5)** — a fresh Supabase account shows no value to the reviewer in their 5-minute window. Mitigation: pre-seed a dedicated demo account with 2-3 weeks of sessions, wellness check-ins, recovery snapshots, at least one PR, and a coach-athlete relationship; verify credentials before every submission.

3. **Raw HealthKit data in PDF export (Pitfall 2)** — new `PDFExportEngine` accidentally includes HRV/RHR/sleep values, violating Guideline 5.1.3(i). Mitigation: enforce the same data boundary as `CSVExportEngine` (composite scores only); grep any export code for `HKQuantity` as a code-review gate before merging.

4. **Notification permission prompt at wrong time (Pitfall 3)** — calling `requestAuthorization()` at app launch or immediately after signup yields 40-50% denial rate vs 70-80% for contextual prompts. Mitigation: pre-permission screen explaining the weekly summary value; trigger system prompt only after user taps "Turn On," ideally after their first completed training week.

5. **Streak mechanics punishing rest days (Pitfall 7)** — daily streaks contradict the app's own recovery recommendations. Mitigation: weekly streaks (at least 1 session OR check-in per calendar week); never break a streak on a day the autoregulation engine recommended rest.

## Implications for Roadmap

Based on combined research, five phases are suggested in dependency order:

### Phase 1: Streak Tracking
**Rationale:** Zero dependencies on other new features; pure computation engine with no external surfaces. Ships the only fully-internal feature first, providing streak data to enrich the weekly notification content in Phase 2. Validates the engine pattern before tackling more complex features.
**Delivers:** `StreakEngine`, `StreakBadge` component, `DashboardViewModel` streak properties, two streak types (workout + check-in)
**Addresses:** Streak tracking differentiator from FEATURES.md; behavioral retention hook before screenshots are finalized
**Avoids:** Daily-streak-punishes-rest-days anti-pattern (Pitfall 7); no new `@Model` complexity per ARCHITECTURE.md anti-pattern 2

### Phase 2: Push Notifications
**Rationale:** Depends on streak data being available for rich notification content ("4 sessions this week, 3-week streak"). Independent of PDF export. Local-only approach eliminates all server infrastructure risk entirely for v1.1.
**Delivers:** `NotificationService`, pre-permission screen, weekly `UNCalendarNotificationTrigger` scheduled for Monday 9am, ProfileView notifications toggle
**Addresses:** Weekly summary push notification differentiator from FEATURES.md
**Avoids:** Wrong-time permission prompt (Pitfall 3); timezone bug via `Calendar.current` (Pitfall 14); mistaken need for remote APNs (Pitfall 4 — explicitly not needed for local weekly summary)

### Phase 3: PDF Report Export
**Rationale:** Most technically complex new feature (Core Graphics coordinate math, font rendering, HealthKit data boundary enforcement). Benefits from streak data being finalized so it can be included in reports. Reuses `CSVExportEngine` data query patterns and enforces the same export boundary.
**Delivers:** `PDFExportEngine`, `ExportSheet` view, ProfileView export section, subscription gate (Pro/Coach)
**Addresses:** PDF report export differentiator from FEATURES.md; Coach-tier value proposition
**Avoids:** Raw HealthKit data leak (Pitfall 2); `ImageRenderer` limitations for data reports (Pitfall 9); memory pressure on large histories via batched `FetchDescriptor` (Pitfall 8); iPad `UIActivityViewController` crash by using `ShareLink` (Pitfall 13)

### Phase 4: ASO Metadata + Screenshots
**Rationale:** Copywriting and screenshot work is parallelizable during code phases but must be finalized after all features are implemented so screenshots represent the complete product. `fastlane` setup should happen during this phase but captures the app in its final state.
**Delivers:** `fastlane` Fastfile and metadata directory structure, final 6.7" and 6.5" screenshots with marketing captions, keyword-optimized App Store listing targeting long-tail keywords ("workload management", "training load tracker", "ACWR")
**Addresses:** App Store metadata table stakes and discoverability from FEATURES.md; ASO differentiation
**Avoids:** Placeholder or fake-looking screenshots (Pitfall 15); last-minute upload delays

### Phase 5: QA, Performance Audit + App Review Compliance
**Rationale:** Must happen last — validates the complete app including all new features. Performance regression from new `@Query` usage can only be measured after features are built. App Review compliance is a checklist against the finished product state.
**Delivers:** XCTest unit tests for `StreakEngine` and `PDFExportEngine`, XCUITest coverage for new flows, `performAccessibilityAudit()` on all screens, performance baselines (cold launch time, `DashboardViewModel.load` duration), `MetricKit` subscriber registration, demo account with pre-seeded data, `PrivacyInfo.xcprivacy` audit, final compliance checklist
**Addresses:** QA pass and performance audit table stakes from FEATURES.md; all App Review rejection vectors from PITFALLS.md
**Avoids:** HealthKit empty-state rejection (Pitfall 1); demo account rejection (Pitfall 5); subscription disclosure rejection (Pitfall 6); privacy manifest rejection (Pitfall 12); `@Query` cascade performance regression (Pitfall 11)

### Phase Ordering Rationale

- Streak before Notifications: notification content is richer with streak count; both are small phases but the dependency means sequential is cleaner than parallel
- Streak and Notifications before PDF: PDF is the most complex new feature and benefits from a stabilized codebase; it also touches the most data models
- ASO/Screenshots after code phases: screenshots must capture the finished product; keyword decisions can be drafted earlier but execution is last
- QA/Compliance always last: validates everything that came before; unknown bug scope means time must be reserved

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 3 (PDF Export):** Core Graphics layout math for multi-page reports with DM Sans requires careful `NSAttributedString` attribute validation; HealthKit data boundary implementation needs an explicit review checklist before code review
- **Phase 5 (QA + Compliance):** Scope is unknown until bugs are found; `PrivacyInfo.xcprivacy` required-reason API list changes with each OS version; RevenueCat subscription term display requirements may have updated since last submission

Phases with standard patterns (skip research-phase):
- **Phase 1 (Streak Engine):** Pure Swift date arithmetic; well-understood problem domain; analogous to `WorkloadCalculator` pattern already in the codebase
- **Phase 2 (Push Notifications):** Apple documentation is comprehensive and directly applicable; local-only approach eliminates all server-side complexity
- **Phase 4 (ASO):** Copywriting and `fastlane` invocation; no novel technical territory

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All recommendations are Apple-native frameworks with official documentation; zero new SPM packages eliminates version-compatibility uncertainty entirely |
| Features | HIGH | Competitor analysis (TrainingPeaks, Athlytic, Alpha Progression, HRV4Training) plus App Store submission requirements are well-documented; feature scope is narrow and bounded |
| Architecture | HIGH | All new components follow existing patterns with direct code references to `CSVExportEngine`, `HealthKitService`, `AppContainer`; no speculative patterns introduced |
| Pitfalls | HIGH | App Review rejection causes sourced from Apple guidelines, RevenueCat rejection guide, and Apple Developer Forums; HealthKit and subscription pitfalls are widely documented with multiple corroborating sources |

**Overall confidence:** HIGH

### Gaps to Address

- **Demo account data seeding strategy:** Research identifies the need but not the implementation. A Supabase script or documented manual seeding procedure must be defined before Phase 5 execution. Address during Phase 5 planning.
- **Notification timing trigger definition:** Research recommends contextual permission "after first completed week" but the exact trigger condition needs definition tied to the `trainingFrequency` property on the `Athlete` model. Define precisely during Phase 2 planning.
- **PrivacyInfo.xcprivacy UserDefaults API reason:** If `NotificationService` persists permission state or preferences to UserDefaults, the CA92.1 required-reason API declaration must be verified. Low-risk but needs explicit check during Phase 5 compliance audit.
- **ASO keyword selection:** Keyword research is recommended via ASO.dev free tier. Actual target keywords are not finalized in this research. This is a content task for the product owner, not an engineering gap, but must be completed before Phase 4 execution.

## Sources

### Primary (HIGH confidence)
- [Apple UserNotifications — Scheduling Local Notifications](https://developer.apple.com/documentation/usernotifications/scheduling-a-notification-locally-from-your-app)
- [Apple UIGraphicsPDFRenderer](https://developer.apple.com/documentation/uikit/uigraphicspdfrenderer)
- [Apple XCTest Performance Tests](https://developer.apple.com/documentation/xctest/performance-tests)
- [Apple performAccessibilityAudit (WWDC23)](https://developer.apple.com/videos/play/wwdc2023/10035/)
- [Apple MetricKit](https://developer.apple.com/documentation/metrickit)
- [Apple App Store Review Guidelines (2025)](https://developer.apple.com/app-store/review/guidelines/)
- [Apple HealthKit Privacy Documentation](https://developer.apple.com/documentation/healthkit/protecting-user-privacy)
- [fastlane deliver](https://docs.fastlane.tools/actions/deliver/)
- Existing codebase: `CSVExportEngine.swift`, `HealthKitService.swift`, `AppContainer.swift`, `WorkloadView.swift` export pattern

### Secondary (MEDIUM confidence)
- [Athlytic App Store listing](https://apps.apple.com/us/app/athlytic-ai-fitness-coach/id1543571755) — competitor feature benchmark
- [RevenueCat: Ultimate Guide to App Store Rejections](https://www.revenuecat.com/blog/growth/the-ultimate-guide-to-app-store-rejections/)
- [App Store Algorithm Update 2025 — Appfigures](https://appfigures.com/resources/guides/app-store-algorithm-update-2025)
- [High Performance SwiftData Apps — Jacob's Tech Tavern](https://blog.jacobstechtavern.com/p/high-performance-swiftdata)
- [iOS push notification best practices 2026](https://evangelistsoftware.com/blog/the-role-of-push-notifications-in-ios-apps/)
- [Hacking with Swift: Render PDFs using UIGraphicsPDFRenderer](https://www.hackingwithswift.com/example-code/uikit/how-to-render-pdfs-using-uigraphicspdfrenderer)
- [Trophy: Designing Streaks for Long-Term User Growth](https://trophy.so/blog/designing-streaks-for-long-term-user-growth)
- [SwiftData Large Data Performance — Apple Developer Forums](https://developer.apple.com/forums/thread/742336)
- [TrainingPeaks premium features](https://www.trainingpeaks.com/blog/best-trainingpeaks-premium-features/)
- [ASO complete guide 2026 — asomobile.net](https://asomobile.net/en/blog/aso-in-2026-the-complete-guide-to-app-optimization/)

### Tertiary (MEDIUM-LOW confidence)
- [ASO.dev](https://aso.dev/) — keyword tracking; actual keyword selection requires manual validation against live App Store search volume
- [Breaking the Chain: Why Streak Features Fail ADHD Users — Klarity Health](https://www.helloklarity.com/post/breaking-the-chain-why-streak-features-fail-adhd-users-and-how-to-design-better-alternatives/) — streak design anti-patterns

---
*Research completed: 2026-04-22*
*Ready for roadmap: yes*
