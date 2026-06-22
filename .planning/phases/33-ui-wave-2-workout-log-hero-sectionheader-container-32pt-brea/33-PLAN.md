---
phase: 33
plan: 33
type: ui-enforce
autonomous: true
wave: 2
subsystem: Views/WorkoutLog
requirements: []
---

# Phase 33 Plan — UI Wave 2: Workout Log (hero screen)

## Objective
Fix the Workout Log hero screen per INVENTORY §3 (4.5/10) + §6 Wave 2. Consume the already-fixed
Phase 31 primitives (SectionHeader / SectionContainer / .cardStyle() / Spacing). Scope:
`WorkloadApp/Views/WorkoutLog/*` only. No primitive or Dashboard edits. No accent. 8pt grid.

## Context
- @WorkloadApp/Components/CardStyle.swift (primitives — consume, do not edit)
- @DESIGN.md (hard rules)
- @.planning/v1.5-audit/INVENTORY.md (§3 Workout Log, §2.B/C, §5 gate, §6 Wave 2)

## Tasks

### Task 1 (auto) — Section grammar + 32pt breaks in WorkoutLogView
- Replace micro-caps "Prescribed" label (`workoutLog.section.prescribed`, lines 108-115) with
  `SectionHeader` wrapped in `SectionContainer(header:)`.
- Wrap the template carousel, prescribed block, and session-history block so they read as distinct
  top-level sections with 32pt breaks instead of being divided only by 0.5pt hairlines.
- Snap off-grid `12` paddings → `Spacing.*` (12→8/16) on the prescribed label + card stack + SessionRow.
- Fix flat `SessionRow` hierarchy: one dominant emphasis tier (session name → `bodyMedium`/text1),
  metadata stays `label`/text2, date stays `smallLabel`/text3. Snap `vertical, 12` → `Spacing.xs`(8)
  paired with consistent grid; use `Spacing.sm` horizontal.
- Done: builds; section structure visible; SessionRow has one clear emphasis.

### Task 2 (auto) — TemplateCarouselSection: SectionHeader + surfaceEl card + icon tokens
- Replace micro-caps `section.myTemplates` header (lines 100-107) with `SectionHeader`.
- Move the primary tappable templateCard plane from `.surface` (line 247) → `surfaceEl`
  (`.cardStyle()` not usable due to fixed-height swipe layout; use `ColorTokens.surfaceEl` fill +
  existing 0.5pt divider overlay).
- Replace `.font(.system(size: 17/15/24))` icon glyphs (lines 172,193,226,346) → `.imageScale(.*)`.
- Snap `spacing: 4` weekday/initial stacks and `padding(.vertical, 2)` → `Spacing.xs` where on-grid.
- Done: builds; My Templates reads as a section; resting card on surfaceEl plane.

### Task 3 (auto) — PrescribedWorkoutCard: surfaceEl plane + grid + group-label
- Move card plane `.surface` (line 90) → `surfaceEl`.
- Snap `.top, 12` / `.vertical, 12` / `.bottom, 2` → `Spacing.*` (12→8, 2→Spacing.xs where on-grid;
  keep 2pt only if a true tight inline rule — prefer 8).
- Group sub-label uses `.micro` micro-caps for an inline caption (HRV-style) — acceptable per
  DESIGN.md (micro-caps reserved for inline captions, which this is). Keep.
- Done: builds; prescribed card lifts off page on surfaceEl.

### Task 4 (auto) — ActiveWorkoutSheet ExerciseEntryCard + SetEntryRow + FillButtonBar
- Move ExerciseEntryCard plane `.surface` (line 803) → `surfaceEl`. (FillButtonBar:990 stays
  `.surface` — it is a flat inline action strip, not a grouped tappable card; leave per ladder.)
- Localize hardcoded EN column headers SET/WEIGHT/REPS/RPE/DIST/TIME in `setHeaderRow` (lines
  765-772): change the column tuple type from `String` to `LocalizedStringKey` and pass the
  existing `table.header.*` keys + new `table.header.dist` / `table.header.time` / `table.header.timeMin`.
- Snap `.vertical, 10` set/add-button paddings → `Spacing.xs` (8); `padding(.horizontal, 48)` for the
  suggestion indent is on-grid (48 = xl) — keep.
- Done: builds; column headers localize; exercise card on surfaceEl.

### Task 5 (auto) — SessionDetailView: surfaceEl + section grammar
- Move ExerciseDetailCard plane `.surface` (line 188) and header strip `.surface` (line 27) →
  surfaceEl for the grouped exercise cards; keep header strip as inline `surface` (it is a flat
  top strip, not a tappable card) — apply surfaceEl only to ExerciseDetailCard.
- Snap `.vertical, 12` / `.vertical, 10` → `Spacing.xs`(8) / `Spacing.sm` as on-grid.
- Column headers already localized (`table.header.*`) — verify, no change needed.
- Done: builds; exercise detail cards distinct plane.

### Task 6 (i18n) — Add catalog keys
- Add `table.header.dist` (EN "DIST (M)" / zh "距离(米)"), `table.header.time`
  (EN "TIME (S)" / zh "时间(秒)"), `table.header.timeMin` (EN "TIME (MIN)" / zh "时间(分)")
  to `Localizable.xcstrings`, mirroring the existing `table.header.*` structure.
- Separate commit. Expect xcstrings build-churn — keep real additions only.

## Verification / Build Gate
```
xcodebuild -scheme "workload management" \
  -destination 'platform=iOS Simulator,id=CAF84E71-BB64-491D-87C8-875A0143B26D' build 2>&1 | tail -40
```
MUST report BUILD SUCCEEDED. Incremental build after batches. Then run INVENTORY §5 regression
grep on edited files — no NEW forbidden patterns.

## Success criteria
- [ ] All sections use SectionHeader/SectionContainer with 32pt breaks
- [ ] Tappable cards on surfaceEl (PrescribedWorkoutCard, templateCard, ExerciseEntryCard, ExerciseDetailCard)
- [ ] SessionRow has one dominant emphasis tier
- [ ] `.system(size:)` icon glyphs → imageScale
- [ ] Column headers localized (no hardcoded EN literals)
- [ ] Off-grid 12/10 → Spacing.*
- [ ] No accent, no RoundedRectangle/.shadow/.cornerRadius, no hardcoded color/font
- [ ] BUILD SUCCEEDED + regression gate clean on edited files
