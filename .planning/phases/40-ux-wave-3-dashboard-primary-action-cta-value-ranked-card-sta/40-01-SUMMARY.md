---
phase: 40-ux-wave-3-dashboard-primary-action-cta-value-ranked-card-sta
plan: 01
subsystem: Dashboard / Home tab UX
tags: [ux, dashboard, cta, value-rank, swiftui, i18n]
requires:
  - "viewModel.recommendation (AutoregulationEngine.TrainingRecommendation?) — read-only"
  - "viewModel.hasRealData — read-only"
  - "showActiveWorkout state + .sheet ActiveWorkoutSheet() (existing)"
provides:
  - "PrimaryActionCTA subview (recommendation-aware, dominant non-accent)"
  - "value-ranked Dashboard body VStack (established cluster up top, setup prompts demoted, context-aware)"
  - "dashboard.cta.* localized strings (en + zh-Hans)"
affects:
  - "WorkloadApp/Views/Dashboard/DashboardView.swift"
  - "WorkloadApp/Resources/Localizable.xcstrings"
tech-stack:
  added: []
  patterns:
    - "View-side label mapping from recommendation.sessionType (no new VM/engine logic)"
    - "Context-aware ordering via existing render guards + hasRealData wrapper"
key-files:
  created: []
  modified:
    - "WorkloadApp/Views/Dashboard/DashboardView.swift"
    - "WorkloadApp/Resources/Localizable.xcstrings"
decisions:
  - "CTA nil-recommendation reuses a distinct dashboard.cta.logWorkout key (value identical to dashboard.action.logWorkout) for self-contained CTA string namespace."
  - "Toolbar 'Log Workout' button KEPT (existing entry point, harmless) — body CTA is additive."
  - "Established cluster wrapped in `if viewModel.hasRealData { ... }`; setup-prompt group placed after it with guards verbatim, so cold-start users see prompts first (cluster renders nothing)."
  - "CycleStatusStrip + cycle prompt left in the (always-rendered) prompt group gated only by their own guards (latestCycleSnapshot / showCyclePrompt) — preserved byte-equivalent; still visible to established users with cycle data, below the cluster."
metrics:
  duration: ~12min
  tasks: 3
  files: 2
  completed: 2026-06-02
---

# Phase 40 Plan 01: UX Wave 3 — Dashboard primary-action CTA + value-ranked card stack Summary

Added a recommendation-aware primary-action CTA directly under the hero readiness score (dominant text1-fill, no accent) and value-ranked the Dashboard body so established no-coach users get readiness → CTA → load → metrics → summary → sessions up top, while cold-start users keep their setup/connect prompts prominent — no engine/flag/ViewModel-logic change.

## What was built

### Task 1 — PrimaryActionCTA subview (commit `3d273d7`)
- New `PrimaryActionCTA` struct in DashboardView.swift: takes `recommendation: AutoregulationEngine.TrainingRecommendation?` + `onTap: () -> Void`.
- Label mapping (view-side only, no new VM/engine call) from `recommendation?.sessionType`:
  - `.rest` → `dashboard.cta.logRestDay` ("Log a rest day")
  - `.activeRecovery` → `dashboard.cta.logLightSession` ("Log a light session")
  - `.power/.strength/.hypertrophy/.conditioning` → `dashboard.cta.startSession` ("Start session")
  - `nil` → `dashboard.cta.logWorkout` ("Log Workout") neutral fallback
- Style: dominant non-accent treatment per `<interfaces>` — `ColorTokens.text1` fill, `ColorTokens.background` label, `.font(.Tokens.bodyMedium)`, `.frame(maxWidth: .infinity)`, `.padding(.vertical, Spacing.sm)`, `Rectangle().stroke(text1, 0.5)`, 0pt corners, `.buttonStyle(.plain)`, `.padding(.horizontal, Spacing.sm)` + `.padding(.top, Spacing.xs)`. `.accessibilityLabel` reflects the chosen label. Action ALWAYS calls `onTap` (logging never blocked).
- 4 new keys added to Localizable.xcstrings with en + zh-Hans translations.

### Task 2 — Value-ranked body + CTA wiring (commit `1ff9b43`)
- Reordered the body `VStack(spacing: 0)` per C.2.
- CTA wired `onTap: { showActiveWorkout = true }`, placed under hero/PRSDualRun, above the bulk.
- Established cluster wrapped in `if viewModel.hasRealData`: fatigue/cold-start banner → TrainingLoadSection → MetricsStrip → WeeklySummary block (+NotificationPrePermissionCard / firstWeekPrompt) → RecentSessionsSection.
- Setup/connect prompt group (WelcomeActionCard, TrainingProfileCard, HealthKit empty-state switch, cycle prompt, CycleStatusStrip) follows, with every render guard byte-equivalent. Because the cluster renders nothing for cold-start users, the setup prompts appear first (prominent) for them; for established users their guards no-op.
- PRSDualRunCard line + `viewModel.dualRunMessage` UNCHANGED; PRSActivation flag never referenced. Niggle Button remains the last child of the VStack. `.sheet`/`.task`/`.onChange`/`loadData` untouched. Toolbar Log Workout button kept.

### Task 3 — Regression gate sweep (no code changes needed)
- Verified on DashboardView.swift: exactly **1** `ColorTokens.accent` (hero score, the recoveryScore Text — CTA has zero accent); **0** `RoundedRectangle` / `.cornerRadius` / `.shadow(` / `.system(`; no off-grid spacing literals introduced (CTA uses `Spacing.sm`/`Spacing.xs`; pre-existing `spacing: 8`/`16`/`0` are 8pt-grid compliant and untouched).
- Verified all 4 `dashboard.cta.*` keys have non-empty en + zh-Hans values.
- Build green; gate already clean from Tasks 1–2, so no Task-3 commit (verification-only task).

## Card-block inventory (proves nothing dropped)

| Block | Before | After |
|-------|:--:|:--:|
| HeroReadinessCard | 1 | 1 |
| PRSDualRunCard (flag/EmptyView) | 1 | 1 |
| PrimaryActionCTA | 0 | 1 (new) |
| WelcomeActionCard (`showWelcomeCard`) | 1 | 1 |
| TrainingProfileCard (`showTrainingProfileCard`) | 1 | 1 |
| HealthKit EmptyStateCard (`!hasRealData` .notRequested) | 1 | 1 |
| HealthKitNoDataCard (.requestedNoData) | 1 | 1 |
| cycle prompt (`showCyclePrompt`) | 1 | 1 |
| CycleStatusStrip (`latestCycleSnapshot`) | 1 | 1 |
| MetricsStrip | 1 | 1 |
| WeeklySummaryCard | 1 | 1 |
| NotificationPrePermissionCard (`!prePermissionShown`) | 1 | 1 |
| firstWeekPrompt (else branch) | 1 | 1 |
| cold-start buildingBaseline (`isColdStartActive`) | 1 | 1 |
| FatigueAttentionBanner (`fatigueZone != .low`) | 1 | 1 |
| TrainingLoadSection | 1 | 1 |
| RecentSessionsSection | 1 | 1 |
| niggle Button (last child) | 1 | 1 |

**16 pre-existing blocks all preserved + 1 new (PrimaryActionCTA) = 17.** Every render guard grep-confirmed byte-equivalent (`showWelcomeCard`, `showTrainingProfileCard`, `!viewModel.hasRealData` + connectionState switch, `showCyclePrompt`, `latestCycleSnapshot`, `!prePermissionShown`, `isColdStartActive`, `fatigueZone != .low`).

## Deviations from Plan

None — plan executed exactly as written. Task 3 was verification-only (gate clean from Tasks 1–2), so it produced no separate commit by design.

## Constraints honored

- Exactly ONE `ColorTokens.accent` remains (hero score); CTA is non-accent (text1 fill).
- 0pt corners, no shadow, Font.Tokens, 8pt grid (Spacing.*) on edited file.
- No engine/flag/VM-logic change (AutoregulationEngine, PRSActivation, DashboardViewModel untouched).
- files_modified = DashboardView.swift + Localizable.xcstrings only.
- New strings localized en + zh-Hans.
- Build green on iPhone 17 Pro sim (id CAF84E71-BB64-491D-87C8-875A0143B26D) after each task.

## Self-Check: PASSED
- FOUND: WorkloadApp/Views/Dashboard/DashboardView.swift (PrimaryActionCTA present)
- FOUND: WorkloadApp/Resources/Localizable.xcstrings (4 cta keys, en+zh-Hans)
- FOUND commit: 3d273d7 (Task 1)
- FOUND commit: 1ff9b43 (Task 2)
