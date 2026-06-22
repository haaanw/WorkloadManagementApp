---
phase: 40-ux-wave-3-dashboard-primary-action-cta-value-ranked-card-sta
reviewed: 2026-06-02T00:00:00Z
depth: deep
files_reviewed: 2
files_reviewed_list:
  - WorkloadApp/Views/Dashboard/DashboardView.swift
  - WorkloadApp/Resources/Localizable.xcstrings
findings:
  critical: 0
  warning: 0
  info: 1
  total: 1
status: clean
---

# Phase 40: Code Review Report

**Reviewed:** 2026-06-02
**Depth:** deep
**Files Reviewed:** 2
**Status:** clean

## Summary

Reviewed the Phase 40 changes: a recommendation-aware `PrimaryActionCTA` subview under the hero readiness score, and a context-aware value-ranked reorder of the Dashboard card stack. Adversarial review against all locked focus criteria found no Critical or Warning defects. The implementation is faithful to the spec and DESIGN.md.

Verified ground-truth facts:

- **Engine/VM untouched:** `git diff` of `AutoregulationEngine.swift` and `DashboardViewModel.swift` over the phase commit range is empty. No engine/flag/VM-logic change.
- **Accent constraint (CRITICAL focus):** Exactly ONE `ColorTokens.accent` usage remains in `DashboardView.swift` — line 386, the hero score number. The new CTA uses `ColorTokens.text1` fill + `ColorTokens.background` label (dominant non-accent treatment). Compliant.
- **Card inventory preserved:** Pre/post inventory diff confirms every card and its render guard survived the reorder — `HeroReadinessCard`, `PRSDualRunCard`, `WelcomeActionCard` (`showWelcomeCard`), `TrainingProfileCard` (`showTrainingProfileCard`), `EmptyStateCard`/`HealthKitNoDataCard` (`!hasRealData` + `connectionState` switch), cycle prompt (`showCyclePrompt`), `CycleStatusStrip` (`latestCycleSnapshot`), `MetricsStrip`, `WeeklySummaryCard` + `NotificationPrePermissionCard`, `FatigueAttentionBanner`, cold-start "building baseline" + first-week fallback, `TrainingLoadSection`, `RecentSessionsSection`, niggle button. No card dropped, no guard semantics altered.
- **Context-aware demotion correct:** The value cluster (fatigue/cold-start → load → metrics → weekly → recent) is gated behind `if viewModel.hasRealData`. The setup/connect prompt group (group 5) follows with its original guards unchanged. No card renders in both groups — the value-cluster gate (`hasRealData`, HealthKit-derived) and the prompt guards (`recentSessions`/`allCheckIns`/`trainingProfiles` emptiness, cycle state) reference disjoint data sources, so there is no double-render path. For cold-start (`hasRealData == false`) the entire value cluster including its leading `Spacer(height: lg)` is skipped, so setup prompts render directly under the CTA with no stranded gap. Established users correctly see prompts demoted below core cards.
- **CTA label mapping exhaustive:** `recommendation?.sessionType` is `AutoregulationEngine.TrainingRecommendation.RecommendedSessionType` with exactly six cases (power/strength/hypertrophy/conditioning/activeRecovery/rest). The switch handles all six plus `nil`, is exhaustive, and the action (`showActiveWorkout = true` → `ActiveWorkoutSheet`) is always wired regardless of label — logging never blocked.
- **PRSDualRunCard verbatim:** Identical line pre/post; not reordered into prominence, flag untouched.
- **Niggle button last:** Remains the final element in the scroll VStack.
- **Localization complete:** All four new CTA keys (`dashboard.cta.logRestDay`, `dashboard.cta.logLightSession`, `dashboard.cta.startSession`, `dashboard.cta.logWorkout`) present in both `en` and `zh-Hans`.
- **DESIGN.md compliance:** No `RoundedRectangle`/`cornerRadius`/`.shadow`/`.system` anywhere in the file. CTA uses `Rectangle().stroke` (0pt corners), `Font.Tokens.bodyMedium`, and Spacing tokens (`xs`=8, `sm`=16, `md`=24, `lg`=32 — all 8pt multiples).
- **SwiftUI correctness:** Two `ForEach` blocks, each with a unique, correctly-scoped id (`\.offset` over enumerated reasoning factors; `\.id` over sessions). No duplicate-ID risk. No broken conditionals after reorder.

## Info

### IN-01: CTA `accessibilityLabel` duplicates the visible label verbatim

**File:** `WorkloadApp/Views/Dashboard/DashboardView.swift:355`
**Issue:** The CTA sets `.accessibilityLabel(String(localized: labelKey))` on a `Button` whose label `Text` already carries the same localized string. SwiftUI already derives the accessibility label from a `Button`'s text content, so this explicit label is redundant (not harmful — it produces the identical value). It does, however, mean VoiceOver announces only the adaptive label (e.g. "Log a rest day") with no extra context that the action opens the workout sheet. Minor; not a defect.
**Fix:** Optional — either drop the redundant `.accessibilityLabel` line, or enrich it with action context, e.g.:
```swift
.accessibilityLabel(String(localized: labelKey))
.accessibilityHint(String(localized: "a11y.opensWorkoutSheet",
                          defaultValue: "Opens the workout logging sheet"))
```

---

_Reviewed: 2026-06-02_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: deep_
