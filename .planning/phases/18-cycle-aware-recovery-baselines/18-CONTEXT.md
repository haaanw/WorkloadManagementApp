# Phase 18: Cycle-Aware Recovery Baselines - Context

**Gathered:** 2026-05-25
**Status:** Ready for planning

<domain>
## Phase Boundary

Replace the male-normative 7-day rolling HRV/RHR baseline in `RecoveryScoreEngine` with a confidence-gated **same-phase** baseline that removes predictable within-athlete cyclic variance (luteal HRV suppression / RHR rise), while preserving genuine fatigue detection. Engine remains a pure struct; `RecoveryPipeline.run()` queries cycle data and passes `CycleContext` plus phase-tagged history into the engine. When cycle data is absent, low-confidence, or excluded (OC/pregnant/lactating), behavior is **identical** to the current 7-day engine.

**Backend/algorithm only — no UI.** Surfacing cycle context to the user is Phase 19.

</domain>

<decisions>
## Implementation Decisions

### Phase Bucketing
- **D-01:** Same-phase baselines use **2 buckets** — follicular (earlyFollicular + lateFollicular + ovulatory) vs luteal (earlyLuteal + lateLuteal). Captures the dominant physiological signal (luteal progesterone suppresses HRV / raises RHR) while keeping samples dense and robust. Avoids the sparse-data noise of 5-phase splitting (Altini: individual signal over thinly-spread population noise). The 5-phase `CyclePhase` enum from Phase 17 is retained; bucketing is a mapping applied at baseline-grouping time.

### Baseline Window & Sample Minimums
- **D-02:** Same-phase baseline = equal-weight average of HRV/RHR readings from the **same bucket over the most recent 3 cycles**. Short window → equal weighting is sufficient (no recency decay needed).
- **D-03:** Minimum **4 valid HealthKit readings** in a bucket before its same-phase baseline is trusted. Below that, that bucket falls back to 7-day rolling (see D-06).

### Confidence Gate
- **D-04:** The engine switches to same-phase mode when `CycleContext.confidence >= 0.7` **AND** `CycleContext.hasExclusion == false` **AND** the current phase is not `.unknown`. Reuse the confidence already computed by `CycleTrackingService` in Phase 17 (1 cycle = 0.4, 2 = 0.6, 3+ ≈ 0.7+) — the engine does NOT independently recount cycles or re-derive regularity. Single source of truth. Irregular/anovulatory cycles already produce low upstream confidence and thus fall back automatically.
- **D-05:** OC users always 7-day (carried from Phase 17 D-04); enforced here via `hasExclusion`.

### Transition & Missing-Data Fallback
- **D-06:** **Per-bucket** fallback — even when the overall gate passes, if a specific bucket lacks the D-03 minimum (e.g. athlete's first recorded luteal phase), THAT bucket uses 7-day rolling independently while the other bucket may use same-phase.
- **D-07:** **Hard switch, no blending.** Once the gate passes, use same-phase. Baseline only changes when the bucket changes, so transitions are naturally gradual — no interpolation state needed. Rejected blend-over-N-days (extra state for marginal smoothing) and borrow-adjacent-bucket (introduces risky modeling assumptions).

### Scope Locks (from ROADMAP success criteria — not re-decided)
- Same-phase baseline applies to **both HRV and RHR** (RHR luteal rise handled automatically by same-phase denominator).
- `RecoveryScoreEngine.compute` with `CycleContext == nil`/`.none`/unknown behaves **identically** to today — additive, non-breaking change.
- Trend modifier logic stays unchanged (operates on recovery scores, not raw HRV).

### Claude's Discretion (for planner/executor)
- **Data join mechanism:** how the pipeline pairs historical `RecoverySnapshot` HRV/RHR with the `CyclePhase` active on that date — join `RecoverySnapshot` × `MenstrualCycleSnapshot` by date at read-time in `RecoveryPipeline`, vs stamping bucket/phase onto `RecoverySnapshot` at write-time. Planner picks; read-time join keeps `RecoverySnapshot` schema untouched and is preferred unless query cost is a concern.
- Exact shape of the `RecoveryInput` extension (new optional fields for same-phase baselines + bucket source data) vs a separate computation path.
- Bucket→`CyclePhase` mapping helper location (engine static helper vs `CyclePhase` extension).
- Handling of partial/missing HealthKit days within a cycle when counting the 4-reading minimum.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Research
- `.planning/research/female-athlete-optimization-research.md` — evidence base; algorithm implications (luteal HRV suppression, same-phase baselining), guiding principles §9 (Sims "cycle as context"; Altini "individual > population, avoid sparse population noise")

### Phase 17 Foundation (depends on)
- `.planning/phases/17-cycle-data-foundation/17-CONTEXT.md` — D-04 (OC → 7-day), D-06 (irregular → 7-day), D-09 (`CycleContext` passed to engine), D-10 (`CyclePhase` enum), confidence model
- `WorkloadApp/Models/MenstrualCycleSnapshot.swift` — `MenstrualCycleSnapshot` (@Model, daily phase + confidence, local-only) and `CycleContext` struct (phase, confidence, cycleDay, exclusion flags, `hasExclusion`, `.none`)
- `WorkloadApp/Models/Enums.swift` §`CyclePhase` (line ~380) — 5-phase enum to bucket
- `WorkloadApp/Services/CycleTrackingService.swift` — produces `CycleContext`; confidence scoring (cycle-count based)

### Existing Code to Modify
- `WorkloadApp/Services/RecoveryScoreEngine.swift` — pure struct; extend `RecoveryInput` + `compute()`; `computeBaseline()` is current 7-day rolling (line ~223); component math `ratioToScore` HRV higherIsBetter / RHR lowerIsBetter
- `WorkloadApp/Services/RecoveryPipeline.swift` — `run()` fetches 7-day history + baselines (lines ~53-58); add `CycleTrackingService` query + phase-tagged history; pass `CycleContext` to engine
- `WorkloadApp/Repositories/RecoveryRepository.swift` — `fetchRecoveryHistory(days:athlete:)` (extend window/query for 3-cycle history)
- Privacy: raw menstrual data stays local (Phase 17 D-12) — only phase/cycle-day influence the algorithm; nothing new syncs to Supabase

### Requirements
- ROADMAP.md Phase 18 — CYCLE-04, CYCLE-05; 7 success criteria (the WHAT, locked)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `RecoveryScoreEngine.computeBaseline(values:)` — existing 7-day rolling average; same-phase baseline is a sibling computation feeding the same `hrvBaseline`/`restingHRBaseline` slots in `RecoveryInput`. No change to scoring math (`ratioToScore`) — only the denominator source changes.
- `CycleContext` (already built in Phase 17) — exactly the value type the engine needs; `.none` sentinel gives the nil-safe identical-behavior path for free.
- `RecoveryRepository.fetchRecoveryHistory` — existing date-windowed query; extend to ~3-cycle span for same-phase grouping.

### Established Patterns
- Engines are pure structs, static methods, deterministic — same-phase logic must stay pure (no HealthKit/SwiftData inside the engine; pipeline does I/O and passes plain arrays/`CycleContext` in).
- Pipelines (`@MainActor struct`, static `run`) do the data orchestration and I/O.
- `RecoverySnapshot` = one-row-per-day; `MenstrualCycleSnapshot` = one-row-per-day → date-key join is natural.

### Integration Points
- `RecoveryPipeline.run()` step 2 (baseline computation) is the primary insertion point — branch: gated same-phase vs existing 7-day.
- `RecoveryScoreEngine.RecoveryInput` gains optional same-phase inputs; `compute()` selects baseline source. Nil → current path (criterion 1).
- `CycleTrackingService` already injectable via `AppContainer` — pipeline gains it as a parameter (mirror `healthKitService`/`syncService` optional injection).

</code_context>

<specifics>
## Specific Ideas

- Worked examples to validate against (from ROADMAP success criteria):
  - Consistent 35ms late-luteal HRV vs 42ms follicular → scores **normal** in luteal (same-phase denominator ≈ 35, not 42).
  - Genuine 28ms luteal HRV vs her 36ms luteal average → **still triggers** fatigue (ratio < 1 against same-phase baseline).
- Dr. Stacy Sims: "train by readiness, use cycle as context" — baseline correction removes predictable variance; it does NOT override or hard-gate training.
- Marco Altini: group-level cyclic patterns don't always transfer to the individual → prefer the athlete's own same-phase history over any population model, and prefer dense 2-bucket grouping over sparse 5-phase.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope. Surfacing cycle context/explanations to the user is already scoped as Phase 19.

</deferred>

---

*Phase: 18-cycle-aware-recovery-baselines*
*Context gathered: 2026-05-25*
