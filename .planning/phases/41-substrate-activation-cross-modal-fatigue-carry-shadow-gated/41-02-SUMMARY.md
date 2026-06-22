---
phase: 41-substrate-activation-cross-modal-fatigue-carry-shadow-gated
plan: 02
subsystem: algorithm-engine
tags: [cross-modal-fatigue, interference-effect, sRPE, per-region-load, swift, pure-engine, tdd, xctest]

# Dependency graph
requires:
  - phase: 27-strength-load-substrate
    provides: "StrengthLoadEngine.perMuscleStrengthLoad/.perRegion + perMuscleElevation deadband+saturating shape + Constants windows"
  - phase: foundational
    provides: "WorkloadCalculator.srpeLoad, MuscleGroup.region taxonomy, WorkoutSession model, SportType/MuscleRegion enums"
provides:
  - "CrossModalFatigueEngine — pure deterministic struct producing directional, region-resolved cross-modal fatigue carry"
  - "Per-region decayed carry, above-personal-normal elevation, saturating-concave penalty, multiplicative systemic combine"
  - "CrossModalResult.exerciseAdjustment(forRegion:) — the per-exercise multiplicative nudge the Phase 43 verdict will consume once shadow-validated"
  - "Glass-box dominantReason string (built, not surfaced this phase)"
affects: [41-03-shadow-validation-gate, 43-verdict-engine, 44-verdict-ui, 45-measurement]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Pure engine convention reuse: static methods, Foundation-only, dateless-by-injection (asOf/calendar), no SwiftData/HealthKit"
    - "Endurance/conditioning sRPE regionalized by sportType β-map into MuscleRegion (the one genuinely new primitive)"
    - "Decay for carry magnitude, RAW un-decayed per-day load for personal-baseline elevation (keeps steady-state ratio ≈ 1)"
    - "Anchor + saturating concave modifier maxPenalty·(1−e^(−k·E)) — anti-linear-stacking by construction"

key-files:
  created:
    - "WorkloadApp/Services/CrossModalFatigueEngine.swift"
    - "WorkloadAppTests/CrossModalFatigueEngineTests.swift"
  modified:
    - "workload management/workload management.xcodeproj/project.pbxproj"

key-decisions:
  - "Elevation baseline uses RAW (un-decayed) per-day regional load on exactly-partitioned acute[0,7)/chronic-exclusive[7,28) windows so a steady-state athlete gets ratio≈1 → elevation 0; decay applies only to carry magnitude"
  - "fullBody planned exercise uses the MAX region elevation (dominant loaded region — does not spare itself)"
  - "Registered the new engine file via 4 explicit pbxproj entries — the MAIN APP TARGET is NOT a file-system-synchronized group (only WorkloadAppTests + ScreenshotTests are synced)"
  - "β-maps, τ, k, maxPenalty, systemicMin all documented in-source as HEURISTIC priors to be shadow-calibrated; reused StrengthLoadEngine.Constants.elevationDeadband + windows for one coherent baseline"

patterns-established:
  - "Cross-modal carry = Σ(srpeLoad·β_region·decay(Δdays)) + StrengthLoadEngine.perRegion over the acute window"
  - "Per-exercise adjustment = systemicFactor·(1 − regionPenalty(E_region)), multiplicative not additive"

requirements-completed: [ACT-02]

# Metrics
duration: 14min
completed: 2026-06-13
---

# Phase 41 Plan 02: CrossModalFatigueEngine Summary

**Directional, region-resolved cross-modal fatigue carry — a hard run penalizes today's squat (legs ~−9%) but spares today's bench (chest ~0%) — via sRPE×sportType→region β-maps, personal-baseline elevation, and a saturating-concave anti-linear-stacking penalty combined multiplicatively with systemic readiness. Pure deterministic engine, built DARK, 22/22 unit tests green.**

## Performance

- **Duration:** 14 min
- **Started:** 2026-06-13T10:40:09Z
- **Completed:** 2026-06-13T10:54:33Z
- **Tasks:** 1 TDD feature (RED → GREEN)
- **Files modified:** 3 (2 created, 1 pbxproj)

## Accomplishments
- Built `CrossModalFatigueEngine` — the one genuinely new v2.0 engine — as a pure, deterministic, Foundation-only struct with static methods, reusing the existing per-region strength substrate and elevation shape (no reinvention).
- Implemented the **run-hits-squat-not-bench** behaviour as an emergent property of the region kernel: legs get a meaningful penalty, chest is near-zero (only the neutral systemic factor) — observable directly in engine output.
- Anti-linear-stacking by construction: a concave saturating modifier `maxPenalty·(1−e^(−k·E))`, bounded by the cap, proven `penalty(E) < 2·penalty(E/2)`.
- Personal normalization: a habitual hard-runner (acute ≈ chronic regional carry) gets zero leg penalty via the reused deadband — only above-personal-normal carry counts.
- 22 unit tests covering regionalization, the headline asymmetry, anti-linear-stacking, decay, normalization, multiplicative systemic combine, determinism, degenerate inputs, fullBody, glass-box reason, and the no-injury-prediction copy guard — all pass on the known-alive simulator.

## The cross-modal formula (as implemented)

Per region `r`, over the acute window `[0, 7)` days:

```
# Carry magnitude (decays with recency)
CF_r = Σ_{non-strength sessions in window} ( srpeLoad(session) · β_region(sport, r) · exp(−Δdays / τ_r) )
     + StrengthLoadEngine.perRegion[r]          # heavy squat day also accrues leg carry

# Personal-normal elevation (RAW un-decayed per-day load, acute vs chronic-exclusive [7,28))
E_r = perMuscleElevation( acutePerDay_r , chronicPerDay_r )    # deadband 0.20, clamp 0…1; 0 if no chronic baseline

# Anchor + saturating concave modifier (anti-linear-stacking, bounded)
regionPenalty(E) = maxPenalty · (1 − exp(−k · E))              # maxPenalty 0.10, k 2.0

# Per-exercise multiplicative combine
systemicFactor(readiness) = systemicMin + (1 − systemicMin)·(readiness/100)   # readiness 0→0.85, 100→1.0
exerciseAdjustment(r) = systemicFactor · (1 − regionPenalty(E_r))             # fullBody uses max_r E_r
```

**β-maps (HEURISTIC priors):** running→legs 1.0; cycling→legs 0.7; swimming→{back 0.6, shoulders 0.6}; crossfit/teamSport→{legs 0.6, back 0.4, shoulders 0.3, core 0.3}; custom→fullBody 0.5; lifting→handled by StrengthLoadEngine.perRegion (empty here). A region absent from a sport's map contributes ~0 carry (e.g. running ⇒ chest absent ⇒ chest carry 0 — the asymmetry).

**τ (HEURISTIC):** legs 2.0d (slower eccentric recovery), upper 1.5d.

Worked example (run yesterday rpe 9 / 60min, light prior running): `E_legs` saturates to 1.0 → `regionPenalty ≈ 0.0865` → squat adjustment ≈ 0.913 (~−9%); chest `E=0` → adjustment 1.0. Magnitude is explicitly documented in-source as a **shadow-tuned heuristic**, never a precise scientific claim, never an injury prediction.

## Task Commits

TDD feature — RED then GREEN:

1. **RED: failing tests** - `6d2e4c6` (test) — full suite referencing the not-yet-existing engine; confirmed `cannot find 'CrossModalFatigueEngine' in scope` (build-for-testing FAILED).
2. **GREEN: engine implementation** - `fbc5d25` (feat) — engine + pbxproj registration; TEST SUCCEEDED 22/22, app BUILD SUCCEEDED.

No REFACTOR commit needed — implementation was clean and minimal at GREEN.

**Plan metadata:** (final docs commit) — this SUMMARY + STATE/ROADMAP/REQUIREMENTS updates.

## Files Created/Modified
- `WorkloadApp/Services/CrossModalFatigueEngine.swift` — the pure engine (Constants, regionCarry, regionElevation, regionPenalty, systemicFactor, compute, CrossModalResult, dominantReason).
- `WorkloadAppTests/CrossModalFatigueEngineTests.swift` — 22 deterministic unit tests (fixed UTC anchor + calendar, in-memory session builders).
- `workload management/workload management.xcodeproj/project.pbxproj` — 4 entries registering the engine into the app target's Sources.

## Decisions Made
- **Decay vs baseline split:** carry magnitude is decayed (recency matters), but the personal-baseline elevation comparison uses RAW un-decayed per-day load on the exactly-partitioned StrengthLoadEngine windows — this is what makes a steady-state athlete's acute/chronic ratio ≈ 1 → elevation 0 (the test `test_steadyStateRunner_noLegPenalty` would otherwise fail under decay weighting).
- **fullBody = max region elevation:** a fullBody planned exercise reflects the dominant loaded region rather than averaging itself to near-neutral.
- Reused `StrengthLoadEngine.Constants.elevationDeadband` and the acute/chronic window spans so the cross-modal baseline is coherent with the strength substrate, not a parallel re-derivation.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Registered the engine in the Xcode project file (pbxproj)**
- **Found during:** GREEN gate (first test run after writing the engine)
- **Issue:** The plan assumed the file-system-synchronized group would auto-discover the new engine. Investigation showed only `WorkloadAppTests` and `ScreenshotTests` are `PBXFileSystemSynchronizedRootGroup`s; the **main app target lists every `.swift` file individually**. Without registration, tests failed with `cannot find 'CrossModalFatigueEngine' in scope`.
- **Fix:** Added the 4 standard pbxproj entries (PBXBuildFile, PBXFileReference, group children, Sources build phase) mirroring `StrengthLoadEngine.swift`, with a unique unused ID prefix `EE4102`.
- **Files modified:** `workload management/workload management.xcodeproj/project.pbxproj`
- **Verification:** TEST SUCCEEDED (22/22), app BUILD SUCCEEDED.
- **Committed in:** `fbc5d25` (GREEN commit)

**2. [Rule 1 - Bug] Reworded a doc comment to satisfy the literal injury-prediction grep guard**
- **Found during:** GREEN gate purity audit
- **Issue:** The honest-framing doc comment originally contained the literal substring "injury prediction" ("NEVER an injury prediction"), which the plan's `grep -ri "injury prediction"` verification requires to return nothing.
- **Fix:** Reworded to "It NEVER forecasts harm to the body..." preserving the honest framing without the banned literal substring.
- **Files modified:** `WorkloadApp/Services/CrossModalFatigueEngine.swift`
- **Verification:** `grep -ri "injury prediction"` returns empty; the runtime copy guard test passes.
- **Committed in:** `fbc5d25` (GREEN commit)

---

**Total deviations:** 2 auto-fixed (1 blocking, 1 bug)
**Impact on plan:** Both auto-fixes were necessary to make the TDD cycle actually run and to satisfy the plan's explicit verification gates. No scope creep — engine logic matches the plan formula exactly.

## TDD Gate Compliance
- RED gate: `6d2e4c6` `test(...)` — verified the suite fails to compile against the missing engine (genuine RED, not a passing test).
- GREEN gate: `fbc5d25` `feat(...)` — 22/22 tests pass; no test passed unexpectedly during RED.
- REFACTOR: none required.

## Issues Encountered
- xcodebuild's newer per-suite reporting does not always emit a single "Executed N tests" line; confirmation was taken from `** TEST SUCCEEDED **` plus the 22 individual per-test "passed" lines.

## Known Stubs
None — the engine is fully implemented and tested. It is intentionally DARK (not wired to any pipeline/surface/shadow log); that wiring is Plan 03 (the shadow-validation gate), which is the stated scope fence, not a stub.

## User Setup Required
None — no external service configuration required.

## Next Phase Readiness
- `CrossModalFatigueEngine` is ready to be run DARK through the existing ShadowMetrics harness as a new prediction arm (Plan 03 — the shadow-validation gate). `CrossModalResult.exerciseAdjustment(forRegion:)` is the consumable per-exercise factor; `dominantReason` is the glass-box "why".
- Magnitude constants (β, τ, k, maxPenalty) are flagged in-source as heuristic priors awaiting shadow calibration against the user's own next-day soreness — Plan 03 / Phase 45 measurement work.
- Scope fence held: nothing in this plan drives any user-facing number; the engine is isolated and tested only.

## Self-Check: PASSED
- FOUND: WorkloadApp/Services/CrossModalFatigueEngine.swift
- FOUND: WorkloadAppTests/CrossModalFatigueEngineTests.swift
- FOUND: .planning/phases/41-.../41-02-SUMMARY.md
- FOUND commit: 6d2e4c6 (RED)
- FOUND commit: fbc5d25 (GREEN)
- pbxproj: 4 CrossModalFatigueEngine.swift entries registered in app target

---
*Phase: 41-substrate-activation-cross-modal-fatigue-carry-shadow-gated*
*Completed: 2026-06-13*
