---
phase: 23-multi-language-in-app-support-simplified-chinese
plan: 01
subsystem: i18n
tags: [locale, scaffolding, swiftui, xcstrings, observable]
requires:
  - SwiftUI / SwiftData (iOS 17+)
  - AppContainer + @Environment(AppContainer.self) dependency injection (pre-existing)
provides:
  - LocaleManager service (@MainActor @Observable) with UserDefaults-persisted user pick
  - Root .environment(\.locale, …) injection with 150ms crossfade in AppRouter
  - Empty Localizable.xcstrings + InfoPlist.xcstrings registered as bundle resources
  - Locale-aware DateHelpers (shortString/relativeString/durationString)
  - Locale-aware WeightFormatter (display/displayVolume via MeasurementFormatter)
  - LanguagePickerView (push destination from Profile)
  - Onboarding step 0 (language picker; 4-step flow)
affects:
  - WorkloadApp/Services/LocaleManager.swift (NEW)
  - WorkloadApp/App/AppContainer.swift (+localeManager property)
  - WorkloadApp/App/AppRouter.swift (+env-locale + crossfade + screenshot hook)
  - WorkloadApp/Utilities/DateHelpers.swift (signature change: + Locale)
  - WorkloadApp/Utilities/WeightFormatter.swift (signature change: + Locale)
  - WorkloadApp/Resources/Localizable.xcstrings (NEW)
  - WorkloadApp/Resources/InfoPlist.xcstrings (NEW)
  - workload management/workload-management-Info.plist (+CFBundleDevelopmentRegion, +CFBundleLocalizations)
  - WorkloadApp/Views/Profile/LanguagePickerView.swift (NEW)
  - WorkloadApp/Views/Profile/ProfileView.swift (+language row)
  - WorkloadApp/Views/Onboarding/OnboardingView.swift (4-step flow)
  - WorkloadApp/Views/Dashboard/DashboardView.swift (call-site fix)
  - WorkloadApp/Views/Recovery/RecoveryView.swift (call-site fix)
  - WorkloadApp/Views/WorkoutLog/SessionDetailView.swift (call-site fix)
  - WorkloadApp/Views/WorkoutLog/WorkoutImportBanner.swift (call-site fix)
  - WorkloadApp/Views/WorkoutLog/WorkoutLogView.swift (call-site fix)
  - WorkloadApp/Views/WorkoutLog/ActiveWorkoutSheet.swift (call-site fix)
  - workload management/workload management.xcodeproj/project.pbxproj (+5 file refs)
tech-stack:
  added:
    - String Catalog (.xcstrings) format
    - MeasurementFormatter (UnitMass-based weight rendering)
  patterns:
    - "@MainActor @Observable service in AppContainer (analog: SubscriptionService)"
    - "Root env-locale injection with .animation(.linear(duration: 0.15)) crossfade"
    - "Locale parameter on every utility helper — no Locale.current in Views/Utilities"
    - "Push-navigation picker row pattern with checkmark in text1 (never accent)"
key-files:
  created:
    - WorkloadApp/Services/LocaleManager.swift
    - WorkloadApp/Views/Profile/LanguagePickerView.swift
    - WorkloadApp/Resources/Localizable.xcstrings
    - WorkloadApp/Resources/InfoPlist.xcstrings
  modified:
    - WorkloadApp/App/AppContainer.swift
    - WorkloadApp/App/AppRouter.swift
    - WorkloadApp/Utilities/DateHelpers.swift
    - WorkloadApp/Utilities/WeightFormatter.swift
    - WorkloadApp/Views/Profile/ProfileView.swift
    - WorkloadApp/Views/Onboarding/OnboardingView.swift
    - WorkloadApp/Views/Dashboard/DashboardView.swift
    - WorkloadApp/Views/Recovery/RecoveryView.swift
    - WorkloadApp/Views/WorkoutLog/SessionDetailView.swift
    - WorkloadApp/Views/WorkoutLog/WorkoutImportBanner.swift
    - WorkloadApp/Views/WorkoutLog/WorkoutLogView.swift
    - WorkloadApp/Views/WorkoutLog/ActiveWorkoutSheet.swift
    - workload management/workload-management-Info.plist
    - workload management/workload management.xcodeproj/project.pbxproj
decisions:
  - "LocaleManager.init() does NOT persist on first-launch system default — only on explicit user pick (D-15)"
  - "First-launch system-locale coarse mapping: zh-Hans/zh-CN → zh-Hans; everything else (incl. zh-Hant) → en (A5)"
  - "UserDefaults reads whitelisted against supportedLocales.map(\\.identifier) to mitigate T-23-01 tampering"
  - "Continue label is locale-key parameterized per step (toSetup on step 0, action.continue elsewhere) — keys not yet in catalog; render as raw keys until P2 populates"
  - "All call sites of locale-aware helpers updated in this plan to keep build green, not deferred to P2 (avoid temporarily broken compile)"
metrics:
  duration: ~25 min
  tasks_completed: 3
  files_created: 4
  files_modified: 14
  commits: 3
  completed: 2026-05-26
---

# Phase 23 Plan 01: i18n Infrastructure Scaffold — Summary

Built the live-switch i18n plumbing every other plan in phase 23 depends on: a `LocaleManager` service, root-level `.environment(\.locale, …)` injection with a 150 ms crossfade, empty String Catalogs, Info.plist locale registration, locale-aware formatters, and the Profile + Onboarding picker surfaces. App builds clean on iPhone 17 Pro Max simulator; switching language now live-flips the env locale across the entire view tree.

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| 1 | `f01914b` | LocaleManager service + AppContainer wiring + root env-locale injection |
| 2 | `734bf16` | Empty xcstrings + Info.plist locales + locale-aware formatters (+ call-site updates) |
| 3 | `9cd7b41` | LanguagePickerView + Profile language row + onboarding step 0 (4-step flow) |

## What was built

### LocaleManager (Task 1)

`@MainActor @Observable final class LocaleManager` mirroring `SubscriptionService`'s shape. Holds `activeLocale: Locale` (private(set)) and exposes `supportedLocales` (`[en, zh-Hans]`). `init()` reads `UserDefaults["selectedLocaleIdentifier"]`, whitelists against `supported.map(\.identifier)` (T-23-01), and on miss falls back to a coarsely-mapped system locale (`zh-Hans`/`zh-CN` → zh-Hans; everything else, including `zh-Hant`, → en). First-launch system-default is NOT persisted — only explicit `setLocale(_:)` calls write to UserDefaults.

AppContainer instantiates `localeManager` between `notificationService` and `cycleTrackingService`. AppRouter root content view now ends with:

```swift
.environment(container)
.environment(\.locale, container.localeManager.activeLocale)
.animation(.linear(duration: 0.15), value: container.localeManager.activeLocale)
```

The `SCREENSHOT_MODE` `.task` block honors a `-AppleLanguages (zh-Hans)` launch arg as belt-and-braces with Bundle resolution.

### Catalogs + Info.plist + formatters (Task 2)

Created empty `Localizable.xcstrings` and `InfoPlist.xcstrings` under `WorkloadApp/Resources/` (valid xcstrings JSON: `{ "sourceLanguage": "en", "version": "1.0", "strings": {} }`). Both registered as resources of the `workload management` target.

`workload-management-Info.plist` now carries `CFBundleDevelopmentRegion = en` and `CFBundleLocalizations = [en, zh-Hans]`. `SWIFT_EMIT_LOC_STRINGS = YES` was already set on the target — no change needed there.

`DateHelpers.shortString(locale:)` now uses `setLocalizedDateFormatFromTemplate("MMMd")` (renders `May 26` / `5月26日`). `relativeString(locale:)` returns catalog-backed `String(localized: "date.today")` / `"date.yesterday"`, falling through to `shortString(locale:)`. `durationString(seconds:locale:)` is now a static method on `Date` that uses catalog templates `duration.hoursMinutes` / `duration.minutes`.

`WeightFormatter.display` and `displayVolume` now take a `Locale` and use `MeasurementFormatter` (with `.providedUnit` so user choice — kg or lbs — is preserved while locale only governs language). `toKg` and `displayValue` are numeric only and stay locale-free.

Every existing call site of the refactored helpers (DashboardView, RecoveryView, SessionDetailView, WorkoutImportBanner, WorkoutLogView, ActiveWorkoutSheet) was updated to inject `@Environment(\.locale)` and pass it through. This was done in this plan (not deferred) to keep the build green between plans.

`git grep 'Locale.current' WorkloadApp/Utilities/` returns zero matches — D-14 enforcement passes for the utilities tier.

### Picker UI (Task 3)

New `WorkloadApp/Views/Profile/LanguagePickerView.swift` — VStack of hairline-divided autonym rows ("English" / "中文(简体)") with the active row marked by a `checkmark` SF Symbol in `ColorTokens.text1` (never accent). Tapping a row immediately calls `setLocale` (no auto-pop). Footer reads `"language.picker.footer"` (key still unpopulated until P2). Background is `ColorTokens.background`. Zero `RoundedRectangle`, zero `.shadow()`, zero `ColorTokens.accent` in the file (DESIGN.md hard rules).

ProfileView gains a NavigationLink row above the Weight Unit picker that pushes LanguagePickerView, with the trailing value reading "English" or "中文" and a chevron in `text3`.

OnboardingView reshaped to a 4-step flow: `languageStep` at index 0 (new), `frequencyStep` → 1, `experienceStep` → 2, `healthKitStep` → 3. Dot indicators iterate `0..<4`; Continue button is visible for `currentStep < 3`. `isContinueEnabled` returns `true` on step 0 (LocaleManager already pre-selects the system locale on first launch, so the checkmark is always on one row). Continue button label is `"onboarding.continue.toSetup"` on step 0 and `"action.continue"` thereafter — both still appearing as raw keys until P2 populates the catalog.

## Deviations from Plan

### Auto-fixed Issues

1. **[Rule 3 — Blocker] Missing gitignored config files in worktree**
   - **Found during:** Task 1 first build
   - **Issue:** `SupabaseConfig.swift` and `RevenueCatConfig.swift` are gitignored and therefore absent from the worktree checkout; `xcodebuild` failed with `Build input files cannot be found`.
   - **Fix:** Copied both files from the main checkout (`/Users/hanwen/Desktop/Tonus/WorkloadApp/`) into the worktree. They remain gitignored — not committed.
   - **Files modified:** none (uncommitted local copies only)
   - **Commit:** n/a

2. **[Rule 3 — Blocker] pbxproj path in plan was wrong**
   - **Found during:** initial setup
   - **Issue:** PLAN.md and 23-PATTERNS.md reference `workload management.xcodeproj/project.pbxproj` (top-level), but the file is actually at `workload management/workload management.xcodeproj/project.pbxproj` (nested one level deeper).
   - **Fix:** All staging, edits, and commits used the correct nested path.
   - **Files modified:** `workload management/workload management.xcodeproj/project.pbxproj`
   - **Commit:** captured in each of the three task commits

3. **[Rule 3 — Blocker] xcstrings + LanguagePickerView were initially added to pbxproj before the source files existed**
   - **Found during:** Task 1 prep (before first build)
   - **Issue:** I initially added all five new file references (`LocaleManager`, `LanguagePickerView`, two `.xcstrings`) to the pbxproj at the same time, which would have made the Task 1 build fail because the referenced files didn't yet exist on disk.
   - **Fix:** Reverted to a per-task pbxproj-update cadence — only register a file in the pbxproj in the same task that creates it. Task 1 commit only adds `LocaleManager.swift`; Task 2 adds the two `.xcstrings`; Task 3 adds `LanguagePickerView.swift`.
   - **Files modified:** `workload management/workload management.xcodeproj/project.pbxproj`
   - **Commit:** distributed across the three task commits

4. **[Rule 1 — Bug] Doc-comment substrings tripped grep-based design-system check**
   - **Found during:** Task 3 verification
   - **Issue:** My initial `LanguagePickerView.swift` doc comment literally enumerated forbidden tokens ("no RoundedRectangle", "No .shadow()", "NEVER ColorTokens.accent"), which made automated `grep -q "RoundedRectangle" $F` style checks falsely fail.
   - **Fix:** Rewrote the doc comment to summarize DESIGN.md compliance without restating the forbidden tokens verbatim.
   - **Files modified:** `WorkloadApp/Views/Profile/LanguagePickerView.swift`
   - **Commit:** `9cd7b41` (folded into the Task 3 commit)

### Rule 4 / architectural decisions

None — the plan was followed as written.

## Known Stubs

The following keys are referenced in code but the catalog is intentionally empty (P2 owns the populate sweep):

- `language.picker.title`, `language.picker.footer` — LanguagePickerView chrome
- `profile.language.label` — Profile row label
- `onboarding.language.title`, `onboarding.language.subtitle` — Onboarding step 0 header
- `onboarding.continue.toSetup`, `action.continue` — Onboarding continue button
- `date.today`, `date.yesterday`, `duration.hoursMinutes`, `duration.minutes` — DateHelpers

These will render as raw keys (e.g. `language.picker.title`) until P2 lands. Acceptable for a P1 scaffold per the plan objective.

## Auth gates

None — purely local UI / persistence work, no auth surfaces touched.

## Self-Check: PASSED

- `WorkloadApp/Services/LocaleManager.swift`: FOUND
- `WorkloadApp/Views/Profile/LanguagePickerView.swift`: FOUND
- `WorkloadApp/Resources/Localizable.xcstrings`: FOUND
- `WorkloadApp/Resources/InfoPlist.xcstrings`: FOUND
- Commit `f01914b`: FOUND in `git log`
- Commit `734bf16`: FOUND in `git log`
- Commit `9cd7b41`: FOUND in `git log`
- `xcodebuild` on iPhone 17 Pro Max simulator: **BUILD SUCCEEDED** at end of every task
- `git grep 'Locale.current' WorkloadApp/Utilities/`: 0 matches
