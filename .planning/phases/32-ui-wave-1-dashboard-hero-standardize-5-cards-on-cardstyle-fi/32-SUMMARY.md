---
phase: 32
plan: 1
subsystem: ui-dashboard
tags: [ui, design-system, dashboard, cardstyle, surfaceEl, spacing, wave-1]
requires: [31]
provides: [dashboard-single-card-plane, dashboard-section-grammar]
affects: [WorkloadApp/Views/Dashboard]
tech-stack:
  added: []
  patterns: [.cardStyle(), Spacing.*, Font.Tokens.*]
key-files:
  created: []
  modified:
    - WorkloadApp/Views/Dashboard/WelcomeActionCard.swift
    - WorkloadApp/Views/Dashboard/TrainingProfileCard.swift
    - WorkloadApp/Views/Dashboard/NotificationPrePermissionCard.swift
    - WorkloadApp/Views/Dashboard/WeeklySummaryCard.swift
    - WorkloadApp/Views/Dashboard/PRSDualRunCard.swift
    - WorkloadApp/Views/Dashboard/DashboardView.swift
decisions:
  - "WeeklySummaryCard uses .cardStyle(horizontalPadding:0, verticalPadding:0) — its rows own their 16pt horizontal pads and the collapsible header tap target must stay full-width."
  - "MetricsStrip keeps .surface — it is the sanctioned inline-strip plane (DESIGN.md Dashboard layout), not a card."
  - "Card micro-cap eyebrows kept (card eyebrows, not section headers); TrainingLoadSection inline 19pt head kept (already correct sectionHead) with ZoneBadge trailing."
metrics:
  duration: ~20m
  completed: 2026-06-02
---

# Phase 32 Plan 1: UI Wave 1 — Dashboard (hero screen) Summary

Standardized all 5 Dashboard cards onto `.cardStyle()` (surfaceEl) so the Dashboard reads as one
card plane lifted off the page, killed the two-plane split, promoted the ACWR/ATL/CTL/TSB load
stats to `sectionHead` weight, removed the two `.system(size:)` fonts in WeeklySummaryCard, and
snapped the flagged off-grid 4/2 spacing literals to `Spacing.*`. Build green; regression gate clean.

## What changed

### Task 1 — 5 cards on `.cardStyle()` (surfaceEl)
- `WelcomeActionCard`, `TrainingProfileCard`, `NotificationPrePermissionCard`: replaced the
  hand-rolled `.background(ColorTokens.surface)` + manual divider overlay + redundant per-edge
  16pt paddings with `.cardStyle()`. Card eyebrow (micro-caps) and title (`sectionHead`/`body`)
  retained; button paddings → `Spacing.xs`.
- `WeeklySummaryCard`: `.cardStyle(horizontalPadding: 0, verticalPadding: 0)` (rows own their
  16pt pads; full-width collapsible header preserved). Inner `16/8/4` literals → `Spacing.sm/.xs`.
- `PRSDualRunCard`: `.cardStyle()` replaces `.background(.surface)` + `lineWidth:1` overlay.
  Border is now 0.5 (hairline) via cardStyle. Flag-off path still returns `EmptyView()` — the
  flag-off Dashboard remains byte-identical; only the rendered branch changed.

### Task 2 — WeeklySummaryCard `.system` fonts → Font.Tokens
- Chevron `.font(.system(size: 12))` → `.font(.Tokens.micro)`.
- Flame `.font(.system(size: 13))` → `.font(.Tokens.smallLabel)`.

### Task 3 — Load-stat promotion + section grammar
- `LoadStatCell` value: `.Tokens.label` → `.Tokens.sectionHead` (monospacedDigit kept) so the
  load stats read as primary, matching the MetricStrip tier. Stat captions stay micro-caps
  (sanctioned inline metric captions).
- TrainingLoadSection: inline 19pt `sectionHead` head retained with trailing ZoneBadge; stack
  spacing → `Spacing.sm` / `Spacing.md`. RecentSessionsSection already uses the `SectionHeader`
  primitive (unchanged).

### Task 4 — Off-grid spacing snaps
- DashboardView: factorRow VStack `4`, MetricStripCell VStack `4` + unit HStack `2`, LoadStatCell
  VStack `2`, RecentSessions inner VStack `4` + row `16` paddings → `Spacing.xs` / `Spacing.sm`.
- All residual `16/8/4/2` literals inside the 5 edited cards → `Spacing.*`.

## Verification

- **Build:** `xcodebuild -scheme "workload management" -destination 'platform=iOS Simulator,id=CAF84E71-BB64-491D-87C8-875A0143B26D' build` → **BUILD SUCCEEDED** (run twice: after the 5 cards, and after DashboardView).
- **Regression gate (§5), scoped to edited files:** rules 1–7 clean. No rounded corners, shadows,
  system/semantic fonts, hardcoded colors/hex, hand-rolled `.surface` cards, or off-grid
  padding/frame in the 6 edited files.
- **Accent rule:** `ColorTokens.accent` appears in exactly one place — `DashboardView.swift:314`
  (hero readiness score). Not added elsewhere; not removed from the hero.

## Deviations from Plan

None affecting scope. Notes:
- WeeklySummaryCard used `.cardStyle(horizontalPadding: 0, verticalPadding: 0)` rather than just
  `horizontalPadding: 0` — the rows already supply both horizontal (16) and vertical rhythm, so
  zeroing both avoids double-padding while still applying the surfaceEl plane + 0.5pt border.

## Known Stubs

None. PRSDualRunCard remains behind the dormant `PRSActivation.isEnabled` flag (FALSE by default,
untouched) — its flag-off render path is `EmptyView()`, unchanged by this plan.

## Out-of-scope (deferred) findings noted during the gate

- `HRVDetailView.swift` and `SleepDetailView.swift` (same Dashboard dir, NOT among the 5 cards):
  each has `VStack(... spacing: 4)` and `.background(ColorTokens.surface)`. Pre-existing, not in
  Wave 1 scope (these are trend/detail views) — left untouched. Flag for a later wave.
- `MetricsStrip` (`DashboardView:476`) keeps `.background(ColorTokens.surface)` — correct per
  DESIGN.md (metrics strip is the inline-strip plane, not a card). Intentionally not changed.

## Self-Check: PASSED
- All 6 modified files exist on disk (verified).
- Both feature commits present in git log (d7120e7, 2744997).
