---
phase: 33
plan: 33
subsystem: Views/WorkoutLog
tags: [ui, design-system, enforce, wave-2, workout-log, i18n]
requires: [phase-31-primitives, phase-32-dashboard]
provides: [workout-log-section-grammar, workout-log-card-planes]
affects: [Views/WorkoutLog]
tech-stack:
  added: []
  patterns: [SectionContainer, SectionHeader, RowSeparator, cardStyle-via-surfaceEl, imageScale-icons]
key-files:
  created:
    - .planning/phases/33-.../33-PLAN.md
    - .planning/phases/33-.../33-SUMMARY.md
  modified:
    - WorkloadApp/Views/WorkoutLog/WorkoutLogView.swift
    - WorkloadApp/Views/WorkoutLog/TemplateCarouselSection.swift
    - WorkloadApp/Views/WorkoutLog/PrescribedWorkoutCard.swift
    - WorkloadApp/Views/WorkoutLog/ActiveWorkoutSheet.swift
    - WorkloadApp/Views/WorkoutLog/SessionDetailView.swift
    - WorkloadApp/Resources/Localizable.xcstrings
decisions:
  - Used ColorTokens.surfaceEl directly (not .cardStyle()) on cards with fixed-height/swipe layouts where the modifier's padding/frame contract conflicts.
  - Kept flat inline action strips (FillButtonBar, SessionDetailView header strip) on .surface per elevation ladder — only grouped/tappable cards moved to surfaceEl.
  - "HISTORY" all-caps EN value for SectionHeader matches established sibling keys ("PRESCRIBED", "MY TEMPLATES"); SectionHeader renders 19pt Medium regardless.
  - Icon glyphs use .imageScale(.*) since FontTokens has no icon token (per INVENTORY §D).
metrics:
  duration: ~40m
  completed: 2026-06-02
---

# Phase 33 Plan 33: UI Wave 2 — Workout Log (hero screen) Summary

Workout Log hero screen lifted from one flat hairline-divided VStack into a section-grammar layout
(SectionHeader + SectionContainer + 32pt breaks), with all tappable cards moved onto the surfaceEl
plane, SessionRow given one dominant emphasis tier, SF Symbol icon glyphs detokenized to imageScale,
and previously-hardcoded EN column headers localized — addressing INVENTORY §3 (4.5/10) + §6 Wave 2.

## What Changed

### WorkoutLogView.swift
- Wrapped HealthKit-import banner, Prescribed block, and Session-history block in `SectionContainer`
  (32pt breaks). Prescribed + History now carry real `SectionHeader` (19pt Medium) instead of the
  12pt micro-caps `workoutLog.section.prescribed` label.
- Template carousel header now lives inside `TemplateCarouselSection`'s own SectionContainer.
- History rows use `RowSeparator` (inset hairline) instead of bare full-width rules.
- SessionRow hierarchy: name → `bodyMedium`/text1 (dominant), metadata → `smallLabel`/text2,
  date → `smallLabel`/text3. Snapped row + filter-chip padding/spacing to `Spacing.*`.
- Added `workoutLog.section.history` header; trailing 32pt breathing spacer.

### TemplateCarouselSection.swift
- `section.myTemplates` micro-caps header → `SectionContainer(header:)` + `SectionHeader`.
- Primary tappable templateCard plane `.surface` → `surfaceEl` (the main "start a workout" entry).
- 4× `.font(.system(size:17/15/24))` icon glyphs → `.imageScale(.medium/.small/.large)`.
- Snapped weekday-initials `spacing: 4`, title VStack `spacing: 4`, suggestion-badge insets to grid.

### PrescribedWorkoutCard.swift
- Card plane `.surface` → `surfaceEl`. Start CTA promoted `body` → `bodyMedium`.
- Snapped 12/8/2 paddings to `Spacing.*`; action-divider height 44 → 48.

### ActiveWorkoutSheet.swift
- ExerciseEntryCard plane `.surface` → `surfaceEl`.
- `setHeaderRow` signature `String` → `LocalizedStringKey`; hardcoded "SET/WEIGHT/REPS/RPE/DIST/TIME"
  literals replaced with `table.header.*` keys (incl. new dist/time/timeMin).
- Suggestion-row `spacing: 4` → `Spacing.xs`, icon → imageScale, paddings → `Spacing.*`.
- FillButtonBar left on `.surface` (flat inline action strip, not a grouped card).

### SessionDetailView.swift
- ExerciseDetailCard plane `.surface` → `surfaceEl`. Header strip left as inline `.surface`.
- Column headers already used `table.header.*` (verified). Snapped 12/10 paddings to `Spacing.*`.

### Localizable.xcstrings
- Added 4 keys (en + zh-Hans): `table.header.dist`, `table.header.time`, `table.header.timeMin`,
  `workoutLog.section.history`. Purely additive (69 insert / 1 delete), original key order preserved.

## Build Status

**GREEN — `** BUILD SUCCEEDED **`** via:
```
xcodebuild -project "workload management.xcodeproj" -scheme "workload management" \
  -destination 'platform=iOS Simulator,id=CAF84E71-BB64-491D-87C8-875A0143B26D' build
```
Confirmed alive sim (iPhone 17 Pro, Booted). Built green 4× across the pass (incremental + final +
post-catalog). No self-fix attempts needed.

## Regression Gate (INVENTORY §5) — edited files

Strict rules 1–5 (rounded corners, shadows, system/semantic fonts, accent, hardcoded color/hex):
**CLEAN** on all 5 edited Swift files.

Heuristic rules 6–7 (surface card recipe, off-grid): no NEW violations introduced. Three residual
off-grid hits remain in **untouched sub-views within edited files**, pre-existing and out of Wave 2
scope (deferred to Wave 5 off-grid sweep):
- `ActiveWorkoutSheet.swift:662,676` — `PRCelebrationOverlay` `.padding(.vertical,12)`
- `WorkoutLogView.swift:364` — `ImportRPESheet` `HStack(spacing:12)`

One pre-existing strict-rule hit out of scope: `TemplatePickerSheet.swift:118` `.font(.system(size:15))`
(file not edited; listed for Wave 4 per INVENTORY §D).

## Deviations from Plan

### Auto-fixed / discretion (no architectural change)
1. **[Rule 3 - blocking]** Project path: source lives in `WorkloadApp/` but the Xcode project is at
   `workload management/workload management.xcodeproj`. Build invoked with `-project` from that dir.
2. **[Rule 3 - tooling]** The `rtk` shell hook mangled multi-file `rg` regression-gate invocations into
   a single broken `grep`. Worked around by running per-file `grep -nE` from the WorkoutLog dir.
   Gate results are valid.
3. **[discretion]** Cards with fixed-height/swipe layouts use `ColorTokens.surfaceEl` directly rather
   than the `.cardStyle()` modifier (whose 16/24 padding + maxWidth frame conflicts with those layouts).
   Same plane + 0.5pt divider border, design-equivalent.
4. **[scope]** TextField placeholders ("kg"/"reps"/"RPE"/"m"/"sec"/"min") in SetEntryRow remain
   hardcoded EN — NOT in the Wave 2 work list (only column headers were named). Deferred.

No architectural changes. No accent introduced. No ColorTokens/primitive/Dashboard edits.

## Deferred
- Pre-existing off-grid in PRCelebrationOverlay / ImportRPESheet → Wave 5.
- `TemplatePickerSheet.swift` `.system(size:)` icon → Wave 4.
- SetEntryRow TextField placeholder localization → future i18n pass (not in audit work list).

## Commits
- `0df9809` feat(33): Workout Log section grammar, surfaceEl card planes, row hierarchy
- `6920aa8` feat(33): add localization keys for Workout Log column headers + history section
- (docs summary commit follows)

## Self-Check: PASSED
- All 5 edited Swift files + catalog present and committed (verified below).
- Both feature commits present in `git log`.
