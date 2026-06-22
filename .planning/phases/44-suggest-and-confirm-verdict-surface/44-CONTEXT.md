# Phase 44: Suggest-and-Confirm Verdict Surface (autonomy + nocebo guards) — Context

**Gathered:** 2026-06-14
**Status:** Ready for planning
**Source:** Orchestrator from v2.0 research (pressure-test autonomy/nocebo cracks) + Phase 43 engine
**Requirements:** MOD-10, MOD-11, MOD-12

<domain>
## Phase Boundary

Wrap the Phase-43 verdict in the nocebo-safe, autonomy-respecting UX that the whole validation hinges on. This UX is a HARD PRODUCT CONSTRAINT (the pressure-test's #1 risk: experienced self-coached athletes reject an app that overrules them), not optional polish.

**IN scope (the 4 ROADMAP success criteria):**
- MOD-10 (SC1): suggest-and-confirm — the athlete explicitly ACCEPTS or DECLINES each suggestion; declines are recorded; the app NEVER silently overwrites the planned/authored numbers; accept and decline carry EQUAL visual weight.
- MOD-11 (SC2): feel-override is a first-class LOGGED input (athlete nudges/dismisses with their own feel, recorded); a low/hold verdict is framed as a NUMBER + REASON ("hold last week's weight, skip the PR"), NEVER a red "don't train" gate.
- MOD-12 (SC3): one-tap "keep my plan as written" leaves the planned session unchanged and records the decline with NO friction or guilt copy.
- SC4: no bare pre-session readiness number as the hero affordance; the surface leads with the action-on-the-plan + reason (validated anti-nocebo framing).

**OUT of scope:**
- The verdict computation itself (Phase 43 — this phase CONSUMES `TodayVerdictService` output + the Phase-42 slots)
- Measurement / VerdictEvent / WTP (Phase 45 — but design the accept/decline/feel actions so Phase 45 can log them cleanly)
</domain>

<decisions>
## Locked Decisions

### Consume, don't recompute
- The card consumes the Phase-43 output. GREP/READ: `WorkloadApp/Services/TodayVerdictService.swift` (the verdict + adjusted suggestion + reason + confidence it produces), the Phase-42 `TemplateSet` slots (`adjustedTargetWeightKg`, `adjustedTargetRPE`, `verdictReason`, `verdictAppliedAt`, `athleteOverrode`), `PlannedSessionRepository`, and where today's session surfaces (`WorkloadApp/Views/WorkoutLog/PlanTodaySheet.swift`, `WorkoutLogView.swift`).
- ACCEPT → apply the adjusted suggestion to the working set AND set `verdictAppliedAt`. DECLINE / keep-my-plan → set `athleteOverrode = true`, leave planned numbers unchanged. These two slots are exactly the ones Phase 43 deliberately did NOT touch — this phase owns them. Never mutate the source template.

### Anti-nocebo framing (the load-bearing UX)
- Lead with the ACTION ON THE PLAN + the one-line reason. Do NOT lead with a bare readiness/recovery number as the hero affordance (SC4).
- A hold/low verdict is expressed as a concrete plan action + reason ("hold last week's weight, skip the PR — readiness 12% below your baseline"), NEVER a red "don't train" / "rest day" gate, NEVER a stop sign. No alarm color, no big red number.
- Confidence is reported SEPARATELY and quietly (e.g. "still learning your baseline"), never as a fear lever.

### Equal-weight, friction-free, guilt-free
- Accept and Decline have EQUAL visual weight (same size/treatment — decline is not a tiny grey afterthought).
- "Keep my plan as written" is one tap, no confirmation nag, no guilt copy ("are you sure?", "this may hurt your progress" are BANNED).
- Feel-override is first-class: an obvious affordance to say "I feel good/bad" that nudges or dismisses the suggestion and is logged for Phase 45.

### DESIGN.md — hard, enforced
- 0pt corners (`Rectangle`, never `RoundedRectangle`, never `.cornerRadius`), NO shadows (hairline borders only), `Font.Tokens.*` / General Sans (never `.system()`/semantic styles), 8pt-grid spacing (multiples of 8).
- **`ColorTokens.accent` appears ONLY on the dashboard hero readiness score — NOT anywhere on this verdict card.** The verdict card uses neutral text tokens + optional hairline zone border.
- Zone/verdict state communicated through TEXT LABELS + optional colored border — NEVER color alone (go/modify/hold must be readable without color).
- Reuse existing primitives: `CardStyle`/`.cardStyle()`, `SharpTextFieldStyle`, `SetStepper`/`WeightBlockPicker`, the inline-banner pattern (`SpikeAlertBanner`/`PRBanner`/`ToastBanner`), `DeltaIndicator`. Both dark + light mode via `ColorTokens`. en + zh-Hans strings (this app is localized — add both).

### Conventions + gates
- Views are SwiftUI structs; state via `@Observable` ViewModel or `@State` as the codebase does; `@Environment(AppContainer.self)`. No raw HealthKit leaves device.
- New app-target .swift files need 4 explicit project.pbxproj entries each (app target NOT synchronized); test files auto-discover; NO " 2.swift" dupes (delete any).
- Build/test gate (exact known-alive sim, never invent): `cd "/Users/hanwen/Desktop/Tonus/workload management" && xcodebuild build -scheme "workload management" -destination "platform=iOS Simulator,id=CAF84E71-BB64-491D-87C8-875A0143B26D" -configuration Debug` ⇒ `** BUILD SUCCEEDED **`. Add logic/state tests for accept→verdictAppliedAt, decline→athleteOverrode, feel-override logged, and a grep-guard test that the surface contains NO banned nocebo copy ("don't train", "rest day" gate, "are you sure", guilt phrasing) and NO `ColorTokens.accent` / `RoundedRectangle` / `.shadow`.
- GIT: commit on `main`, never self-branch.
- The human-verify on-device VISUAL UAT (light/dark render, equal-weight check, feels-non-alarming judgment) cannot run headless — do all code-verifiable checks, document deferral, PROCEED.
</decisions>

<canonical_refs>
## Canonical References
- `.planning/research/plan-aware-thesis-pressure-test.md` — the autonomy + nocebo cracks this UX defuses (suggest-and-confirm, feel-override, disagreement, never-red-gate)
- `.planning/phases/43-*/43-03-SUMMARY.md` — TodayVerdictService output shape
- `.planning/phases/42-*/42-0{1,3}-SUMMARY.md` — TemplateSet slots + PlanTodaySheet
- Codebase: `WorkloadApp/Services/TodayVerdictService.swift`, `WorkloadApp/Views/WorkoutLog/PlanTodaySheet.swift` + `WorkoutLogView.swift`, `WorkloadApp/Components/` (CardStyle, SharpTextFieldStyle, SpikeAlertBanner, PRBanner, ToastBanner, SetStepper, DeltaIndicator), `WorkloadApp/Models/WorkoutTemplate.swift` (TemplateSet slots)
- `./DESIGN.md` (read fully before any UI), `./CLAUDE.md`
</canonical_refs>

<deferred>
## Deferred
Measurement/VerdictEvent/WTP (45). On-device visual UAT (human). Cross-modal gate flip (future shadow-validation). MID/LONG horizons.
</deferred>

---
*Phase: 44-suggest-and-confirm-verdict-surface*
*Context gathered: 2026-06-14 by orchestrator*
