# Phase 37: UI Wave 6 — Hierarchy / text-weight polish + motion (LAST) - Context

**Gathered:** 2026-06-02
**Status:** Ready for planning
**Mode:** Auto-generated (discuss skipped; spec locked in INVENTORY.md)

<domain>
## Phase Boundary
Final v1.5.1 wave. Two parts, in order: (1) per-row text-weight/emphasis-tier polish on the flat lists the audit flagged; (2) motion/transition tuning — LAST, and ONLY confirmation/orientation, never to mask contrast/hierarchy. Per INVENTORY.md §3 (flat-hierarchy callouts) + §6 Wave 6.

IN SCOPE: emphasis-tier fixes on named flat rows + tasteful motion. OUT OF SCOPE: any further structural/ladder/spacing change (done in Waves 0-5).
</domain>

<decisions>
## Locked — Part 1 (hierarchy/text-weight):
- Add ONE dominant emphasis tier per row where the audit found everything flat/muted (Font.Tokens weight changes, not new colors):
  - Coach Roster: client status should not read same weight as caption.
  - Export sheets: zone labels currently 12pt micro-caps muted, smaller than the name — invert so the meaningful value/name dominates.
  - SessionDetail / detail-view stat numbers: promote the number over its caption.
  - Paywall (UpgradeSheet): price / SAVE% badge currently text3 12pt low-emphasis — promote.
  - Onboarding: flat frequency text — give the selected value emphasis.
- Use existing Font.Tokens tiers only; do NOT introduce new fonts/sizes off-grid; do NOT add accent (Dashboard-hero-only); do NOT amend ColorTokens.

## Locked — Part 2 (motion, LAST):
- Tasteful confirmation/orientation motion only: e.g. subtle transitions on sheet present/dismiss, list insert/remove, state changes (recovery score reveal, PR celebration already exists). Respect DESIGN.md restraint — no bouncy/decorative excess, no motion that substitutes for hierarchy. Keep durations short, standard easing. Honor reduce-motion accessibility if cheap.
- Motion must NOT regress any rule 1-5 (corners/shadows/fonts/accent/color) or the 8pt grid.

## Claude's Discretion
Exact emphasis tiers per row; which transitions add genuine clarity vs noise (prefer fewer, high-signal). If motion risks feeling decorative/off-brand, do LESS — flag for human review rather than over-animate.
</decisions>

<code_context>
## Existing Code Insights
- Spec: INVENTORY.md §3 per-screen flat-hierarchy notes (Roster status, Export zone labels, detail stat numbers, paywall price/SAVE%, Onboarding frequency) + §6 Wave 6.
- Font.Tokens in WorkloadApp/Utilities/FontTokens.swift. Existing motion patterns: PRCelebrationOverlay (ActiveWorkoutSheet).
- Waves 0-5 left rules 1-5 = 0 and grid clean — do not regress.
</code_context>

<specifics>
## Specifics
Build gate: xcodebuild sim id iPhone 17 Pro `CAF84E71-BB64-491D-87C8-875A0143B26D` via -project. Incremental build. FINAL: run the FULL INVENTORY §5 regression gate (all rules 1-7) across WorkloadApp/ — must pass (justified hairline/PDFKit exceptions only). SERIAL. SourceKit phantom diagnostics expected — trust xcodebuild. rtk mangles multi-file rg — per-file grep.
</specifics>

<deferred>
## Deferred (post-v1.5.1)
v1.5.2 UX flow rework. ASO search-results screenshots. SetEntryRow placeholder i18n. On-device visual UAT (human) + before/after screenshots.
</deferred>
