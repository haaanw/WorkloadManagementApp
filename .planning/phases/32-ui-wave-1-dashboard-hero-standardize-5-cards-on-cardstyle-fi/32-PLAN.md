---
phase: 32
plan: 1
type: auto
autonomous: true
wave: 1
subsystem: ui-dashboard
requirements: []
depends_on: [31]
---

# Phase 32 Plan 1: UI Wave 1 — Dashboard (hero screen)

## Objective

Fix the Dashboard hero screen's plane separation, section grammar, font, and spacing per
INVENTORY.md §3 (Dashboard, 5.5/10) + §6 Wave 1. Consume the Phase-31 shared primitives
(`.cardStyle()`, `SectionHeader`, `SectionContainer`, `Spacing`); edit Dashboard call sites
only. Do NOT touch `Components/` primitives, `ColorTokens`, algorithm code, or feature flags.

## Scope

`WorkloadApp/Views/Dashboard/` only:
- `WelcomeActionCard.swift`
- `TrainingProfileCard.swift`
- `NotificationPrePermissionCard.swift`
- `WeeklySummaryCard.swift`
- `PRSDualRunCard.swift`
- `DashboardView.swift`

## Tasks

### Task 1 — Standardize the 5 cards on `.cardStyle()` (surfaceEl) [type=auto]

For each of the 5 card files, replace the hand-rolled
`.background(ColorTokens.surface) + .overlay(Rectangle().stroke(divider, ...))` recipe with
`.cardStyle()` (surfaceEl + 0.5pt divider + 16/24 pad). Remove now-redundant per-edge 16pt
paddings where `.cardStyle()` supplies them; keep internal structural spacing on `Spacing.*`.

- **WelcomeActionCard / NotificationPrePermissionCard / TrainingProfileCard:** route the
  outer VStack through `.cardStyle()`; drop the manual `.background(.surface)` + overlay and
  the redundant outer `.padding(.horizontal/.top/.bottom, 16)`. Card titles already use
  `sectionHead`/`body` — keep; the micro-cap eyebrow is a card eyebrow (kept), NOT a section
  header. Inner button paddings stay on `Spacing.xs`.
- **WeeklySummaryCard:** route outer VStack through `.cardStyle(horizontalPadding: 0)` (its
  rows already pad `.horizontal, 16`) OR keep internal 16 pads and drop them in favor of
  cardStyle horizontal pad. Choose whichever keeps the collapsible header tap target full
  width. Replace `.background(.surface)+overlay` with cardStyle.
- **PRSDualRunCard:** replace `.background(.surface) + .overlay(stroke lineWidth:1)` with
  `.cardStyle()`. Border 1 → 0.5 comes free from cardStyle. Keep the flag-off `EmptyView()`
  path byte-identical (only the rendered branch changes).

### Task 2 — WeeklySummaryCard `.system` fonts → Font.Tokens [type=auto]

- Line 27 chevron `.font(.system(size: 12))` → `.font(.Tokens.micro)`.
- Line 42 flame `.font(.system(size: 13))` → `.font(.Tokens.smallLabel)`.

### Task 3 — Section grammar + load-stat promotion in DashboardView [type=auto]

- **TrainingLoadSection:** convert to `SectionHeader` + `SectionContainer` grammar
  (consistent with RecentSessionsSection which already uses `SectionHeader`). Keep ZoneBadge
  trailing. Promote `LoadStatCell` value from `.Tokens.label` to `.Tokens.sectionHead`
  (monospacedDigit) so ACWR/ATL/CTL/TSB read as primary stats, matching the MetricStrip
  hierarchy. Keep the micro-cap stat captions (inline metric captions are the sanctioned use
  of micro-caps).

### Task 4 — Snap off-grid 4/2 spacing literals → Spacing.* [type=auto]

In DashboardView, snap the flagged half-step literals to `Spacing.xs` (8):
- factorRow VStack `spacing: 4` → `Spacing.xs`
- MetricStripCell VStack `spacing: 4` → `Spacing.xs`; unit HStack `spacing: 2` → `Spacing.xs`
  (keep `.lastTextBaseline`); MetricStripCell already uses Spacing for padding.
- LoadStatCell VStack `spacing: 2` → `Spacing.xs`
- RecentSessions inner VStack `spacing: 4` → `Spacing.xs`; snap residual literal `16` paddings
  in that section to `Spacing.sm`.
Also snap residual literal `16`/`8`/`4` paddings inside the 5 edited cards to `Spacing.*`.

## Verification

- `xcodebuild -scheme "workload management" -destination 'platform=iOS Simulator,id=CAF84E71-BB64-491D-87C8-875A0143B26D' build` → BUILD SUCCEEDED.
- INVENTORY §5 regression gate scoped to edited Dashboard files → no NEW forbidden patterns.
- Accent remains only on hero readiness score (DashboardView ~:314); not added elsewhere.

## Success Criteria

- All 5 cards on surfaceEl via `.cardStyle()`; no Dashboard card left on `.surface`.
- No `.system(size:)` fonts in WeeklySummaryCard.
- PRSDualRunCard border 0.5 (via cardStyle).
- Load stats promoted to sectionHead; TrainingLoadSection uses SectionHeader/SectionContainer.
- Off-grid 4/2 literals snapped to Spacing.*.
- Build green; regression gate clean for edited files.
