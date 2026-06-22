---
phase: 31
plan: 31
subsystem: ui-design-system
tags: [elevation-ladder, surfaceEl, cardStyle, design-system, v1.5.1]
provides: ["shared-recipe ladder fix (surfaceEl/cardStyle) propagating plane separation app-wide"]
affects: [MetricTile, InsightCard, CycleFuelingCard, FatigueAttentionBanner, REDSAttentionBanner, SpikeAlertBanner, SharpTextFieldStyle]
key-files:
  modified:
    - WorkloadApp/Components/MetricTile.swift
    - WorkloadApp/Views/Recovery/InsightCard.swift
    - WorkloadApp/Components/CycleFuelingCard.swift
    - WorkloadApp/Components/FatigueAttentionBanner.swift
    - WorkloadApp/Components/REDSAttentionBanner.swift
    - WorkloadApp/Components/SpikeAlertBanner.swift
    - WorkloadApp/Components/SharpTextFieldStyle.swift
completed: 2026-06-02
---

# Phase 31 Plan 31: UI Wave 0 — Shared primitives + ladder source recipes Summary

Routed the 7 app-wide source-recipe files onto the existing elevation ladder
(`surfaceEl` / `.cardStyle()`) and snapped `SharpTextFieldStyle` vertical padding to the
8pt grid (12 → 16) — restoring card-vs-page plane separation everywhere these primitives
are copied, the highest-leverage v1.5.1 readability fix. No `ColorTokens` amend; existing
ladder enforced only.

## What changed per file

| File | Change | Mechanic |
|------|--------|----------|
| `MetricTile.swift` | `.background(.surface)` → `.background(.surfaceEl)` | Grouped 2-col tile now reads as a lifted card plane; kept its 0.5pt divider border. |
| `InsightCard.swift` | hand-rolled `frame+padding(16/16)+.surface+overlay` → `.cardStyle()` | Adopts the canonical card recipe (surfaceEl + 0.5pt divider + 16/24 pad). Vertical pad corrected 16 → 24 as a side effect (grid-correct). |
| `CycleFuelingCard.swift` | hand-rolled `.surface` box → `.cardStyle()` | Same canonical-card adoption. |
| `FatigueAttentionBanner.swift` | `.background(.surface)` → `.surfaceEl` | Kept colored left-border attention treatment; container now sits on the card plane. |
| `REDSAttentionBanner.swift` | `.background(.surface)` → `.surfaceEl` | Kept attention border. |
| `SpikeAlertBanner.swift` | `.background(.surface)` → `.surfaceEl` | Kept attention border + tap-to-dismiss. |
| `SharpTextFieldStyle.swift` | vertical padding `12` → `16` | 8pt-grid fix (app-wide). `.surface` fill intentionally retained — text fields are inline controls, where `.surface` is the correct ladder token. |

Net diff: 7 files, 7 insertions, 21 deletions (the `.cardStyle()` adoptions removed redundant
frame/padding/background/overlay boilerplate in InsightCard + CycleFuelingCard).

## Build result

**BUILD SUCCEEDED** (green).
- Project: `workload management/workload management.xcodeproj`, scheme `workload management`.
- Destination: known-alive sim id `CAF84E71-BB64-491D-87C8-875A0143B26D` (iPhone 17 Pro).
- `.pbxproj` unaffected — no new files added (all 7 pre-existing).
- No self-fix iterations needed (first build passed).

## Regression-gate result (INVENTORY §5, scoped to the 7 files)

Clean for everything **introduced** by this phase: no `RoundedRectangle`/`.cornerRadius`/
`.roundedBorder`, no `.shadow(`, no semantic system text style, no `ColorTokens.accent`, no
hardcoded `Color(red:)` / system-semantic foreground / `0x` hex.

Two grep hits are NOT violations introduced here:
1. `REDSAttentionBanner.swift:30` `.font(.system(size: 13))` — **pre-existing**, on the dismiss
   "X" SF Symbol glyph. `git diff` confirms my only change to this file is `surface`→`surfaceEl`.
   Icon-glyph `.system(size:)` fixes are explicitly scoped to **Wave 4** (INVENTORY §D), out of
   scope for Wave 0. Left untouched.
2. `SharpTextFieldStyle.swift:4` `Replaces .roundedBorder` — a comment string, not a
   `.roundedBorder` usage (false positive).

Remaining `ColorTokens.surface` in scope: only `SharpTextFieldStyle.swift:12` (the text-field
fill) — correct per the ladder (inline control), and the phase only asked to fix its padding.

## Deviations from Plan

- **Path correction (Rule 3 — blocking issue):** `SharpTextFieldStyle.swift` was specified at
  `WorkloadApp/Utilities/` but actually lives at `WorkloadApp/Components/`. Located via grep and
  edited at the real path. No other file path differed.
- **CycleFuelingCard doc comment:** attempted to update the "Flat surface" doc-comment line to say
  "Card plane (surfaceEl via .cardStyle())"; the exact-match Edit failed on an em-dash/whitespace
  mismatch. Left the comment as-is (cosmetic only; the code is correct). Minor.

## Pre-existing issues observed (NOT fixed — out of Wave 0 scope)

- `REDSAttentionBanner.swift:30` `.font(.system(size: 13))` dismiss glyph → Wave 4 (INVENTORY §D).
- `MetricTile.swift` `spacing: 4` (line 11) and `ZoneBadge` `5`/`10` off-grid padding → Wave 5
  off-grid sweep (INVENTORY §C). Not touched; Wave 0 is the surface-ladder pass only.

## Self-Check: PASSED

- All 7 modified files exist on disk (verified).
- Build SUCCEEDED against the specified sim id.
- pbxproj unchanged; no new files.
