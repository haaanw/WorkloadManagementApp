---
phase: 28-readiness-fusion-explainable-decisions
plan: overview
type: overview
milestone: v1.6 Algorithm Moat (Personal Readiness v1)
waves: 4
serial: true
autonomous: false   # Wave 4 has a human visual-review checkpoint
requirements: [PRS-28-01, PRS-28-02, PRS-28-03, PRS-28-04, PRS-28-05, PRS-28-06]
hard_invariants:
  - "Master flag PRSActivation.isEnabled defaults FALSE; new Readiness path + AutoregulationEngine swap behind it."
  - "Live recovery score byte-unchanged; RecoveryScoreEngine untouched; BaselineTierFenceTests stays green."
  - "Predicting arm (PRS-v1) is SHADOW ONLY; never reaches live recommendation with flag off."
  - "With flag off, live user-facing recommendation BYTE-IDENTICAL (machine-enforced golden test)."
  - "No new SYNCED SwiftData fields; any new state local-only/never-synced."
  - "Atomic commits to main; no branch; no push; no live-default flip."
  - "Product name Tuwa only; DESIGN.md for all UI; visuals FLAGGED for human review (not final)."
  - "Run FULL WorkloadAppTests after any shared-type/enum change. Discard .xcstrings churn."
  - "SERIAL waves; no parallel executors."
---

<objective>
Add the predicting shadow arm (PRS-v1) of the algorithm moat: a fixed sign-constrained glass-box logistic fusion → Readiness scalar (separate from Strain-Risk), a decision-level explainability upgrade, an AutoregulationEngine matrix swap (recovery×ACWR → readiness×strain-risk) with ACWR demoted to a context label, dual-run "method updated" messaging, a recommendation that adjusts a real logged/planned workout, and the PRS-v1 arm wired into the shadow harness.

Purpose: Complete the Personal Readiness v1 decision layer on top of the Phase 25/26/27 substrate, ready for Phase 29 shadow validation + activation gates — WITHOUT changing any live behavior (everything gated OFF, shadow-only, byte-identical with flag off).

Output: ReadinessFusionEngine + ReadinessZone, PRSActivation flag, AutoregulationEngine flagged swap, ReasoningEngine decision-explanation, dual-run copy surface (flagged), PRS shadow arm in ShadowPredictor/CyclePredictionLog/ShadowAnalyticsService, full guard test battery.
</objective>

<context>
@.planning/research/algorithm-moat-design.md
@.planning/research/competitive-algorithm-analysis.md
@.planning/phases/28-readiness-fusion-explainable-decisions/28-RESEARCH.md
@WorkloadApp/Services/AutoregulationEngine.swift
@WorkloadApp/Services/ReasoningEngine.swift
@WorkloadApp/Services/StrainRiskEngine.swift
@WorkloadApp/Services/BaselineEngine.swift
@WorkloadApp/Services/ShadowPredictor.swift
@WorkloadApp/Services/ShadowAnalyticsService.swift
@WorkloadApp/Models/CyclePredictionLog.swift
@CLAUDE.md
@DESIGN.md
</context>

<wave_structure>

## SERIAL execution — one wave at a time. Do NOT parallelize.

| Wave | Plan | Concern | Autonomous | Depends on |
|------|------|---------|------------|------------|
| 1 | 28-01-PLAN.md | `PRSActivation` flag (default false) + `ReadinessZone` enum + pure `ReadinessFusionEngine` (fixed sign-constrained logistic) + numerics/sign/zone oracle tests + tier-fence + full suite | yes | — |
| 2 | 28-02-PLAN.md | `AutoregulationEngine` flagged swap (readiness×strain-risk; ACWR→context label) + decision-explanation upgrade to `ReasoningEngine` + byte-identical-with-flag-off golden test + isolation grep + no-prediction-copy grep + full suite | yes | Wave 1 |
| 3 | 28-03-PLAN.md | PRS-v1 predicting arm in shadow harness (`ShadowPredictor` third prediction + `CyclePredictionLog` local-only `*PRS` columns + `ShadowAnalyticsService` PRS metrics) + sync-omission test + date-contract test + full suite | yes | Wave 2 |
| 4 | 28-04-PLAN.md | Dual-run "method updated" copy surface + "adjust a real planned/logged workout" wiring (flagged, invisible with flag off) + DESIGN.md compliance + human visual-review checkpoint | no (human-verify) | Wave 3 |

</wave_structure>

<must_haves>
truths:
  - "With PRSActivation.isEnabled == false, AutoregulationEngine recommendation is byte-identical to pre-Phase-28 (golden test passes)."
  - "Live recovery score and BaselineTierFenceTests are unchanged after all four waves."
  - "ReadinessFusionEngine produces a Readiness scalar from fixed sign-constrained coefficients matching a hand-computed oracle."
  - "When the flag is on, the recommendation is keyed on (readinessZone × strainRiskZone) and ACWR appears only as a context label."
  - "ReasoningEngine can explain the DECISION (factors + confidence), not only the recovery score."
  - "The PRS-v1 arm logs predictions in the shadow harness with correct predictionDate/targetDate/cutoff/window against raw self-report labels."
  - "No new SwiftData field added to PRS shadow logging is synced (sync-omission test passes)."
  - "No user-facing copy says 'injury prediction' (no-prediction-copy grep guard passes)."
artifacts:
  - path: "WorkloadApp/Services/ReadinessFusionEngine.swift"
    provides: "Pure fixed glass-box logistic fusion → Readiness + ReadinessZone + factors + confidence"
  - path: "WorkloadApp/Models/Enums.swift"
    provides: "ReadinessZone enum (added)"
  - path: "WorkloadApp/Services/PRSActivation.swift"
    provides: "Master feature flag, default false"
  - path: "WorkloadApp/Services/AutoregulationEngine.swift"
    provides: "Flagged readiness×strain-risk recommendation path; legacy path untouched"
  - path: "WorkloadApp/Services/ReasoningEngine.swift"
    provides: "Additive decision-explanation entry point"
  - path: "WorkloadApp/Services/ShadowPredictor.swift"
    provides: "PRS-v1 third prediction arm (shadow only)"
key_links:
  - from: "AutoregulationEngine flagged path"
    to: "ReadinessFusionEngine + StrainRiskEngine"
    via: "(readinessZone × strainRiskZone) matrix"
  - from: "ShadowPredictor"
    to: "CyclePredictionLog *PRS columns"
    via: "prequential predictionDate/targetDate write (local-only)"
</must_haves>

<verification>
- Full `WorkloadAppTests` suite green after EACH wave (via real `xcodebuild`, not SourceKit).
- `BaselineTierFenceTests` green after each wave.
- Byte-identical-with-flag-off golden test green (Wave 2+).
- ReadinessFusionEngine oracle + sign-constraint + zone-boundary tests green (Wave 1+).
- Isolation grep guard: new Readiness path not referenced by live flag-off call sites.
- No-prediction-copy grep guard green.
- Sync-omission test green for any new CyclePredictionLog column (Wave 3).
- Human visual-review checkpoint approved (Wave 4).
</verification>

<success_criteria>
All four waves committed atomically to main (no push). Flag defaults false. Live recovery score + live recommendation byte-unchanged with flag off. PRS-v1 arm logging in shadow harness. Phase 28 ready for Phase 29 (shadow validation + activation gates).
</success_criteria>

<output>
Create `.planning/phases/28-readiness-fusion-explainable-decisions/28-VERIFICATION.md` after Wave 4, plus per-wave SUMMARY entries.
</output>
