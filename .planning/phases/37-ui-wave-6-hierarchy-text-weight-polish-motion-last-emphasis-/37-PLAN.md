---
phase: 37
plan: 37
type: ui-polish
subsystem: ui
autonomous: true
wave: 6
depends_on: [31, 32, 33, 34, 35, 36]
requirements: []
---

# Phase 37 Plan: UI Wave 6 — Hierarchy / text-weight polish + motion (LAST)

## Objective
Final v1.5.1 wave. Two ordered parts: (1) add ONE dominant emphasis tier per audit-flagged flat
row using existing `Font.Tokens` weights only — no new fonts/sizes, no accent, no color changes;
(2) tasteful confirmation/orientation motion only. Do NOT regress rules 1-7.

## Context
@.planning/phases/37-ui-wave-6-hierarchy-text-weight-polish-motion-last-emphasis-/37-CONTEXT.md
@.planning/v1.5-audit/INVENTORY.md (§3 callouts, §5 regression gate, §6 Wave 6)
@DESIGN.md (restraint; hierarchy via type tiers; minimal-functional motion)

## Part 1 — Hierarchy / text-weight (FIRST)

<task type="auto">
1. Coach Roster (CoachRosterView.swift, ClientCard status row ~152-158): recovery/workload zone
   status reads at same `.label` weight as the sport-type caption. Promote the status line to
   `.labelMedium` + text1 so it dominates the secondary sport caption (text3).
</task>

<task type="auto">
2. Export sheet (CoachExportSheet.swift athlete row ~120): athlete name is `.label` (15pt) and
   the zone badge is `.micro` caps — name reads smaller/equal to the badge. Invert: promote the
   name to `.bodyMedium` so the meaningful value/name dominates the supplementary badge. Lift the
   muted zone badge text from text2→text2 (unchanged; badge stays subordinate micro-caps).
</task>

<task type="auto">
3. SessionDetailView.swift per-exercise "Total: X kg" stat (~180): promote from `.label`/text2 to
   `.labelMedium`/text1 so the totaled number dominates its caption. (MetricTile already promotes
   value→sectionHead over micro caption — no change needed there.)
</task>

<task type="auto">
4. UpgradeSheet.swift planButton price (~268): price is `body`/`bodyMedium` while title+SAVE badge
   are micro. Promote price to `.sectionHead` (19pt Medium) so price prominence dominates. Lift the
   SAVE badge from text3→text2 so it is legible but still subordinate to the price.
</task>

<task type="auto">
5. OnboardingView.swift frequency tiles (~121): selected value distinguished by color only. Give
   the SELECTED frequency `.bodyMedium` emphasis (the existing "active state" token), keeping
   unselected at `.body`. Mirrors experience-level + language-autonym active-state pattern.
</task>

BUILD GATE after Part 1.

## Part 2 — Motion (LAST, only after Part 1 green)

<task type="auto">
6. Add tasteful confirmation/orientation motion only, honoring DESIGN.md Motion section
   (easeOut entrances, easeIn exits, short durations, no spring/bounce):
   - SessionDetailView exercise list: `.animation` on the rendered entries / insertion transition.
   - List insert/remove where cheap (Coach Roster client cards, SessionDetail entries).
   - Key state reveal: recovery score / dashboard hero number — short opacity/scale-free fade.
   Honor `@Environment(\.accessibilityReduceMotion)` where cheap. Prefer FEWER high-signal
   transitions; hold back anything that risks feeling decorative and note it for human review.
   Motion must NOT introduce corners/shadows/fonts/accent/color/off-grid violations.
</task>

BUILD GATE after Part 2. Then run FULL INVENTORY §5 regression gate (rules 1-7).

## Success Criteria
- Each of the 5 flat rows now has one dominant emphasis tier (Font.Tokens only).
- Motion is minimal-functional, reduce-motion-aware, off-brand-safe.
- xcodebuild BUILD SUCCEEDED after each part.
- Full regression gate rules 1-7 pass (only justified PDFKit/hairline exceptions).

## Output
- 37-SUMMARY.md
- Commits: `feat(37): hierarchy emphasis tiers`, `feat(37): motion polish`, `docs(37): summary`
