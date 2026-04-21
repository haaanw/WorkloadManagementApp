# TODOS

## ✅ Progressive Disclosure — Dashboard Metric Drill-Down
**Completed:** 2026-03-23
Tapping an HRV or Sleep factor row on the dashboard hero card pushes to `HRVDetailView` or `SleepDetailView`. Both show a 28-day trend chart (flat design system), stats row (latest / 7-day avg / delta), and an explanation section. Routing via `TrendDestination` enum + `NavigationLink(value:)` + `.navigationDestination(for:)` in `DashboardView`.

---

## ✅ Auth/Onboarding Design System Update
**Completed:** 2026-03-23
`LoginView`, `SignUpView`, `OnboardingView` updated to flat design system. Reusable `InputField` and `SecureInputField` components extracted in `SignUpView.swift`.

---

## ✅ WorkloadCalculator Unit Tests
**Completed:** 2026-03-23
46 tests across 4 test classes in `WorkloadAppTests` target (XCTest). All passing. Covers sessionTSS, srpeLoad, trimp, hrZone (all zones + boundaries), efficiencyIndex, stepEWMA (exact EWMA math), computeHistoryEWMA (convergence, rest/training cycle, no division by zero), computeRollingACWR.

---

## ✅ Phase 2 — Supabase Backend
**Completed:** ~2026-03-24

- Supabase Swift SDK added via Swift Package Manager
- `AuthService` (signIn/signUp/signOut) wired to Supabase Auth
- `AppRouter` switches on `AuthService.isAuthenticated()`
- PostgreSQL schema: `athletes`, `workload_snapshots`, `recovery_snapshots`, `recovery_snapshots`, `wellness_check_ins`, `personal_records`, `workout_sessions`
- Row-level security on all tables (each user reads/writes own rows only)
- `SyncService` fully implemented: push/pull for all entity types, last-write-wins on `updatedAt`
- Multi-device sync: foreground sync on app active, pushAll + pullAll

---

## ✅ Phase 3 — Coach + Athlete Multi-User
**Completed:** 2026-03-25

### Phase 3a — Backend + Invite Flows
- `CoachAthleteRelationship` SwiftData model + Supabase `coach_athlete_relationships` table with RLS
- `is_coach_for()` Supabase RLS helper for coach access to athlete data
- `InviteService`: 6-char invite codes, email invite, deep link handling, NFC (CoreNFC write/scan)
- `SyncService` coach methods: `pullLinkedAthletes`, `pullAthleteSnapshots`, `pushCoachWorkloadSnapshot`, `pushCoachRecoverySnapshot`, `pushCoachPersonalRecord`, `removeRelationship`
- `ProfileView` invite flows: generate code, enter code, email invite, NFC link, linked coaches/athletes lists with swipe-to-remove
- `AppRouter` deep link handler for coach invite emails

### Phase 3b — Coach UI
- `ContextSwitcher`: mode toggle band (Athlete / Coach) above tab bar, only shown when `isCoach == true`
- `CoachRosterViewModel`: loads linked athletes + latest snapshots from SwiftData
- `CoachRosterView`: client roster list with recovery zone color indicators, pull-to-refresh
- `ClientDetailView`: recovery hero score, 28-day ACWR trend chart, recent load list, PRs, session filter bar + coach attribution
- `CoachWorkoutEntrySheet`: coach logs workout for athlete (date/duration/sRPE/session type), uses `WorkoutPipeline`, sets `loggedByCoachId`
- `MainTabView` mode-aware: coach mode shows Roster + Profile; athlete mode shows 5-tab layout
- Sync triggers on mode switch and scene activation

### Multi-Coach Session Attribution (3b add-on)
- `SessionType` enum (strength/skill/cardio/match/recovery) on `WorkoutSession`
- `sessionType` + `loggedByCoachId` fields on `WorkoutSession`
- `WorkoutSessionRow` + `SyncService` push/pull for session headers (derived load fields included)
- Session type segmented picker in `ActiveWorkoutSheet` and `CoachWorkoutEntrySheet`
- `SessionTypeFilterBar` component in `WorkoutLogView` and `ClientDetailView`
- Attribution labels: "Self" / "You" / coach display name / "Unknown Coach"

---

## ✅ Phase 4 — Subscriptions
**Completed:** 2026-03-26

- RevenueCat SDK integrated via Swift Package Manager (purchases-ios 5.66.0+)
- `SubscriptionService`: configures RevenueCat, exposes `isPro`, handles purchase/restore, entitlement refresh on foreground
- `RevenueCatConfig`: API key configuration (test key for sandbox)
- Entitlement `pro` with products `workload_pro_monthly` ($9.99/mo) and `workload_pro_annual` ($79.99/yr)
- `UpgradeSheet`: context-aware paywall (history trigger + coach trigger), annual/monthly toggle, free trial CTA
- `HistoryTeaserBanner`: shows locked weeks count, triggers upgrade sheet
- Free tier gating: workout log + workload/ACWR history truncated to 7 days
- Coach mode gated: `ContextSwitcher` shows upgrade prompt for non-Pro users
- Sandbox purchase verified on physical device

---

## ✅ Phase 5 — App Store Readiness
**Completed:** 2026-03-26

- **App name:** Tonus (`CFBundleDisplayName`), user-facing strings updated
- **App icon:** Custom 1024x1024 PNG in `Assets.xcassets/AppIcon.appiconset`
- **PrivacyInfo.xcprivacy:** Declares HealthKit (health + fitness), purchase history (RevenueCat), user ID + email (Supabase auth), name (athlete profile); required reason APIs (UserDefaults, file timestamps, system boot time)
- **Info.plist:** `NSHealthShareUsageDescription`, `ITSAppUsesNonExemptEncryption = NO`, `UILaunchScreen` with `LaunchBackground` color
- **Assets.xcassets:** AppIcon, AccentColor (travertine dark/light), LaunchBackground (design system bg dark/light)
- **Launch screen:** Configured via `UILaunchScreen` dictionary — warm near-black (dark) / warm off-white (light)
- **Xcode project:** File references and build phase entries for all new resources

### Manual steps before submission
- Set final bundle identifier in Xcode (currently `H.workload-management`)
- App Store screenshots (simulator captures)
- TestFlight beta distribution (Archive → Upload)
- App Store Connect metadata (description, keywords, category: Health & Fitness)
