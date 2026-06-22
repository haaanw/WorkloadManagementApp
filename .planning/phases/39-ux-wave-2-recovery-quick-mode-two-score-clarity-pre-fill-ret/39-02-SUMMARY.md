---
phase: 39-ux-wave-2-recovery-quick-mode-two-score-clarity-pre-fill-ret
plan: 02
subsystem: recovery
tags: [ux, recovery, two-score-clarity, honest-blend, i18n]
requires:
  - WellnessCheckIn.wellnessScore (computed, read-only)
  - RecoveryScoreCard (RecoveryView.swift)
  - RecoveryView.todayCheckIn / todayRecovery accessors
provides:
  - RecoveryScoreCard honest blend subtitle (recovery.blend.subtitle)
  - Subordinate "how you feel" labeled element on Recovery tab (recovery.feel.label)
  - Low-emphasis why-these-differ note (recovery.feel.note)
  - Localizable.xcstrings recovery.blend.subtitle / recovery.feel.label / recovery.feel.note (en + zh-Hans)
affects:
  - WorkloadApp/Views/Recovery/RecoveryView.swift
  - WorkloadApp/Resources/Localizable.xcstrings
tech-stack:
  added: []
  patterns:
    - "Read-only wellnessScore threaded as optional RecoveryScoreCard parameter (no view-side fusion)"
    - "Subordinate label-tier row reusing the existing 0.5pt divider + HStack label/value pattern (no second ZoneBadge hero)"
key-files:
  created: []
  modified:
    - WorkloadApp/Views/Recovery/RecoveryView.swift
    - WorkloadApp/Resources/Localizable.xcstrings
decisions:
  - "HONEST BLEND supersedes a naive 'two independent scores' reading (CONTEXT.md D-B.2): the composite recoveryScore already blends HRV/RHR/sleep with wellness at 25%; copy is honest about this coupling and the how-you-feel score is framed as the subjective part alone, NOT an independent rival."
  - "wellnessScore threaded into RecoveryScoreCard as optional param (vs rendering a sibling row in the body) so the how-you-feel element + why-differ note live inside the composite card section, reinforcing they are facets of one score."
  - "Why-differ note uses Font.Tokens.micro + text3 (lowest emphasis) to stay an info line, not a hero."
metrics:
  duration: ~6min
  completed: 2026-06-02
---

# Phase 39 Plan 02: Two-Score Clarity (Honest Blend) Summary

Reframes the Recovery tab's two near-identical 0-100 scores honestly: the composite Recovery Score card now carries a blend subtitle ("wearable signals + how you feel"), today's subjective wellness score is surfaced as a distinct, visually-subordinate "How you feel" labeled row inside the same card, and a low-emphasis "why these differ" note explains that recovery = wearable + how-you-feel combined while this score = the how-you-feel part alone. Labeling/UX only — no engine, schema, fusion, or new score math; exactly one ZoneBadge remains.

## What Was Built

- **Task 1 — RecoveryView.swift (`ba14f7e`)**: three labeling-only edits.
  1. Blend subtitle `recovery.blend.subtitle` rendered directly under the `recovery.section.recoveryScore` header, styled `Font.Tokens.label` + `ColorTokens.text2`, `.fixedSize(vertical)` + leading frame so it wraps. Shown whenever the card renders (placed before the populated/empty branch split).
  2. New optional `wellnessScore: Double? = nil` parameter on `RecoveryScoreCard`, wired at the call site from `todayCheckIn?.wellnessScore`. When non-nil, a 0.5pt divider + an HStack row (`recovery.feel.label` text2/label leading, `Text("\(Int(wellnessScore))/100")` text1/label/monospacedDigit trailing) renders inside the card below the component rows — subordinate label tier, no ZoneBadge, no `.cardStyle` hero, no accent.
  3. Why-differ note `recovery.feel.note` styled `Font.Tokens.micro` + `ColorTokens.text3` (lowest emphasis), wrapping, adjacent to the how-you-feel row.
- **Task 2 — Localizable.xcstrings (`8c568d0`)**: added `recovery.blend.subtitle`, `recovery.feel.label`, `recovery.feel.note` in the `recovery.*` region, each with en + zh-Hans `stringUnit` (state `translated`), matching the existing entry shape. Catalog valid JSON. Build verified green.

## Honest-Blend Framing Note (for downstream verifier)

Per CONTEXT.md D-B.2, the **honest blend** framing intentionally supersedes a naive "two independent scores" reading. The top Recovery Score is ALREADY a composite (RecoveryScoreEngine blends HRV/RHR/sleep ~75% + subjective wellness 25%); the how-you-feel score is the subjective part alone. Copy reflects this coupling and deliberately does NOT present the two as independent rivals. Do not flag the absence of a second 0-100 zone-badge hero or the "combined" wording as off-spec — both are required by the locked decision.

## Verification

- `grep` on RecoveryView.swift: `recovery.blend.subtitle`, `recovery.feel.label`, `recovery.feel.note`, `wellnessScore` all present.
- Regression gate on RecoveryView.swift: 0 `ColorTokens.accent`, 0 `RoundedRectangle`/`.cornerRadius`, 0 `.shadow`, 0 `.system(`, exactly **1** `ZoneBadge(` (the composite hero). Spacing via `Spacing.*` / existing 0.5pt divider; fonts via `Font.Tokens.*`.
- `RecoveryScoreEngine.swift`: no git diff (untouched). `WellnessCheckIn` unchanged — `wellnessScore` read-only, no recomputation in the view.
- `Localizable.xcstrings`: `python3 json.load` succeeds; all three keys carry en + zh-Hans translated values.
- `xcodebuild ... -destination "platform=iOS Simulator,id=CAF84E71-BB64-491D-87C8-875A0143B26D" build` → **BUILD SUCCEEDED**.

## Behavior Confirmed (logic review)

- Today's check-in present: blend subtitle + subordinate "How you feel" N/100 row + why-differ note all render inside the composite card; still exactly one ZoneBadge.
- No today's check-in: `wellnessScore` is nil → how-you-feel row + note omitted; MorningCheckInPrompt (existing) prompts to add one; blend subtitle still shows.
- Empty recovery branch: blend subtitle renders above the empty body (subtitle placed before the if-let split).

## Deviations from Plan

None - plan executed exactly as written. (Plan offered a choice of threading a parameter vs. rendering a sibling row in the body; chose the parameter approach, which the plan listed as the preferred option.)

## Self-Check: PASSED

- FOUND: WorkloadApp/Views/Recovery/RecoveryView.swift (recovery.blend.subtitle, recovery.feel.label, recovery.feel.note, wellnessScore param)
- FOUND: WorkloadApp/Resources/Localizable.xcstrings (all 3 keys, en + zh-Hans)
- FOUND commits: ba14f7e, 8c568d0
