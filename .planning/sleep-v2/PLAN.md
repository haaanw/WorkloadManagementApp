# Sleep score v2 — build plan

Orchestrator: the v1.7 orchestrator session. Spec authority:
`.planning/v17-field-notes/research-sleep-score.md` (§1–§10, HAN's §7 rulings inside).
Branch: **`sleep-v2`** off `main` at the v1.7 head. **HARD RULE: no merge to `main` until
HAN has archived and uploaded build 18** — the release must not pick up engine code.

## Ground rules (carried from v1.7, binding)

1. Sessions never commit; the orchestrator commits after independent verification.
2. Sessions never run the full test suite (orchestrator verifies serially). Build with
   `-derivedDataPath ~/.tonus-dd-claude-<lane>`.
3. Status to `.planning/sleep-v2/status-<lane>.md`; a done without real command output
   is invalid.
4. Engines are pure structs, static methods, no state. All persistence through
   repositories; all personalization state in `BaselineState`, folded by
   `RecoveryPipeline`. Raw HealthKit data never leaves the device; stage minutes are
   **device-local** (HAN Q2). No UI work in this milestone — shadow phase has no surface.

## Decisions in force (research doc §5, §7, §9)

- Components + base weights: duration-vs-need 0.50 / continuity 0.15 / regularity 0.15 /
  deep 0.10 / REM 0.10. Regularity stays inside (Q6 default).
- **Re-anchor (HAN Q1): duration-only tops out ≈85; the last ~15 points come from the
  quality components. 100 = genuinely excellent night, never merely long.**
- Personalized need: cold-start 7.5h, 28-night gate, bounds 6.5–9.5h, weekly update,
  15-min deadband, ±10 min/week hysteresis, reset on source change; learning FREEZES in
  CHRONIC_IRREGULAR (Q9 default). Target moves silently (HAN Q3).
- Scenario profiles per §9.3/§9.4: BASELINE, HIGH_PRESSURE, HIGH_STRAIN_DAY (TSS OR
  active-energy trigger, Q10), ACUTE_SHIFT ⊻ CHRONIC_IRREGULAR, DEBT_CARRY, NAP_DAY
  (50% credit, cap 45 min, Q7). Deltas stack, clamp [0.05, 0.60], renormalize over the
  available tier's components (Q11). State vector + active profiles + final weights are
  stored per night for audit.
- Degradation ladder A→E; **Tier D must be BIT-IDENTICAL to today's
  `sleepDurationToScore` curve** (golden test), Tier E = today's neutral behaviour.
- Device focus: Apple Watch + Oura (stages via HealthKit). Whoop/Garmin tier check is a
  future item.
- Every §9.5 hypothesis (H-01…H-10) appears in code comments at the point it is used,
  by ID, so the registry and the implementation cannot drift silently.

## Phases

### Phase S1 — the pure engine (serial, one session)

`WorkloadApp/Services/SleepScoreEngine.swift` + tests. Input struct carries everything
(stage minutes, in-bed span, prior sleep end, midpoint stats, debt, need state, prior-day
load z-scores, nap minutes, tier); output = score 0–100, per-component contributions,
active profiles, final weights, confidence tier. Includes the §9.2 state-vector types and
the profile/composition logic. NO HealthKit, NO SwiftData, NO pipeline wiring.
Tests: component curves, the ≈85 duration ceiling (Q1), every profile trigger + the
stack/clamp/renormalize rules, tier ladder, and the Tier-D golden test (bit-identity
against `RecoveryScoreEngine.sleepDurationToScore` across the full minute domain).

### Phase S2 — state, fetch, pipeline fold (after S1 verified)

`BaselineState` sleep sub-state (stage EWMAs per source, midpoint SD-14, 7-night debt,
need estimate + gate/bounds/hysteresis/freeze), `HealthKitService` stage fetch
(asleepDeep/asleepREM/asleepCore/awake + inBed, per-source, iOS 17 API), and the
`RecoveryPipeline` fold that computes the v2 score **in shadow**: recorded, never driving
the live recovery score. `.pbxproj` for new files is this session's (backup first).

### Phase S3 — shadow dual-run instrumentation (after S2)

Per-night record: v1 sleep component vs v2 score, tier, profiles, weights — via the
existing shadow infrastructure patterns (`ShadowMetrics`, gate style of
`CrossModalShadowGate`). The §6 falsification criteria computed on demand. A quiet
readout is Profile-debug only if trivial; otherwise none (no UI milestone).
Exit gate: HAN dogfoods ≥6 weeks; the criteria decide whether v2 ever drives the score.

### Session S1 kickoff prompt

```
You are Session S1 (sleep engine) for Tuwa sleep score v2. Branch sleep-v2 (create from
main). Read .planning/sleep-v2/PLAN.md (rules + decisions bind you), then
.planning/v17-field-notes/research-sleep-score.md in full — §5, §7 rulings, §9 are your
spec. Build WorkloadApp/Services/SleepScoreEngine.swift as a pure struct (static, no
deps beyond Models/Enums) + WorkloadAppTests/SleepScoreEngineTests.swift. Honor: the Q1
re-anchor (duration-only ≈85 ceiling), profile composition §9.4, and the Tier-D golden
test proving bit-identity with RecoveryScoreEngine.sleepDurationToScore. Tag every
hypothesis-backed constant with its H-ID comment. Do NOT commit; do NOT run the full
suite — build your target and run ONLY SleepScoreEngineTests with
-derivedDataPath ~/.tonus-dd-claude-s1. .pbxproj: you may register your two new files
(backup first). Report real outputs to .planning/sleep-v2/status-s1.md.
```
