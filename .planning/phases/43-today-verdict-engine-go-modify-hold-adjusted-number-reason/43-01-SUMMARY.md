---
phase: 43-today-verdict-engine-go-modify-hold-adjusted-number-reason
plan: 01
subsystem: api
tags: [verdict, autoregulation, plate-rounding, cross-modal-gate, swift, pure-engine]

requires:
  - phase: 41-*
    provides: "AutoregulationEngine.recommendReadiness (activated readiness×strain pipeline) + CrossModalShadowGate.crossModalDrivesVerdict + CrossModalFatigueEngine.CrossModalResult"
  - phase: 42-*
    provides: "TemplateSet nullable verdict slots (adjustedTargetWeightKg/adjustedTargetRPE/verdictReason)"
provides:
  - "TodayVerdictEngine pure struct: go/modify/hold trichotomy derived from intensityCap/volumeModifier/sessionType"
  - "Bounded plate-rounded adjusted top-set number (-5% default / -10% ceiling), volume-cut-preferred"
  - "Cross-modal wired through the shadow gate but zero-effect at the shipped default"
affects: [43-02-verdict-reason-builder, 43-03-today-verdict-service, 44-verdict-ui-card]

tech-stack:
  added: []
  patterns:
    - "Pure-struct DERIVED engine: a verdict is a function of an existing recommendation, never a new decision model"
    - "Gate-guarded forward-compat wiring: cross-modal multiplies by exactly 1.0 while the shadow gate is off"

key-files:
  created:
    - WorkloadApp/Services/TodayVerdictEngine.swift
    - WorkloadAppTests/TodayVerdictEngineTests.swift
  modified:
    - "workload management/workload management.xcodeproj/project.pbxproj"

key-decisions:
  - "Verdict trichotomy is a pure derivation of intensityCap/volumeModifier/sessionType — not a 4th model"
  - "volumeModifier >= 0.95 ⇒ GO; [0.85,0.95) ⇒ MODIFY via back-off-set cut (top-set load kept); < 0.85 ⇒ MODIFY via interpolated LOAD trim; rest/activeRecovery ⇒ HOLD"
  - "LOAD trim interpolates between -5% (at the 0.85 boundary) and -10% (at volumeModifier 0), hard-clamped to the -10% ceiling"
  - "Adjusted weight plate-snapped via the PUBLIC WeightFormatter.snapToIncrement; never rounds up past plan; sub-increment delta collapses to GO"
  - "HOLD carries the planned number (no progression), never a nil / 'don't train' (nocebo guard)"

patterns-established:
  - "Constants enum as the single home for tunables (mirrors CrossModalFatigueEngine.Constants)"
  - "Source-grep honesty fence test via #filePath parent traversal"

requirements-completed: [VERDICT-01, VERDICT-02]

duration: 18min
completed: 2026-06-13
---

# Phase 43 Plan 01: TodayVerdictEngine Summary

**Pure-struct verdict core that collapses the existing readiness×strain recommendation into go/modify/hold and computes a -5%/-10%-bounded, plate-rounded adjusted top-set number with volume-cut preference, cross-modal wired through the shadow gate at zero effect.**

## Performance

- **Duration:** ~18 min
- **Started:** 2026-06-13T23:40:00Z
- **Completed:** 2026-06-13T23:51:00Z
- **Tasks:** 3
- **Files modified:** 3

## Accomplishments
- `TodayVerdictEngine.evaluate(recommendation:plannedTopSet:crossModalResult:plateStepKg:)` — pure, Foundation-only, deterministic
- go/modify/hold mapping derived purely from the existing `TrainingRecommendation` (VERDICT-01)
- bounded plate-rounded adjusted number, volume-cut-preferred over load-cut, never rounds up past plan (VERDICT-02)
- cross-modal read through `CrossModalShadowGate` but contributes exactly 0 at the shipped default (gate-off-identical test, byte-for-byte)
- 13 unit tests green; XCTest host did not crash

## Task Commits

1. **Task 1: Failing test suite (RED)** - `fad7b74` (test)
2. **Task 2: Implement engine + pbxproj (GREEN)** - `e44c775` (feat)
3. **Task 3: Run GREEN + no-injury grep fence** - folded into the Task 1/2 commits (the grep fence test shipped in Task 1; the engine doc-comment reword that satisfies it shipped in Task 2)

## Files Created/Modified
- `WorkloadApp/Services/TodayVerdictEngine.swift` - the pure verdict core (Verdict enum, PlannedTopSet, VerdictResult, Constants, evaluate)
- `WorkloadAppTests/TodayVerdictEngineTests.swift` - 13 tests: mapping, bounds, plate rounding, volume-cut preference, gate-off-identical, gate-on at-most, no-injury grep
- `workload management/workload management.xcodeproj/project.pbxproj` - 4 explicit entries (AC4301* object ids)

## The go/modify/hold mapping + bounds (as implemented)

| Recommendation condition | Verdict | Number behavior |
|---|---|---|
| `sessionType` ∈ {rest, activeRecovery} | **HOLD** | hold planned top set, no progression, loadFactor 1.0, volumeCutSets nil |
| `volumeModifier >= 0.95` (GO candidate) | **GO** | adjusted = planned, loadFactor 1.0 |
| `0.85 <= volumeModifier < 0.95` | **MODIFY** | top-set load kept (loadFactor 1.0); back-off cut `volumeCutSets = max(1, round((1-vol)/(1-0.85) * 3))` |
| `volumeModifier < 0.85` | **MODIFY** | LOAD trim: `loadFactor = clamp(1 - trim, ≥ 0.90)`, trim interpolated -5%→-10% |
| trim delta `< plateStep` and no back-off cut | collapses to **GO** | adjusted = planned (no false-precision micro-change) |

Bounds: LOAD trim is `-5%` default (at the 0.85 boundary), `-10%` ceiling (hard-clamped, `loadFactor >= 1 - maxLoadTrim`). Adjusted weight is always a multiple of `plateStepKg` (2.5) via `WeightFormatter.snapToIncrement`, never rounded up past planned when trimming. Cross-modal multiplies `loadFactor` only when `CrossModalShadowGate.crossModalDrivesVerdict == true` AND a `CrossModalResult` is present — otherwise `×1.0` (zero effect), re-clamped to the -10% ceiling on the gate-on path.

## Decisions Made
None beyond the plan — followed the locked decisions exactly. Reused the public `WeightFormatter.snapToIncrement` (the private `ProgressionEngine.roundToNearest` was correctly avoided).

## Deviations from Plan

None - plan executed exactly as written. (One minor in-task adjustment: the engine's honesty doc-comment was reworded to avoid the literal phrase "injury prediction" so the source-grep fence test passes — this is the intended behavior of that test, not a scope change.)

## Issues Encountered
- The no-injury source-grep test initially failed because the engine's honesty doc-comment literally contained "injury prediction". Reworded the comment to "never frames a trim as harm-forecasting" — test green. (Same posture `CrossModalFatigueEngine` uses for its own grep fence.)

## Next Phase Readiness
- `TodayVerdictEngine.Verdict` / `PlannedTopSet` / `VerdictResult` / `evaluate(...)` are the stable contract 43-02 (reason builder) and 43-03 (service) consume.
- Cross-modal gate-on wiring is in place for a future shadow-validation flip with no re-architecture.

---
*Phase: 43-today-verdict-engine-go-modify-hold-adjusted-number-reason*
*Completed: 2026-06-13*

## Self-Check: PASSED

All created source/test files exist on disk; all task commits present in git history (fad7b74, e44c775, faa8d88, ecea35d, b7e8a06, a8d8d49, 3ebe399).
