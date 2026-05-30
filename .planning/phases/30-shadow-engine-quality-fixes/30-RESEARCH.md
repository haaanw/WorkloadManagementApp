# Phase 30 — Shadow-engine quality fixes — RESEARCH

**Date:** 2026-05-31
**Mode:** Planner-only (no human discuss-phase). Gray-area calls made from the findings + confirmed source reads and recorded here with rationale.
**Milestone:** v1.6 Algorithm Moat (Personal Readiness v1) — pre-activation cleanup.

## Scope

Fix the 6 shadow / display / flag-on quality findings surfaced by the Phase 27/28/29 adversarial + codex review. ALL six live entirely in the shadow / display / flag-on layers; NONE reaches live behavior.

These fixes **deliberately change shadow engine OUTPUTS** (Strain-Risk score, coverage confidence, per-muscle elevation, dual-run volume). That is the intended deliverable. The affected ENGINE/ORACLE tests get **re-derived correct expected values**; the three live FENCE families are **untouched and must stay green**.

## Confirmed source reads (exact lines, not the ~approximate ones in the roadmap)

All six confirmed by reading the real source on 2026-05-31:

| # | File | Confirmed location | Confirmed mechanism |
|---|------|--------------------|---------------------|
| 1 | `WorkloadApp/Services/StrainRiskEngine.swift` | comp 3 = L123-124 (`fatigue.index/100`), comp 5 = L138-141 (`fatigue.softTissueRisk`), comp 6 = L143-144 (`fatigue.restDebt`) | `FatigueIndexEngine.compute` (FatigueIndexEngine.swift L213-218, L196-201) folds softTissueRisk (internal weight 0.10) and restDebt (internal weight 0.15) INTO `index`. StrainRisk consumes `index` (comp 3) AND re-adds `softTissueRisk` (comp 5, w=0.12) + `restDebt` (comp 6, w=0.08) standalone → both counted twice. |
| 2 | `WorkloadApp/Services/LoadDistributionEngine.swift` | `sessionUnifiedLoad` L96-103, `sessionStrengthLoad` L107-119 | sRPE load (`WorkloadCalculator.srpeLoad` = minutes×RPE, tens–hundreds) summed directly with strength strain weights (`StrengthLoadEngine.Constants.strainWeight` ∈ {0.6,0.8,1.0,1.3} per hard set, single digits) into ONE per-day series fed to Foster `monotony`/`strain` (L125-136). Endurance dominates; strength is noise whenever `sessionRPE` is logged. |
| 3 | `WorkloadApp/Services/StrengthLoadEngine.swift` | `perMuscleStrengthLoad` L255-257 + L283-285, `perMuscleElevation` L221-228, `windowed` L315-327 | Chronic 28d window is a SUPERSET of acute 7d (`windowed(...,days:28)` ⊇ `windowed(...,days:7)`); chronicPerDay = chronicLoad/28. New exercise present only in last 7d → acutePerDay high, chronicPerDay diluted by /28 → ratio≈4 → max elevation. Also `perMuscleElevation` returns 0 when `chronic<=0` (L222) → a warmup-only / zero-chronic muscle under heavy acute load reports 0 elevation. Also `windowed` uses `diff >= 0 && diff <= days` (L325) — inclusive of BOTH endpoints = `days+1` calendar days. |
| 4 | `WorkloadApp/Services/StrengthLoadEngine.swift` | `estRIR` L117-121 (`Int(max(0.0, rpeToRIRMax - rpe))`) | `Int(...)` TRUNCATES: RPE 7.5 → `Int(2.5)` = 2 → `hardByRIR` (`rir <= 2`, L150) TRUE → classified `.hard`. A 7.5-RPE set (2.5 RIR) is below the hard bar and should be `.easy`. |
| 5 | `WorkloadApp/Services/StrainRiskEngine.swift` | `confidence(_:)` L200-204 | coverage = `hardSets / (hardSets + unscored)` — omits scored `.easy` sets from BOTH numerator and denominator. An all-easy fully-scored session reports coverage 0 (looks like no coverage); mixed sessions overstate the unscored share. |
| 6 | `WorkloadApp/Services/PRSDualRunSurface.swift` | `adjust(...)` L75-84; `PrescribedWorkout.targetVolume` (PrescribedWorkout.swift L27, init never sets it) | flag-ON path: when `workout.targetVolume == nil` (the default for every normal prescription — initializer L51-76 never populates it, sync-pull does not either), the volume branch (L76-80) sets `newVolume = nil`, silently DISCARDING a 50%-volume / rest recommendation. Existing fence/shadow tests seed `targetVolume = 100.0` manually (DualRunFlagFenceTests L20), hiding the gap. Also `adjust` mutates `targetRPE`/`targetVolume` but never bumps `updatedAt` (model L29-30). Runs flag-ON only (never live this milestone) — but must be correct for future activation. |

## Test surface (which engine/oracle tests get new expected values)

Confirmed test files (`WorkloadAppTests/`):

| File | Touched? | Why |
|------|----------|-----|
| `StrengthLoadEngineTests.swift` | YES (Wave 1) | `estRIR`-from-RPE cases (L59-62), hard-set classification, `perMuscleElevation` oracle (L182-200), `perMuscleStrengthLoad` elevation expectations (L235-256). New expected values for fractional-RPE RIR and chronic-exclusion elevation; new zero-chronic-confidence assertions; `windowed` boundary test. |
| `LoadDistributionEngineTests.swift` | YES (Wave 2) | `dailyLoadSeries` load-sum oracle (`day1.load == 280.0`, L79) — recomputed under the new strength→sRPE-equivalent scaling. Pure-math `monotony`/`strain` known-value tests (L47-56) operate on raw arrays and are UNAFFECTED. |
| `StrainRiskEngineTests.swift` | YES (Wave 3) | Worked-example fusion (`score > 0.9`, L75), confidence builders + coverage tests (L183-209), sign-constraint tests, redistribution test. New `Weights` set after removing the double-count; new coverage formula incl. easy. |
| `PRSShadowArmTests.swift` | MAYBE (Wave 4) | If `MuscleStrengthLoad` gains a field (Finding 3 confidence channel), the shadow-arm builders must compile. Verify; update only if the struct changes. |
| `DualRunFlagFenceTests.swift` | **NO — DO NOT TOUCH** | LIVE FENCE. Flag-off no-op + flag-on existing-targetVolume behavior must stay byte-identical. New nil-targetVolume coverage goes in a NON-fence test file. |
| `BaselineTierFenceTests.swift` | **NO — DO NOT TOUCH** | LIVE FENCE. |
| `AutoregulationFlagFenceTests.swift` | **NO — DO NOT TOUCH** | LIVE FENCE. |

## Gray-area decisions (planner calls — each = a grayAreaAssumption)

### GA-30-A — Finding 1 double-count: SUBTRACT-THEN-RE-ADD (keep standalone channels)
Two legitimate fixes: (i) consume softTissue/restDebt ONLY via the composite (drop comp 5 & 6), or (ii) remove their contribution from the composite before re-adding standalone.
**Decision: (ii) — subtract their internal contribution from `fatigue.index` before feeding comp 3, keeping the standalone comp 5 (soft-tissue, w=0.12, which ALSO carries the recurrence bonus that the composite lacks) and comp 6 (rest debt, w=0.08).**
**Rationale:** comp 5 is not a pure duplicate — it adds the `recurrenceFlags` bonus (StrainRiskEngine L139) the composite cannot represent, and the StrainRisk design intentionally weights soft-tissue (0.12) and rest-debt (0.08) higher than FatigueIndex's internal 0.10/0.15-of-100 share. Dropping the standalone channels would silently down-weight the moat's soft-tissue signal. Subtracting the composite's internal contribution (recompute a "fatigue-without-softtissue-restdebt" index by re-normalising FatigueIndexEngine's OTHER four components) preserves both the FEA composite lineage AND the deliberate StrainRisk weighting, with each underlying signal counted exactly once.
**Implementation:** add a derived helper `FatigueIndexEngine.indexExcluding(softTissue:restDebt:)` (pure, re-normalises the remaining 4 components: load 0.20, density 0.20, recovery 0.20, wellness 0.15 → /0.75) OR compute it inside StrainRisk from the already-exposed component fields on `FatigueResult` (loadElevation, sessionDensity, recoveryTrend, wellnessTrend, with their FatigueIndex weights). Prefer computing inside StrainRisk from the exposed fields (no FatigueIndexEngine change → no cross-engine blast radius; FatigueResult already exposes all four). Comp 3 label stays "Accumulated fatigue".

### GA-30-B — Finding 2 scale mismatch: Z-STANDARDISE EACH STREAM before summing
Options: (i) convert strength strain to an sRPE-equivalent via a fixed multiplier, (ii) z/standardise each stream over the window, (iii) min-max each stream.
**Decision: (ii) — build TWO per-day sub-series (endurance sRPE load, strength strain load), z-standardise EACH over the window's logged days, then sum the standardised values into the unified per-day series fed to Foster monotony/strain.**
**Rationale:** A fixed sRPE-equivalent multiplier (i) is a magic constant with no defensible value (strain weights are unitless relative-intensity tallies, not minutes×RPE). Min-max (iii) is dominated by single outliers on sparse consumer logs. Z-standardisation puts both streams on a mean-0/SD-1 footing so each contributes comparably to the monotony mean/SD regardless of native scale, and degrades gracefully: a stream with zero variance (e.g. only endurance logged) contributes a constant 0 after standardisation, so the OTHER stream drives monotony (no NaN, no divide-by-zero — guard SD>0, else that stream contributes 0). Foster monotony is itself a mean/SD ratio, so feeding it standardised inputs is dimensionally coherent.
**Edge handling:** if a stream is entirely zero / has <2 nonzero days or SD==0, its standardised contribution is 0 for all days (documented in code comment + plan). The completeness gate (≥7 logged days, nonzero combined variance) is unchanged and still guards Foster.
**Note:** the standardisation is applied to the SERIES used for monotony/strain ONLY. `dailyLoadSeries` (raw per-day load) keeps its existing meaning for any other consumer; introduce a SEPARATE `standardizedDailyLoadSeries` (or standardise inside `distribution`) so the raw series oracle is explicit.

### GA-30-C — Finding 3 chronic-exclusion: CHRONIC EXCLUDES ACUTE + zero-chronic ⇒ reduce confidence (not 0, not 4×)
Options: (i) chronic window excludes the acute window (chronic = days 8–28, 21d span), (ii) roll per training-day instead of calendar-day.
**Decision: (i) — the chronic baseline is computed over the window that EXCLUDES the acute window (sessions with `8 <= dayDiff <= chronicWindowDays`), normalised by the chronic-exclusive day count (chronicWindowDays − acuteWindowDays). Acute stays days 0–7.**
**Rationale:** (i) is the minimal, well-understood ACWR-style "uncoupled" fix and matches the finding's primary suggestion; per-training-day rolling (ii) is a larger redesign with its own edge cases (what is a "training day" for a multi-sport athlete) — out of scope for a quality fix. Excluding acute removes the superset double-count so a steady-state athlete gets ratio≈1 (elevation 0), and a genuine acute spike vs an established chronic base still elevates.
**Zero-chronic / new-exercise handling:** when chronic-exclusive load is 0 (new exercise / warmups-only history) `perMuscleElevation` must NOT return 0 (false "no strain") NOR 4× (false max). **Decision: return elevation 0 AND mark the muscle's elevation as "insufficient baseline" by surfacing a per-muscle `hasChronicBaseline: Bool` (or `baselineConfidence` 0..1) flag on `MuscleStrengthLoad`; the StrainRisk confidence() then DISCOUNTS for muscles lacking a chronic baseline** (a new-exercise heavy session shows as low-confidence, not high-strain and not silently-safe). This adds ONE field to `MuscleStrengthLoad` → the test helper `strengthResult(...)` in StrainRiskEngineTests and any `MuscleStrengthLoad(...)` memberwise call must add the new argument (compile-touch only).
**windowed off-by-one:** `diff >= 0 && diff <= days` spans `days+1` calendar days. **Decision: tighten acute to `diff >= 0 && diff < acuteWindowDays` (exactly `acuteWindowDays` days: 0..6 for 7d) and chronic-exclusive to `diff >= acuteWindowDays && diff < chronicWindowDays`.** This makes acute and chronic exactly partitioned and removes the boundary overlap day. Add an explicit `windowed` boundary test. (`LoadDistributionEngine.dailyLoadSeries` and `fallbackLoadSignal` use the SAME inclusive idiom but are NOT in scope for the off-by-one — leave them; only StrengthLoadEngine's acute/chronic partition matters for the ratio. Document this scoping in the plan.)

### GA-30-D — Finding 4 RPE→RIR: COMPARE IN DOUBLE before the ≤2 test
**Decision: keep `estRIR` returning the existing `Int?` contract for callers that need an Int, BUT add a `Double`-precision RIR (`estRIRPrecise -> Double?` = `max(0, rpeToRIRMax - rpe)`, rir wins as `Double(rir)`) and have `classify` compute `hardByRIR` against the Double value with a Double threshold (`<= 2.0`).** So RPE 7.5 → 2.5 RIR → NOT hard. `estRIR` (Int) stays for display/back-compat; its truncation no longer affects classification.
**Rationale:** Comparing in Double before the threshold (the finding's stated fix) is exact and avoids changing the public `estRIR` Int return that other code/tests depend on (StrengthLoadEngineTests L56-62 assert Int values). Round-half-up on the Int would make 7.5→3 (correct here) but would push 7.6→2 (`Int(2.4.rounded())`=2) wrong-direction at other fractions — comparing the raw Double is unambiguous. Update the from-RPE hard-classification tests for fractional RPE (7.5, 7.6, 8.0).

### GA-30-E — Finding 5 coverage incl. easy: `(hard+easy)/(hard+easy+unscored)`
**Decision: add `easyCount` to `MuscleStrengthLoad` (currently it tracks only hardSetCount + unscoredCount; easy sets are `continue`d in `aggregateMuscle` L206-207 and not counted). StrainRisk `confidence()` then uses `(hard+easy)/(hard+easy+unscored)`.**
**Rationale:** the finding requires easy sets in BOTH numerator and denominator; the engine currently discards the easy count entirely, so the data must first be captured. This is a second new field on `MuscleStrengthLoad` (alongside GA-30-C's baseline flag) — fold both struct changes into the SAME Wave-1 StrengthLoadEngine edit so the memberwise-init blast radius is paid once. Then Wave 3 reads `easyCount` in confidence().
**Sequencing consequence:** because `easyCount` and the chronic-baseline flag both live on `MuscleStrengthLoad`, **Finding 5's data capture is done in Wave 1** (StrengthLoadEngine) and Finding 5's *consumption* (the confidence formula) is done in Wave 3 (StrainRiskEngine). The plan splits it accordingly.

### GA-30-F — Finding 6 nil-targetVolume: DERIVE EFFECTIVE BASE + bump updatedAt
Options: populate `targetVolume` at prescription creation, or handle nil at adjust time.
**Decision: handle at adjust time — when `workout.targetVolume == nil`, treat the effective base as the volume implied by the prescription's template/sets if derivable, else fall back to a neutral base of 1.0 and apply the modifier, so a 0.5 modifier yields 0.5 (a meaningful reduction signal) and a rest (0.0) yields 0.0, instead of silently dropping to nil. Also set `workout.updatedAt = .now` whenever a mutation occurs.**
**Rationale:** Populating at creation would touch the live prescription-creation path (initializer / sync-pull) — broader blast radius and risk to the flag-off invariant. Handling at adjust time keeps the change inside the already-flag-gated `PRSDualRunSurface.adjust` (flag-OFF still returns nil + no-op first, before any of this runs → fence stays byte-identical). Deriving from the template (sum of `TemplateSet` target volumes across `allExercises`) is the honest base when available; the 1.0 neutral fallback makes the modifier the *fraction of full* so the reduction is never lost. `.now` for `updatedAt` is acceptable because this path is flag-ON only (not deterministic-pure like the engines) — but to keep `adjust` testable, inject the timestamp via an optional `now: Date = .now` parameter so the new test can assert the bump deterministically.
**Test placement:** the new nil-targetVolume coverage test goes in `PRSShadowArmTests.swift` (or a new `PRSDualRunSurfaceTests.swift`) — NEVER in `DualRunFlagFenceTests.swift` (the fence must keep its existing seeded-targetVolume flag-on assertion byte-identical).

## Hard invariants (enforced by every plan)

1. SHADOW/DISPLAY/FLAG-ON only. LIVE behavior byte-identical. The three fence families stay green: `BaselineTierFenceTests`, `AutoregulationFlagFenceTests`, `DualRunFlagFenceTests`. Do NOT touch `RecoveryScoreEngine.computeBaseline` or the flag-off `AutoregulationEngine` path.
2. NO activation. `PRSActivation` + `PRSMasterActivation` stay default FALSE. No live default flipped.
3. All new/changed models stay local-only / never-synced (no Codable-sync, absent from `SyncService`). `MuscleStrengthLoad` is a pure value type (not a SwiftData model) — adding fields keeps it local; verify it never enters a sync payload.
4. Atomic commits directly to `main`. NO branch. NEVER push.
5. Product name "Tuwa". Strain-Risk copy = "load-tolerance / overreaching caution", NEVER "injury prediction".
6. These fixes CHANGE shadow OUTPUTS intentionally — update affected ENGINE/ORACLE tests to new CORRECT expected values; do NOT weaken/touch the three live fence tests.

## Execution gotchas

- Run waves SERIAL, one at a time. No self-branching parallel executors.
- DISCARD any `.xcstrings` build-churn diffs before committing.
- Agent SourceKit "Cannot find type/module" diagnostics are routinely STALE/FALSE. Only a real `xcodebuild` run proves green.
- After ANY shared-type / enum change (esp. the `MuscleStrengthLoad` field additions in Wave 1), run the FULL `WorkloadAppTests` suite, not just new tests.
- Use Write (or python) to author plan/doc files, not Edit.

## Build / test command (confirmed from Phase 28 verification)

```
cd "workload management" && xcodebuild test \
  -project "workload management.xcodeproj" -scheme "workload management" \
  -destination 'platform=iOS Simulator,id=CAF84E71-BB64-491D-87C8-875A0143B26D'
```

`CAF84E71-BB64-491D-87C8-875A0143B26D` = iPhone 17 Pro simulator, confirmed available 2026-05-31.

## Package legitimacy

No new packages. Foundation-only edits to existing pure engines + one model field + one flag-gated surface. Package Legitimacy Gate not applicable.
