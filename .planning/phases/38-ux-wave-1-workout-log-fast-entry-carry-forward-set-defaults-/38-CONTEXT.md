# Phase 38: UX Wave 1 — Workout log fast entry - Context

**Gathered:** 2026-06-02
**Status:** Ready for planning
**Mode:** Auto-generated (discuss skipped; spec V152-UX-SPEC.md §A + sketch decision)

<domain>
## Phase Boundary
Cut the ~15-taps-per-set workout-log loop. UX/flow + interaction only — NO algorithm/flag change (dormant v1.6 stays dormant). Scope = ActiveWorkoutSheet ExerciseEntryCard set-row entry + the finish/PR/spike flow. Spec: .planning/v1.5-audit/V152-UX-SPEC.md §A. INTERACTION LOCKED via sketch: .planning/sketches/38-set-entry/ — chosen **Variant A (stepper-primary)**, full detail in that dir's DECISION.md.
</domain>

<decisions>
## Locked — build Variant A (per sketch DECISION.md):
- Inline ± steppers on weight + reps, ALWAYS visible per set row (no tap-to-reveal). Weight ±2.5 (unit-aware if cheap: lb ±5), reps ±1. Tap the number → numeric keypad for big jumps.
- Carry-forward: new set row pre-fills previous set's weight/reps (within-session), shown ghosted until touched.
- "↻ Repeat last set" button clones the prior set entirely.
- "+ Add set" dashed affordance.
- Per-set RPE = collapsed "+ RPE" chip; tap expands inline RPE control for that row. Per-session RPE stays at finish. Fast path = weight+reps only.
- PR-celebration + load-spike → INLINE dismissible banners (border-left zone color: optimal=PR, danger=spike), NOT full-screen modals. Session commit still happens first; banners never block closing the sheet.
- DESIGN.md: 0pt corners, no shadows, hairline divider borders, Font.Tokens, 8pt grid, NO accent in this view (steppers/buttons use text1/divider). Dark+light. Localize new strings (en+zh).

## Claude's Discretion
Stepper increment unit-awareness; exact ghost styling for carried-forward; inline-banner placement; whether steppers reuse an existing component or a new SetStepper view. Keep the data model unchanged (SetRecord) — this is interaction, not schema.
</decisions>

<code_context>
## Existing Code Insights
- Target: WorkloadApp/Views/WorkoutLog/ActiveWorkoutSheet.swift (ExerciseEntryCard ~:803 region, set rows, finish/PR/spike flow ~:534-560). Current: 3 text fields/set; PRCelebrationOverlay + SpikeAlertBanner are full-screen.
- Primitives: CardStyle.swift (.cardStyle/Spacing/SectionHeader). Existing SharpTextFieldStyle for keypad fields. Sketch tokens already match ColorTokens.
- Flow map (reference): set commit already happens before PR/spike overlays (keep that invariant).
</code_context>

<specifics>
## Specifics
Build gate: xcodebuild sim iPhone 17 Pro `CAF84E71-BB64-491D-87C8-875A0143B26D` via -project. Incremental build every 3-5 files. SERIAL. SourceKit phantom diagnostics expected — trust xcodebuild. rtk mangles multi-file rg — per-file grep. Regression: INVENTORY §5 rules 1-7 must stay clean on edited files (no accent, 0pt corners, 8pt grid).
</specifics>

<deferred>
## Deferred
Cross-session carry-forward (history-driven) = later/Pro. Recovery = Phase 39. Dashboard = Phase 40.
</deferred>
