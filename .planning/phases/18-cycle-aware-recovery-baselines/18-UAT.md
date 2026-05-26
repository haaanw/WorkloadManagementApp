---
status: testing
phase: 18-cycle-aware-recovery-baselines
source: [18-01-SUMMARY.md, 18-02-SUMMARY.md]
started: 2026-05-26T00:00:00Z
updated: 2026-05-26T00:00:00Z
---

## Current Test
<!-- OVERWRITE each test - shows where we are -->

number: 1
name: Dashboard cycle-tracking prompt copy
expected: |
  On the Dashboard, the cycle-tracking onboarding card shows the body copy
  "Track your menstrual cycle in Apple Health to get cycle-aware recovery
  insights. Tuwa reads existing data from apps like Clue, Flo, or Apple Cycle
  Tracking — no manual re-entry needed."
  The brand name MUST read "Tuwa" (not "Faros").
awaiting: user response

## Tests

### 1. Dashboard cycle-tracking prompt copy
expected: |
  Dashboard cycle-tracking onboarding card body copy reads "Tuwa reads
  existing data from apps like Clue, Flo, or Apple Cycle Tracking — no
  manual re-entry needed." Brand name MUST be "Tuwa" (Faros fix from WR-01).
result: pending

### 2. Recovery card 7-day fallback for athletes without cycle data
expected: |
  Open the app as an athlete with NO menstrual cycle data in HealthKit (or
  with hormonal-contraceptive flag set, or fewer than 3 logged cycles).
  Dashboard recovery card renders normally with a recovery score. Behavior
  is byte-identical to pre-Phase-18 (the same-phase path is gated off; the
  7-day rolling baseline drives HRV/RHR scoring as before). No crash, no
  visible regression.
result: pending

## Summary

total: 2
passed: 0
issues: 0
pending: 2
skipped: 0
blocked: 0

## Gaps

[none yet]
