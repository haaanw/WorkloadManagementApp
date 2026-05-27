---
phase: 23-multi-language-in-app-support-simplified-chinese
plan: 06
subsystem: localization
tags: [i18n, gap-closure, swiftui, xcstrings, zh-Hans]
gap_closure: true
closes_gap: 2
requires:
  - "23-04 (catalog pattern precedent)"
provides:
  - "Full string-coverage sweep across Auth, Dashboard, Profile, Workload, Recovery, WorkoutLog surfaces"
  - "+123 namespaced catalog keys, all en + zh-Hans translated, no fullwidth-punctuation violations"
affects:
  - "WorkloadApp/Views/Auth/LoginView.swift"
  - "WorkloadApp/Views/Auth/SignUpView.swift"
  - "WorkloadApp/Views/Dashboard/DashboardView.swift"
  - "WorkloadApp/Views/Profile/ProfileView.swift"
  - "WorkloadApp/Views/Workload/WorkloadView.swift"
  - "WorkloadApp/Views/Recovery/RecoveryView.swift"
  - "WorkloadApp/Views/WorkoutLog/WorkoutLogView.swift"
  - "WorkloadApp/Resources/Localizable.xcstrings"
tech-stack:
  patterns:
    - "LocalizedStringKey-typed helper parameters (sectionHeader, profileRow, actionButton, editableTextField, editablePicker, InputField, SecureInputField, SessionFilterChip)"
    - "String(format: String(localized: KEY), args...) for interpolated catalog values with %@/%lld placeholders"
key-files:
  modified:
    - "WorkloadApp/Views/Auth/LoginView.swift"
    - "WorkloadApp/Views/Auth/SignUpView.swift"
    - "WorkloadApp/Views/Dashboard/DashboardView.swift"
    - "WorkloadApp/Views/Profile/ProfileView.swift"
    - "WorkloadApp/Views/Workload/WorkloadView.swift"
    - "WorkloadApp/Views/Recovery/RecoveryView.swift"
    - "WorkloadApp/Views/WorkoutLog/WorkoutLogView.swift"
    - "WorkloadApp/Resources/Localizable.xcstrings"
  created:
    - ".planning/phases/23-multi-language-in-app-support-simplified-chinese/23-06-AUDIT.md"
decisions:
  - "Date-interpolated READINESS label uses Option B from interfaces (`String(format: String(localized: \"dashboard.hero.readinessLabel\"), dateLabel)`) rather than `LocalizedStringKey` interpolation — keeps the catalog key stable as `dashboard.hero.readinessLabel` rather than `dashboard.hero.readinessLabel %@`"
  - "RPE interpolated labels also use the String(format:String(localized:)) pattern — keeps Latin ACRONYM per D-06"
  - "SessionFilterChip refactored to take `Text` directly (rather than `LocalizedStringKey` or `String`) — allows `Text(verbatim: type.displayName)` for already-localized enum names alongside `Text(\"workoutLog.filter.all\")` catalog-key lookup"
  - "WORKLOAD wordmark preserved as Latin in zh-Hans value per D-22 logotype convention; flagged MARKETING-PASS for native reviewer"
metrics:
  duration_minutes: ~32
  tasks_completed: 4
  files_modified: 8
  files_created: 2
  catalog_keys_added: 123
  commits: 4
---

# Phase 23 Plan 06: Catalog string-coverage sweep (gap #2 closure) Summary

**One-liner:** Migrate 138 hardcoded `Text("…")` literals across 7 view surfaces into `Localizable.xcstrings` with full en + zh-Hans coverage, closing VERIFICATION gap #2 (WR-01 deferred broader sweep).

## Closure evidence (gap #2)

**Lint script output:**

```
Total keys: 264, failures: 0
```

(264 keys total: 141 pre-existing + 123 net new across Tasks 2 + 3 — every key has both `en` and `zh-Hans` stringUnit at `state: "translated"`; zero fullwidth U+FF08/U+FF09/U+3000 in any zh-Hans value.)

**Audit grep output (zero residual capitalized literals):**

```
grep -REc 'Text\("[A-Z]' WorkloadApp/Views/Auth/LoginView.swift \
  WorkloadApp/Views/Auth/SignUpView.swift WorkloadApp/Views/Dashboard/DashboardView.swift \
  WorkloadApp/Views/Profile/ProfileView.swift WorkloadApp/Views/Workload/WorkloadView.swift \
  WorkloadApp/Views/Recovery/RecoveryView.swift WorkloadApp/Views/WorkoutLog/WorkoutLogView.swift
=> Sum: 0
```

**xcodebuild output:**

```
xcodebuild -project "workload management/workload management.xcodeproj" \
  -scheme "workload management" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' build
=> ** BUILD SUCCEEDED **
```

## Tasks completed

| # | Name | Commit | Status |
|---|------|--------|--------|
| 1 | Audit pass — enumerate all hardcoded literals across 7 view files | `cb9a4c5` | ✓ (138 rows, ≥33 sanity gate met) |
| 2 | Migrate Auth + Dashboard surfaces (3 files + catalog) | `638e757` | ✓ (26 new keys; build green) |
| 3 | Migrate Profile + Workload + Recovery + WorkoutLog surfaces (4 files + catalog) | `305f298` | ✓ (97 new keys; build green) |
| 4 | Catalog hygiene + lint + SUMMARY | (this commit) | ✓ (lint 0 failures; 0 residual literals; SUMMARY written) |

## Marketing-pass candidates flagged for native-reviewer human gate (D-22)

These three zh-Hans strings ship with primary candidates today but require native-reviewer sign-off in **23-HUMAN-UAT.md Test 4** (visual audit). The reviewer should confirm tone, register, and brand voice; alternate candidates are documented for easy substitution.

| Key | en value | Primary zh-Hans (shipped) | Alternate candidate |
|-----|----------|---------------------------|---------------------|
| `auth.brand.wordmark` | `WORKLOAD` | `WORKLOAD` (logotype preserved) | `训练负荷` (translated wordmark) |
| `auth.brand.tagline` | `Train smarter. Recover better.` | `更聪明地训练，更有效地恢复。` | `训练更聪明，恢复更彻底。` |
| `auth.signup.subhead` | `Set up your athlete profile.` | `创建你的运动员档案。` | `设置你的运动员资料。` |

## Literals deliberately left unmigrated

| Literal | File:line | Reason |
|---------|-----------|--------|
| `you@example.com` (placeholder) | LoginView.swift:69, SignUpView.swift:67 | Universal email-format example; not a user-facing translatable string |
| `••••••••` (placeholder) | LoginView.swift:95 | Universal password-mask glyph |
| `athlete@example.com` (placeholder) | ProfileView.swift:825 | Universal email-format example |
| `/ 100` | RecoveryView.swift:248 | Universal score denominator; same in en and zh-Hans |
| Image(systemName: …) | many | SF Symbol resource identifiers — not user-facing text |
| `\u{2014}` em-dash in cycle prompt | DashboardView.swift:82 | Embedded in catalog value `dashboard.cycleAware.body` (pre-existing key) — already covered |
| `tonus_sessions_…` CSV filenames | WorkloadView.swift:225, 228 | Programmatic file-naming, not UI |
| `dataTypes` tuple labels in HealthKitPermissionsView | ProfileView.swift:897-905 | Out of audit scope — these are passed via Text(item.0) using verbatim String; the 8 data-type labels need a follow-up if zh-Hans rendering is required. Flagged below in "Known Stubs" |

## Known Stubs

| File:line | Pattern | Reason / Future work |
|-----------|---------|----------------------|
| ProfileView.swift:897-905, 926 | `HealthKitPermissionsView.dataTypes` tuple uses raw English strings rendered via `Text(item.0)` — Text initializer uses verbatim String here, not LocalizedStringKey | Out of scope for plan 23-06 audit (these 8 strings are inside a `[(String, String)]` array and feed `Text` via String, requiring a deeper refactor — likely making dataTypes a `[(LocalizedStringKey, String)]` or `[(String, String)]` with explicit `Text(LocalizedStringKey(item.0))` calls and corresponding catalog keys `profile.healthkit.dataType.hrv` etc.). Defer to follow-up plan or 23-HUMAN-UAT note. |
| ProfileView.swift:560 | `errorMessage = "Failed to delete account: \(error.localizedDescription)"` is composed via String interpolation, not catalog | Defer — low-frequency error path; not in the 138-row audit |

These do NOT prevent the plan goal (gap #2 closure across the 7 named surfaces' Text/Label/Button/navigationTitle literals).

## Hand-off to 23-HUMAN-UAT.md Test 4

Plan 23-06 newly brings the following surfaces into scope for the native-reviewer visual audit (Test 4):

- **Auth flow:** LoginView wordmark + tagline + email/password labels + Sign In button + Create-an-account link; SignUpView heading + subhead + PRIMARY SPORT label + button + nav title
- **Dashboard:** Open Settings button, READINESS · {date} hero label, weekly summary first-week prompt, building-baseline cold-start label, nav title, Log Workout toolbar button, Connect Health empty-state, TRAINING LOAD section header, EST estimated flag, RECENT SESSIONS section header + empty-state + RPE row labels
- **Profile:** ATHLETE / TRAINING PROFILE / CYCLE & HORMONES / PREFERENCES / NOTIFICATIONS / CONNECTED DEVICES / DATA SYNC / COACH / MY COACHES / MY ATHLETES section headers; all preference rows (Weight Unit, ACWR Method, Load Metric, Coach Mode, Coach Only, Hormonal Contraceptive, Pregnant, Lactating, Weekly Summary); HealthKit Permissions navigation row, disclaimer body, Authorize/Authorized states, nav title; sync status row + states; invite flows (My Coach, Athlete Email, code body); delete account confirmation + Cancel/Delete buttons; nav title; Error alert + OK button
- **Workload:** Load & Progress nav title, Export confirmation dialog (Session Summary, Detailed Sets, PDF Report (Pro), Cancel), ACWR section header, ratio label, no-data empty body, LOAD TREND section header, RECENT PRS section header
- **Recovery:** INSIGHTS (×2 locations) + BEHAVIOR IMPACT section headers, Recovery nav title, Morning Check-in title + prompt, RECOVERY SCORE section header, empty body, WELLNESS CHECK-INS section header
- **WorkoutLog:** PRESCRIBED section header, No-Workouts-Yet empty title + body, Workout Log nav title, 4 menu Labels (Import Workout (AI), My Programs, Import Program (Text), Import Shared Template), RPE prompt + interpolated value, Easy/Maximal endpoints, Import Workout nav title + Cancel/Import toolbar buttons, RPE history row label, All filter chip

The reviewer should confirm on a zh-Hans simulator (iPhone 17 Pro Max, `Screenshots-zhHans` scheme) that:
1. None of the above surfaces falls back to English.
2. Mixed Chinese-Latin strings (e.g., `ACWR 计算方法`, `PDF 报告 (Pro)`, `RPE 7`, `连接 Apple Health 即可查看你的准备度评分。`) render with General Sans on Latin glyphs and Noto Sans SC on CJK glyphs via the FontTokens cascade.
3. The marketing-pass candidates (table above) are acceptable, or pick alternates and re-edit.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking Issue] Helper-function signatures used `label: String`, blocking LocalizedStringKey lookup**

- **Found during:** Task 2 (SignUpView InputField), Task 3 (ProfileView × 5 helpers, WorkoutLogView SessionFilterChip)
- **Issue:** `Text(label)` where `label: String` invokes the verbatim `Text(String)` initializer, NOT the `Text(LocalizedStringKey)` initializer. Catalog-key resolution requires the latter.
- **Fix:** Changed `label: String` → `label: LocalizedStringKey` (or `label: Text` for SessionFilterChip where one call site is already-localized enum displayName); placeholder params similarly converted.
- **Files modified:** SignUpView.swift (InputField, SecureInputField), ProfileView.swift (sectionHeader ×2 — main view + nested HealthKitPermissionsView, profileRow, actionButton, editableTextField, editablePicker), WorkoutLogView.swift (SessionFilterChip)
- **Commits:** `638e757` (Task 2), `305f298` (Task 3)

**2. [Rule 1 - Bug] Interpolation pattern for date-templated labels**

- **Found during:** Task 2 (DashboardView READINESS label)
- **Issue:** First attempt used `Text("dashboard.hero.readinessLabel \(dateLabel)")` — SwiftUI would generate a synthetic key `"dashboard.hero.readinessLabel %@"` (with literal `%@` in the key), not lookup `dashboard.hero.readinessLabel` and substitute. Catalog stores `READINESS · %@` as the value of key `dashboard.hero.readinessLabel`, so lookup would miss.
- **Fix:** Switched to `Text(String(format: String(localized: "dashboard.hero.readinessLabel"), dateLabel))` — explicit format-string substitution after catalog lookup. Pattern reused for `dashboard.session.rpeValue` and `workoutLog.rpe.valueLabeled`.
- **Files modified:** DashboardView.swift, WorkoutLogView.swift
- **Commits:** `638e757`, `305f298`

### No Architectural Changes

No new tables, frameworks, or auth flows introduced. Pure string migration.

## Authentication Gates

None encountered. Plan executes on local code only — no external services accessed.

## Self-Check: PASSED

- `23-06-AUDIT.md` exists at `.planning/phases/23-multi-language-in-app-support-simplified-chinese/23-06-AUDIT.md` ✓
- 138 audit rows recorded (sanity gate ≥33 met)
- Commits exist in git history:
  - `cb9a4c5` Task 1 ✓
  - `638e757` Task 2 ✓
  - `305f298` Task 3 ✓
- Localizable.xcstrings JSON parses (jq pass) ✓
- Python lint script: 0 failures across 264 keys ✓
- Final repo-wide grep `Text\("[A-Z]` across 7 files: 0 hits ✓
- xcodebuild iPhone 17 Pro Max: BUILD SUCCEEDED ✓
- SUMMARY.md (this file) written with all required sections ✓

---

_Authored: 2026-05-27_
_Closes: VERIFICATION.md gap #2 (WR-01 deferred string-coverage sweep)_
_Hands off to: 23-HUMAN-UAT.md Test 4 (native-reviewer visual audit on zh-Hans simulator)_
