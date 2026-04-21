# Implementation Plan: UI Redesign + Algorithm Transparency Layer

Reviewed by /plan-eng-review on 2026-03-21. Status: COMPLETE as of 2026-03-23.

Design doc: ~/.gstack/projects/workload-app/hanwen-unknown-design-20260321-182704.md
Design system: DESIGN.md
Test plan: ~/.gstack/projects/workload-app/hanwen-unknown-test-plan-20260321-212727.md

---

## Status

All steps complete. The following was delivered across sessions ending 2026-03-23:

| Step | Description | Status |
|------|-------------|--------|
| 1 | DM Sans fonts added to Xcode project + Info.plist | ✅ |
| 2 | ColorTokens.swift replaced with DESIGN.md palette (programmatic dark/light via UIColor adaptive init) | ✅ |
| 3 | FontTokens.swift created (Font.Tokens extension, DM Sans only) | ✅ |
| 4 | RecoverySnapshot gained `hrvBaseline` + `restingHRBaseline` optional fields | ✅ |
| 5 | RecoveryPipeline passes baselines to upsertRecoverySnapshot | ✅ |
| 6 | ReasoningEngine.swift created (pure struct, HRV/RHR/sleep/streak factors ranked by impact) | ✅ |
| 7 | DashboardViewModel updated (reasoningFactors, hasRealData, hrv28Days, recentSnapshots) | ✅ |
| 8 | DashboardView redesigned (hero card, metrics strip, flat layout, NavigationLink factor rows) | ✅ |
| 9 | All other views updated (RecoveryView, WorkoutLogView, WorkloadView, ActiveWorkoutSheet, SessionDetailView, ExercisePickerView, MorningCheckInSheet, MetricTile, ZoneBadge) | ✅ |
| 10 | WorkloadAppTests target created with ReasoningEngine, RecoveryScoreEngine, AutoregulationEngine, WorkloadCalculator tests (46 tests, all passing) | ✅ |
| 11 | WorkloadApp.swift font validation DEBUG assertions | ✅ |
| +A | Auth/Onboarding design system (LoginView, SignUpView, OnboardingView) | ✅ |
| +B | WorkloadCalculator unit tests (sessionTSS, srpeLoad, trimp, hrZone, efficiencyIndex, stepEWMA, computeHistoryEWMA, computeRollingACWR) | ✅ |
| +C | Progressive disclosure: HRVDetailView + SleepDetailView wired via NavigationLink from dashboard factor rows; HRVTrendChart + SleepTrendChart updated to flat design system | ✅ |

---

## Next Phase

**Phase 4 — Subscriptions** (not started). See TODOS.md.

Phases 2 and 3 are complete — see TODOS.md for details.
