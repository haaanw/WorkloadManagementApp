# Phase 31: UI Wave 0 — Shared primitives + ladder source recipes - Context

**Gathered:** 2026-06-02
**Status:** Ready for planning
**Mode:** Auto-generated (discuss skipped via workflow.skip_discuss — spec locked in INVENTORY.md)

<domain>
## Phase Boundary

Route the 7 app-wide source recipes (`MetricTile`, `InsightCard`, `CycleFuelingCard`, `FatigueAttentionBanner`, `REDSAttentionBanner`, `SpikeAlertBanner`, `SharpTextFieldStyle`) through `.cardStyle()`/`surfaceEl`, and fix `SharpTextFieldStyle` padding 12→16. These primitives are copied across every screen, so fixing them at the source restores plane separation app-wide — the highest-leverage fix in v1.5.1.

IN SCOPE: the 7 named source-recipe files only. OUT OF SCOPE: screen-level call sites (those are Waves 1-3, phases 32-34) except where a recipe's own definition lives.
</domain>

<decisions>
## Implementation Decisions

### Locked (do NOT deviate)
- Enforce the EXISTING elevation ladder: `ColorTokens.surfaceEl` for grouped/tappable cards, `.surface` only for inline strips/selected controls, `background` for canvas. Prefer routing through `.cardStyle()` (WorkloadApp/Components/CardStyle.swift) over hand-rolled `.background(...)+.overlay(Rectangle().stroke)`.
- Do NOT amend ColorTokens (audit found zero amend-candidates).
- DESIGN.md hard rules: 0pt corners (no RoundedRectangle/.cornerRadius), no shadows, General Sans via Font.Tokens only, 8pt grid, accent only on Dashboard hero score.
- SharpTextFieldStyle padding 12 → 16 (8pt-grid fix, app-wide).

### Claude's Discretion
Exact refactor mechanics (whether a recipe adopts `.cardStyle()` wholesale vs swaps `.surface`→`.surfaceEl` + keeps its custom border) per file, guided by INVENTORY.md §2.A and CardStyle.swift conventions. Banners (Fatigue/REDS/Spike) may keep their attention-border treatment but must sit on surfaceEl, not surface.
</decisions>

<code_context>
## Existing Code Insights

- Spec + exact file:line targets: `.planning/v1.5-audit/INVENTORY.md` §2.A and §6 Wave 0.
- Primitive definitions live in `WorkloadApp/Components/` (MetricTile, CycleFuelingCard, FatigueAttentionBanner, REDSAttentionBanner, SpikeAlertBanner) + `WorkloadApp/Utilities/SharpTextFieldStyle.swift`. InsightCard is under `WorkloadApp/Views/Recovery/`.
- Card primitive: `.cardStyle()` = surfaceEl + 0.5pt divider border + 16/24 padding (CardStyle.swift). `Spacing` tokens: xs8/sm16/md24/lg32/xl48.
- ChartTooltipOverlay.swift:51 is already correct (surfaceEl + 0.5pt) — flagged only for not routing through .cardStyle() (LOW, optional).
</code_context>

<specifics>
## Specific Ideas

Build gate: `xcodebuild` against KNOWN-ALIVE sim id iPhone 17 Pro `CAF84E71-BB64-491D-87C8-875A0143B26D`. Incremental build every 3-5 files. After edits, run the INVENTORY.md §5 regression-gate script scoped to these files — must pass. Verify .pbxproj unaffected (no new files expected). Execute SERIAL.
</specifics>

<deferred>
## Deferred Ideas

Screen-level call sites that consume these primitives = Waves 1-3 (phases 32-34). Motion = Wave 6 (phase 37).
</deferred>
