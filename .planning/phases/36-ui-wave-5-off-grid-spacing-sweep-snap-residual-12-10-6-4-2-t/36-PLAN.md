---
phase: 36
plan: 36
type: ui-sweep
autonomous: true
wave: 5
subsystem: design-system / spacing
requirements: []
---

# Phase 36 — UI Wave 5: Off-grid spacing sweep

## Objective
Sweep ALL residual off-8pt-grid spacing literals (padding / spacing / frame) across
`WorkloadApp/Views` + `WorkloadApp/Components` → `Spacing.*` tokens. Per INVENTORY.md §2.C
(112 original findings; Waves 0–4 already cleared the files they touched) + §6 Wave 5.
Grid hygiene only — NOT redesign. Do NOT regress DESIGN.md hard rules 1–5 (corners/shadows/
fonts/accent/color), which Wave 4 left CLEAN.

## Context
@.planning/v1.5-audit/INVENTORY.md (§2.C, §5 rules 6–7, §6 Wave 5)
@WorkloadApp/Components/CardStyle.swift (Spacing enum: xs8/sm16/md24/lg32/xl48)
@DESIGN.md (8pt grid)

## Snap rules (locked)
12→8 or 16 (context), 10→8, 6→8, 4→baselinePair(4pt token) or 8, 2→drop, 14→16, 18→16,
20→24, 22→24, 28→24/32, 36→32, 44→48, 52→48; frames 180→184, toggle 28/20→32/24, grabber 36/4.

## Sub-grid token decision
The recurring `spacing: 4` is overwhelmingly a **label-to-value baseline pair** (caption/micro
label tight above its value). Tokenize as ONE documented `Spacing.baselinePair = 4` rather than
churning all to 8 (which breaks the typographic pairing — that is redesign). Drop `4` from gate
rule 7b. True hairlines/indicators (0.5/1/2/3pt, severity-bar height:4, zone-bar width:3,
value-unit spacing:2) stay as documented exceptions.

## Tasks (serial, build gate every 3–5 files)

1. **type=auto** Add `Spacing.baselinePair` token; sweep shared Components
   (MetricTile, StalenessWarningBadge, SleepTrendChart, RadialPicker, HRVTrendChart). Build. Commit.
2. **type=auto** Dashboard + Workload (HRVDetailView, SleepDetailView, WorkloadView, RecoveryLoadChart).
   Snap label-value pairs + chart frames 180→184. Build. Commit.
3. **type=auto** Recovery (MorningCheckInSheet, NiggleLogSheet, RecoveryView). Build. Commit.
4. **type=auto** Workout Log (ActiveWorkoutSheet, WorkoutLogView, ExercisePickerView, WorkoutImportBanner,
   WorkoutImportSheet, TextTemplateImportSheet). Build. Commit.
5. **type=auto** Profile (ProfileView, TrainingProfileSheet). Build. Commit.
6. **type=auto** Coach + Templates (CoachRosterView, ContextSwitcher, both TemplateEditorSheet,
   both PrescribeWorkoutSheet, both TemplateListView). Build. Commit.
7. **type=auto** Paywall (UpgradeSheet: grabber, feature list, plan badge). Build. Commit.
8. **type=auto** Toggle dims (CardStyle DesignToggleStyle 48×28/20×20 → 48×32/24×24). Build. Commit.
9. **type=auto** Regression gate: confirm rules 7a/7b/7c CLEAN, rules 1–5 still 0. Tighten INVENTORY
   §5 gate lists (drop `4` from 7b; document remaining exceptions). Commit (chore).
10. **type=auto** Write SUMMARY. Commit (docs).

## Success criteria
- Gate rules 7a/7b/7c report zero off-grid hits in Views+Components.
- Rules 1–5 remain CLEAN (no regression).
- Build green on iPhone 17 Pro sim each gate.
- One documented sub-grid token adopted; gate lists reflect reality.
