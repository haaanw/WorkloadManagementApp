# Phase 43: TODAY Verdict Engine — Go/Modify/Hold + Adjusted Number + Reason — Context

**Gathered:** 2026-06-13
**Status:** Ready for planning
**Source:** Orchestrator from v2.0 research + Phase 41/42 outputs
**Requirements:** VERDICT-01, VERDICT-02, VERDICT-03

<domain>
## Phase Boundary

Produce the verdict itself: collapse the existing readiness×strain recommendation into a go/modify/hold trichotomy, compute an evidence-bounded adjusted top-set number / back-off volume cut for today's planned lift, and assemble a one-line plain-language reason. This is a PURE DERIVED engine — no new model.

**IN scope:**
- VERDICT-01: a pure function → go/modify/hold for today's planned strength session, derived from the EXISTING `AutoregulationEngine.Recommendation` (`intensityCap`, `volumeModifier`, `sessionType`). NOT a 4th model.
- VERDICT-02: a concrete adjusted top-set number and/or back-off volume cut, bounded (−5% default, −10% ceiling, volume-cut preferred over load-cut), rounded to loadable plates (no "−6.2%"). Written into the Phase-42 nullable slots (`adjustedTargetWeightKg`, `adjustedTargetRPE`, `verdictReason`) as a SUGGESTION — not auto-applied.
- VERDICT-03: a one-line reason via `ReasoningEngine.explainDecision` naming the driving signals; no "injury prediction" copy; confidence reported separately.

**OUT of scope (later phases):**
- The suggest-and-confirm verdict UI card / accept-decline / nocebo framing (Phase 44 — it consumes this engine's output + the slots)
- Measurement / VerdictEvent / WTP (Phase 45)
- Flipping the cross-modal shadow gate ON (a future human shadow-validation decision)
</domain>

<decisions>
## Locked Decisions

### Derived, not a new model
- The verdict is a PURE function of the existing `AutoregulationEngine.recommendReadiness(...)` output. GREP/READ it first: `WorkloadApp/Services/AutoregulationEngine.swift` (`Recommendation { intensityCap: Double /*max RPE*/, volumeModifier: Double /*1.0 full*/, sessionType, ... }`). `PRSDualRunSurface.adjust` (lines ~52-72) ALREADY caps RPE at `intensityCap` and scales volume by `volumeModifier` — reuse/extend that logic; do NOT reinvent autoregulation.
- go/modify/hold mapping (derive, document thresholds): roughly `go` = full intensity/volume (cap≈planned, modifier≈1.0); `modify` = capped RPE or reduced volume; `hold`/swap = sessionType says rest/active-recovery or modifier very low. Make it a small, tested, deterministic mapping.

### Adjusted number: bounded, plate-rounded, suggestion-only
- Compute the adjusted top-set weight by applying the recommendation to the planned target (from the Phase-42 `TemplateSet`/`PrescribedWorkout` slots). Bound the LOAD cut to −5% default / −10% ceiling; PREFER a volume (back-off set) cut over a load cut where the recommendation implies it.
- Round to loadable plates via the existing `WorkloadApp/Utilities/WeightFormatter.swift` (and/or `ProgressionEngine` rounding) — never emit fractional-percent precision. Respect kg/lb unit.
- WRITE the suggestion into the nullable slots (`adjustedTargetWeightKg`, `adjustedTargetRPE`, `verdictReason`). Do NOT set `verdictAppliedAt`/`athleteOverrode` — those are the Phase-44 accept/decline action. Suggestion only; the plan is never silently overwritten.

### Cross-modal stays gate-controlled
- The engine READS cross-modal through `CrossModalShadowGate.crossModalDrivesVerdict` (built Phase 41-03, defaults FALSE). Gate OFF ⇒ cross-modal contributes ZERO to the number this ship. Wire it so flipping the gate later lights it up with no re-architecture. The reason names the cross-modal cause ("legs still loaded from yesterday's run") ONLY when the gate is on and cross-modal is the driver.

### Honest-confidence deferral
- On low confidence / cold-start, the verdict DEFERS to the plan ("going with your plan, still learning your baseline") rather than trimming on a guess. Reuse the same confidence signal that gates `PRSReadinessInputBuilder.build` (it returns nil on cold-start → defer). Report confidence SEPARATELY from the verdict.

### Conventions + gates
- Pure struct, static methods (engine convention). Reason copy is "Tuwa"-voice, NEVER "injury prediction" (grep-guarded test).
- New app-target .swift files need 4 explicit project.pbxproj entries each (app target is NOT a synchronized group); test files auto-discover. Do NOT leave " 2.swift" duplicate copies — delete any you see.
- Build/test gate (exact known-alive sim id, never invent): `cd "/Users/hanwen/Desktop/Tonus/workload management" && xcodebuild build -scheme "workload management" -destination "platform=iOS Simulator,id=CAF84E71-BB64-491D-87C8-875A0143B26D" -configuration Debug` ⇒ `** BUILD SUCCEEDED **`. Tests run (host does NOT crash). Cover the mapping, bounds, plate-rounding, gate-off cross-modal=0, cold-start defer, and no-injury-prediction.
- GIT: commit on `main`, never self-branch.
</decisions>

<canonical_refs>
## Canonical References

- `.planning/research/v2-verdict-engine.md` — magnitude bounds, derived-verdict design, UX precedent
- `.planning/phases/41-*/41-0{1,2,3}-SUMMARY.md` — what the activated engines + cross-modal gate expose
- `.planning/phases/42-*/42-0{1,2,3}-SUMMARY.md` — the plan-input slots (`adjustedTargetWeightKg` etc.) + `PlannedSessionRepository`
- Codebase: `WorkloadApp/Services/AutoregulationEngine.swift`, `PRSDualRunSurface.swift`, `ReasoningEngine.swift`, `ProgressionEngine.swift`, `CrossModalShadowGate.swift`, `WorkloadApp/Utilities/WeightFormatter.swift`, `WorkloadApp/Models/WorkoutTemplate.swift` (TemplateSet slots), `PrescribedWorkout.swift`
- `./CLAUDE.md`, `./DESIGN.md`
</canonical_refs>

<deferred>
## Deferred
Verdict UI card + accept/decline (44), measurement (45), cross-modal gate flip (future human shadow-validation), MID/LONG horizons (out of v2.0).
</deferred>

---
*Phase: 43-today-verdict-engine-go-modify-hold-adjusted-number-reason*
*Context gathered: 2026-06-13 by orchestrator*
