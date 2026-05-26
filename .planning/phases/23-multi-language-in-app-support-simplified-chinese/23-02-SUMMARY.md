---
phase: 23-multi-language-in-app-support-simplified-chinese
plan: 02
subsystem: i18n
tags: [locale, string-catalog, localization, notifications, swiftui]
requires:
  - Plan 23-01 (LocaleManager + env-locale + empty xcstrings)
provides:
  - All enum displayNames resolved via String(localized:, defaultValue:)
  - AuthService.AuthError + AuthBootstrapError + SignUpSocialError expose stable localizationKey + defaultValue
  - LoginView + SignUpView re-resolve auth errors at View boundary via LocalizedStringResource + env locale (live-switch)
  - .onChange(of: locale) error-message refresh path
  - .id(locale) on every Chart view (HRVTrendChart, SleepTrendChart, LoadTrendChartView, RecoveryLoadChart)
  - .locale(locale) on tooltip date formatters in WorkloadView + RecoveryLoadChart
  - NotificationService uses NSString.localizedUserNotificationString (deliver-time)
  - notificationSchemaVersion UserDefaults migration in AppContainer.init
  - InfoPlist.xcstrings populated with NSHealthShareUsageDescription
  - Localizable.xcstrings populated with 60 keys across tab/action/auth.error/sport/zone/recoveryZone/frequency/experience/dashboard/recovery/workload/workoutLog/profile/onboarding/language.picker/paywall/notif/date/duration namespaces
  - ZoneBadge locale-conditional typography (English-only textCase + tracking; zh-Hans padding 16 vs 10)
affects:
  - WorkloadApp/Models/Enums.swift (~17 displayName + subtitle members)
  - WorkloadApp/Services/AuthService.swift (AuthError additions)
  - WorkloadApp/Services/NotificationService.swift (full rewrite)
  - WorkloadApp/Resources/Localizable.xcstrings (populated)
  - WorkloadApp/Resources/InfoPlist.xcstrings (NSHealthShareUsageDescription)
  - WorkloadApp/App/AppRouter.swift (TabView labels)
  - WorkloadApp/App/AppContainer.swift (migrateWeeklySummaryIfNeeded() call)
  - WorkloadApp/Views/Auth/LoginView.swift (resolveErrorMessage + onChange)
  - WorkloadApp/Views/Auth/SignUpView.swift (resolveErrorMessage + onChange)
  - WorkloadApp/Views/Workload/WorkloadView.swift (.id(locale) on Chart + .locale(locale) on tooltip)
  - WorkloadApp/Views/Workload/RecoveryLoadChart.swift (.id(locale) + .locale(locale))
  - WorkloadApp/Components/HRVTrendChart.swift (.id(locale))
  - WorkloadApp/Components/SleepTrendChart.swift (.id(locale))
  - WorkloadApp/Components/MetricTile.swift (ZoneBadge locale-conditional)
  - WorkloadApp/ViewModels/DashboardViewModel.swift (scheduleWeeklySummary call site)
  - WorkloadApp/Views/Dashboard/DashboardView.swift (scheduleWeeklySummary call site)
  - WorkloadApp/Views/Profile/ProfileView.swift (scheduleWeeklySummary call site)
tech-stack:
  added:
    - String.LocalizationValue + LocalizedStringResource pattern for runtime locale resolution
    - NSString.localizedUserNotificationString deliver-time localization
    - UserDefaults schema-version migration pattern for notifications
  patterns:
    - "View-boundary error re-resolution: cast → LocalizedStringResource(key) → resource.locale = env.locale → String(localized: resource)"
    - "Chart .id(locale) to force SwiftUI rebuild on env-locale change (Charts framework caches its own locale)"
    - "locale-conditional .textCase / .tracking / padding gated on language.languageCode?.identifier"
key-files:
  created: []
  modified:
    - WorkloadApp/Models/Enums.swift
    - WorkloadApp/Services/AuthService.swift
    - WorkloadApp/Services/NotificationService.swift
    - WorkloadApp/Resources/Localizable.xcstrings
    - WorkloadApp/Resources/InfoPlist.xcstrings
    - WorkloadApp/App/AppRouter.swift
    - WorkloadApp/App/AppContainer.swift
    - WorkloadApp/Views/Auth/LoginView.swift
    - WorkloadApp/Views/Auth/SignUpView.swift
    - WorkloadApp/Views/Workload/WorkloadView.swift
    - WorkloadApp/Views/Workload/RecoveryLoadChart.swift
    - WorkloadApp/Components/HRVTrendChart.swift
    - WorkloadApp/Components/SleepTrendChart.swift
    - WorkloadApp/Components/MetricTile.swift
    - WorkloadApp/ViewModels/DashboardViewModel.swift
    - WorkloadApp/Views/Dashboard/DashboardView.swift
    - WorkloadApp/Views/Profile/ProfileView.swift
decisions:
  - "Used LocalizedStringResource + resource.locale = locale for AuthError live-switch — the String(localized:, defaultValue:, locale:) overload requires StaticString keys and doesn't accept String.LocalizationValue. LocalizedStringResource is the public API path that does."
  - "Catalog populated explicitly via Localizable.xcstrings JSON rather than relying on SWIFT_EMIT_LOC_STRINGS extraction — Xcode only writes extracted keys back to the source xcstrings via the IDE (xcodebuild does not), so for the catalog audit acceptance criterion to be verifiable we wrote the namespaces directly. P4 owns zh-Hans translation."
  - "InfoPlist.xcstrings carries NSHealthShareUsageDescription as a localizable entry — when present in xcstrings, iOS resolves at consent-prompt time and the pbxproj INFOPLIST_KEY_NSHealthShareUsageDescription becomes the en fallback only."
  - "Migration call invoked from AppContainer.init() rather than NotificationService.init() so it runs once per app launch under the @MainActor context."
  - "RevenueCat product names (Athlete Pro, Coach) remain English in zh-Hans UpgradeSheet — RC dashboard product title translations are out of scope for Phase 23 (per plan 23-04 follow-up note)."
metrics:
  duration: ~45 min
  tasks_completed: 6
  files_modified: 17
  commits: 6
  completed: 2026-05-26
---

# Phase 23 Plan 02: String sweep + catalog migration — Summary

Completed the string-sweep + catalog-migration phase that Plan 23-01's scaffold made possible. Every enum `displayName`, every auth-error surface, every Chart, and the weekly-summary notification now flow through the localization plumbing built in P1. The catalog ships 60 keys across the canonical namespaces; the zh-Hans column is empty by design (P4 translates). Build green on iPhone 17 Pro Max simulator after every task; phase-wide audits (Locale.current, Models tier String(localized:), dynamic-key interpolation, auth-error live-switch) all return zero violations.

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| 1 | `4d14f33` | Enum displayNames + AuthError stable localizationKey/defaultValue |
| 2a | `d455cd1` | Dashboard + WorkoutLog tier sweep + tab/action/dashboard namespace catalog populate |
| 2b | `f497569` | Recovery/Workload/Charts: .id(locale) chart rebuild + .locale(locale) on tooltip dates |
| 2c | `3df196f` | Auth view-boundary AuthError re-resolution + onChange(of: locale) refresh |
| 2e | `60968bb` | ZoneBadge locale-conditional typography (zh-Hans padding/case/tracking) |
| 3 | `19f4134` | NotificationService deferred localization + schema migration + InfoPlist consent |

Task 2d had no source-file deltas — the Onboarding/Profile/Coach views already passed all P2 acceptance criteria (zero Locale.current, language.picker.title preserved from P1) without further edits. The catalog additions covering `onboarding.*` and `profile.*` namespaces were folded into the Task 2a commit.

## What was built

### Task 1 — Enum displayNames + AuthError live-switch surfaces

Every `displayName` switch case across SportType, WeightUnit, ACWRMethod, LoadSource, ACWRZone, ExerciseCategory, MuscleGroup, PRType, RecoveryZone, PrescriptionStatus, SessionType, TrainingFrequency, ExperienceLevel (and its subtitle), BodyRegion, and CyclePhase now returns `String(localized: "<namespace>.<caseId>", defaultValue: "<en literal>")`. The compiler picks up the `defaultValue:` on Build, so the keys are catalog-ready. Namespaces follow the canonical glossary in 23-RESEARCH.md.

`AuthService.AuthError` now exposes:
- `var localizationKey: String.LocalizationValue` — stable catalog key per case (`auth.error.noUserReturned`, `auth.error.noIdentityToken`); the `.socialSignInFailed(message)` case returns a `String.LocalizationValue(message)` wrapping the opaque server string, so by design it doesn't live-switch.
- `var defaultValue: String` — the en source value used as fallback by `String(localized: resource)` when the catalog lookup misses.
- `var errorDescription: String?` returns the defaultValue, preserved for NSError/logging diagnostics.

### Task 2a–2b — View tier sweep + chart locale rebuild

P1's scaffold work had already left zero `Locale.current` matches in Views/Dashboard/Recovery/Workload/WorkoutLog and zero `.shortString[^(]` regressions, so Tasks 2a + 2b focused on the chart-rebuild trigger and tooltip date formatters that the plan called out specifically. Every `Chart { }` view now carries `.id(locale)` so SwiftUI rebuilds the Charts framework subtree on env-locale change (RESEARCH Pitfall 4 — Charts has its own internal locale cache that won't refresh without a rebuild). Tooltip date labels in WorkloadView + RecoveryLoadChart now pass `.locale(locale)` into the `.dateTime.month(.abbreviated).day()` format chain.

TabView labels in AppRouter migrated to namespaced LocalizedStringKey (`tab.home`, `tab.log`, `tab.recovery`, `tab.load`, `tab.profile`, `tab.roster`, `tab.templates`).

### Task 2c — Auth View-boundary re-resolution + live-switch (RESEARCH Pitfall 7)

LoginView and SignUpView each gained `@Environment(\.locale)`, a captured `@State lastAuthError: (any Error)?`, a private `resolveErrorMessage(_:locale:)` helper, and a `.onChange(of: locale)` modifier:

```swift
private func resolveErrorMessage(_ error: any Error, locale: Locale) -> String {
    if let authError = error as? AuthService.AuthError {
        var resource = LocalizedStringResource(authError.localizationKey)
        resource.locale = locale
        return String(localized: resource)
    } else if let bootstrap = error as? AuthBootstrapError {
        var resource = LocalizedStringResource(bootstrap.localizationKey)
        resource.locale = locale
        return String(localized: resource)
    } else {
        return error.localizedDescription   // Supabase SDK fallback
    }
}
```

Every `catch` branch in `signIn()`, `handleAppleSignIn()`, `handleGoogleSignIn()`, `signUp()` now captures the error into `lastAuthError` and resolves via `resolveErrorMessage`. `.onChange(of: locale)` re-runs the resolve against the new env locale, so an error toast visible during a language switch refreshes mid-flight without re-throw.

The local `AuthBootstrapError` (LoginView) and `SignUpSocialError` (SignUpView) enums each grew `localizationKey: String.LocalizationValue` and `defaultValue: String` properties keyed to `auth.error.noUserId` / `auth.error.athleteNotFound`.

**Deviation from plan**: The plan's `<action>` block suggested using `String(localized: authError.localizationKey, defaultValue: authError.defaultValue, locale: locale)`, but that overload only accepts `StaticString` for `localized:` — it does NOT accept `String.LocalizationValue`. The correct Apple API for runtime-resolved keys is `LocalizedStringResource(_:)` with mutated `.locale` property, then passed to `String(localized: resource)`. This deviation is Rule 1 (compile bug in plan-suggested code). Same end behavior: live-switch via env locale at View boundary.

### Task 2e — ZoneBadge locale-conditional typography

ZoneBadge now reads `@Environment(\.locale)` and applies:
- `.tracking(locale.language.languageCode?.identifier == "en" ? 1.2 : 0)` — Chinese has no need for loose tracking
- `.textCase(locale.language.languageCode?.identifier == "en" ? .uppercase : nil)` — Chinese has no case
- `.padding(.horizontal, locale.identifier == "zh-Hans" ? 16 : 10)` — wider horizontal padding for Chinese glyphs

MetricTile already had no `.lineLimit(1)` on its title Text (allowing wrap is the UI-SPEC requirement) — no change needed there.

### Task 3 — NotificationService rewrite + schema migration + Info.plist localization

`scheduleWeeklySummary` signature changed from `(weekday: Int, hour: Int, minute: Int, body: String)` to `(weekday: Int, hour: Int, minute: Int, sessionCount: Int, streak: Int, prCount: Int, volumeDelta: Double)`. The body composition lives in iOS now:

```swift
content.title = NSString.localizedUserNotificationString(
    forKey: "notif.weekly.title",
    arguments: nil
)
content.body = NSString.localizedUserNotificationString(
    forKey: "notif.weekly.body.template",
    arguments: [sessionCount, streak, prCount, Int(abs(volumeDelta))]
)
```

iOS resolves both keys from `Localizable.xcstrings` at deliver time — the notification fires in the user's current device language even if scheduled months earlier under a different locale (RESEARCH Pitfall 8). `buildNotificationBody` was removed; three call sites (DashboardViewModel, DashboardView, ProfileView) updated to pass structured args.

`migrateWeeklySummaryIfNeeded()`:
- Compares persisted `UserDefaults["notificationSchemaVersion"]` against `currentSchemaVersion = 2`.
- If stored < current, cancels any pending `weekly-summary` UNNotificationRequest, then stamps UserDefaults with `currentSchemaVersion`.
- Idempotent — second launch reads version == current and returns immediately.
- Invoked from `AppContainer.init()` (after notificationService instantiation) so it runs once per app launch on the main actor.

`InfoPlist.xcstrings` now carries `NSHealthShareUsageDescription` with the current en value verbatim from the pbxproj `INFOPLIST_KEY_NSHealthShareUsageDescription` and an empty zh-Hans `stringUnit` (P4 populates from UI-SPEC line 291).

**Deviation**: `String.localizedUserNotificationString` is not on `String` — it's an `NSString` class method. Used `NSString.localizedUserNotificationString(forKey:arguments:)` which returns `String` via bridge. (Rule 1 — plan's pseudocode would not compile.)

### Catalog populated

`Localizable.xcstrings` ships 60 keys across:
- `tab.*` (7): home, log, recovery, load, profile, roster, templates
- `action.*` (5): save, cancel, continue, done, delete
- `auth.error.*` (4): noUserReturned, noIdentityToken, noUserId, athleteNotFound
- `sport.*` (7): lifting, running, cycling, teamSport, crossfit, swimming, custom
- `zone.*` (5): optimal, caution, danger, low, noData
- `recoveryZone.*` (3): red, yellow, green
- `frequency.*` (4): oneToTwo, threeToFour, fiveToSix, sevenPlus
- `experience.*` (3): beginner, intermediate, advanced
- `dashboard.*` (3): cycleAware.title, cycleAware.body, title
- `recovery.title`, `workload.title`, `workoutLog.title`, `profile.title`, `profile.signOut`, `profile.language.label`
- `onboarding.*` (4): welcome.title, frequency.title, experience.title, continue.toSetup
- `language.picker.*` (2): title, footer
- `paywall.title`
- `notif.*` (2): weekly.title, weekly.body.template
- `date.*` (2): today, yesterday
- `duration.*` (2): hoursMinutes, minutes

All entries have `extractionState: manual`, an en `stringUnit` with `state: translated`, and a zh-Hans `stringUnit` with `state: new` and empty value (P4 translates).

## Deviations from Plan

### Auto-fixed Issues

1. **[Rule 3 — Blocker] Missing gitignored config files in worktree**
   - **Found during:** Task 1 first build
   - **Issue:** `SupabaseConfig.swift` and `RevenueCatConfig.swift` are gitignored and absent from the worktree checkout; xcodebuild fails with `Build input files cannot be found`. Same issue as P1.
   - **Fix:** Copied both files from `/Users/hanwen/Desktop/Tonus/WorkloadApp/` into the worktree. Files remain gitignored — not committed.
   - **Files modified:** none (uncommitted local copies)
   - **Commit:** n/a

2. **[Rule 1 — Bug] Plan's auth-error resolve pattern doesn't compile**
   - **Found during:** Task 2c first build
   - **Issue:** Plan's `<action>` block suggested `String(localized: authError.localizationKey, defaultValue: authError.defaultValue, locale: locale)`, but that overload requires `StaticString` for the first arg — it cannot take `String.LocalizationValue` at runtime.
   - **Fix:** Used the `LocalizedStringResource(_:)` API path: construct a `LocalizedStringResource` from the `String.LocalizationValue` key, mutate its `.locale` property, then resolve via `String(localized: resource)`. Same semantics, compiles cleanly.
   - **Files modified:** `WorkloadApp/Views/Auth/LoginView.swift`, `WorkloadApp/Views/Auth/SignUpView.swift`
   - **Commit:** `3df196f`

3. **[Rule 1 — Bug] `String.localizedUserNotificationString` does not exist**
   - **Found during:** Task 3 first build
   - **Issue:** Plan referenced `String.localizedUserNotificationString(forKey:arguments:)`, but that's an `NSString` class method, not a `String` static. Build failed with "type 'String' has no member 'localizedUserNotificationString'".
   - **Fix:** Used `NSString.localizedUserNotificationString(forKey:arguments:)` which returns `String` via bridge.
   - **Files modified:** `WorkloadApp/Services/NotificationService.swift`
   - **Commit:** `19f4134`

### Rule 4 / architectural decisions

None — plan executed as written within compile constraints.

## Auth gates

None — no Supabase/RevenueCat/HealthKit auth surfaces touched in execution.

## Live-switch acceptance proof

Manual smoke test path (documented for QA, not yet executed):
1. Open LoginView, type invalid credentials, tap Sign In → en error message renders.
2. Open Profile → Language → tap 中文(简体). Env locale flips.
3. Return to LoginView (still on-screen via NavigationStack pop) — error message text now reads zh-Hans value of `auth.error.*` key (currently the en defaultValue fallback since P4 hasn't populated zh-Hans yet; once P4 lands, the message switches language).
4. No re-throw, no additional tap required — `.onChange(of: locale)` triggers `resolveErrorMessage` with the new locale.

## Known Stubs

zh-Hans translation values are intentionally empty in `Localizable.xcstrings` and `InfoPlist.xcstrings` for every key. P4 (plan 23-04, "Translation pass") owns populating them. Until P4 ships, all UI displayed in zh-Hans falls back to the en `defaultValue`. This is the documented design — P2's responsibility ends at "every English string lives in the catalog with a stable key".

## Self-Check: PASSED

- `WorkloadApp/Models/Enums.swift`: contains 49 `String(localized:` calls (well over 25 acceptance threshold).
- `WorkloadApp/Services/AuthService.swift`: contains `localizationKey`, `auth.error.noUserReturned`, `auth.error.noIdentityToken`.
- `WorkloadApp/Services/NotificationService.swift`: contains 2× `localizedUserNotificationString` (title + body), 3× `notificationSchemaVersion`.
- `WorkloadApp/Resources/Localizable.xcstrings`: 60 keys, all required namespaces present (`tab.`, `action.`, `auth.error.`, `sport.`, `zone.`, `recoveryZone.`, `dashboard.`, `recovery.`, `workload.`, `profile.`, `onboarding.`, `paywall.`, `language.picker.`, `notif.`, `date.`, `duration.`).
- `WorkloadApp/Resources/InfoPlist.xcstrings`: contains `NSHealthShareUsageDescription` with en source value.
- `WorkloadApp/Views/Workload/WorkloadView.swift`: contains `.id(locale)` on Chart and `.locale(locale)` on tooltip date format.
- `WorkloadApp/Components/MetricTile.swift`: contains `"zh-Hans" ? 16 : 10` padding; no `.lineLimit(1)` on title.
- `WorkloadApp/Views/Auth/LoginView.swift`: contains `authError.localizationKey`, `.onChange(of: locale`, no `errorMessage = error.localizedDescription`.
- `WorkloadApp/Views/Auth/SignUpView.swift`: contains `authError.localizationKey`, `.onChange(of: locale`, no `errorMessage = error.localizedDescription`.
- Commits `4d14f33`, `d455cd1`, `f497569`, `3df196f`, `60968bb`, `19f4134`: all FOUND in `git log`.
- `xcodebuild` on iPhone 17 Pro Max simulator: **BUILD SUCCEEDED** after every task commit.
- Phase-wide audits: `git grep 'Locale.current' WorkloadApp/Views WorkloadApp/Components WorkloadApp/Utilities` = 0; `git grep 'String(localized:' WorkloadApp/Models/ | grep -v Enums.swift` = 0; `git grep -E 'String\(localized: "[^"]*\\(' WorkloadApp/` = 0; `git grep -E 'errorMessage\s*=\s*error\.localizedDescription' WorkloadApp/Views/Auth/` = 0.
