# Phase 32: UI Wave 1 — Dashboard (hero screen) - Context

**Gathered:** 2026-06-02
**Status:** Ready for planning
**Mode:** Auto-generated (discuss skipped; spec locked in INVENTORY.md)

<domain>
## Phase Boundary

Fix the Dashboard hero screen's plane separation, section grammar, font, and spacing per INVENTORY.md §3 (Dashboard, 5.5/10) and §6 Wave 1. Dashboard is the daily value moment — highest-visibility screen after the shared primitives.

IN SCOPE: WorkloadApp/Views/Dashboard/* call sites. Phase 31 already fixed the shared primitives (MetricTile etc.) — consume them, don't re-edit them.
OUT OF SCOPE: other screens (Waves 3), Workout Log (Wave 2), motion (Wave 6).
</domain>

<decisions>
## Locked
- Standardize all 5 Dashboard cards (Welcome / TrainingProfile / Notification / WeeklySummary / PRSDualRun) on `.cardStyle()` (surfaceEl), matching the Hero/cycle/firstWeek cards that already use it. No two card planes.
- WeeklySummaryCard `.system(size:12/13)` chevron/flame → Font.Tokens.
- PRSDualRunCard border lineWidth 1 → 0.5 (hairline).
- Promote ACWR/ATL/CTL/TSB load stats to sectionHead weight; fix TrainingLoadSection grammar with SectionHeader/SectionContainer; card titles must not be micro-caps.
- Snap off-grid 4/2 spacing literals (DashboardView lines ~360/496/501/589/635) to Spacing.*.
- DESIGN.md hard rules; accent stays ONLY on the hero readiness score (DashboardView:314) — do not add accent elsewhere. Do NOT amend ColorTokens.
- Do not touch algorithm code / flags (stay dormant/FALSE).

## Claude's Discretion
Exact section-grouping structure on Dashboard, guided by INVENTORY §3 Dashboard + CardStyle.swift conventions.
</decisions>

<code_context>
## Existing Code Insights
- Spec + file:line targets: INVENTORY.md §3 (Dashboard) + §2.B (hierarchy) + §6 Wave 1.
- Primitives (fixed in Phase 31): `.cardStyle()`, SectionHeader, SectionContainer, Spacing tokens in WorkloadApp/Components/CardStyle.swift.
- Cards live in WorkloadApp/Views/Dashboard/ (DashboardView.swift + WelcomeActionCard/TrainingProfileCard/NotificationPrePermissionCard/WeeklySummaryCard/PRSDualRunCard.swift).
</code_context>

<specifics>
## Specifics
Build gate: xcodebuild sim id iPhone 17 Pro `CAF84E71-BB64-491D-87C8-875A0143B26D`. Incremental build every 3-5 files. Run INVENTORY §5 regression-gate on edited files. SERIAL. SourceKit phantom diagnostics are expected — trust xcodebuild.
</specifics>

<deferred>
## Deferred
Workout Log = Wave 2 (33). Remaining screens = Wave 3 (34). Motion = Wave 6 (37).
</deferred>
