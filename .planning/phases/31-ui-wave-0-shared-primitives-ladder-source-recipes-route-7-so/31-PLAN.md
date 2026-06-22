---
phase: 31
plan: 31
title: "UI Wave 0 — Shared primitives + ladder source recipes"
type: ui-enforce
autonomous: true
requirements: []
---

# Phase 31 Plan — UI Wave 0: Shared primitives + ladder source recipes

## Objective

Route the 7 app-wide source-recipe files onto the existing elevation ladder
(`surfaceEl` / `.cardStyle()`) and fix the app-wide `SharpTextFieldStyle` padding
12 → 16 (8pt grid). Fixing these shared primitives at the source restores plane
separation across every screen that copies them — the highest-leverage v1.5.1 fix.

Source: `.planning/v1.5-audit/INVENTORY.md` §2.A (elevation-ladder/surface misuse),
§2.C (off-grid spacing for SharpTextFieldStyle), §6 Wave 0.

## Scope

Edit ONLY the 7 source-recipe definitions (not screen call sites — those are Waves 1-3):

1. `WorkloadApp/Components/MetricTile.swift`
2. `WorkloadApp/Views/Recovery/InsightCard.swift`
3. `WorkloadApp/Components/CycleFuelingCard.swift`
4. `WorkloadApp/Components/FatigueAttentionBanner.swift`
5. `WorkloadApp/Components/REDSAttentionBanner.swift`
6. `WorkloadApp/Components/SpikeAlertBanner.swift`
7. `WorkloadApp/Components/SharpTextFieldStyle.swift`  (lives in Components, not Utilities)

## Locked constraints

- Enforce the EXISTING ladder; do NOT amend `ColorTokens` (audit found zero amend-candidates).
- DESIGN.md hard rules: 0pt corners, no shadows, General Sans via `Font.Tokens.*` only, 8pt grid,
  accent only on Dashboard hero score.
- Reserve `.surface` for inline strips / selected controls only.
- Do NOT touch algorithm code or feature flags (stay dormant/FALSE).

## Tasks

1. **MetricTile** — grouped 2-col metric tile: swap `.surface` → `.surfaceEl`, keep custom
   0.5pt divider border. (Inline metrics strip on Dashboard does not use this recipe.)
2. **InsightCard** — plain card: replace hand-rolled `frame + padding + .surface background +
   overlay` with `.cardStyle()` (surfaceEl + 0.5pt divider + 16/24 pad).
3. **CycleFuelingCard** — plain card: adopt `.cardStyle()`.
4. **FatigueAttentionBanner** — keep colored left-border attention treatment; swap container
   fill `.surface` → `.surfaceEl`.
5. **REDSAttentionBanner** — same: swap `.surface` → `.surfaceEl`, keep attention border.
6. **SpikeAlertBanner** — same: swap `.surface` → `.surfaceEl`, keep attention border.
7. **SharpTextFieldStyle** — fix vertical padding 12 → 16 (8pt grid). Keep `.surface` fill
   (text fields are inline controls, where `.surface` is the correct ladder token).

## Verification

- Build gate: `xcodebuild -scheme "workload management"` against known-alive sim id
  `CAF84E71-BB64-491D-87C8-875A0143B26D`. MUST succeed.
- Regression gate (INVENTORY §5) scoped to the 7 files: no rounded/shadow/.system/accent/
  hardcoded-color introduced.
- `.pbxproj` unaffected (no new files).

## Success criteria

- All 7 recipes on the correct ladder plane (cards/banners → surfaceEl/`.cardStyle()`;
  field stays `.surface`).
- SharpTextFieldStyle padding on 8pt grid.
- Build green; regression gate clean for introduced patterns.
