# Phase 38 set-entry sketch — DECISION

Decided 2026-06-02. Chosen: **Variant A — stepper-primary** (see index.html).

## Build target (Variant A)
- Every set row shows inline ± steppers for weight and reps, always visible (no tap-to-reveal).
  - Weight stepper increment: ±2.5 (kg) default — discretion to make unit-aware (lb ±5). Reps ±1.
  - Tap the number itself → numeric keypad for big jumps.
- New set row pre-fills the previous set's weight/reps (carry-forward, within-session); shown ghosted/lighter until touched.
- "↻ Repeat last set" button below the rows clones the prior set entirely.
- "+ Add set" dashed affordance below that.
- Per-set RPE = collapsed `+ RPE` chip on the right; tap expands an inline RPE control for that row. Per-session RPE stays at finish. Default fast path = weight + reps only.
- PR-celebration + load-spike = INLINE dismissible banners (border-left accent in zone color: optimal for PR, danger for spike), NOT full-screen modals. Session commit still happens before they show; banners never block closing the sheet.
- Finish bar: dominant filled "Finish workout" (text1 fill / bg label) + ghost "Cancel".

## Rejected
- Variant B (repeat-first / tap-to-reveal): cleanest at rest but the most common action (progressive-overload weight nudge) costs an extra tap to activate the row. Target user nudges constantly → steppers should be always-on.

## Constraints carried into build
0pt corners, no shadows, hairline `divider` borders, General Sans / Font.Tokens, 8pt grid, NO accent in this view (steppers/buttons use text1/divider, not accent fill — accent is Dashboard-hero-only). Dark + light. Localize any new strings (en+zh). UX-only — no algorithm/flag change.
