---
phase: 23-multi-language-in-app-support-simplified-chinese
reviewed: 2026-05-27T00:00:00Z
depth: standard
files_reviewed: 29
files_reviewed_list:
  - WorkloadApp/App/AppContainer.swift
  - WorkloadApp/App/AppRouter.swift
  - WorkloadApp/App/WorkloadApp.swift
  - WorkloadApp/Components/HRVTrendChart.swift
  - WorkloadApp/Components/MetricTile.swift
  - WorkloadApp/Components/SleepTrendChart.swift
  - WorkloadApp/Models/Enums.swift
  - WorkloadApp/Services/AuthService.swift
  - WorkloadApp/Services/LocaleManager.swift
  - WorkloadApp/Services/NotificationService.swift
  - WorkloadApp/Utilities/DateHelpers.swift
  - WorkloadApp/Utilities/FontTokens.swift
  - WorkloadApp/Utilities/WeightFormatter.swift
  - WorkloadApp/ViewModels/DashboardViewModel.swift
  - WorkloadApp/Views/Auth/LoginView.swift
  - WorkloadApp/Views/Auth/SignUpView.swift
  - WorkloadApp/Views/Dashboard/DashboardView.swift
  - WorkloadApp/Views/Onboarding/OnboardingView.swift
  - WorkloadApp/Views/Profile/LanguagePickerView.swift
  - WorkloadApp/Views/Profile/ProfileView.swift
  - WorkloadApp/Views/Recovery/RecoveryView.swift
  - WorkloadApp/Views/Workload/RecoveryLoadChart.swift
  - WorkloadApp/Views/Workload/WorkloadView.swift
  - WorkloadApp/Views/WorkoutLog/ActiveWorkoutSheet.swift
  - WorkloadApp/Views/WorkoutLog/SessionDetailView.swift
  - WorkloadApp/Views/WorkoutLog/WorkoutImportBanner.swift
  - WorkloadApp/Views/WorkoutLog/WorkoutLogView.swift
  - WorkloadApp/Resources/Localizable.xcstrings
  - WorkloadApp/Resources/InfoPlist.xcstrings
findings:
  critical: 6
  warning: 9
  info: 5
  total: 20
status: issues_found
---

# Phase 23: Code Review Report

**Reviewed:** 2026-05-27
**Depth:** standard
**Files Reviewed:** 29
**Status:** issues_found

## Summary

Phase 23 ships a LocaleManager / env-locale injection pattern, font cascade (General Sans → Noto Sans SC), deferred-localization for the weekly notification, and locale-aware date / duration / weight formatters. The plumbing is competent — env locale propagates through `.environment(\.locale, ...)` at AppRouter root, charts use `.id(locale)` to force re-resolution, error messages are re-resolved on locale change, and the NotificationService correctly uses `localizedUserNotificationString` with a schema migration.

But the catalog itself is the weak point: large portions of the user-facing UI are bare English string literals never added as catalog keys, and many of the enum `displayName` keys that *are* referenced via `String(localized:)` have no corresponding entry in `Localizable.xcstrings` at all. The net effect is that a zh-Hans user will see a heavily English UI in Profile, Dashboard sub-headers, Workout Log, Recovery, Workload, Auth, and Onboarding (everything that wasn't part of the surgical locale-aware utilities). The notification body template has a placeholder/argument count mismatch, the Info.plist privacy string contains the dead brand name "Tonus" instead of "Tuwa" and has lossy zh-Hans content, and the LanguagePicker has an Image-with-empty-systemName glitch.

## Critical Issues

### CR-01: zh-Hans translations missing for most enum displayName keys

**File:** `WorkloadApp/Resources/Localizable.xcstrings`, `WorkloadApp/Models/Enums.swift:128-400`
**Issue:** `Enums.swift` references the following `String(localized:)` keys, but they are **not present** in the string catalog: `exerciseCategory.compound/isolation/cardio/bodyweight/plyometric/drill/interval`, `muscleGroup.chest/back/legs/shoulders/arms/core/fullBody`, `prType.maxWeight/maxReps/maxVolume/fastestPace`, `sessionType.strength/skill/cardio/match/recovery`, `acwrMethod.ewma/rolling28day`, `loadSource.srpe/trimp/combined`, `weightUnit.kg/lbs`, `prescriptionStatus.assigned/completed/skipped`, `cyclePhase.earlyFollicular/lateFollicular/ovulatory/earlyLuteal/lateLuteal/unknown`, `bodyRegion.shoulder/knee/back/hip/ankle/wrist/elbow/neck`, `experience.beginner.subtitle/intermediate.subtitle/advanced.subtitle`. Because each call site supplies `defaultValue:` in English, zh-Hans users will read English labels everywhere these are surfaced (Profile pickers, ActiveWorkoutSheet session/sport pickers, prescription cards, cycle UI, onboarding subtitles, PR cards, etc.). This is a phase-defining defect: the phase title is "Simplified Chinese support".
**Fix:** Add every key listed above to `Localizable.xcstrings` with both `en` and `zh-Hans` `translated` strings. The state should be `translated`, not `new`, before shipping.

### CR-02: Notification body template — placeholder/argument count mismatch

**File:** `WorkloadApp/Services/NotificationService.swift:71-74`, `WorkloadApp/Resources/Localizable.xcstrings:386-387`
**Issue:** Code passes **4** integer arguments to `localizedUserNotificationString(forKey: "notif.weekly.body.template", arguments:)` — `[sessionCount, streak, prCount, Int(abs(volumeDelta))]` — but both the `en` and `zh-Hans` templates contain only **3 `%lld` placeholders**. `volumeDelta` is silently dropped. The doc comment ("4th arg") and the schema migration (v2) both lie about what ships. If a future translator restores a 4th placeholder, the existing scheduled notification will format with the wrong value because translators expect ordered args.
**Fix:** Either add a 4th `%lld` placeholder (e.g. include "%lld%% volume vs. last week") to both en and zh-Hans values and use positional specifiers (`%1$lld … %4$lld`) so translators can reorder safely, or drop `volumeDelta` from the arguments array. Use positional specifiers in any string with ≥2 args to avoid CJK word-order traps.

### CR-03: Info.plist HealthKit privacy string — wrong brand name and lossy zh-Hans

**File:** `WorkloadApp/Resources/InfoPlist.xcstrings:11-18`
**Issue:** Per project memory and global instructions, the app is **Tuwa**, never "Tonus" or "Faros". The English value correctly says "Tuwa reads…" but the **zh-Hans value says "Tonus 读取您的心率…"** — wrong brand. Additionally, the zh-Hans translation lists only "心率、心率变异性和睡眠" and adds an unsourced claim ("这些原始数据不会离开您的设备"), while English lists six data types (HRV, RHR, sleep, workout HR, body temperature, VO2 Max). This is the App Store-facing HealthKit consent prompt — Apple reviewers will see the mismatch and the "Tonus" brand will surface to every Chinese user at first launch.
**Fix:** Replace zh-Hans value with a faithful translation that (a) uses "Tuwa", (b) enumerates all six data types, and (c) drops any privacy guarantee not in the English source.

### CR-04: Empty `Image(systemName: "")` in LanguagePickerView / OnboardingView checkmark slot

**File:** `WorkloadApp/Views/Profile/LanguagePickerView.swift:36-39`, `WorkloadApp/Views/Onboarding/OnboardingView.swift:77-81`
**Issue:** When a locale row is not the active one, the code passes `Image(systemName: "")`. SF Symbols logs `"No symbol named '' found in system symbol set"` to the console on every render; on some iOS versions the image renders as a small placeholder square, breaking the layout's checkmark alignment. The "blank to reserve width" pattern only works for `Text`, not `Image`.
**Fix:** Use a frame-only spacer or conditional view:
```swift
if container.localeManager.activeLocale.identifier == locale.identifier {
    Image(systemName: "checkmark")
        .frame(width: 24)
        .foregroundStyle(ColorTokens.text1)
} else {
    Color.clear.frame(width: 24, height: 1)
}
```

### CR-05: `HeroReadinessCard.dateLabel` formatter ignores env locale

**File:** `WorkloadApp/Views/Dashboard/DashboardView.swift:257-261`
**Issue:** The "READINESS · TUE 27 MAY" header uses a raw `DateFormatter` with `dateFormat = "EEE d MMM"` and no `.locale` assignment. The formatter therefore defaults to `Locale.autoupdatingCurrent` (system locale), not the env locale the rest of the app reads. A zh-Hans user whose iOS system language is English will see "TUE 27 MAY" instead of the localized form. The view doesn't read `@Environment(\.locale)`, and `.uppercased()` mangles CJK characters that have no case (no-op visually but semantically wrong and prevents a future Chinese weekday from rendering correctly).
**Fix:** Inject locale and configure formatter:
```swift
@Environment(\.locale) private var locale
private var dateLabel: String {
    let f = DateFormatter()
    f.locale = locale
    f.setLocalizedDateFormatFromTemplate("EEEdMMM")
    let s = f.string(from: .now)
    return locale.language.languageCode?.identifier == "en" ? s.uppercased() : s
}
```

### CR-06: `ZoneBadge` locale-conditional padding breaks under any zh variant other than identifier == "zh-Hans"

**File:** `WorkloadApp/Components/MetricTile.swift:42-58`
**Issue:** `padding(.horizontal, locale.identifier == "zh-Hans" ? 16 : 10)` — `locale.identifier` produced by SwiftUI's env-locale propagation is frequently a regionalized form (e.g. `"zh-Hans_US"`, `"zh-Hans_CN"`) depending on iOS region settings, not the bare `"zh-Hans"` set by LocaleManager. The padding/case-toggle then takes the wrong branch on devices set to e.g. China region: tracking 1.2 and `.textCase(.uppercase)` will be applied to Chinese glyphs. The earlier `.tracking()` / `.textCase()` lines correctly use `locale.language.languageCode?.identifier == "en"` — the padding line must use the same comparison.
**Fix:**
```swift
.padding(.horizontal, locale.language.languageCode?.identifier == "zh" ? 16 : 10)
```
Audit every other `locale.identifier == "zh-Hans"` comparison in the codebase (ProfileView:164 has the same bug for the picker right-detail label) and switch to `languageCode?.identifier`.

## Warnings

### WR-01: Most user-facing strings in Profile/Dashboard/Recovery/Workload/Auth/Onboarding are bare English literals with no catalog entry

**File:** `WorkloadApp/Views/Profile/ProfileView.swift` (passim), `Views/Dashboard/DashboardView.swift`, `Views/Recovery/RecoveryView.swift`, `Views/Workload/WorkloadView.swift`, `Views/Auth/LoginView.swift`, `Views/Auth/SignUpView.swift`, `Views/Onboarding/OnboardingView.swift:107-156`, `Views/WorkoutLog/*.swift`, `Views/WorkoutLog/WorkoutImportBanner.swift`
**Issue:** `Text("Sign Out")`, `Text("Profile")`, `sectionHeader("ATHLETE")`, `Text("Weekly Summary")`, `Text("Hormonal Contraceptive")`, `Text("Pregnant")`, `Text("Lactating")`, `Text("Weight Unit")`, `Text("ACWR Method")`, `Text("Load Metric")`, `Text("Enable Coach Mode")`, `Text("Invite My Coach")`, `Text("Sign In")`, `Text("Create Account")`, `Text("PASSWORD")`, `Text("EMAIL")`, `Text("READINESS · …")`, `Text("TRAINING LOAD")`, `Text("RECENT SESSIONS")`, `Text("INSIGHTS")`, `Text("BEHAVIOR IMPACT")`, `Text("WELLNESS CHECK-INS")`, `Text("RECOVERY SCORE")`, `Text("ACWR")`, `Text("LOAD TREND")`, `Text("RECENT PRS")`, `Text("PRESCRIBED")`, `Text("Workout Log")`, `Text("Add Exercise")`, `Text("Add Set")`, `Text("Cancel")`, `Text("Finish")`, `Text("Import Workout")`, `Text("Import")`, `Text("How hard was this session?")`, `Text("How often do you train?")`, `Text("What's your training experience?")`, `Text("Connect Health")`, `Text("Skip for now")`, etc. SwiftUI treats `Text("literal")` as a `LocalizedStringKey`, so this *would* localize — but none of these keys exist in `Localizable.xcstrings`. zh-Hans users see English. The UI-SPEC ties phase 23 to comprehensive zh-Hans support; this is the bulk of the surface area still untranslated.
**Fix:** Add catalog entries for every visible literal. Migrate keys to a stable namespaced convention (`profile.section.athlete`, `profile.signOut`, `recovery.section.score`, etc.) rather than relying on English-as-key, and assign translated zh-Hans values. Prefer stable keys over English-as-key so future copy edits don't silently drop translations.

### WR-02: `String.LocalizationValue(message)` wraps a non-key as if it were one

**File:** `WorkloadApp/Services/AuthService.swift:128-131`
**Issue:** For `case .socialSignInFailed(let message)`, `localizationKey` returns `String.LocalizationValue(message)`. `LocalizationValue` expects a *key* (used for catalog lookup), not arbitrary user-facing text. When `resolveErrorMessage` calls `LocalizedStringResource(authError.localizationKey)` and then `String(localized: resource)`, iOS will look up the *server-originated error message* as a catalog key, fail to find it, and return the raw string. That works by accident today, but logs noise and could silently localize one day if a server message happens to match a real catalog key (e.g. a server returning `"Cancel"`).
**Fix:** Return a tagged sentinel like `"auth.error.socialSignInFailed"` for the catalog key path, and surface the opaque server text via a separate property the view chooses explicitly:
```swift
case .socialSignInFailed: return "auth.error.socialSignInFailed"
```
and in `resolveErrorMessage`, special-case `.socialSignInFailed(let m)` to return `m` directly.

### WR-03: LocaleManager init does not normalize zh-CN preferred-language tag persistence path

**File:** `WorkloadApp/Services/LocaleManager.swift:26-42`
**Issue:** First-launch resolves zh-CN → `zh-Hans` (correct), but if the user later picks zh-Hans explicitly via the picker and `UserDefaults` is later corrupted to a non-whitelist value (e.g. a future build adds `zh-Hant` then is rolled back), the init silently falls through to "system locale" branch. This is **defensive whitelisting working as designed**, but the comment claims "invalid stored value: silently follow system locale" — that path will then **also not persist**, so each launch keeps re-resolving from system. If the user is on a zh-Hant device after rolling back a Hant build, they'll get English silently every launch with no way to surface this. Low impact today (only en + zh-Hans shipping) but a footgun for the next locale.
**Fix:** On invalid stored value, log to console in DEBUG and proactively clear the bad key so the picker UI presents a clean state.

### WR-04: `LanguagePickerView.activeLocale.identifier` mid-string compare won't pop, but `setLocale` regions

**File:** `WorkloadApp/Services/LocaleManager.swift:46-50`, `WorkloadApp/Views/Profile/LanguagePickerView.swift:33`
**Issue:** `setLocale` guards on `supported.map(\.identifier).contains(locale.identifier)`. When the env locale is reconstructed by SwiftUI it may be `Locale(identifier: "zh-Hans_US")` not `Locale(identifier: "zh-Hans")`, but here the picker always passes one of `supportedLocales` directly, so today this works. However, if any other caller (deep-link handler, screenshot launch arg path) constructs the locale differently, the guard silently rejects it. Combined with CR-06, this is the same `identifier` vs `language.languageCode` confusion.
**Fix:** Compare on `language.languageCode?.identifier` (and `language.script?.identifier` for `zh-Hans`/`zh-Hant`) when normalizing user-supplied locales.

### WR-05: `cascaded(...)` Font factory crashes silently if fonts aren't registered

**File:** `WorkloadApp/Utilities/FontTokens.swift:65-77`
**Issue:** `UIFont(descriptor:size:)` will fall back to system font if `GeneralSans-Regular`, `GeneralSans-Medium`, `NotoSansSC-Regular`, or `NotoSansSC-Medium` PostScript names cannot be resolved — there's no error, no log, just system font. The DEBUG asserts in `WorkloadApp.init()` check the *family* "Noto Sans SC" exists, not the specific PostScript faces. The doc comment warns to verify PostScript names match `UIFont.fontNames(forFamilyName:)` output, but the assert doesn't gate on the exact names — a release build with a renamed font produces silent fallback to system, no CJK cascade.
**Fix:** Add asserts on the exact PostScript names used:
```swift
#if DEBUG
let required = ["GeneralSans-Regular", "GeneralSans-Medium",
                "NotoSansSC-Regular", "NotoSansSC-Medium"]
for ps in required {
    assert(UIFont(name: ps, size: 12) != nil, "Missing font PostScript name: \(ps)")
}
#endif
```

### WR-06: `RecoveryComponentRow` HRV / RHR / Sleep values render hardcoded English-style units (zh-Hans)

**File:** `WorkloadApp/Views/Recovery/RecoveryView.swift:262-272`
**Issue:** `"%.0f ms"`, `"%.0f bpm"`, `"\(hours)h \(mins)m"` are concatenated English. In zh-Hans, users expect 毫秒 / 次/分 / x小时y分钟 (matching the duration helper that *was* localized). The Dashboard's `sleepString` (line 442-446) has the same problem. The Workload view's `String(format: "%.0f kg")` (WorkloadView:51, ActiveWorkoutSheet PR overlay line 635) likewise hardcodes "kg" even though WeightFormatter exists exactly for this.
**Fix:** Route HRV/RHR/sleep through localized format strings (`"recovery.hrv.value" = "%lld 毫秒"` in zh-Hans), and route weight strings through `WeightFormatter.display(...)` with env locale. The duration helper already exists in DateHelpers — call it.

### WR-07: `MeasurementFormatter.unitOptions = .providedUnit` defeats locale-localized unit choice

**File:** `WorkloadApp/Utilities/WeightFormatter.swift:19-22, 51-54`
**Issue:** `.providedUnit` forces kg/lbs verbatim regardless of locale. That's intentional (user-chosen unit must be honored), but the docstring comment shows `"82.5 公斤"` — `MeasurementFormatter` with `unitStyle: .medium, unitOptions: .providedUnit` in zh-Hans will render "82.5 千克" (full word) or "82.5 公斤" depending on system, not "kg". If the user picks `.lbs`, zh-Hans output is "82.5 磅" — not always desired by lifters who expect "lb". Confirm with product whether the unit *symbol* should be locale-translated.
**Fix:** If you want stable "kg"/"lb" everywhere, append the unit manually instead of using `MeasurementFormatter`. If you want localized units, the docstring example is the wrong character (公斤 is OK, 千克 is the formal CN). At minimum, drop the misleading example from the docstring.

### WR-08: `Calendar.current.weekdaySymbols` ignores env locale in Profile notification picker

**File:** `WorkloadApp/Views/Profile/ProfileView.swift:254-256`
**Issue:** `Calendar.current.weekdaySymbols[weekday - 1]` returns localized weekday names using the **system** locale (Calendar.current), not the env locale the rest of the app honors. zh-Hans users with English iOS will see "Sunday/Monday/..." inside the picker rendered on otherwise-zh-Hans screens.
**Fix:**
```swift
var cal = Calendar.current
cal.locale = locale  // from @Environment(\.locale)
return cal.weekdaySymbols[weekday - 1]
```

### WR-09: AM/PM hardcoded — broken for any 24-hour locale

**File:** `WorkloadApp/Views/Profile/ProfileView.swift:276-282`
**Issue:** Time picker formats with `let ampm = hour >= 12 ? "PM" : "AM"`. zh-Hans typically uses 24-hour format ("19:00") or 上午/下午 prefix. The picker stores `"19:00"` in UserDefaults (good — locale-independent) but always *displays* "7:00 PM". On a zh-Hans device this is jarring and wrong.
**Fix:** Build a `Date` from `hour:minute` components, then use `Date.FormatStyle.time(.shortened).locale(locale)` for display.

## Info

### IN-01: `LanguagePickerView` does not pop after selection — confirm UX intent

**File:** `WorkloadApp/Views/Profile/LanguagePickerView.swift:6-49`
**Issue:** Comment says "Live-renders immediately (no auto-pop) per UI-SPEC line 173." Behavior is intentional, but new users may tap a row, see the checkmark move, and not know how to back out. No issue if intentional — flagged for QA confirmation. Add a haptic / visible toast confirming "Switched to 中文" to reduce ambiguity.

### IN-02: Unused fallback strings in catalog (English bare-key)

**File:** `WorkloadApp/Views/Profile/ProfileView.swift:514-518`
**Issue:** `.alert("Your Invite Code", isPresented: …) {...} message: { code in Text("Share this code with your coach:\n\n\(code)\n\nExpires in 48 hours.") }` — alert title and body are bare English literals, not in catalog. Same pattern in delete-account confirm (line 558).
**Fix:** Add catalog entries for these alert strings.

### IN-03: `defaultValue` parameter is `LocalizedStringResource`-compatible String, not `String.LocalizationValue`

**File:** `WorkloadApp/Views/Auth/LoginView.swift:298-317`, `Views/Auth/SignUpView.swift:302-321`
**Issue:** `AuthBootstrapError.defaultValue` returns `String`, but `localizationKey` is `String.LocalizationValue`. The `resolveErrorMessage` path constructs `LocalizedStringResource(authError.localizationKey)` then sets `.locale`. It never passes `defaultValue` to the resource — so if the catalog lookup fails, the user sees the *key* (`"auth.error.noUserId"`) instead of the English fallback. Use `LocalizedStringResource(localizationKey, defaultValue: defaultValue)`.
**Fix:**
```swift
var resource = LocalizedStringResource(authError.localizationKey,
                                       defaultValue: .init(stringLiteral: authError.defaultValue))
resource.locale = locale
```
(Verify the LocalizedStringResource initializer; this API has shipped variants — pin to one and test against a missing key.)

### IN-04: Duplicate enum definitions for the same error in LoginView and SignUpView

**File:** `WorkloadApp/Views/Auth/LoginView.swift:298-317`, `Views/Auth/SignUpView.swift:302-321`
**Issue:** `AuthBootstrapError` (LoginView) and `SignUpSocialError` (SignUpView) define identical cases (`noUserId`, `athleteNotFound`) with identical localization keys. This is dead-weight code duplication that will drift.
**Fix:** Hoist into one shared enum in `Services/AuthService.swift` or a new `AuthBootstrapError.swift`.

### IN-05: `OnboardingView` step 1/2 use hardcoded English titles/subtitles

**File:** `WorkloadApp/Views/Onboarding/OnboardingView.swift:107-108, 154-155`
**Issue:** `stepHeader(title: "How often do you train?", subtitle: "This helps us calibrate…")` and the experience-level step pass raw English. Only step 0 (language) uses catalog keys. Step 3 (HealthKit) also uses raw English. Onboarding is the first impression for a zh-Hans user.
**Fix:** Add `onboarding.frequency.title/subtitle`, `onboarding.experience.title/subtitle`, `onboarding.healthkit.title/subtitle` etc. and pass as LocalizedStringKey.

---

_Reviewed: 2026-05-27_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
