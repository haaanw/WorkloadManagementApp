# Phase 36: UI Wave 5 — Off-grid spacing sweep - Context

**Gathered:** 2026-06-02
**Status:** Ready for planning
**Mode:** Auto-generated (discuss skipped; spec locked in INVENTORY.md)

<domain>
## Phase Boundary
Sweep ALL residual off-8pt-grid spacing across WorkloadApp/Views + Components → Spacing.* tokens. Per INVENTORY.md §2.C (112 findings) + §6 Wave 5. Prior waves already snapped spacing in the files they touched; this is the cleanup of everything remaining.

IN SCOPE: padding/spacing/frame/offset numeric literals that are not multiples of 8, across all Views/Components NOT already grid-clean. OUT OF SCOPE: motion (Wave 6/37), any visual-system change beyond spacing.
</domain>

<decisions>
## Locked
- Snap residual off-grid literals → Spacing.* (xs8/sm16/md24/lg32/xl48): 12→8 or 16 (judge by context), 10→8, 6→8, 4→8, 2→drop/8, 14→16, 18→16, 20→24, 22→24, 28→24 or 32, 36→32 or 40, 44→48, 52→48; off-grid frames 44→48, 180→176/184, toggle 28/20, grabber 36/4.
- Known residual sites from prior-wave reports: PRCelebrationOverlay (ActiveWorkoutSheet ≈:662/676), ImportRPESheet (WorkoutLogView ≈:364), HRVDetailView/SleepDetailView (spacing:4 + others), PDFGenerationSheet minHeight 44→48 (Coach uses 48). Plus anything §2.C lists not yet fixed.
- ALLOWED sub-grid exceptions (do NOT flag/change): true hairline/indicator widths & heights 0.5 / 1 / 2 / 3 pt (divider strokes, ring widths, baseline rules). Decide + DOCUMENT a sub-grid token if a 4pt baseline-pair recurs; otherwise leave documented hairlines.
- DESIGN.md hard rules stay intact (don't regress corners/shadows/fonts/accent/color — Wave 4 left them CLEAN). Do NOT amend ColorTokens. Do NOT touch algorithm/flags.
- After sweep, TIGHTEN the INVENTORY §5 regression-gate off-grid lists (rules 6-7) to match what truly remains; drop `4` from rule 7 only if a documented 4pt token is adopted.

## Claude's Discretion
12→8-vs-16 and similar context calls (use surrounding rhythm). Whether to introduce a documented sub-grid token. Keep visual changes minimal — this is grid-hygiene, not redesign.
</decisions>

<code_context>
## Existing Code Insights
- Spec: INVENTORY.md §2.C (112 off-grid findings, highest-priority files listed) + §6 Wave 5. Spacing tokens in WorkloadApp/Components/CardStyle.swift (Spacing enum).
- Many files already grid-clean from Waves 0-4; focus on the untouched remainder + the named residual sites.
</code_context>

<specifics>
## Specifics
Build gate: xcodebuild sim id iPhone 17 Pro `CAF84E71-BB64-491D-87C8-875A0143B26D` via -project. Incremental build every 3-5 files. After sweep, run INVENTORY §5 rules 6-7 across WorkloadApp/ and report residual (with justified hairline exceptions). Re-confirm rules 1-5 still 0 (no regression). SERIAL. SourceKit phantom diagnostics expected — trust xcodebuild. rtk mangles multi-file rg — per-file grep.
</specifics>

<deferred>
## Deferred
Hierarchy/text-weight polish + motion = Wave 6 (37). SetEntryRow placeholder i18n = future.
</deferred>
