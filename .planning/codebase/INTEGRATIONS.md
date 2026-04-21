# External Integrations

**Analysis Date:** 2025-02-23

## APIs & External Services

**Supabase (Backend-as-a-Service):**
- Hosted PostgreSQL + Auth + Realtime
- SDK: Supabase Swift SDK (imported via `import Supabase`)
- Auth method: Email/password (OAuth not currently used)
- Auth flow: `AuthService.signUp()` and `AuthService.signIn()` wrap Supabase client methods
- Keychain integration: `AppRouter` checks Keychain for existing session on cold start (bootstraps local Athlete if missing)

**RevenueCat (Subscription Management):**
- Handles in-app purchase processing and entitlement management
- SDK: RevenueCat Swift SDK (imported via `import RevenueCat`)
- Integration point: `SubscriptionService` initialized in `AppContainer`
- Config: `RevenueCatConfig.apiKey` (production key — gitignored, never commit)
- Log level: Set to `.error` in production to minimize logging

## Data Storage

**Local Database:**
- Type: SwiftData (Apple's modern ORM, replaces CoreData)
- Storage: On-device file-based storage (not in-memory)
- Location: Standard app documents directory
- Schema: 13 models defined in `WorkloadApp.swift` schema initialization:
  - `Athlete` - User profile (displayName, sportType, dateOfBirth, supabaseUserId)
  - `WorkoutSession` - Completed workouts (sessionDate, sessionRPE, durationSeconds, exerciseEntries)
  - `ExerciseEntry` - Exercises within a session (exerciseName, category, setRecords)
  - `SetRecord` - Individual set data (reps, weight, durationSeconds)
  - `WorkloadSnapshot` - Daily ACWR + load metrics (snapshotDate, ATL, CTL, ACWR)
  - `RecoverySnapshot` - Daily recovery scores (snapshotDate, recoveryScore, hrvValue, rhValue, sleepMinutes)
  - `WellnessCheckIn` - User-reported wellness data (checkInDate, mood, soreness, motivation)
  - `PersonalRecord` - Tracked PRs (exerciseName, weight, date, category)
  - `CoachAthleteRelationship` - Coach-athlete pairings (status: pending, accepted, declined)
  - `WorkoutTemplate` - Coach-created workout templates (templateName, createdBy, exerciseGroups)
  - `ExerciseGroup` - Groupings within templates (orderIndex, exercises)
  - `TemplateExercise` - Individual exercises in templates
  - `TemplateSet` - Set prescriptions within template exercises
  - `PrescribedWorkout` - Coach-assigned specific workouts (coachId, assignedToAthleteId, status)
  - `CustomExercise` - Athlete-created custom exercises (exerciseName, category)

**Remote Database:**
- Type: Supabase PostgreSQL
- Connection: Supabase REST/Realtime APIs via Swift SDK
- Sync strategy: Full upsert with last-write-wins (uses `updatedAt` timestamp)
- Tables synced via `SyncService`:
  - `athletes` (user profiles + coach flag)
  - `workload_snapshots` (daily workload data)
  - `recovery_snapshots` (daily recovery data)
  - `wellness_check_ins` (user wellness entries)
  - `personal_records` (athlete PRs)
  - `workout_sessions` (completed sessions)
  - `coach_athlete_relationships` (coach-athlete links)
  - `workout_templates` (coach templates)
  - `prescribed_workouts` (coach-assigned workouts)
  - Custom exercises (synced)

**File Storage:**
- Local only (no cloud file uploads)
- Custom fonts bundled in app: `DMSans-Regular.ttf`, `DMSans-Medium.ttf`
- Mock data seeding: `MockDataSeeder.swift` generates test data on first app launch or when `SCREENSHOT_MODE` is active

## Authentication & Identity

**Auth Provider:**
- Supabase Auth (email/password only)
- `AuthService` wraps Supabase client authentication

**Session Management:**
- Keychain storage (automatic via Supabase Swift SDK)
- `AppRouter` checks `hasSession()` on cold start
- Session listeners: `AppContainer` subscribes to `client.auth.authStateChanges` to detect sign-out and password recovery events
- Single user per installation (one `Athlete` record per app instance)

**User Metadata:**
- Stored in Supabase auth user metadata:
  - `display_name` - User's athlete name
  - `sport_type` - Primary sport (lifting, running, cycling, etc.)
- Athlete profile bootstrapped from Supabase after first sign-in via `SyncService.pullAthlete()`

## Monitoring & Observability

**Error Tracking:**
- Not detected — no Sentry, Bugsnag, or similar integration

**Logging:**
- Console logging only (standard `print()` statements)
- RevenueCat: Set to `.error` level in `SubscriptionService` (line 18)
- No persistent logging or analytics service detected

**Analytics:**
- No analytics SDK detected (no Amplitude, Mixpanel, Google Analytics, etc.)
- Exception handling: try/catch used locally, errors logged via `print()` or ignored

## CI/CD & Deployment

**Hosting:**
- Target: Apple App Store (Phase 5 in progress)
- Deployment method: Xcode Archive → App Store Connect

**CI Pipeline:**
- Not detected (no `.github/workflows`, Jenkins, or Xcode Cloud configuration found)
- Tests run manually: `Product → Test` in Xcode or `xcodebuild test`

**Screenshot Automation:**
- XCUITest-based (`ScreenshotTests/ScreenshotTests.swift`)
- Triggered by: `SCREENSHOT_MODE` launch argument
- Tool: `xcparse` for extracting screenshots from xcresult bundles

## Environment Configuration

**Required Environment Variables:**
- None (credentials are baked into Swift config files)

**Secrets Location:**
- `SupabaseConfig.swift` - Publishable Supabase key (safe to commit, read-only)
- `RevenueCatConfig.swift` - Gitignored (contains production API key — DO NOT commit)
- Keychain - Supabase session tokens (managed by SDK, secure)

## Webhooks & Callbacks

**Incoming Webhooks:**
- Not detected — no webhook endpoints in codebase

**Outgoing Webhooks:**
- Supabase auth state change listeners in `AppContainer` (listen for sign-out/password recovery, trigger local cleanup)
- RevenueCat purchase callbacks handled in `SubscriptionService.purchase()` and `refreshEntitlement()`

## Health Data Integration

**HealthKit (Apple's health data API):**
- Service: `HealthKitService` - Read-only access to device health data
- Permissions required:
  - `NSHealthShareUsageDescription` (privacy text in Info.plist)
  - HealthKit capability in Xcode project
- Data read:
  - Heart Rate Variability (HRV) — `HKQuantityType(.heartRateVariabilitySDNN)`
  - Resting Heart Rate (RHR) — `HKQuantityType(.restingHeartRate)`
  - Heart Rate (workout) — `HKQuantityType(.heartRate)`
  - Sleep duration — `HKCategoryType(.sleepAnalysis)`
  - Active energy burned — `HKQuantityType(.activeEnergyBurned)`
  - VO2 Max — `HKQuantityType(.vo2Max)`
  - Body temperature — `HKQuantityType(.bodyTemperature)`
  - Apple sleeping wrist temperature — `HKQuantityType(.appleSleepingWristTemperature)` (iOS 17+)
  - Workouts — `HKWorkoutType.workoutType()` (auto-import from Apple Health or companion apps)

**Wearable Integration:**
- No direct integration with device APIs
- Data flows through HealthKit when companion apps installed:
  - Apple Watch (native)
  - Oura Ring (Oura companion app)
  - Whoop (Whoop companion app)
  - Garmin (Garmin Connect app)
- Data flow: Wearable app → HealthKit → `HealthKitService` reads → composite scores computed locally → only scores synced to Supabase (raw values never uploaded)

## Subscription Entitlements

**Tiers:**
- `athlete_pro` - Training data history, overload suggestions, custom exercises, PR tracking
- `coach` - Coach dashboard, athlete roster management, workout template creation, coach mode toggle

**Entitlements checked in code:**
- `SubscriptionService.isPro` - True if `athlete_pro` OR `coach` entitlement is active
- `SubscriptionService.isCoach` - True if only `coach` entitlement is active
- Feature gating: Views check `isPro` and `isCoach` flags to show/hide pro features

**Data Gating:**
- Free users: Last 7 days of workload/recovery data visible
- Pro users: Full history visible
- Filtering: `SubscriptionService.filterSessionsForFree()` and `SubscriptionService.filterSnapshotsForFree()` limit free user data

---

*Integration audit: 2025-02-23*
