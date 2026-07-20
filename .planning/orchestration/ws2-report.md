# WS2 · Layout Recomposition — Report

Date: 2026-07-20. Session: WS2 (Layout Recomposition). Canonical checkout, no branch/worktree.
Direction: demo §3 "After" (decision D14) — asymmetric readouts, metric grids with unit
superscripts + delta lines, ruled section headers, varied density. Composition only — no
behavior change, all render conditions/values/bindings/a11y IDs preserved.

## Files touched (per item)

**Shared primitive — `Components/LayoutPrimitives.swift`** (built out from the pre-registered stub)
- `MetricCell(label:value:unit:valueColor:delta:)` + trailing-closure form + `MetricDeltaLine`:
  micro-caps label, 30pt mono `dialValue` (tabular → fixed-width; a re-measure never reflows
  the grid), optional unit superscript, optional bottom delta/accessory. Own light plane
  (`dataPlate`); fills its share of an `HStack` so a row reads as a scannable grid.
- `RuledSectionHeader(title:)`: micro-caps + trailing 0.5pt hairline rule, no internal
  horizontal padding (aligns flush with the cards beneath). Tracking/casing Latin-only.

**Item 2 — Home (`Views/Dashboard/DashboardView.swift`)** (by me)
- Hero panel readout → baseline-aligned: `.lastTextBaseline` + `Spacer` pins the zone label to
  the trailing edge on the score's baseline (was zone tucked beside the score). Tick numerals
  under the hero scale unchanged. Kept `dashboard.hero`, count-up, skeleton, all guards.
- `MetricsStrip` → 3-cell `MetricCell` grid (HRV/RHR/Sleep) with unit superscripts; each cell
  keeps its staleness badge in the bottom accessory slot (no info lost). Removed the now-unused
  `MetricStripCell` struct.
- `RecentSessionsSection` header → `RuledSectionHeader`. Rows already two-line (name + relative
  date, mono RPE right).

**Item 3 — Log (`Views/WorkoutLog/WorkoutLogView.swift` + `TodayVerdictCard.swift`)** (fork)
- TodayVerdictCard: `.textCase(.uppercase)` on the verdict state label so it optically aligns
  to the uppercase header sharing its `firstTextBaseline` line. Dial weight already baseline-
  aligned with its "from planned" caption. No other change (guard-fenced card).
- WorkoutLogView: history section → `RuledSectionHeader`. Rows unchanged (already two-line).

**Item 4 — Load (`Views/Workload/WorkloadView.swift`)** (fork)
- `ACWRGaugeCard` readout → baseline-aligned (value left, zone label pinned right). Panel + its
  TickScale untouched.
- ATL/CTL/TSB → `MetricCell` grid (descriptors moved to the delta line). Removed unused
  `LoadMetricRow`.
- Three `SectionContainer(header:)` → `RuledSectionHeader`.

**Item 5 — Recovery (`Views/Recovery/RecoveryView.swift`)** (fork)
- Score card = designed peak WITHOUT a panel: stays on `emphasisCardStyle()` (light), baseline-
  aligned readout (`71 /100` left, ZoneBadge pinned right) + a `.micro` `TickScale` (theme
  `.light`) strip beneath — the instrument moment that substitutes for the panel Home owns.
- HRV/RHR/Sleep contributors → standalone `MetricCell` grid (removed plate-in-plate
  `RecoveryComponentRow`).
- Six `SectionContainer(header:)` → ruled headers via a local `RuledSection` wrapper.

**Item 6 — Profile (`Views/Profile/ProfileView.swift`)** (fork)
- Every section header (Athlete, Training Profile, Movement Bank, Preferences, Notifications,
  Connected Devices, Data Sync, Measurement, Account + the pushed HealthKit detail) →
  `RuledSectionHeader` via the two shared header helpers. Quiet, consistent. Meta lines NOT
  invented (rows either already carry a trailing value or have no genuine secondary datum).

## a11y IDs verified present (post-build, on device)
`dashboard.hero`, `workoutLog.startWorkout` + `workoutLog.verdict.strikeZone`/`.reason`,
`recovery.scoreCard`, `workload.acwr`, `profile.movementBank` — each confirmed via
`axe describe-ui` before its screenshot. No container ID placed above a leaf.

## Panel Law
`panelStyle(` count: Home = 1, Load = 1, Recovery = 0 (replaced with `emphasisCardStyle`),
Log/Profile = 0. Compliant.

## Anti-nocebo (verdict card)
Accept/Keep (I-feel-strong / I-feel-rough) equal weight preserved; zero `ColorTokens.accent`/
`.index`/`.zoneDanger` on verdict state or number; strike-zone semantics untouched. (Guard
tests are the orchestrator's to run — build only per Coordination rule 2.)

## Build (combined tree — WS1/WS3 edits also present)
`xcodebuild … -derivedDataPath ~/.tonus-dd build` →
```
** BUILD SUCCEEDED **
```
Ran only after `pgrep xcodebuild` showed none (Coordination rule 2). No tests run.

## Screenshots (SCREENSHOT_MODE, sim 8E872500-…)
`.planning/orchestration/ws2-shots/`
- `01-home.png` — hero baseline readout + tick numerals
- `02-home-scrolled.png` — ruled RECENT SESSIONS + two-line rows
- `03-home-metricgrid.png` — HRV/RHR/SLEEP MetricCell grid
- `04-log.png` — verdict card grid (state label aligned) + ruled MY-TEMPLATES/history
- `05-recovery.png` — no-panel designed peak (baseline readout + micro TickScale) + grid + ruled headers
- `06-load.png` — ACWR panel readout + ATL/CTL/TSB grid + ruled headers
- `07-profile.png` — ruled headers throughout

Note: an interleaved WS1/WS3 relaunch bounced the app to login mid-capture; tabs were re-shot
after relaunch with per-tab a11y-ID verification, so 04–07 are confirmed real content.

## Deferrals
- Home Recent Sessions / Recovery rows: did NOT add "· duration" to meta lines or "vs base"
  deltas to the Home metric grid — the VM exposes no clean per-metric baseline delta and rows
  already carry the available secondary datum. Adding either = inventing data, out of scope.
- Log "MY TEMPLATES" / "Next match" headers stay 19pt: they live in `TemplateCarouselSection`
  / `NextMatchSection` (not in the WS2 ownership row) — left for a future pass or the orchestrator.
- Profile meta lines: none added (see item 6) — no genuine secondary data.
