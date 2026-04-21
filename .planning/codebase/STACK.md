# Technology Stack

**Analysis Date:** 2025-02-23

## Languages

**Primary:**
- Swift (iOS app codebase) - All application logic, UI, and business engines

## Runtime

**Environment:**
- iOS 17+ (target deployment minimum implied by API usage: `HKQuantityType.appleSleepingWristTemperature`, iOS 17+ feature)
- Xcode (build environment)

**Device Support:**
- iPhone (tested on iPhone 17 Pro Max simulator)
- Apple Watch (HealthKit data via companion apps)

## Frameworks

**Core UI & Data:**
- SwiftUI - Declarative UI framework
- SwiftData - Local ORM/persistence (replaces CoreData)
- Charts - Apple framework for data visualization (used in `WorkloadView.swift`)

**Native Capabilities:**
- HealthKit - Read-only health and fitness data (HRV, RHR, sleep, workout data, VO2 Max, body temperature)
- UIKit - Required for font management (`UIFont` assertions in `WorkloadApp.swift`)
- CoreNFC - NFC session coordination (see `NFCSessionCoordinator.swift`)

**Testing:**
- XCTest - Apple's native testing framework
- XCUITest - UI automation (used in `ScreenshotTests`)

**Build/Dev:**
- Xcode (implied, standard iOS development)
- xcparse - CLI tool for extracting screenshots from xcresult bundles (optional, used in screenshot automation)

## Key Dependencies

**Critical:**
- Supabase Swift SDK - Backend auth + PostgreSQL sync
  - Used in: `AppContainer`, `AuthService`, `SyncService`
  - Handles: Email/password authentication, bidirectional data sync (athletes, workouts, snapshots, relationships)
  - Tables accessed: `athletes`, `workload_snapshots`, `recovery_snapshots`, `wellness_check_ins`, `personal_records`, `workout_sessions`, `coach_athlete_relationships`, `workout_templates`, `prescribed_workouts`

- RevenueCat SDK - Subscription management
  - Used in: `SubscriptionService` (initialized in `AppContainer`)
  - Manages: Two-tier entitlements (`athlete_pro`, `coach`)
  - Offerings: `athlete_pro` and `coach` product identifiers

**Infrastructure:**
- SwiftData models bridge (JSON encoding/decoding for Supabase sync)
  - Custom `Row` types for each model: `AthletteRow`, `WorkloadSnapshotRow`, `RecoverySnapshotRow`, `WellnessCheckInRow`, `PersonalRecordRow`, `WorkoutSessionRow`, etc.
  - Encoder/decoder configured with snake_case key encoding and ISO8601 date strategy

## Configuration

**Environment:**
- `SupabaseConfig.swift` (committed, contains publishable key)
  - `supabaseURL`: `https://wbqnzblcixlmlwbqmxjp.supabase.co`
  - `anonKey`: `sb_publishable_g5xsj1G3vR6RbXgsQ3Siyg_bRyttC_P`

- `RevenueCatConfig.swift` (gitignored — DO NOT commit API keys)
  - Contains: RevenueCat iOS public API key (production key in codebase)

- `Info.plist` (in `workload management/workload-management-Info.plist`)
  - `UIAppFonts`: `DMSans-Regular.ttf`, `DMSans-Medium.ttf`
  - `NSHealthShareUsageDescription`: Privacy text for HealthKit read access
  - `NSHealthUpdateUsageDescription`: Privacy text for Apple Health write access
  - `UILaunchScreen`: Custom launch screen with `LaunchBackground` color

- `PrivacyInfo.xcprivacy` - App Store Privacy Manifest

**Launch Arguments:**
- `SCREENSHOT_MODE` - DEBUG build flag that bypasses authentication and seeds mock data for automated screenshots (see `AppRouter.swift`)

## Fonts

**Custom Fonts (bundled):**
- `DMSans-Regular.ttf` (55.0 KB) - Regular weight for body text
- `DMSans-Medium.ttf` (55.1 KB) - Medium weight for headings/emphasis

Both fonts are asserted to exist at app launch (`WorkloadApp.swift` lines 11-18). Usage via `Font.custom("DMSans-Regular", size:)` and `Font.custom("DMSans-Medium", size:)`.

## Platform Requirements

**Development:**
- Xcode (latest, tested with iPhone 17 Pro Max simulator)
- iOS 17+ SDK
- Apple device or simulator with HealthKit support

**Production:**
- Deployment target: iOS 17+
- App Store distribution (Phase 5 in progress)
- Requires user to grant HealthKit permissions (prompted via `NSHealthShareUsageDescription`)
- Requires in-app purchase capability (RevenueCat SDK handles StoreKit integration)

**External Requirements:**
- Supabase PostgreSQL backend (always available, no local fallback)
- RevenueCat cloud configuration (subscription offerings must be configured in dashboard)
- Apple Health app or compatible wearable (Apple Watch, Oura, Whoop, Garmin) for HealthKit data

---

*Stack analysis: 2025-02-23*
