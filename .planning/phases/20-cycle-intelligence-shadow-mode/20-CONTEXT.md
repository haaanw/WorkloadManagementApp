# Phase 20: Cycle Intelligence (Shadow Mode) - Context

**Gathered:** 2026-05-29
**Status:** Ready for planning

<domain>
## Phase Boundary

Build a **silent shadow-mode analytics layer** that measures whether cycle phase improves prediction of next-day outcomes (recovery score, wellness score, workout completion, reported pain/soreness), and **design but gate OFF** the three evidence-gated algorithmic modifiers (AutoregulationEngine soft volume modifier, FatigueIndexEngine phase-aware dampening, ProgressionEngine late-luteal maintain bias). No user-facing behavior changes until the shadow signal is confirmed.

This phase is the Wave 2 of the v1.4 Cross-AI consensus: Phase 18 delivered same-phase **baselines** (measurement correction, already live), Phase 19 delivers cycle **context/explanations** in the UI (no algorithm change). Phase 20 is where algorithmic **modifiers** are first written — but they ship dark, behind a single reusable evidence gate and a master OFF flag, with their effect only ever logged in shadow, never applied, until the validation data says otherwise.

**Backend/analytics only — no new always-on UI.** The only surface a user could see is a debug/developer-facing shadow report and a future explanation string attached to a modifier (which stays inert this phase). Surfacing modifier effects to users is explicitly out of scope and deferred to a future "modifier activation" phase gated on shadow results.

**Privacy is load-bearing:** raw menstrual data never leaves the device (Phase 17 D-12). The shadow log stores only derived phase/bucket + already-computed composite scores, and is a **local-only `@Model`** that is never added to any Supabase sync payload.

</domain>

<decisions>
## Implementation Decisions

### Shadow-Mode Measurement
- **D-01:** Shadow mode is a persisted, append-only **local-only** `@Model` (`CyclePredictionLog`) — one row per athlete per day per outcome-prediction pair. Each row captures: date, cycle phase + 2-bucket, confidence, exclusion flag, the **baseline prediction** (model WITHOUT cycle phase), the **cycle-aware prediction** (model WITH cycle phase as a feature), and — recorded later when the outcome materializes — the **actual observed outcome**. This lets us compute prediction error for both models and ask "did adding phase reduce error?"
- **D-02:** Four tracked outcomes (ROADMAP criterion 1): next-day **recovery score**, next-day **wellness score**, next-day **workout completion** (did a planned/typical session get logged), next-day **reported pain/soreness** (from WellnessCheckIn `soreness`). Each outcome is logged independently so a sparse outcome (pain) doesn't block a dense one (recovery).
- **D-03:** **Two-stage record.** Stage 1 (prediction): at recovery-pipeline run time, write a row with predicted-tomorrow values and current cycle state, outcome fields nil. Stage 2 (resolution): the next day, the pipeline (or a lightweight resolver run on launch) finds yesterday's unresolved rows and fills in the observed actuals by date-join. No real-time outcome needed; resolution is idempotent.
- **D-04:** The "prediction" is intentionally **lightweight and deterministic**, not a trained model. Baseline prediction = persistence/trend extrapolation already available in the engines (e.g. recovery trend slope from `RecoveryScoreEngine.computeSlope`, last wellness score, recent completion rate). Cycle-aware prediction = the same extrapolation plus a **fixed, literature-derived phase offset** (e.g. expected luteal recovery suppression). We are measuring whether the phase offset's *direction and magnitude* track reality for THIS athlete — not building an ML system. Keep it a pure struct (`ShadowPredictor`) with static methods.

### Evidence Gate (single reusable guard)
- **D-05:** A single reusable guard `CycleModifierGate` (pure struct, static `func isEligible(context:cyclesObserved:) -> Bool`) is the ONLY place modifier eligibility is decided. It returns true ONLY when ALL hold: (a) `context.confidence >= 0.7`, (b) `!context.hasExclusion` (no hormonal contraception / pregnancy / lactation), (c) `context.phase != .unknown` (detected regularity is already folded into upstream confidence per Phase 17/18 — do NOT recount cycles), (d) `cyclesObserved >= 3` (3+ usable cycles), AND (e) a **user-visible explanation string** is producible for the modifier (the guard returns the explanation alongside eligibility so a modifier can never fire without text). Mirrors the Phase 18 D-04 gate verbatim in semantics, plus the 3-cycle and explanation requirements unique to modifiers.
- **D-06:** A **master shadow-validation flag** `CycleModifierActivation.isEnabled` (default **false**, compile-time/Bool constant for this phase) wraps every modifier *application*. With it false, modifiers compute their would-be effect and that effect is recorded to the shadow log (so we can compare "what we'd have done" against "what helped"), but the value returned to the app is the unmodified value. Flipping it true is a future phase decision, made only after shadow data shows signal — NOT in this phase.

### AutoregulationEngine Soft Volume Modifier (designed, gated OFF)
- **D-07:** Additive overload: `recommend(input:cycleContext:)` accepting an optional `CycleContext` (default nil → byte-identical to today). When `CycleModifierGate.isEligible` AND `CycleModifierActivation.isEnabled`, a soft volume modifier of **5–15%** applies **only in the yellow recovery zone**. It NEVER fires in green or red zones, NEVER overrides a `.rest` or `.activeRecovery` recommendation, and NEVER raises volume (downward-only, and only with readiness/symptom support per D-09). With activation false, the would-be modified volume is logged to shadow only; the returned recommendation is unchanged.
- **D-08:** The 5–15% magnitude is itself a function of corroborating signal, not phase alone: phase contributes the *direction*; the actual reduction scales with how much the yellow-zone recovery score / wellness / symptoms already point down. Phase with no other negative signal → 0% (no reduction from phase alone, D-09).

### No-Phase-Alone Rule
- **D-09:** Enforced as an engine invariant (ROADMAP criterion 5): **no upward boost from phase alone; no reduction from phase alone without readiness or symptom support.** Concretely, every modifier requires a same-direction non-phase signal (low-ish recovery score within yellow, low wellness, or reported soreness) before it applies any change. This is asserted in tests for all three engines.

### FatigueIndexEngine Phase-Aware Dampening (designed, gated OFF, ships only if shadow confirms)
- **D-10:** Additive overload: `compute(input:cycleContext:)`. The hypothesis is **double-counting**: luteal progesterone suppresses HRV / raises RHR, which Phase 18's same-phase baseline already corrects in the *recovery* component — but `FatigueIndexEngine.recoveryTrend` (weight 0.20) and `wellnessTrend` consume recovery/wellness scores that may still carry residual cyclic variance, inflating fatigue during luteal. Phase-aware dampening would slightly down-weight or de-bias the recoveryTrend component in the luteal bucket. This ships **only if** shadow mode confirms the double-counting (i.e. cycle-aware fatigue prediction beats baseline). Until then it is fully behind D-06 and logged in shadow only.

### ProgressionEngine Late-Luteal Maintain Bias (designed, gated OFF)
- **D-11:** Additive overload: `suggest(..., cycleContext:)`. In **late luteal only** (`CyclePhase.lateLuteal`), when the computed `progressionType` would be `.increase` **but the progression rate is marginal** (small positive `computeProgressionRate`, below a threshold), bias to `.maintain` instead of `.increase`. Never converts `.maintain`/`.deload`/`.returnFromBreak` into anything more aggressive; never affects non-late-luteal phases. Gated by D-05 + D-06; logged in shadow only until activation.

### Engine Purity & Non-Breaking (scope locks)
- **D-12:** All engines stay **pure structs with static methods**. New `CycleContext` parameters are **additive optional overloads defaulting to nil** — existing call sites compile unchanged and behave identically (mirrors Phase 18's additive `RecoveryInput` extension). No existing engine signature is changed in a breaking way.
- **D-13:** The shadow log is **local-only** and never enters a Supabase payload. Only derived phase/bucket + already-existing composite scores are stored — no raw menstrual records, no cycle-start dates beyond what `MenstrualCycleSnapshot` already holds locally (Phase 17 D-12).

### Claude's Discretion (for planner/executor)
- Where the shadow log is written/resolved: extend `RecoveryPipeline.run` (already has `CycleTrackingService` + the date-join machinery) vs a dedicated `ShadowAnalyticsPipeline`. Read-time resolution mirroring Phase 18's join is preferred.
- Exact `CyclePredictionLog` field set and the repository (`CyclePredictionLogRepository`) query shape; reuse the Phase 18 `CycleSnapshotRepository` date-join pattern.
- Whether `CycleModifierActivation` is a plain `static let isEnabled = false` constant vs a `UserDefaults`-backed debug toggle (constant is simpler and safer for shipping dark; a hidden debug toggle aids internal validation).
- The exact phase-offset constants in `ShadowPredictor` (literature-derived starting values from the research doc).
- Shape of the debug-only shadow report view/printout (developer-facing only; not a shipped UI surface).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Research
- `.planning/research/female-athlete-optimization-research.md` — evidence base; §9 guiding principles (Sims "train by readiness, use cycle as context"; Altini "individual > population, avoid sparse population noise"); luteal HRV suppression / RHR rise magnitudes for the `ShadowPredictor` phase offsets

### Phase 17 Foundation
- `WorkloadApp/Models/MenstrualCycleSnapshot.swift` — `MenstrualCycleSnapshot` (@Model, local-only, daily phase + confidence + exclusion flags) and `CycleContext` struct (`phase`, `confidence`, `cycleDay`, `cycleLength`, exclusion bools, `hasExclusion`, `static let none`)
- `WorkloadApp/Models/Enums.swift` §`CyclePhase` (lines 380-386) — 5-phase enum (earlyFollicular, lateFollicular, ovulatory, earlyLuteal, lateLuteal, unknown)
- `WorkloadApp/Services/CycleTrackingService.swift` — produces `CycleContext`; single source of truth for confidence (do NOT recount cycles)

### Phase 18 (the pattern to mirror)
- `.planning/phases/18-cycle-aware-recovery-baselines/18-CONTEXT.md` and `18-01-PLAN.md` / `18-02-PLAN.md` — the exact artifact format, additive-optional-param convention, the D-04 gate semantics this phase's `CycleModifierGate` extends, and the read-time date-join pattern
- `WorkloadApp/Services/RecoveryScoreEngine.swift` — `enum PhaseBucket { case follicular, luteal }`, `static func bucket(for:) -> PhaseBucket?`, `static func samePhaseBaseline(readings:) -> Double?`, `static func computeSlope(values:) -> Double?`, `RecoveryInput.samePhaseHRVBaseline/samePhaseRestingHRBaseline`. REUSE `bucket(for:)` and `computeSlope` — do not re-derive.
- `WorkloadApp/Services/RecoveryPipeline.swift` — already injects `CycleTrackingService`, derives `CycleContext`, and runs the RecoverySnapshot × MenstrualCycleSnapshot date-join (lines 69-113). Primary insertion point for shadow logging.
- `WorkloadApp/Repositories/CycleSnapshotRepository.swift` — date-windowed phase-per-date reads; mirror for `CyclePredictionLogRepository`

### Phase 19 (depends on; not yet planned at time of writing)
- `.planning/phases/19-cycle-context-ui-guidance/` is **empty** at planning time. Plan Phase 20 against ROADMAP Phase 19 success criteria (cycle context as explanations, not overrides; readiness-first language; 100% optional UI). Phase 20 does not consume Phase 19 UI; it depends on Phase 19 only in execution order. The one cross-link: the modifier explanation strings (D-05 (e)) should be consistent in tone with Phase 19's "cycle as context, never deload-because-luteal" language.

### Existing Code to Modify (additive, non-breaking)
- `WorkloadApp/Services/AutoregulationEngine.swift` — pure struct; `recommend(input:)` (line 90); add `cycleContext:` overload; yellow-zone-only soft volume modifier (D-07/D-08)
- `WorkloadApp/Services/FatigueIndexEngine.swift` — pure struct; `compute(input:)` (line 94); add `cycleContext:` overload; luteal recoveryTrend dampening (D-10)
- `WorkloadApp/Services/ProgressionEngine.swift` — pure struct; `suggest(...)` (line 49); add `cycleContext:` overload; late-luteal marginal-progression maintain bias (D-11)
- `WorkloadApp/ViewModels/DashboardViewModel.swift` — builds `AutoregulationEngine.DailyInput` + `FatigueIndexEngine.FatigueInput` (lines 231-258); already threads `cycleTrackingService`. Pass `CycleContext` through and trigger shadow logging.
- `WorkloadApp/App/WorkloadApp.swift` — `Schema([...])` (line 40); register the new `CyclePredictionLog.self` model
- `WorkloadApp/Services/SyncService.swift` — MUST NOT gain any reference to the shadow log or cycle data (verify by grep)

### Requirements
- ROADMAP.md Phase 20 — CYCLE-09, CYCLE-10; 6 success criteria (the WHAT, locked). NOTE: CYCLE-09/10 have no standalone text definition in REQUIREMENTS.md (which stops at v1.3); the ROADMAP Phase 20 success criteria ARE the authoritative requirement text.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `RecoveryScoreEngine.bucket(for:)` and `PhaseBucket` (Phase 18) — reuse for shadow-log bucketing and FatigueIndex dampening; do not re-implement the 2-bucket mapping.
- `RecoveryScoreEngine.computeSlope(values:)` — already used by FatigueIndexEngine for trend; reuse for the `ShadowPredictor` baseline (persistence/trend) prediction.
- `RecoveryPipeline.run()` (Phase 18) — already owns the `CycleTrackingService` query, `CycleContext`, the ~3-cycle window fetch, and the RecoverySnapshot × MenstrualCycleSnapshot date-join. Shadow prediction (Stage 1) and resolution (Stage 2) slot in here with minimal new I/O.
- `CycleSnapshotRepository` (Phase 18) — copy its `@MainActor final class` + date-windowed `FetchDescriptor` + `#Predicate` athlete-scoped pattern for `CyclePredictionLogRepository`.
- `CycleContext.none` / `hasExclusion` — gives the nil-safe identical-behavior path and the exclusion check for `CycleModifierGate` for free.

### Established Patterns
- Engines are pure structs / static methods / deterministic — all new modifier logic and `ShadowPredictor` / `CycleModifierGate` stay pure (no HealthKit/SwiftData inside the engine; pipeline does I/O and passes plain values / `CycleContext` in).
- Pipelines (`@MainActor struct`, static `run`) do data orchestration and I/O.
- New SwiftData `@Model` must be added to the `Schema([...])` list in `WorkloadApp.swift` AND registered in `project.pbxproj` if it's a new source file.
- Additive optional params default to nil so existing call sites compile and behave identically (Phase 18 precedent).

### Integration Points
- `RecoveryPipeline.run()` step 3b (the existing cycle block, lines 69-113) is where `CycleContext` and the date-join already live — shadow Stage 1 write + Stage 2 resolve attach here.
- `DashboardViewModel.load()` (lines 226-258) builds the Autoregulation/Fatigue inputs — pass `CycleContext` into the new engine overloads; with activation OFF the returned values are unchanged so the dashboard is visually identical.
- `CyclePredictionLog` row is written per-day; `MenstrualCycleSnapshot` is one-row-per-day → same date-key join already proven in Phase 18.

</code_context>

<specifics>
## Specific Ideas

- The shadow question, stated precisely: **for each tracked outcome, is the mean absolute prediction error of the cycle-aware model lower than the baseline model, for this athlete, over N resolved days?** Store both errors per row; aggregation/judgement is a later analysis step (and a debug report), not an in-app decision this phase.
- Worked guardrail examples to test (from ROADMAP criteria 2 & 5):
  - Yellow recovery + luteal + low-ish wellness → soft volume reduction up to 15% **but only when activation is ON**; with activation OFF the recommendation volume is unchanged and the would-be value is shadow-logged.
  - Green recovery + luteal → **no modifier**, ever (criterion 2: never overrides green).
  - Red recovery + luteal → **no modifier**, rest/active-recovery preserved (criterion 2).
  - Luteal phase + perfectly normal recovery & wellness & no soreness → **no reduction** (criterion 5: no reduction from phase alone).
  - No phase information (nil context) → byte-identical to today (criterion 6 implies graceful absence; D-12 scope lock).
- Dr. Stacy Sims: "train by readiness, use cycle as context" — modifiers are downward-only nudges within readiness guardrails, never the driver.
- Marco Altini: prefer the athlete's own response over population priors — which is exactly why we measure in shadow before activating.

</specifics>

<deferred>
## Deferred Ideas

- **Activating any modifier for real users** — explicitly out of scope; a future "modifier activation" phase, gated on this phase's shadow results, flips `CycleModifierActivation.isEnabled`.
- **Surfacing modifier effects / shadow report in production UI** — debug-only this phase; a polished user-facing explanation is future work consistent with Phase 19 tone.
- **A trained/statistical prediction model** — D-04 keeps the predictor deterministic and lightweight; ML is out of scope.
- **Foster monotony/strain session-density metric** (from MEMORY) — separate deferred research, not part of this phase.

</deferred>

## Assumptions (full-auto)

These were decided without a discuss-phase round; flag any the user disagrees with before execution.

1. **CYCLE-09/10 text = ROADMAP Phase 20 success criteria.** REQUIREMENTS.md does not define CYCLE-09/10 as standalone text (the file ends at v1.3 requirements). I treat the six ROADMAP Phase 20 success criteria as the authoritative requirement definition. (Verified: grep found only `**Requirements**: CYCLE-09, CYCLE-10` references, no text blocks.)
2. **Plan count = 3** (justified in the plans below): (01) shadow infrastructure + predictor + log model, (02) the three gated modifiers + reusable gate, (03) pipeline/ViewModel wiring + shadow record/resolve + debug report. Wave 1 = Plan 01; Wave 2 = Plan 02 (depends on 01 for the gate's home) + Plan 03 (depends on 01 & 02).
3. **Modifiers ship dark behind `CycleModifierActivation.isEnabled = false`** and are exercised only via tests + shadow logging this phase. No real user sees any behavior change. This is the safest reading of "evidence-gated … only if shadow mode shows signal."
4. **Shadow predictor is deterministic, not ML** (D-04) — measuring whether a fixed literature-derived phase offset tracks reality, keeping engines pure and shippable.
5. **Shadow log is a local-only `@Model`** added to the schema, never synced (D-13) — consistent with Phase 17 D-12 privacy constraint. No Supabase migration is part of this phase.
6. **Phase 19 is planned/executed before Phase 20** per ROADMAP execution order (17→18→19→20). At planning time Phase 19's dir is empty, so Phase 20 is planned against ROADMAP Phase 19 criteria; the only coupling is explanation-string tone consistency, which does not block planning.
7. **Outcome "workout completion"** is derived from whether a `WorkoutSession` was logged on the predicted day relative to the athlete's recent typical frequency (no new "planned workout" model exists). "Reported pain" maps to `WellnessCheckIn.soreness`.

---

*Phase: 20-cycle-intelligence-shadow-mode*
*Context gathered: 2026-05-29*
