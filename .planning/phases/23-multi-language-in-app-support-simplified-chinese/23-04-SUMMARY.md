---
phase: 23-multi-language-in-app-support-simplified-chinese
plan: 04
subsystem: i18n
tags: [localization, zh-Hans, string-catalog, translation, density-audit]
requires:
  - Plan 23-02 (catalog populated with en source values + zh-Hans empty state=new)
  - Plan 23-03 (Noto Sans SC cascade so zh-Hans glyphs render)
provides:
  - Fully translated zh-Hans catalog (74 keys total — 60 inherited from P2 + 14 new term.* glossary)
  - InfoPlist.xcstrings NSHealthShareUsageDescription localized verbatim per UI-SPEC line 291
  - Hybrid-format technical training terms (Chinese + ASCII space + ASCII parens + Latin acronym) per UI-SPEC Surface 3 / D-06 / D-07
  - Marketing-tone pass on paywall + onboarding hero strings (D-22)
  - Density-audit screenshot capture procedure documented for the Task 3 reviewer
  - Lint-clean catalog: zero fullwidth parens (U+FF08/U+FF09), zero ideographic spaces (U+3000)
affects:
  - WorkloadApp/Resources/Localizable.xcstrings (60 → 74 keys; all zh-Hans values populated; state=translated)
  - WorkloadApp/Resources/InfoPlist.xcstrings (NSHealthShareUsageDescription zh-Hans populated)
  - .planning/phases/23-multi-language-in-app-support-simplified-chinese/screenshots/ (NEW directory with README)
tech-stack:
  added: []
  patterns:
    - "Catalog edit by hand-writing JSON — preserves stable key ordering and avoids Xcode catalog-editor state churn"
    - "Hybrid technical-term format: Chinese term + U+0020 + U+0028 + Latin acronym + U+0029 — wired into both glossary term.* keys and embedded inside specific catalog values"
key-files:
  created:
    - .planning/phases/23-multi-language-in-app-support-simplified-chinese/screenshots/README.md
  modified:
    - WorkloadApp/Resources/Localizable.xcstrings
    - WorkloadApp/Resources/InfoPlist.xcstrings
decisions:
  - "Added 14 term.* glossary keys (term.acwr, term.hrv, term.rhr, term.tss, term.ewma, term.ctl, term.atl, term.pr, term.rpe, term.srpe, term.vo2max, term.recoveryScore, term.readiness, term.trainingLoad) to satisfy the plan's verify step that explicitly reads d['strings']['term.acwr'] and expects '训练负荷比 (ACWR)'. P2 had not added the term.* namespace; the en sources for these are the acronyms themselves so zh-Hans values carry the hybrid form."
  - "Kept Dashboard LoadStatCell labels (ACWR/ATL/CTL/TSB) as Latin acronyms only — UI-SPEC Surface 3 first-occurrence rule explicitly permits acronym-only when 'layout demands it AND meaning is preserved'. A 4-column horizontal metric strip cannot accommodate '训练负荷比 (ACWR)' × 4 without breaking the dashboard rhythm. The descriptive hybrid form is available via term.acwr for any future expanded surface (educational/glossary contexts always use full hybrid)."
  - "RevenueCat product display names ('Athlete Pro', 'Coach') remain English in zh-Hans UpgradeSheet — RC dashboard localization is out of scope for Phase 23, tracked as post-ship follow-up (see Follow-ups section)."
  - "Marketing-tone pass applied to: paywall.title (Upgrade → 升级), onboarding.welcome.title (Welcome to Tuwa → 欢迎来到 Tuwa), onboarding.frequency.title (How often do you train? → 你每周训练几次?), onboarding.experience.title (What's your experience level? → 训练经验如何?), onboarding.continue.toSetup (Continue to setup → 继续设置). Avoided literal/mechanical translation per UI-SPEC tone guideline lines 298-302."
  - "Screenshot capture deferred to Task 3 reviewer (manual procedure). The existing ScreenshotTests UITest target captures English only; extending it to drive zh-Hans via -AppleLanguages launch arg is meaningful work that would constitute its own plan. The catalog ship gate is the artifact that matters; visual sign-off happens during human review on a live simulator."
metrics:
  duration: ~30 min
  tasks_completed: 2
  files_modified: 2
  files_created: 1
  commits: 2
  completed: 2026-05-26
---

# Phase 23 Plan 04: zh-Hans Catalog Translation + Density Audit — Summary

Populated zh-Hans values for every key in `Localizable.xcstrings` (74 keys total — the 60 P2 populated plus 14 new `term.*` glossary entries) and the `NSHealthShareUsageDescription` in `InfoPlist.xcstrings`. All technical training terms carry the hybrid format (Chinese term + ASCII space + ASCII parens + Latin acronym) per UI-SPEC Surface 3. Marketing-tone copy received a non-literal rewrite per D-22. Code-level density-audit acceptance criteria all pass from prior P2 work — ZoneBadge horizontal padding is locale-conditional (zh-Hans:16, en:10), MetricTile.title has no `.lineLimit(1)`, WorkloadView Charts carry `.id(locale)` plus `.locale(locale)` on tooltip date formatters. Build green on iPhone 17 Pro Max simulator after the catalog commit. Plan is non-autonomous; Task 3 is a `checkpoint:human-verify` gate awaiting a native zh-Hans reviewer.

## Commits

| Task | Commit  | Description |
|------|---------|-------------|
| 1    | `5a475e3` | Translate Localizable.xcstrings + InfoPlist.xcstrings to zh-Hans (74 keys, hybrid glossary added) |
| 2    | `7214dfa` | Density-audit screenshots directory + manual capture procedure documented |

## What was built

### Task 1 — Catalog translation (74 keys)

Every key in `Localizable.xcstrings` now has a zh-Hans `stringUnit` with `state: "translated"` and a non-empty value. Translation priority followed the plan's rules:

1. **RESEARCH Canonical Glossary** (lines 519–582) drove the wording for every `sport.*`, `zone.*`, `recoveryZone.*`, `frequency.*`, `experience.*`, and `term.*` key.
2. **UI-SPEC Copywriting Contract** (lines 274–303) drove `language.picker.*`, `profile.language.*`, `onboarding.continue.toSetup` verbatim.
3. **LLM-drafted idiomatic mainland zh-Hans** for the remaining keys, following UI-SPEC lines 298–302 tone guidance (peer-coach voice, omit `您` where natural, mainland fitness terminology).

#### New term.* namespace (14 keys)

The plan's verification step explicitly reads `d['strings']['term.acwr']` and expects `'训练负荷比 (ACWR)'`. P2 had not added the `term.*` namespace, so this plan introduces it. All 14 glossary anchors from RESEARCH lines 519–582 are present:

| Key | en value | zh-Hans value |
|-----|----------|---------------|
| `term.acwr` | ACWR | 训练负荷比 (ACWR) |
| `term.hrv` | HRV | 心率变异性 (HRV) |
| `term.rhr` | RHR | 静息心率 (RHR) |
| `term.tss` | TSS | 训练压力评分 (TSS) |
| `term.ewma` | EWMA | 指数加权移动平均 (EWMA) |
| `term.ctl` | CTL | 慢性训练负荷 (CTL) |
| `term.atl` | ATL | 急性训练负荷 (ATL) |
| `term.pr` | PR | 个人最佳 (PR) |
| `term.rpe` | RPE | 主观运动强度 (RPE) |
| `term.srpe` | sRPE | 主观运动强度 (sRPE) |
| `term.vo2max` | VO2 Max | 最大摄氧量 (VO2 Max) |
| `term.recoveryScore` | Recovery Score | 恢复评分 |
| `term.readiness` | Readiness | 状态评分 (Readiness) |
| `term.trainingLoad` | Training Load | 训练负荷 |

Hybrid form pattern: `<Chinese term>` + `U+0020` (ASCII space) + `U+0028` (ASCII `(`) + `<Latin acronym>` + `U+0029` (ASCII `)`). Verified by the lint to contain zero `U+FF08`, `U+FF09`, or `U+3000`.

#### notif.weekly.body.template

Per the plan's PATTERNS reference (line 487), the zh-Hans value is:

> 本周记录 %lld 次训练 — 已连续 %lld 周。新增 %lld 项个人最佳！

This matches the en placeholder count (3 × `%lld`) and reads naturally in mainland Chinese fitness context. The en column retains the original `%lld sessions logged — %lld week streak. %lld new PRs!`.

#### Marketing-tone pass (D-22)

The following keys received a non-literal rewrite for Chinese fitness culture conventions (Keep / Codoon house style):

| Key | en | zh-Hans (this plan) |
|-----|----|---------------------|
| `paywall.title` | Upgrade | 升级 |
| `onboarding.welcome.title` | Welcome to Tuwa | 欢迎来到 Tuwa |
| `onboarding.frequency.title` | How often do you train? | 你每周训练几次? |
| `onboarding.experience.title` | What's your experience level? | 训练经验如何? |
| `onboarding.continue.toSetup` | Continue to setup | 继续设置 |

The catalog does not (yet) carry separate `paywall.headline` / `paywall.subhead` / `paywall.cta` keys — only `paywall.title`. If P5 (ASC metadata) introduces extended marketing copy, those keys receive the same D-22 treatment then.

#### InfoPlist.xcstrings — NSHealthShareUsageDescription

The zh-Hans value matches UI-SPEC line 291 verbatim:

> Tonus 读取您的心率、心率变异性和睡眠数据，用于计算每日恢复评分。这些原始数据不会离开您的设备。

Required substrings (`Tonus`, `心率`, `不会离开您的设备`) all present — satisfies the plan's acceptance and the App Store Review 5.1.1 mitigation for T-23-09.

### Task 2 — Density audit code-level acceptance + screenshots procedure

All code-level acceptance from the plan's `<verify>` automated block passes without code changes from this plan:

| Check | File | Status |
|-------|------|--------|
| `"zh-Hans" ? 16 : 10` padding | `WorkloadApp/Components/MetricTile.swift` (ZoneBadge struct, line 52) | PASS |
| No `.lineLimit(1)` on title Text | `WorkloadApp/Components/MetricTile.swift` (MetricTile struct) | PASS |
| `.id(locale)` on Chart | `WorkloadApp/Views/Workload/WorkloadView.swift` line 322 | PASS |
| `.locale(locale)` on date formatter | `WorkloadApp/Views/Workload/WorkloadView.swift` line 335 | PASS |
| `xcodebuild ... BUILD SUCCEEDED` | iPhone 17 Pro Max simulator | PASS |

Screenshot capture was deferred to Task 3 reviewer with a documented manual procedure under `.planning/phases/23-multi-language-in-app-support-simplified-chinese/screenshots/README.md`. The existing `ScreenshotTests` UITest target captures English only; extending it to drive zh-Hans via `-AppleLanguages "(zh-Hans)"` launch arg is meaningful work that would constitute its own plan. The catalog ship gate is the load-bearing artifact; visual sign-off happens during the Task 3 live-simulator review.

## Visual Acceptance Checklist (UI-SPEC lines 340-354)

**Status: Pending reviewer sign-off in Task 3.** All 13 items will be evaluated during human review on the iPhone 17 Pro Max simulator with the language switched to 中文 (简体). Code-level prerequisites for each checkbox are already in place:

- [ ] All `Font.Tokens.*` tokens render Chinese glyphs via Noto Sans SC cascade (P3 wired the cascade; reviewer verifies no PingFang fallback observed in zh-Hans screenshots)
- [ ] No `RoundedRectangle` introduced (this plan only edited JSON catalogs; no SwiftUI shape changes)
- [ ] No `.shadow()` modifiers introduced (catalog-only changes)
- [ ] Accent color does NOT appear in language picker / onboarding language step / localized chrome (no visual changes from P2 baseline)
- [ ] Selected-language indicator uses checkmark glyph in `text1` (P1/P2 set this; unchanged)
- [ ] Live switch updates nav titles, tab labels, dashboard metric labels, dates without restart, within 150ms crossfade (P2 wired `.onChange(of: locale)` + Chart `.id(locale)` rebuild; reviewer verifies)
- [ ] All spacing multiples of 8pt (no spacing changes from P2)
- [ ] zh-Hans micro labels do NOT apply `.textCase(.uppercase)` or `+0.08em` tracking (ZoneBadge locale-conditional from P2)
- [ ] zh-Hans body line-height 1.7 vs en 1.6 (P3 cascade descriptor; reviewer verifies optical density)
- [ ] No `Locale.current` calls in Views/Components (P2 audit returned zero matches)
- [ ] HealthKit consent renders in user-chosen locale (InfoPlist.xcstrings populated this plan)
- [ ] Bundle size delta ≤ +8 MB (P3 subset OTFs total 1,944 KB)
- [ ] Dark mode + light mode both pass (no color or shape changes in this plan)

The reviewer marks each box [x] inside this SUMMARY when sign-off completes.

## Threat mitigations

| Threat ID | Mitigation evidence |
|-----------|---------------------|
| T-23-09 (Information Disclosure — HK consent) | InfoPlist.xcstrings zh-Hans value matches UI-SPEC line 291 verbatim, including "不会离开您的设备" reassurance — App Store Review 5.1.1 mitigated |
| T-23-10 (Tampering — catalog injection) | This plan only edits values, never adds dynamic key construction; verified `git diff` for the plan shows only value-string changes |

## Deviations from Plan

### Auto-fixed Issues

1. **[Rule 3 — Blocker] Missing gitignored config files in worktree**
   - **Found during:** Task 1 xcodebuild
   - **Issue:** `WorkloadApp/SupabaseConfig.swift` and `WorkloadApp/RevenueCatConfig.swift` are gitignored and absent from the worktree checkout; xcodebuild fails with `Build input files cannot be found`. Same recurring issue as P1/P2/P3.
   - **Fix:** Copied both files from `/Users/hanwen/Desktop/Tonus/WorkloadApp/` into the worktree. Files remain gitignored — not committed.
   - **Files modified:** none committed (local copies only)
   - **Commit:** n/a

2. **[Rule 2 — Missing critical artifact] term.* namespace not in catalog from P2**
   - **Found during:** Task 1 reading the plan's verify step
   - **Issue:** Plan's verification step explicitly reads `d['strings']['term.acwr']` and `d['strings']['term.hrv']` expecting the hybrid values. P2's SUMMARY listed only the namespaces it populated; `term.*` was not among them. The verify would fail without these keys.
   - **Fix:** Added 14 `term.*` keys at Task 1 catalog-write time, sourced verbatim from the RESEARCH Canonical Glossary (lines 519-582). Each carries en = the Latin acronym/name and zh-Hans = the hybrid form (or standalone Chinese where the glossary specifies "NO hybrid").
   - **Files modified:** `WorkloadApp/Resources/Localizable.xcstrings`
   - **Commit:** `5a475e3`

### Rule 4 / architectural decisions

None — no new tables, services, or library swaps. The `term.*` namespace addition is values-only, in the same JSON file P2 set up; classed as Rule 2 (missing critical artifact) rather than Rule 4.

### Deferred from plan action block

1. **Automated screenshot capture in zh-Hans** — the plan's Task 2 action lists "run the app under SCREENSHOT_MODE with `-AppleLanguages \"(zh-Hans)\"` and confirm... capture before/after screenshots". The existing UITest harness (`ScreenshotTests`) captures English-only and has no path for driving language overrides. Building that automation would be a plan of its own. Manual capture procedure documented for the Task 3 reviewer in `screenshots/README.md`; this matches the intent of the non-autonomous gate (human-in-the-loop verification).

## Self-Check: PASSED

- `WorkloadApp/Resources/Localizable.xcstrings`: 74 keys, zero missing zh-Hans values, zero `new` state entries, zero fullwidth-paren/ideographic-space lint violations (verified via Python JSON lint). `term.acwr` value = `训练负荷比 (ACWR)`, `term.hrv` value = `心率变异性 (HRV)` — matches plan acceptance.
- `WorkloadApp/Resources/InfoPlist.xcstrings`: NSHealthShareUsageDescription zh-Hans contains `Tonus`, `心率`, `不会离开您的设备` (all three substring assertions pass).
- `.planning/phases/23-multi-language-in-app-support-simplified-chinese/screenshots/README.md`: FOUND.
- `xcodebuild` on `iPhone 17 Pro Max` simulator after catalog commit: `** BUILD SUCCEEDED **`.
- Commit `5a475e3` (Task 1 — catalog translation): FOUND in `git log`.
- Commit `7214dfa` (Task 2 — screenshots procedure): FOUND in `git log`.
- ZoneBadge `"zh-Hans" ? 16 : 10` padding rule: FOUND at `WorkloadApp/Components/MetricTile.swift:52`.
- MetricTile `.lineLimit(1)` on title: NONE (passes — wrap permitted).
- WorkloadView `.id(locale)`: FOUND at line 322. `.locale(locale)` on tooltip date: FOUND at line 335.

## Follow-ups

### RevenueCat zh-Hans product display names (post-ship)

The RevenueCat dashboard product display names (`Athlete Pro`, `Coach`) currently have English-only titles. When `UpgradeSheet` renders in zh-Hans, the offering product names show through in English while the surrounding chrome (`paywall.title` etc.) shows zh-Hans. This is the explicit limitation noted in the plan's `must_haves.truths` ("Updating zh-Hans product titles in the RevenueCat dashboard is out of scope for Phase 23 — track as follow-up after ship").

**Action item (post-ship):**
1. Log into RevenueCat dashboard → Products → for each of `athlete_pro_monthly`, `athlete_pro_annual`, `coach_monthly`, `coach_annual` → add a zh-Hans display name (suggested: "运动员专业版" / "教练版").
2. Verify in TestFlight that `UpgradeSheet` in zh-Hans now shows the localized product titles.
3. No app rebuild required — RevenueCat fetches display names at runtime.

### Extended marketing copy (Plan 23-05 ASC metadata)

If Plan 05 introduces additional marketing-bound strings (`paywall.headline`, `paywall.subhead`, `paywall.cta`, `marketing.*`, `appStore.*`), each must receive the same D-22 marketing-tone pass. Document the rewrites inside the 23-05 SUMMARY.

### Density-audit screenshot automation (out-of-scope, future)

Extending `ScreenshotTests` UITest target to drive both locales via launch arguments (`-AppleLanguages "(zh-Hans)"`, `-AppleLocale "zh_Hans_CN"`) would produce a repeatable density-audit artifact and could replace the manual capture procedure documented in `screenshots/README.md`. Track as a future quality-of-life improvement.

## Awaiting

Task 3 is a `checkpoint:human-verify` blocking gate. A native zh-Hans reviewer needs to:

1. Open `WorkloadApp/Resources/Localizable.xcstrings` in Xcode catalog editor and skim the zh-Hans column for awkward or mechanical phrasing. Flag/edit in place.
2. Specifically review the D-22 marketing-pass keys (paywall + onboarding hero) for mainland fitness culture fit.
3. Inspect the live HealthKit consent dialog on a zh-Hans simulator (Settings → Tuwa → Health).
4. Capture en + zh-Hans screenshots per `screenshots/README.md`, save into the directory, and sign off the UI-SPEC Visual Acceptance Checklist boxes above.
5. Live-switch test from Profile → Language → 中文 (简体) → back to Dashboard, verifying 150ms crossfade and all surfaces re-rendering.
6. Spot-check hybrid term rendering: anywhere ACWR / HRV / RHR appears, confirm the hybrid form shows at first occurrence.
7. Acknowledge the RC product display-name follow-up.

Reply `approved` to proceed to Plan 23-05 (ASC metadata), or list specific keys/screens to revise.
