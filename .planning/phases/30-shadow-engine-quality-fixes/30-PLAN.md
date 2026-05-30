---
phase: 30-shadow-engine-quality-fixes
plan: overview
type: overview
milestone: v1.6 Algorithm Moat (Personal Readiness v1)
waves: 4
serial: true
autonomous: true
requirements: [PRS-30-01, PRS-30-02, PRS-30-03, PRS-30-04, PRS-30-05, PRS-30-06]
hard_invariants:
  - "SHADOW/DISPLAY/FLAG-ON only. LIVE behavior byte-identical. BaselineTierFenceTests + AutoregulationFlagFenceTests + DualRunFlagFenceTests stay GREEN and are NOT edited."
  - "Do NOT touch RecoveryScoreEngine.computeBaseline or the flag-off AutoregulationEngine recommendation path."
  - "NO activation. PRSActivation + PRSMasterActivation stay default FALSE. No live default flipped."
  - "All changed value types stay local-only / never-synced. MuscleStrengthLoad gains fields but is a pure value type, absent from SyncService."
  - "These fixes intentionally CHANGE shadow OUTPUTS — re-derive the affected ENGINE/ORACLE tests to new CORRECT expected values; never weaken or touch the three live fence tests."
  - "Atomic commits directly to main; NO branch; NEVER push."
  - "Product name Tuwa only. Strain-Risk copy = load-tolerance / overreaching caution, NEVER injury prediction."
  - "Run the FULL WorkloadAppTests suite via REAL xcodebuild after Wave 1 (MuscleStrengthLoad field additions) and after every wave. Discard .xcstrings churn. SwiftKit 'cannot find type' agent diagnostics are stale — only xcodebuild proves green."
  - "SERIAL waves; one executor at a time; no self-branching."
---

<objective>
Fix the 6 shadow/display/flag-on quality findings from the Phase 27/28/29 adversarial + codex review, in 4 serial waves grouped by file so each shared-type change is paid once and downstream consumers re-derive against corrected upstream values. NONE of these reaches live behavior; all change shadow/display/flag-on OUTPUTS by design, and the corrected ENGINE/ORACLE tests are updated to the new correct expected values while the three live fence families stay untouched and green.

Purpose: clean the shadow Strain-Risk + readiness inputs so the eventual activation-gate evaluation (Phase 29) runs on correct data — soft-tissue/rest-debt counted once, strength visible inside monotony, honest acute-vs-chronic elevation, correct fractional-RPE hard-set classification, easy sets in coverage, and a flag-on first-time prescription that actually applies its volume reduction.

Output: corrected StrengthLoadEngine (Findings 3+4 + the MuscleStrengthLoad field additions that Finding 5 needs), LoadDistributionEngine (Finding 2 z-standardised unified series), StrainRiskEngine (Findings 1+5 consumption), PRSDualRunSurface (Finding 6), each with re-derived oracle tests and a per-wave full-suite green gate.
</objective>

<context>
@.planning/phases/30-shadow-engine-quality-fixes/30-RESEARCH.md
@.planning/ROADMAP.md
@CLAUDE.md
@WorkloadApp/Services/StrengthLoadEngine.swift
@WorkloadApp/Services/LoadDistributionEngine.swift
@WorkloadApp/Services/StrainRiskEngine.swift
@WorkloadApp/Services/FatigueIndexEngine.swift
@WorkloadApp/Services/PRSDualRunSurface.swift
@WorkloadApp/Models/PrescribedWorkout.swift
</context>

<wave_plan>

## Wave 1 — StrengthLoadEngine (Findings 3 + 4 + Finding-5 data capture)
Plan: `30-01-PLAN.md`. Single file `StrengthLoadEngine.swift` + `StrengthLoadEngineTests.swift`.
- Finding 4: Double-precision RIR comparison in `classify` so RPE 7.5 → 2.5 RIR → NOT hard (GA-30-D).
- Finding 3: chronic window EXCLUDES acute (chronic = days `acute..<chronic`), per-day normalised by the exclusive day count; `windowed` tightened to half-open `< days` to partition acute/chronic exactly; zero-chronic ⇒ elevation 0 + per-muscle `hasChronicBaseline=false` (GA-30-C).
- Finding 5 (DATA only): add `easyCount` to `MuscleStrengthLoad`, captured in `aggregateMuscle` (GA-30-E). Consumption happens in Wave 3.
- `MuscleStrengthLoad` gains `easyCount: Int` and `hasChronicBaseline: Bool` → every memberwise init (engine + StrainRiskEngineTests builder + PRSShadowArm builders if any) updated. **Full-suite xcodebuild gate (shared-type change).**

## Wave 2 — LoadDistributionEngine (Finding 2)
Plan: `30-02-PLAN.md`. Single file `LoadDistributionEngine.swift` + `LoadDistributionEngineTests.swift`. Depends on Wave 1 (reuses corrected `StrengthLoadEngine.classify`/`strainWeight`).
- Z-standardise the endurance-sRPE and strength-strain sub-series separately over the window, sum standardised values into the series fed to Foster monotony/strain (GA-30-B). Zero-variance stream contributes 0 (no NaN). Raw `dailyLoadSeries` keeps its meaning; standardisation is a separate path used only for monotony/strain.

## Wave 3 — StrainRiskEngine (Findings 1 + 5 consumption)
Plan: `30-03-PLAN.md`. Single file `StrainRiskEngine.swift` + `StrainRiskEngineTests.swift`. Depends on Waves 1+2 (consumes corrected `MuscleStrengthLoad.easyCount`/`hasChronicBaseline` + corrected monotony).
- Finding 1: subtract softTissue+restDebt from the fatigue composite fed to component 3 (compute "fatigue-excluding-softtissue-restdebt" from the exposed FatigueResult component fields), keep standalone comps 5 (+recurrence bonus) and 6 — each signal counted once (GA-30-A).
- Finding 5: coverage = `(hard+easy)/(hard+easy+unscored)`; discount confidence for muscles lacking a chronic baseline (GA-30-C/E).

## Wave 4 — PRSDualRunSurface (Finding 6)
Plan: `30-04-PLAN.md`. File `PRSDualRunSurface.swift` (+ a NON-fence test file). Independent of Waves 1-3 but run last (serial). Touches the flag-gated surface only.
- nil `targetVolume` → derive effective base (template-derived else neutral 1.0) so the volume modifier is applied not discarded; bump `updatedAt` via injected `now`; flag-OFF still returns nil + no-op FIRST (DualRunFlagFenceTests byte-identical) (GA-30-F). New coverage test in `PRSShadowArmTests.swift` / new `PRSDualRunSurfaceTests.swift`, NOT the fence.

</wave_plan>

<multi_source_coverage_audit>

| Source item | Type | Covered by |
|-------------|------|-----------|
| Finding 1 — StrainRisk soft-tissue/rest-debt double-count | ROADMAP/REVIEW | Wave 3 (30-03), GA-30-A |
| Finding 2 — LoadDistribution scale mismatch | ROADMAP/REVIEW | Wave 2 (30-02), GA-30-B |
| Finding 3 — StrengthLoad chronic ⊇ acute + zero-chronic + windowed off-by-one | ROADMAP/REVIEW | Wave 1 (30-01), GA-30-C |
| Finding 4 — StrengthLoad RPE→RIR truncation | ROADMAP/REVIEW | Wave 1 (30-01), GA-30-D |
| Finding 5 — StrainRisk coverage excludes easy | ROADMAP/REVIEW | Wave 1 data capture + Wave 3 consumption, GA-30-E |
| Finding 6 — PRSDualRun nil-targetVolume discard + updatedAt | ROADMAP/REVIEW | Wave 4 (30-04), GA-30-F |
| INV: live byte-identical / 3 fences green | CONTEXT | every wave verification + final 30-VERIFICATION |
| INV: no activation, flags FALSE | CONTEXT | every wave (no flag touched); Wave 4 flag-off-first ordering |
| INV: local-only / never-synced | CONTEXT | Wave 1 (MuscleStrengthLoad value-type / SyncService-absence check) |

No MISSING items. No deferred ideas implemented. All six findings + invariants covered.

</multi_source_coverage_audit>

<verification>
Final phase verification recorded in `30-VERIFICATION.md`:
1. Full `xcodebuild test` exit 0, 0 failures (excluding known XCUITest screenshot flake).
2. BaselineTierFenceTests + AutoregulationFlagFenceTests + DualRunFlagFenceTests files UNMODIFIED (git diff shows zero changes) and green.
3. `grep` confirms `PRSActivation.isEnabled` + `PRSMasterActivation.isEnabled` defaults still FALSE.
4. `grep` confirms `MuscleStrengthLoad` not referenced by `SyncService` and not Codable-synced.
5. No `injury prediction` copy introduced (grep guard).
</verification>

<success_criteria>
All 6 findings fixed with corrected oracle tests; 4 waves committed atomically to main; full suite green; three live fences untouched and green; no flag flipped.
</success_criteria>

<output>
Each wave executor writes `.planning/phases/30-shadow-engine-quality-fixes/30-0N-SUMMARY.md`. Phase closes with `30-VERIFICATION.md`.
</output>
