---
phase: 39-ux-wave-2-recovery-quick-mode-two-score-clarity-pre-fill-ret
plan: 01
subsystem: recovery
tags: [ux, recovery, morning-checkin, prefill, i18n]
requires:
  - RecoveryRepository.fetchTodayWellnessCheckIn
  - WellnessCheckIn model (sleepQuality/soreness/energy/stress/behaviorTags)
  - BehaviorTag (tagName, isActive)
provides:
  - RecoveryRepository.fetchLatestWellnessCheckIn (read-only latest-prior fetch)
  - MorningCheckInSheet pre-fill (sliders + active tags) + conditional prefill hint
  - Localizable.xcstrings morning.prefill.hint (en + zh-Hans)
affects:
  - WorkloadApp/Repositories/RecoveryRepository.swift
  - WorkloadApp/Views/Recovery/MorningCheckInSheet.swift
  - WorkloadApp/Resources/Localizable.xcstrings
tech-stack:
  added: []
  patterns:
    - "Mirror existing fetchLatestSnapshot reverse-sort descriptor shape for new wellness fetch"
    - "didSeed guard so .task re-fire never clobbers user edits"
key-files:
  created: []
  modified:
    - WorkloadApp/Repositories/RecoveryRepository.swift
    - WorkloadApp/Views/Recovery/MorningCheckInSheet.swift
    - WorkloadApp/Resources/Localizable.xcstrings
decisions:
  - "Today's-then-latest-prior precedence: fetchTodayWellnessCheckIn ?? fetchLatestWellnessCheckIn"
  - "Notes never carried forward (day-specific); notes field opens empty"
  - "First-ever check-in keeps default 3 sliders, isPrefilled=false, no hint"
metrics:
  duration: ~8min
  completed: 2026-06-02
---

# Phase 39 Plan 01: Recovery Quick-Mode Pre-fill Summary

Pre-fills MorningCheckInSheet sliders + active behavior tags from today's-then-latest-prior WellnessCheckIn via a new read-only RecoveryRepository fetch, so returning users edit only deltas; shows a subtle text3 prefill hint, never carries notes, and leaves the engine/schema untouched.

## What Was Built

- **Task 1 — `fetchLatestWellnessCheckIn(athlete:)`** in RecoveryRepository: returns the most recent `WellnessCheckIn` by `SortDescriptor(\.date, order: .reverse)`, with athlete-scoped `#Predicate` branch + unscoped branch, mirroring the existing `fetchLatestSnapshot` shape. Pure read — no `insert`/`save`, no schema change. Commit `f846229`.
- **Task 2 — MorningCheckInSheet pre-fill**: added `isPrefilled` + `didSeed` `@State`. New `seedFromPriorCheckIn()` runs in the existing `.task`, resolving source = `fetchTodayWellnessCheckIn ?? fetchLatestWellnessCheckIn`. On a found source it seeds `sleepQuality/soreness/energy/stress` and `selectedTags` (from `behaviorTags` where `isActive`, mapped to `tagName`), sets `isPrefilled = true`. `notes` is never assigned. `didSeed` guard ensures one-time seeding. A conditional `Text("morning.prefill.hint")` renders only when prefilled, styled `Font.Tokens.label` + `ColorTokens.text3`, `Spacing.sm` padding, placed under the heading before the first divider. Commit `454021e`.
- **Task 3 — Localization**: added `morning.prefill.hint` (en: "Prefilled from your last check-in — edit what changed"; zh-Hans: "已根据上次记录预填 — 仅修改有变化的项") in the `morning.*` region, valid JSON. Build verified green. Commit `0d19851`.

## Verification

- `xcodebuild ... -destination "platform=iOS Simulator,id=CAF84E71-BB64-491D-87C8-875A0143B26D" build` → **BUILD SUCCEEDED**.
- Regression gate on both edited Swift files: 0 `ColorTokens.accent`, no `RoundedRectangle`/`.cornerRadius`, no `.shadow`, no `.system(`, spacing via `Spacing.*`, fonts via `Font.Tokens.*` — clean.
- `RecoveryScoreEngine.swift` and `WellnessCheckIn.swift`: no git diff (untouched).
- `Localizable.xcstrings`: `python3 json.load` succeeds.
- New repo method: no `modelContext.insert`/`save`.

## Behavior Confirmed (logic review)

- Returning user (prior exists, none today): seeds from latest prior, hint shown, notes empty.
- Editing-today (today's exists): seeds from today's values (precedence).
- First-ever (no check-ins): sliders stay 3, `isPrefilled` false, no hint.
- `.task` re-fire: `didSeed` short-circuits — user edits preserved.

## Deviations from Plan

None - plan executed exactly as written.

## Self-Check: PASSED

- FOUND: WorkloadApp/Repositories/RecoveryRepository.swift (fetchLatestWellnessCheckIn)
- FOUND: WorkloadApp/Views/Recovery/MorningCheckInSheet.swift (isPrefilled, morning.prefill.hint)
- FOUND: WorkloadApp/Resources/Localizable.xcstrings (morning.prefill.hint)
- FOUND commits: f846229, 454021e, 0d19851
