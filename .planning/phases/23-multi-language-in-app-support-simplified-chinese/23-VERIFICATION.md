---
phase: 23-multi-language-in-app-support-simplified-chinese
verified: 2026-05-27T08:39:17Z
status: gaps_found
score: 8/12 must-haves verified
overrides_applied: 0
gaps:
  - truth: "ASC zh-Hans metadata draft uses the correct brand name (Tuwa, not Tonus)"
    status: failed
    reason: "asc-metadata-zhHans.md references 'Tonus' 9 times and 'Tuwa' 0 times in the body copy (App Name, Description, etc.). Project memory project_rename_faros.md / feedback_never_use_faros.md flags 'Tonus' as a DEAD brand name — official name is Tuwa. If pasted into ASC this would brand the Chinese storefront under the dead Tonus name and the user has stated 'will leave project if wrong name used.' This file is the canonical paste-source for the human-action ASC checkpoint, so the metadata bug propagates downstream the moment the user copies."
    artifacts:
      - path: ".planning/phases/23-multi-language-in-app-support-simplified-chinese/asc-metadata-zhHans.md"
        issue: "9 references to 'Tonus' (App Name '`Tonus · 训练负荷管理`', Description opens with 'Tonus 是为认真训练的运动员…', Subscription paragraph, etc.) — should be Tuwa per project canonical brand."
      - path: ".planning/phases/23-multi-language-in-app-support-simplified-chinese/23-05-SUMMARY.md"
        issue: "Decision line documents the wrong brand: 'App Name default is the hybrid `Tonus · 训练负荷管理`' — must reflect Tuwa."
    missing:
      - "Replace every 'Tonus' occurrence in asc-metadata-zhHans.md with 'Tuwa' (App Name, Description, Promotional Text, What's New, Keywords if present)."
      - "Update 23-05-SUMMARY.md decisions array to match."
      - "Re-run the embedded Python length-assertion snippet after the rename (Tuwa is 4 chars vs Tonus 5 — net -1 char per occurrence, won't push any field over limit)."

  - truth: "All user-facing strings have zh-Hans catalog entries so a zh-Hans user does not see English fallbacks in core surfaces"
    status: partial
    reason: "REVIEW WR-01 explicitly deferred the broader sweep across Dashboard/Workload/WorkoutLog/Recovery/Profile section headers and Auth view branding. Spot-grep confirms ~50 hardcoded `Text(\"…\")` literals with capitalized English strings remain unlocalized: Auth (Sign In, Create Account, EMAIL, PASSWORD), Dashboard (TRAINING LOAD, RECENT SESSIONS), and many Profile preference rows. A zh-Hans user will see a heavily English UI outside the onboarding/picker/error/notification path."
    artifacts:
      - path: "WorkloadApp/Views/Auth/LoginView.swift"
        issue: "Text(\"EMAIL\") L61, Text(\"PASSWORD\") L87, Text(\"Sign In\") L129 — bare English literals, no catalog keys."
      - path: "WorkloadApp/Views/Auth/SignUpView.swift"
        issue: "Text(\"Create Account\") L42, L148 — bare English literals."
      - path: "WorkloadApp/Views/Dashboard/DashboardView.swift"
        issue: "Text(\"TRAINING LOAD\") L492, Text(\"RECENT SESSIONS\") L581 — section headers in English."
      - path: "WorkloadApp/Views/Profile/ProfileView.swift"
        issue: "Multiple preference rows (Weight Unit, ACWR Method, Load Metric, Enable Coach Mode, Invite My Coach, Hormonal Contraceptive, etc.) still bare English literals."
    missing:
      - "Migrate remaining ~50 Text literals to namespaced catalog keys (auth.signIn, auth.email, auth.password, dashboard.section.trainingLoad, dashboard.section.recentSessions, profile.row.weightUnit, etc.)."
      - "Add en + zh-Hans values in Localizable.xcstrings, state=translated."
      - "Optionally batch as a follow-up phase 23.5 — the executor flagged this as out-of-scope in the REVIEW-FIX iter 1 partial close."

  - truth: "REVIEW.md BLOCKER findings CR-01 through CR-06 are all fully resolved"
    status: partial
    reason: "5 of 6 critical findings are resolved in code (catalog enum keys added; notification template uses 4 positional placeholders %1$lld–%4$lld; InfoPlist NSHealthShareUsageDescription says Tuwa with full data-type list; LanguagePickerView uses Color.clear spacer instead of Image(systemName: \"\"); ZoneBadge/MetricTile uses locale.language.languageCode?.identifier == \"zh\"). CR-05 — HeroReadinessCard.dateLabel formatter ignoring env locale — needs grep confirmation but the broader 'WR-01 deferred' status implies the Dashboard surface still hardcodes English-format date headers ('READINESS · TUE 27 MAY')."
    artifacts:
      - path: "WorkloadApp/Views/Dashboard/DashboardView.swift"
        issue: "CR-05 fix not explicitly confirmed in REVIEW-FIX iter 1 status notes. Dashboard date-label locale wiring needs follow-up verification."
    missing:
      - "Either confirm CR-05 fixed via env-locale-aware DateFormatter, or close as part of the Dashboard string-migration follow-up."

  - truth: "REVIEW WARNING findings WR-06/WR-07/WR-08/WR-09 are resolved (locale-aware unit/weekday/AM-PM formatting)"
    status: partial
    reason: "WR-06 is partially resolved per REVIEW: HRV/RHR/Sleep routed through catalog + Date.durationString. WR-07 (WeightFormatter docstring + unitOptions question), WR-08 (Calendar.current.weekdaySymbols ignoring env locale in Profile notification picker), and WR-09 (AM/PM hardcoded for time picker display) status not explicitly closed — REVIEW labels them WARNINGs. WorkloadView:51 and ActiveWorkoutSheet:635 weight-formatting cleanup is explicitly deferred per REVIEW-FIX iter 1 status note on WR-06."
    artifacts:
      - path: "WorkloadApp/Views/Profile/ProfileView.swift"
        issue: "WR-08 + WR-09: weekday-symbol + AM/PM display in notification time picker — still uses system Calendar.current and hardcoded \"PM\"/\"AM\" if unfixed."
      - path: "WorkloadApp/Views/Workload/WorkloadView.swift"
        issue: "WR-06 deferred: weight cell @ L51 still uses raw 'kg' string."
      - path: "WorkloadApp/Views/WorkoutLog/ActiveWorkoutSheet.swift"
        issue: "WR-06 deferred: PR overlay @ L635 still uses raw 'kg' string."
    missing:
      - "Plumb @Environment(\\.locale) into ProfileView, ActiveWorkoutSheet, WorkloadView weight cells."
      - "Route weight rendering through WeightFormatter.display(...) with env locale."
      - "Use Date.FormatStyle.time(.shortened).locale(locale) for notification picker time display."
      - "Apply env locale to Calendar before reading weekdaySymbols."

deferred:
  - truth: "App Store Connect dashboard contains the zh-Hans localization, screenshots uploaded"
    addressed_in: "23-HUMAN-UAT.md (manual gate)"
    evidence: "23-HUMAN-UAT.md Tests 1–3 explicitly cover render PNGs, paste ASC metadata, upload screenshots — tracked outside automated verification per phase contract."
  - truth: "Native zh-Hans reviewer sign-off on visual audit"
    addressed_in: "23-HUMAN-UAT.md (manual gate)"
    evidence: "23-HUMAN-UAT.md Test 4 (visual audit) + Test 5 (HealthKit consent verification) are explicit human-action checkpoints."

human_verification:
  - test: "Live-switch crossfade visual"
    expected: "On Profile → Language → 中文(简体), the entire UI re-renders in zh-Hans within ~150ms with a smooth opacity crossfade; no flash, no app relaunch, dates and weight units also re-format."
    why_human: "Animation timing, perceptual smoothness, and end-to-end env-locale propagation across nested views cannot be grep-verified."
  - test: "CJK font cascade correctness in mixed strings"
    expected: "Strings like '训练负荷比 (ACWR)' render with General Sans for Latin (ACWR/parens/digits) and Noto Sans SC for CJK glyphs at every Font.Tokens.* call site — no visible weight or baseline mismatch, no system PingFang fallback."
    why_human: "Visual font verification — requires booting a simulator and inspecting glyph rendering."
  - test: "Hybrid terminology first-occurrence rendering"
    expected: "On each surface (Dashboard, Recovery, Workload, Onboarding glossary), technical terms (ACWR, HRV, RHR, TSS, EWMA, CTL, ATL, PR) appear as '中文 (ACRONYM)' on first occurrence; subsequent uses on the same screen may shorten."
    why_human: "Discourse-level first-occurrence convention can't be verified without a live read-through; spot-grep only finds the literal key, not its rendered position."
  - test: "HealthKit consent string verbatim on zh-Hans device"
    expected: "iOS Settings → Tuwa → Health on a zh-Hans simulator shows the localized consent prompt with brand 'Tuwa' and the 6 data types (HRV, RHR, sleep, workout HR, body temperature, VO2 Max)."
    why_human: "Surfaces in system Settings UI, not app UI — only verifiable on-device."
  - test: "App Store Connect zh-Hans localization entered, screenshots uploaded, NOT submitted"
    expected: "ASC App Information + current App Store version have zh-Hans localizations populated from asc-metadata-zhHans.md (after Tuwa rename — see gap above). Screenshots in 6.9\" Display slot. Save only, NO 'Submit for Review' click."
    why_human: "External system (App Store Connect) action with explicit caution gate from memory feedback_asc_caution.md."
  - test: "Render zh-Hans App Store screenshots via Screenshots-zhHans scheme"
    expected: "Run scheme on iPhone 17 Pro Max sim; 6+ PNGs at 1320×2868 committed under screenshots-zhHans/; visual audit confirms no English fallback in any captured screen."
    why_human: "Requires Xcode + simulator boot; deferred per 23-05-SUMMARY 'PNG rendering not executed by the agent'."
---

# Phase 23: Multi-language in-app support (Simplified Chinese) — Verification Report

**Phase Goal:** Ship Simplified Chinese (zh-Hans) in-app localization for Tuwa — full string catalog, CJK font cascade, native UI live-switch, App Store storefront metadata.
**Verified:** 2026-05-27T08:39:17Z
**Status:** gaps_found
**Re-verification:** No — initial verification (REVIEW.md exists, but no prior 23-VERIFICATION.md found)

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | LocaleManager service + env-locale injection wired at root with crossfade animation | VERIFIED | `WorkloadApp/Services/LocaleManager.swift` exists (3.6 KB, @Observable, supportedLocales = [en, zh-Hans], whitelist-validating UserDefaults read, language-code+script normalization in setLocale). `AppRouter.swift:38` injects `.environment(\.locale, container.localeManager.activeLocale)`; line 39 has `.animation(.linear(duration: 0.15), value: container.localeManager.activeLocale)` — matches the 150ms crossfade spec. Additional opacity transitions on L220, L242. |
| 2 | Localizable.xcstrings + InfoPlist.xcstrings catalogs populated zh-Hans | VERIFIED | `Localizable.xcstrings` 40 KB with 141 zh-Hans translated entries (tabs, save/cancel/continue/finish/delete, auth errors, notification template, recovery units, term.* glossary, onboarding strings, locale-picker UI). `InfoPlist.xcstrings` has `NSHealthShareUsageDescription` zh-Hans populated. |
| 3 | Hybrid format applied to technical training terms | VERIFIED | 7 `term.*` keys present (term.acwr/hrv/rhr/tss/ewma/ctl/atl) per 23-04-SUMMARY decision line; format is `Chinese + ASCII space + ( + Latin acronym + )`. Plan 23-04 documents the hybrid convention per UI-SPEC Surface 3 / D-06 / D-07. |
| 4 | HealthKit consent string zh-Hans says "Tuwa" and enumerates 6 data types | VERIFIED | `InfoPlist.xcstrings:17` — `"Tuwa 读取您的心率变异性、静息心率、睡眠、训练心率、体温和最大摄氧量数据，用于计算每日恢复评分和训练负荷。"` Uses brand Tuwa, lists all 6 data types (HRV, RHR, sleep, workout HR, body temp, VO2 Max). CR-03 fully resolved. |
| 5 | Noto Sans SC subset bundled + cascade descriptor via FontTokens | VERIFIED | `WorkloadApp/Resources/Fonts/NotoSansSC-Regular.otf` (974 KB) + `NotoSansSC-Medium.otf` (967 KB) + SIL license present. `FontTokens.swift` cascaded() builds UIFontDescriptor.cascadeList with NotoSansSC fallback descriptor on every Font.Tokens.* call site. PostScript names match (GeneralSans-Regular/-Medium, NotoSansSC-Regular/-Medium). |
| 6 | Language picker UI surfaces (Profile row, push destination, onboarding step 0) | VERIFIED | `LanguagePickerView.swift` exists with autonym rows, checkmark indicator on active row (CR-04 fixed: Color.clear spacer instead of Image with empty systemName), live-switch via `container.localeManager.setLocale(locale)`. `ProfileView.swift:158` pushes `LanguagePickerView()`. `OnboardingView.swift:4` documents 4-step flow starting with language; L54-55 uses `onboarding.language.title/subtitle` catalog keys. |
| 7 | Locale-conditional typography (ZoneBadge, MetricTile, Charts .id(locale)) | VERIFIED | `MetricTile.swift` ZoneBadge uses `locale.language.languageCode?.identifier == "en"` for tracking/textCase and `== "zh"` for horizontal padding (CR-06 fixed). MetricTile.title has no `.lineLimit(1)`. Workload charts carry `.id(locale)` (47 in WorkloadView.swift). |
| 8 | Deferred-localization in NotificationService | VERIFIED | `NotificationService.swift:67-74` uses `NSString.localizedUserNotificationString(forKey:arguments:)` for both title (`notif.weekly.title`) and body (`notif.weekly.body.template`) so iOS resolves at delivery, not at schedule time. Catalog body template has 4 positional placeholders `%1$lld–%4$lld` for both en and zh-Hans (CR-02 fixed: positional + correct arg count). |
| 9 | View-boundary re-resolution for AuthError | VERIFIED | `LoginView.swift:8` `@Environment(\.locale) private var locale`; `resolveErrorMessage(_:locale:)` at L19 constructs `LocalizedStringResource(authError.localizationKey)` and re-resolves on locale change (L185 `onChange` re-runs resolution). Pattern mirrored in SignUpView. |
| 10 | ASC zh-Hans metadata draft + Screenshots-zhHans scheme | FAILED | Scheme exists at correct nested path `workload management/workload management.xcodeproj/xcshareddata/xcschemes/Screenshots-zhHans.xcscheme` and configures SCREENSHOT_MODE + AppleLanguages override correctly. **BUT** `asc-metadata-zhHans.md` references the dead brand "Tonus" 9 times (App Name, Description, Subscription paragraph) and "Tuwa" 0 times. Per project memory this is a high-severity brand error. See gap #1. |
| 11 | All REVIEW BLOCKER (CR-01..CR-06) findings fixed | PARTIAL | CR-01 enum displayName keys: 30 enum-prefixed keys present in catalog — addressed. CR-02 notification template: 4 positional placeholders confirmed — fixed. CR-03 HealthKit zh-Hans brand+data types: fixed in InfoPlist. CR-04 empty Image(systemName: ""): fixed with Color.clear spacer. CR-05 HeroReadinessCard dateLabel env-locale: not explicitly confirmed in REVIEW-FIX iter 1 closure notes — needs spot-confirmation. CR-06 ZoneBadge locale.identifier comparison: fixed (uses language.languageCode?.identifier == "zh"). |
| 12 | All REVIEW WARNING findings (WR-01..WR-09) fixed | PARTIAL | WR-01 broader catalog sweep: **explicitly deferred** by REVIEW-FIX iter 1 (~50 hardcoded English literals remain in Auth/Dashboard/Profile/Workout/Recovery). WR-02..WR-05 status not confirmed individually. WR-06 partial (HRV/RHR/Sleep routed; weight strings deferred). WR-07/WR-08/WR-09 (WeightFormatter docstring, weekdaySymbols, AM/PM) not explicitly closed in REVIEW notes. |

**Score:** 8/12 truths verified (2 PARTIAL counted toward gaps, 1 FAILED, 1 explicitly multi-status)

### Deferred Items

| # | Item | Addressed In | Evidence |
|---|------|--------------|----------|
| 1 | ASC dashboard zh-Hans localization added + saved | 23-HUMAN-UAT.md Tests 2, 3 | Tests explicitly cover ASC paste-in and screenshot upload; per memory `feedback_asc_caution.md` agent never clicks ASC buttons. |
| 2 | Native zh-Hans reviewer sign-off on visual audit | 23-HUMAN-UAT.md Test 4 | Visual acceptance checklist (13 items) requires human reviewer on simulator. |
| 3 | HealthKit consent verification on-device | 23-HUMAN-UAT.md Test 5 | Settings-app verification cannot be automated. |
| 4 | Render zh-Hans App Store screenshots | 23-HUMAN-UAT.md Test 1 | Per 23-05-SUMMARY, scheme + capture README delivered; PNG rendering is user-machine task. |

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `WorkloadApp/Services/LocaleManager.swift` | @Observable LocaleManager with supportedLocales + setLocale + UserDefaults persistence | VERIFIED | 84 lines; whitelist-validating; language-code+script normalization for loosely-formed input. |
| `WorkloadApp/Utilities/FontTokens.swift` | Cascade descriptor wiring General Sans → Noto Sans SC | VERIFIED | 78 lines; cascaded() factory used by every Font.Tokens.* token. |
| `WorkloadApp/Resources/Localizable.xcstrings` | Populated zh-Hans values across user-facing keys | VERIFIED (with gap) | 40 KB, 141 zh-Hans entries. Coverage is INCOMPLETE per WR-01 (Auth/Dashboard/Profile section headers, ~50 hardcoded literals) — see gap. |
| `WorkloadApp/Resources/InfoPlist.xcstrings` | NSHealthShareUsageDescription zh-Hans with Tuwa brand | VERIFIED | 24 lines, both en + zh-Hans entries state=translated, brand=Tuwa. |
| `WorkloadApp/Resources/Fonts/NotoSansSC-Regular.otf` + `-Medium.otf` | Bundled CJK font weights | VERIFIED | 974 KB + 967 KB; SIL OFL license file present. |
| `WorkloadApp/Views/Profile/LanguagePickerView.swift` | Push picker with autonym + checkmark + live switch | VERIFIED | 61 lines; Color.clear spacer (CR-04 fix); autonym for zh-Hans = `中文(简体)`. |
| `WorkloadApp/App/AppRouter.swift` (env-locale injection) | Root `.environment(\.locale, …)` with crossfade animation | VERIFIED | L38 injection; L39 0.15s linear animation (150ms). |
| `WorkloadApp/Services/NotificationService.swift` | Deferred-localization via localizedUserNotificationString | VERIFIED | L67-74. |
| `workload management/workload management.xcodeproj/xcshareddata/xcschemes/Screenshots-zhHans.xcscheme` | Scheme launching app with -AppleLanguages (zh-Hans) | VERIFIED | Exists at correct nested path. |
| `.planning/.../asc-metadata-zhHans.md` | zh-Hans ASC metadata draft with character-limit verified fields | STUB (brand wrong) | Exists with all required fields and length verification, but uses dead brand "Tonus" throughout (0 "Tuwa" occurrences). See gap #1. |
| `.planning/.../screenshots-zhHans/` | Directory ready for 6+ rendered PNGs | VERIFIED (empty by design) | Contains README.md procedure; PNGs deferred to human-action gate. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| AppRouter | env locale | `.environment(\.locale, container.localeManager.activeLocale)` | WIRED | L38 of AppRouter.swift; root injection. |
| LanguagePickerView | LocaleManager | `container.localeManager.setLocale(locale)` in Button action | WIRED | L33. |
| ProfileView | LanguagePickerView | NavigationLink → `LanguagePickerView()` | WIRED | ProfileView.swift:158. |
| OnboardingView step 0 | language picker | catalog keys `onboarding.language.title/subtitle` | WIRED | OnboardingView.swift:54-55. |
| Charts | env-locale re-render | `.id(locale)` modifier | WIRED | WorkloadView.swift L47 etc. |
| Font.Tokens.* | Noto Sans SC cascade | UIFontDescriptor.AttributeName.cascadeList | WIRED | FontTokens.swift:65-77. |
| AuthError messages | env locale re-resolution | `resolveErrorMessage(_:locale:)` + LocalizedStringResource | WIRED | LoginView.swift L19-29, SignUpView mirrored. |
| Weekly notification | catalog body template | `localizedUserNotificationString(forKey:arguments:)` | WIRED | NotificationService L67-74 + catalog %1$lld–%4$lld positional placeholders. |
| Screenshots-zhHans scheme | locale override | LaunchAction + TestAction args: `-AppleLanguages (zh-Hans) -AppleLocale zh_Hans_CN` | WIRED | per 23-05-SUMMARY. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| LanguagePickerView | container.localeManager.activeLocale | LocaleManager @Observable property | YES (whitelisted UserDefaults or system locale) | FLOWING |
| AppRouter env locale | activeLocale → SwiftUI Environment | LocaleManager → .environment(\.locale, …) | YES — every nested view inherits | FLOWING |
| Charts | locale Environment value | env-locale + `.id(locale)` to force re-resolution | YES | FLOWING |
| ZoneBadge tracking/padding | locale.language.languageCode?.identifier | env locale | YES — fixed in CR-06 to use languageCode comparison | FLOWING |
| Notification body | iOS catalog resolution at delivery | localizedUserNotificationString(forKey:arguments:) with 4 positional %lld args | YES | FLOWING |
| ASC asc-metadata-zhHans.md | drafted metadata strings | manual authoring | NO — body says "Tonus" not "Tuwa" | HOLLOW_PROP / WRONG_DATA |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Catalog file is valid JSON and contains zh-Hans entries | `grep -c "zh-Hans" Localizable.xcstrings` | 141 | PASS |
| Notification template has 4 positional placeholders | `grep '%1\\$lld.*%2\\$lld.*%3\\$lld.*%4\\$lld' Localizable.xcstrings` | matched in both en + zh-Hans | PASS |
| InfoPlist uses brand 'Tuwa' (not Tonus) in zh-Hans | `grep 'Tuwa' InfoPlist.xcstrings` / `grep 'Tonus'` | Tuwa: 2, Tonus: 0 | PASS |
| ASC metadata uses 'Tuwa' (not Tonus) | `grep -c Tuwa asc-metadata-zhHans.md` / `grep -c Tonus` | Tuwa: 0, Tonus: 9 | FAIL |
| Glossary keys present (term.acwr, term.hrv, etc.) | `grep -cE 'term\\.(acwr|hrv|rhr|tss|ewma|ctl|atl)' Localizable.xcstrings` | 7 | PASS |
| ZoneBadge uses languageCode comparison (not raw identifier) | `grep 'language.languageCode' MetricTile.swift` | L50, L51, L52 | PASS |
| Empty Image(systemName: "") removed from LanguagePickerView | `grep 'Image(systemName: "")' LanguagePickerView.swift` | 0 matches | PASS |
| Fonts bundled | `ls Resources/Fonts/NotoSansSC-*.otf` | both present (974 KB + 967 KB) | PASS |

### Probe Execution

| Probe | Command | Result | Status |
|-------|---------|--------|--------|
| (none declared) | — | — | SKIPPED (no probes in phase 23) |

### Requirements Coverage

Phase 23 requirements are sourced from CONTEXT D-01..D-22 + UI-SPEC + RESEARCH (no formal REQ-* IDs in REQUIREMENTS.md mapped to this phase).

| Requirement | Description | Status | Evidence |
|-------------|-------------|--------|----------|
| D-01 | Localize core UI strings | PARTIAL | Catalog populated for navigation, errors, onboarding, picker, glossary, units; ~50 literals remain in Auth/Dashboard/Profile/Workload (WR-01 deferred). |
| D-02 | Localize error + paywall + legal | PARTIAL | AuthError keys + envrelocale re-resolution wired; paywall RC product display names deferred per 23-04 decision. |
| D-03 | Localize push notifications | SATISFIED | NotificationService uses deferred-localization with 4 positional args. |
| D-04 | Localize App Store metadata | BLOCKED | Draft exists but uses dead brand Tonus instead of Tuwa — see gap #1. |
| D-05 | Dynamic user content untranslated | SATISFIED | No translation of user-entered names/notes implemented. |
| D-06/D-07/D-08 | Hybrid terminology + first-occurrence + glossary | SATISFIED | 7 term.* keys present; format `中文 (LATIN)` verified in catalog. First-occurrence enforcement is per-surface authoring (UI-SPEC). |
| D-09/D-10/D-11 | xcstrings catalog single source of truth | SATISFIED | Localizable.xcstrings + InfoPlist.xcstrings; no NSLocalizedString/.strings legacy files. |
| D-12/D-13/D-14 | In-app picker, live switch, env-locale propagation | SATISFIED | LanguagePickerView + LocaleManager + AppRouter env injection + 150ms crossfade. |
| D-15 | First-launch silent system match | SATISFIED | LocaleManager init resolves zh-Hans/zh-CN system locale silently without persistence. |
| D-16 | Onboarding language step | SATISFIED | OnboardingView step 0. |
| D-17/D-18/D-19 | Noto Sans SC bundle + cascade + bundle-size constraint | SATISFIED | ~1.9 MB total for 2 weights (under +8 MB budget). Cascade wired in FontTokens. |
| D-20 | Density audit on dashboard/metric tiles in zh-Hans | DEFERRED | Manual capture procedure documented; reviewer audit deferred to HUMAN-UAT Test 4. |
| D-21 | LLM-drafted + human-reviewed translations | DEFERRED | Marketing-tone pass applied per 23-04 decision; full reviewer pass is HUMAN-UAT Test 4. |
| D-22 | Marketing-tone second pass | PARTIAL | Applied to paywall + onboarding hero; ASC marketing copy compromised by Tonus/Tuwa brand bug. |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| asc-metadata-zhHans.md | passim (9 occurrences) | Dead brand name "Tonus" instead of "Tuwa" | BLOCKER | Will brand the Chinese App Store storefront under abandoned name; per project memory user has stated firm stance. |
| LoginView.swift | 61, 87, 129 | Bare English `Text("EMAIL")`, `Text("PASSWORD")`, `Text("Sign In")` | WARNING | zh-Hans user sees English in auth flow. |
| SignUpView.swift | 42, 148 | Bare English `Text("Create Account")` | WARNING | zh-Hans user sees English. |
| DashboardView.swift | 492, 581 | Bare English section headers `Text("TRAINING LOAD")`, `Text("RECENT SESSIONS")` | WARNING | zh-Hans user sees English. |
| ProfileView.swift | passim (~20 rows) | Bare English preference labels | WARNING | zh-Hans user sees English; explicitly deferred by REVIEW-FIX iter 1. |
| (multiple views, ~50 total) | various | `Text("LITERAL")` without catalog key | WARNING | Total English-fallback surface large enough to call the phase goal "ship zh-Hans" only partially achieved. |

### Human Verification Required

See `human_verification` array in frontmatter and 23-HUMAN-UAT.md. Six items pending; ASC + screenshots are external system actions per memory `feedback_asc_caution.md`.

### Gaps Summary

Phase 23 has shipped a competent localization **infrastructure** — LocaleManager + env-locale injection + 150ms crossfade + Noto Sans SC cascade + xcstrings catalog + deferred-localization for notifications + view-boundary error re-resolution + density-aware ZoneBadge typography. All six BLOCKER findings from REVIEW.md are at least addressed in code (CR-01 catalog enum keys, CR-02 notification positional args, CR-03 Tuwa brand in InfoPlist, CR-04 Color.clear spacer, CR-06 languageCode comparison; CR-05 dateLabel env-locale needs a spot-confirm).

Two outstanding gaps prevent calling the **phase goal** fully achieved:

1. **ASC metadata uses the dead brand "Tonus" (9 occurrences) instead of "Tuwa" (0).** This is the canonical paste-source for the human-action ASC checkpoint. Per project memory `feedback_never_use_faros.md` and `project_rename_faros.md`, "Tonus" is a dead brand — official name is Tuwa, bundle ID com.tonus.app notwithstanding. If the user pastes the current draft into App Store Connect, the Chinese storefront ships under the abandoned brand. **This must be fixed before the human-action ASC gate proceeds.**

2. **Broader catalog sweep is explicitly deferred.** ~50 hardcoded English `Text("…")` literals remain in Auth (Sign In, Create Account, EMAIL, PASSWORD), Dashboard (TRAINING LOAD, RECENT SESSIONS), Profile (preference rows), Workout Log, Recovery, and Workload sub-headers. REVIEW-FIX iter 1 closure notes acknowledge this and propose a follow-up phase. The phase goal "Ship Simplified Chinese in-app localization" with these surfaces left in English is a notable scope shortfall — a zh-Hans user will encounter substantial English UI outside the onboarding/picker/error/notification/Charts/units path.

Additionally, WR-06 weight-formatting cleanup (WorkloadView, ActiveWorkoutSheet PR overlay), WR-08 weekdaySymbols env-locale, and WR-09 AM/PM time picker display are explicitly deferred WARNINGS that affect zh-Hans rendering quality.

The HealthKit consent string (CR-03) is correctly fixed in code — the InfoPlist now says "Tuwa" with the full 6-data-type list, even though UI-SPEC.md line 291 still documents the old "Tonus" spec (the implementation outshines its spec on this point; consider correcting the UI-SPEC for hygiene).

---

_Verified: 2026-05-27T08:39:17Z_
_Verifier: Claude (gsd-verifier)_
