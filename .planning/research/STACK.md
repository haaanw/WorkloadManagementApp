# Technology Stack

**Project:** Tonus v1.1 - App Store Launch
**Researched:** 2026-04-22

## Current Stack (Keep As-Is)

Already in the project. No changes needed.

| Technology | Purpose | Status |
|------------|---------|--------|
| SwiftUI + SwiftData | UI + persistence | Existing, keep |
| Swift Charts | Data visualization | Existing, keep |
| HealthKit | Biometric data (HRV, RHR, sleep) | Existing, keep |
| Supabase Swift SDK | Auth + sync | Existing, keep |
| RevenueCat | Subscriptions | Existing, keep |
| Accelerate (vDSP) | Vectorized math for analytics | Added in v1.0, keep |
| ImageRenderer + UIGraphicsPDFRenderer | PDF report generation | Planned in v1.0 research, keep |
| UniformTypeIdentifiers | File type declarations for export | Planned in v1.0 research, keep |

## New Stack Additions for v1.1

### Push Notifications: Local Notifications via UserNotifications

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| UserNotifications (Apple framework) | iOS 17+ | Weekly summary notification | Local scheduling is the right fit. The weekly summary is computed on-device from local data (workload snapshots, recovery scores, session counts). No server-side trigger needed. | HIGH |

**Architecture decision: Local, not remote.**

The v1.1 notification requirement is a weekly summary ("You trained 4 times this week, recovery trending up"). This data is already on-device in SwiftData. Using APNs remote push for this would require:
1. Supabase Edge Function (Deno) to call APNs or FCM
2. Device token registration and storage in Supabase
3. APNs certificate management (.p8 key in Supabase secrets)
4. Server-side weekly cron job via pg_cron or external scheduler

All of that complexity for a notification whose content is computed locally. Local notifications eliminate all of it.

**Implementation approach:**
- `UNCalendarNotificationTrigger` with `DateComponents(weekday: 2, hour: 9)` for Monday 9 AM
- Content populated by a `WeeklySummaryService` that queries the last 7 days of `WorkoutSession` and `RecoverySnapshot` from SwiftData
- Schedule on app launch / foreground (refresh content each time)
- Request `UNUserNotificationCenter.requestAuthorization(options: [.alert, .badge, .sound])`
- Add `UNNotificationCategory` with "View Summary" action to deep-link to dashboard

**When to add remote push (NOT now):**
Remote push via APNs becomes necessary when the app needs to notify about events the user did not initiate locally -- e.g., "Your coach assigned a new workout" or "Your athlete logged a session." That is a v1.2+ concern (coach-initiated actions). When that time comes, the recommended path is Supabase Edge Function calling APNs directly (not FCM -- the app is iOS-only, FCM adds unnecessary Google dependency).

**What NOT to use:**
- **Firebase Cloud Messaging (FCM):** iOS-only app. FCM is a wrapper around APNs that adds the Firebase SDK (~10MB), Google service account management, and a dependency on Google infrastructure. Zero benefit for a single-platform app.
- **OneSignal:** SaaS push service. Overkill for local weekly summaries. Adds SDK, dashboard dependency, and a third-party data processor (privacy policy implications for a health app).
- **Supabase Edge Functions + APNs (for now):** Correct architecture for remote push, but unnecessary for the weekly summary use case. Defer to v1.2.

### Streak Tracking: Pure SwiftData + Engine Pattern

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| No new dependencies | N/A | Streak calculation and persistence | Streaks are a simple domain concept (consecutive days with qualifying events). Fits the existing pure-engine pattern perfectly. | HIGH |

**Implementation approach:**
- New `StreakEngine` (pure struct, static methods) computes current streak, longest streak, and streak status from date arrays
- New `StreakSnapshot` SwiftData model stores daily streak state (avoids recomputing from full history each time)
- Streaks computed in `WorkoutPipeline.processSession()` and `RecoveryPipeline.run()` (after wellness check-in)
- Two streak types: Training streak (days with sessions) and Check-in streak (days with wellness check-ins)
- Reset logic: streak breaks at midnight if no qualifying event the prior calendar day

**What NOT to use:**
- No third-party gamification libraries. Streak logic is ~50 lines of date arithmetic. Adding a dependency would be absurd.
- No server-side streak tracking. Streaks are local-first, synced to Supabase like other snapshots.

### PDF Report Generation (Carried from v1.0 Research)

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| ImageRenderer | iOS 16+ (SwiftUI) | Snapshot SwiftUI views to image | Captures existing chart views pixel-perfectly into PDF context | HIGH |
| UIGraphicsPDFRenderer | UIKit | Multi-page PDF creation | Apple's blessed PDF document builder, handles pages and metadata | HIGH |

**No changes from v1.0 research.** The approach remains: compose report pages as SwiftUI views, render via ImageRenderer into UIGraphicsPDFRenderer pages, export via ShareLink/UIActivityViewController.

**Coach PDF export addition:** For coach users, the PDF should aggregate multiple athletes. This means the `PDFReportService` needs to accept an array of athlete data, not just the current athlete. Architecture consideration, not a stack change.

### App Store Metadata / ASO: Manual + fastlane deliver

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| fastlane deliver | Latest (via Homebrew/Bundler) | Upload metadata and screenshots to App Store Connect | The app already has a screenshot automation framework (Phase 5). fastlane deliver automates uploading those screenshots plus metadata (title, subtitle, keywords, description) to ASC. Avoids manual upload of 10+ screenshots across device sizes. | HIGH |
| fastlane snapshot | Latest | Automated screenshot capture | Integrates with existing XCUITest screenshot tests to capture across simulators | MEDIUM |

**ASO metadata is content work, not code.** The stack need is just the delivery pipeline:

1. **Metadata files:** `fastlane/metadata/en-US/` directory with `name.txt`, `subtitle.txt`, `keywords.txt`, `description.txt`, `promotional_text.txt`, `release_notes.txt`
2. **Screenshots:** Already generated by existing `ScreenshotTests` XCUITest target. fastlane snapshot can orchestrate multi-device capture. fastlane deliver uploads them.
3. **Keywords research:** Use ASO.dev ($0 free tier for basic keyword tracking) or manual App Store Connect keyword field. No code dependency.

**2025-2026 ASO considerations:**
- Apple now indexes screenshot caption text for keyword ranking. Captions in screenshots should include target keywords naturally.
- Custom Product Pages (CPPs) entered organic search mid-2025 with keyword linking. Worth creating 2-3 CPPs targeting different user intents (athlete vs coach vs runner).
- AI-generated App Store Tags are derived from metadata. Ensure metadata is clear and category-specific.

**What NOT to use:**
- **App Store Connect API directly:** fastlane wraps it. No need to build custom API integration for a single app.
- **Paid ASO tools (AppTweak, Sensor Tower, data.ai):** Overkill for launch. Start with free ASO.dev keyword tracking. Upgrade if the app reaches 1K+ downloads and needs competitive intelligence.
- **AppDrift or similar AI metadata generators:** The app's domain (athletic training load management) is niche enough that generic AI-generated descriptions will be too generic. Write metadata manually with domain expertise.

### QA Testing: XCTest + XCUITest + Accessibility Audits

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| XCTest | Apple framework | Unit tests for engines and repositories | Already available in project. Engines are pure structs with static methods -- trivially testable. | HIGH |
| XCUITest | Apple framework | UI integration tests and screenshot automation | Already have ScreenshotTests target. Extend for critical user flows (onboarding, workout logging, recovery check-in). | HIGH |
| performAccessibilityAudit() | Xcode 15+ / iOS 17+ | Automated accessibility compliance | Built into XCUITest since Xcode 15. Call on XCUIApplication to audit current view for VoiceOver, Dynamic Type, contrast issues. Tests fail automatically on violations. | HIGH |

**Testing strategy (no new dependencies):**

1. **Unit tests (XCTest):** Cover all pure engines -- WorkloadCalculator, RecoveryScoreEngine, AutoregulationEngine, PRDetector, StreakEngine (new). These are deterministic functions with known inputs/outputs.
2. **Integration tests (XCTest):** Cover pipelines with in-memory SwiftData ModelContainer. Test WorkoutPipeline.processSession() and RecoveryPipeline.run() end-to-end.
3. **UI tests (XCUITest):** Cover critical flows -- sign up, log workout, complete wellness check-in, view dashboard, export data. Use SCREENSHOT_MODE for deterministic data.
4. **Accessibility audits:** Add `try app.performAccessibilityAudit()` to each UI test. Audit types: `.dynamicType`, `.contrast`, `.elementDetection`, `.hitRegion`.
5. **Crash testing:** Test edge cases -- empty states (no workouts), boundary dates, nil HealthKit permissions, no network.

**What NOT to use:**
- **Third-party testing frameworks (Quick/Nimble, ViewInspector):** XCTest is sufficient. The app's architecture (pure engines + SwiftData repositories) maps cleanly to standard XCTest assertions. Adding Quick/Nimble creates a learning curve for a solo developer with no benefit.
- **Snapshot testing libraries (swift-snapshot-testing by Point-Free):** Good for UI regression testing at scale, but the v1.1 priority is functional correctness and crash prevention, not pixel-perfect regression. Defer to v1.2+ if UI churn becomes a problem.
- **BrowserStack / Firebase Test Lab:** Cloud device testing services. Not needed for a single-developer iOS app targeting iOS 17+. Test on simulator + one physical device.

### Performance Profiling: Xcode Instruments + XCTMetric

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| Xcode Instruments | Xcode 16+ | Profile CPU, memory, energy, Core Animation | Apple's built-in profiler. Time Profiler for CPU hotspots, Allocations for memory leaks, Core Animation for scroll performance, Energy Log for background impact. | HIGH |
| XCTApplicationLaunchMetric | XCTest (iOS 14+) | Measure app launch time | Automated launch time measurement in XCTest. Apple recommends < 400ms cold launch, < 200ms warm launch. Run as performance test with baseline. | HIGH |
| XCTOSSignpostMetric | XCTest (iOS 14+) | Measure specific code paths | Place os_signpost markers around pipeline execution (WorkoutPipeline, RecoveryPipeline, DashboardViewModel.load) to measure and regress-test performance. | HIGH |
| MetricKit | iOS 14+ | Production performance monitoring | Collects aggregated diagnostic and performance data from real user devices. Reports launch times, hang rates, disk writes, battery drain. Requires opt-in via MXMetricManager. | MEDIUM |

**Performance audit approach:**

1. **Launch time:** Add XCTest performance test with `XCTApplicationLaunchMetric`. Set baseline. Ensure < 400ms cold start.
2. **Dashboard load:** Instrument `DashboardViewModel.load()` with os_signpost. This is the heaviest operation (RecoveryPipeline + AutoregulationEngine + data queries). Target < 500ms.
3. **Scroll performance:** Use Core Animation instrument on workout history list (potentially hundreds of sessions) and recovery history. Target 60fps sustained.
4. **Memory:** Profile with Allocations instrument. Check for SwiftData relationship leaks (common pitfall with @Relationship cascade chains).
5. **Energy:** Run Energy Log instrument during typical 5-minute session. Check for unnecessary background work, timer leaks, or excessive HealthKit queries.
6. **Production telemetry:** Adopt MetricKit to receive weekly performance reports from real devices after App Store launch.

**What NOT to use:**
- **Firebase Performance Monitoring:** Adds Firebase SDK dependency for a single metric category. MetricKit provides equivalent data with zero dependencies.
- **Datadog / New Relic mobile SDK:** Enterprise monitoring. Way too heavy for a solo-developer app at launch stage.

### App Review Compliance: No Stack Additions

App Review compliance is a process concern, not a technology concern. Key areas to verify:

| Area | Tool | Notes |
|------|------|-------|
| Privacy manifest | PrivacyInfo.xcprivacy (already exists) | Verify all required domains and API reasons are declared |
| HealthKit usage description | Info.plist | Already configured. Ensure descriptions are specific and accurate |
| Subscription metadata | RevenueCat + App Store Connect | Ensure subscription descriptions match App Review guidelines |
| Data deletion | Supabase RPC | Apple requires account deletion capability. Need a "Delete Account" flow |
| Export compliance | Info.plist ITSAppUsesNonExemptEncryption | Set to NO (HTTPS-only encryption is exempt) |

## Full Dependency List

### SPM Dependencies (existing, NO additions for v1.1)

```
https://github.com/supabase/supabase-swift
https://github.com/RevenueCat/purchases-ios.git
```

### Apple Frameworks (existing + new usage)

```
SwiftUI              -- UI
SwiftData            -- Persistence
Charts               -- Visualization
HealthKit            -- Biometrics
Accelerate           -- Vectorized math (added v1.0)
UIKit                -- PDF rendering (UIGraphicsPDFRenderer, ImageRenderer)
UniformTypeIdentifiers -- File type declarations for export
UserNotifications    -- NEW: Local push notifications for weekly summary
MetricKit            -- NEW: Production performance telemetry
XCTest               -- EXPANDED: Unit + integration + performance + accessibility tests
```

### Dev/CI Dependencies (new)

```
fastlane             -- Metadata and screenshot upload to App Store Connect
```

### No New SPM Dependencies

v1.1 adds zero new third-party SPM packages. Every new capability uses Apple frameworks:
- Notifications: UserNotifications (Apple)
- Streaks: Pure Swift + SwiftData (no library)
- PDF: ImageRenderer + UIGraphicsPDFRenderer (Apple)
- QA: XCTest + XCUITest (Apple)
- Performance: Instruments + XCTMetric + MetricKit (Apple)
- ASO: fastlane (dev tool, not compiled into app)

This is intentional:
1. **Zero additional binary size** -- no new frameworks shipped to users
2. **Zero dependency risk** -- no third-party breakage on Xcode/iOS updates
3. **App Review friendly** -- fewer dependencies = fewer potential rejection vectors
4. **Privacy compliant** -- no new third-party SDKs to declare in privacy manifest

## Alternatives Considered

| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| Weekly notification | UserNotifications (local) | Supabase Edge Function + APNs | Weekly summary is computed from local data; remote push adds server complexity for no benefit |
| Weekly notification | UserNotifications (local) | Firebase Cloud Messaging | iOS-only app; FCM adds ~10MB Firebase SDK and Google dependency |
| Weekly notification | UserNotifications (local) | OneSignal | SaaS dependency; privacy implications for health app; overkill for one notification type |
| Streak tracking | Pure Swift engine | Third-party gamification library | 50 lines of date math; a library adds dependency overhead |
| PDF reports | ImageRenderer + UIGraphicsPDFRenderer | TPPDF | Reports mirror existing SwiftUI views; TPPDF duplicates layout code |
| QA testing | XCTest + XCUITest | Quick/Nimble | Extra learning curve; XCTest covers all needs for pure-engine architecture |
| QA testing | XCTest + XCUITest | swift-snapshot-testing | Good tool, but v1.1 priority is functional correctness, not pixel regression |
| Performance | Instruments + MetricKit | Firebase Performance | Adds Firebase SDK for one metric category; MetricKit is zero-dependency |
| ASO delivery | fastlane deliver | App Store Connect API direct | fastlane wraps the API; no need to build custom integration |
| ASO research | ASO.dev (free tier) | AppTweak/Sensor Tower | Overkill at launch; upgrade after reaching meaningful download volume |
| Accessibility | performAccessibilityAudit() | Deque axe DevTools | Built-in Xcode solution is sufficient; third-party adds complexity |

## Installation

### Apple Frameworks (add imports where needed)

```swift
import UserNotifications  // In NotificationService
import MetricKit          // In AppDelegate or AppContainer
import os                 // For os_signpost in performance instrumentation
```

### Dev Tools (one-time setup)

```bash
# Install fastlane (if not already installed)
brew install fastlane

# Initialize fastlane in project
cd /Users/hanwen/Desktop/Tonus
fastlane init

# Create metadata directory structure
mkdir -p fastlane/metadata/en-US
mkdir -p fastlane/screenshots/en-US
```

### MetricKit Setup (minimal)

```swift
// In AppContainer or App init
import MetricKit

class MetricSubscriber: NSObject, MXMetricManagerSubscriber {
    func didReceive(_ payloads: [MXMetricPayload]) {
        // Log or forward to analytics
        for payload in payloads {
            print("Launch time: \(payload.applicationLaunchMetrics)")
        }
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        // Crash and hang diagnostics
        for payload in payloads {
            print("Diagnostics: \(payload)")
        }
    }
}

// Register on app launch
MXMetricManager.shared.add(subscriber)
```

## Integration Points with Existing Stack

| New Feature | Touches Existing | Integration Notes |
|-------------|------------------|-------------------|
| Local notifications | AppContainer, WorkoutPipeline, RecoveryPipeline | Schedule/refresh notification on pipeline completion |
| Streak tracking | WorkoutPipeline, RecoveryPipeline, SwiftData models | New StreakSnapshot model; compute in pipelines alongside existing snapshots |
| PDF export | Existing SwiftUI chart views, ShareLink | Render existing views to PDF; add share button to relevant screens |
| fastlane | ScreenshotTests XCUITest target | Orchestrate existing screenshot tests across device sizes |
| Performance tests | XCTest target, DashboardViewModel, pipelines | Add os_signpost instrumentation to hot paths |
| Accessibility audits | XCUITest target | Add performAccessibilityAudit() calls to existing UI tests |
| MetricKit | AppContainer | One-time subscriber registration on app launch |

## Sources

- [Apple UserNotifications - Scheduling Local Notifications](https://developer.apple.com/documentation/usernotifications/scheduling-a-notification-locally-from-your-app) -- HIGH confidence
- [Supabase Push Notifications Docs](https://supabase.com/docs/guides/functions/examples/push-notifications) -- HIGH confidence (evaluated and deferred)
- [Apple XCTest Performance Tests](https://developer.apple.com/documentation/xctest/performance-tests) -- HIGH confidence
- [Apple XCTApplicationLaunchMetric](https://developer.apple.com/documentation/xcode/writing-and-running-performance-tests) -- HIGH confidence
- [Apple performAccessibilityAudit (WWDC23)](https://developer.apple.com/videos/play/wwdc2023/10035/) -- HIGH confidence
- [Apple MetricKit](https://developer.apple.com/documentation/metrickit) -- HIGH confidence
- [fastlane deliver](https://docs.fastlane.tools/actions/deliver/) -- HIGH confidence
- [Apple ImageRenderer](https://developer.apple.com/documentation/swiftui/imagerenderer) -- HIGH confidence
- [UIGraphicsPDFRenderer](https://developer.apple.com/documentation/uikit/uigraphicspdfrenderer) -- HIGH confidence
- [App Store Algorithm Update 2025 - Appfigures](https://appfigures.com/resources/guides/app-store-algorithm-update-2025) -- MEDIUM confidence
- [ASO.dev](https://aso.dev/) -- MEDIUM confidence
- [App Store Connect API Metadata](https://developer.apple.com/documentation/appstoreconnectapi/app-metadata) -- HIGH confidence
