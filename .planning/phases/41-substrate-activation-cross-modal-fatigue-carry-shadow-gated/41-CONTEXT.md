# Phase 41: Substrate Activation + Cross-Modal Fatigue Carry (shadow-gated) — Context

**Gathered:** 2026-06-13
**Status:** Ready for planning
**Source:** Orchestrator-authored from v2.0 research (`.planning/research/v2-verdict-engine.md`, `.planning/research/v2-crossmodal-and-measurement.md`)
**Requirements:** ACT-01, ACT-02

<domain>
## Phase Boundary

This phase turns ON the dormant readiness/strain engine substrate and builds the ONE genuinely new engine (directional cross-modal fatigue carry), shadow-validated before it influences anything user-facing. It is the foundation the Phase 43 verdict consumes.

**IN scope:**
- ACT-01: Activate the dormant PRS readiness pipeline so its outputs are computed live and reachable (un-gate, wire to a real surface — existing dashboard readiness/strain display is acceptable; the full suggest-confirm verdict CARD is NOT this phase).
- ACT-02: Build `CrossModalFatigueEngine` — regionalize endurance/conditioning sessions (sRPE × sportType → muscle region) and apply an anchor + saturating modifier so yesterday's run penalizes today's squat but spares bench. Run it DARK through the existing ShadowMetrics harness; an explicit shadow-validation pass — not a code merge — is the gate that lets it feed downstream.

**OUT of scope (later phases):**
- Plan input / today's-planned-session designation (Phase 42)
- The go/modify/hold verdict + adjusted-number engine (Phase 43)
- Suggest-and-confirm verdict UI card, nocebo framing (Phase 44)
- Measurement / VerdictEvent / WTP (Phase 45)
</domain>

<decisions>
## Locked Decisions

### Activate, do not rebuild
- ~70% of the engine substrate already EXISTS, built + tested green, flag-gated OFF (dormant v1.6 work). Per `v2-verdict-engine.md`: `ReadinessFusionEngine`, `StrainRiskEngine`, `BaselineEngine`, `AutoregulationEngine.recommendReadiness` (3×3 readiness×strain matrix), `ProgressionEngine`, `ReasoningEngine.explainDecision`, `ShadowMetrics`. The executor MUST locate the existing engines + their activation flag(s) (e.g. PRS activation flag referenced in STATE.md / `PRSDualRunCard`) and wire them, NOT re-implement.
- Preserve the existing honest-confidence gating (low-confidence baselines must degrade gracefully, never fabricate a verdict).

### Cross-modal is the one new engine
- `FatigueIndexEngine` is whole-body — it cannot express directional carry. Build a new `CrossModalFatigueEngine` (pure struct, static methods, per project conventions).
- Model: regionalize endurance/conditioning load via existing `sRPE`/`srpeLoad` × `sportType` → `MuscleGroup.region`; combine an anchor + saturating (`1 − e^(−k·E)`) modifier per region, multiplicatively with systemic readiness. NO naive linear penalty stacking (matches the HybridLoad insight from discovery).
- Direction is HIGH-confidence (interference-effect literature); MAGNITUDE is an honest, shadow-tuned heuristic — label it as such, do not over-claim precision.

### Shadow-gate before influence
- Cross-modal output runs through the existing `ShadowMetrics` harness DARK (logged, not surfaced) until an explicit validation pass. This is a phase success criterion. Do NOT let the new engine drive any user-facing number in this phase.

### Reuse + conventions
- Engines = pure structs with static methods, no state. Repositories = `@MainActor final class`. Follow existing per-muscle taxonomy (`MuscleGroup`, `LoadSource`, `StrengthLoadEngine.perRegion`, `LoadDistributionEngine`).
- Any schema change must be additive-nullable (no migration, no Supabase sync-payload change). Raw HealthKit never leaves device; composite-only.
- DESIGN.md constraints hold for any surfaced UI: 0pt corners (`Rectangle`, never `RoundedRectangle`), no shadows, General Sans / `Font.Tokens.*`, `ColorTokens` accent ONLY on the hero readiness number, 8pt-grid spacing.

### Build gate
- After each 3–5 file batch and at phase end: `xcodebuild build -scheme "workload management" -destination "platform=iOS Simulator,id=CAF84E71-BB64-491D-87C8-875A0143B26D" -configuration Debug` must end `** BUILD SUCCEEDED **`. (Known-alive sim — do NOT invent sim ids.) Baseline is already green as of 2026-06-13.
- Tests: pure-engine logic gets unit tests (XCTest) where existing engines have them. NOTE pre-existing blocker: a `#if DEBUG` font `assertionFailure` in `App/WorkloadApp.swift` can crash the XCTest host — if the suite won't run, rely on `xcodebuild build` green + targeted logic review and flag it, do not spin.
</decisions>

<canonical_refs>
## Canonical References (read before planning/implementing)

- `.planning/research/v2-verdict-engine.md` — exact existing engines, what's reusable vs new, activation flag, magnitude bounds, UX precedent
- `.planning/research/v2-crossmodal-and-measurement.md` — cross-modal formula, regionalization via existing models, schema approach, ShadowMetrics harness
- `.planning/notes/core-redefinition-plan-aware-engine.md` — the validated thesis + constraints
- `./CLAUDE.md` — architecture, conventions, DESIGN.md enforcement
- `./DESIGN.md` — visual constraints (read before any UI)
- Codebase: `WorkloadApp/Services/` (engines), `WorkloadApp/Models/Enums.swift` (LoadSource, SportType, MuscleGroup), `WorkloadApp/Models/` (PrescribedWorkout, WorkoutSession)
</canonical_refs>

<deferred>
## Deferred

Verdict engine (43), plan input (42), verdict UI (44), measurement (45). Full multi-week program ingestion, MID/LONG horizons — out of v2.0 entirely.
</deferred>

---
*Phase: 41-substrate-activation-cross-modal-fatigue-carry-shadow-gated*
*Context gathered: 2026-06-13 by orchestrator from v2.0 research*
