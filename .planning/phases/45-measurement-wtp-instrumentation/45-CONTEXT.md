# Phase 45: Measurement & WTP Instrumentation — Context

**Gathered:** 2026-06-14
**Status:** Ready for planning
**Source:** Orchestrator from v2.0 research (founder's-playbook MVP measurement gap) + Phase 44 hooks
**Requirements:** METRIC-01, METRIC-02, METRIC-03

<domain>
## Phase Boundary

Instrument the validation layer BEFORE the verdict ships to validation users — the founder's-playbook MVP gate ("build the measurement framework before the first user"). This closes the v2.0 loop: it proves whether the verdict earns its keep.

**IN scope (the 4 ROADMAP success criteria):**
- METRIC-01: a `VerdictEvent` logged per planned session — verdict, suggested-vs-planned numbers, whether they DIFFERED, accept/decline action, and a post-session self-reported outcome — COMPOSITE-ONLY (no raw HealthKit; region labels + deltas only).
- METRIC-02: compute the GREEN-LIGHT signal = differing-verdict days where the athlete acted on the suggestion AND reported it was right — surfaced alongside activation rate and Day-7 / Day-30 retention.
- METRIC-03: capture a Sean-Ellis disappointment question ("how would you feel if you could no longer use this") + a willingness-to-pay / card-on-file signal via the EXISTING RevenueCat path (trial→paid).
- SC4: instrumentation is live + verified BEFORE the verdict surface is exposed to any validation user (prerequisite, not follow-up).

**OUT of scope:** MID/LONG horizons, cross-modal gate flip, any new training logic. This phase only OBSERVES.
</domain>

<decisions>
## Locked Decisions

### Reuse the Phase-44 hook + existing patterns
- The accept/decline/feel event already exists: `TodayVerdictViewModel.onDecisionRecorded: ((VerdictDecision) -> Void)?` (WorkloadApp/ViewModels/TodayVerdictViewModel.swift:35) emitting `VerdictDecision` (WorkloadApp/Services/VerdictDecision.swift). WIRE this hook → VerdictEvent logging. Do NOT re-plumb the surface.
- `VerdictEvent` is a local `@Model` following the `SorenessLog` / `CyclePredictionLog` analogs (local-only, NOT synced to Supabase — verify it's excluded from every SyncService DTO). Add to the SwiftData schema (`WorkloadApp.swift` container) additively.
- Repository = `@MainActor final class` taking `ModelContext` (project convention).

### COMPOSITE-ONLY privacy (hard guardrail)
- `VerdictEvent` stores ONLY: the verdict (go/modify/hold), suggested vs planned numbers + their delta, a `differed: Bool`, the action (accepted/keptPlan/feel), a muscle REGION label, the post-session self-reported outcome, and dates/confidence band. It MUST NOT store raw HRV/RHR/sleep/HealthKit values. Add a grep-guard/review test asserting no raw-biometric field names on the model. Never leaves device beyond composite (mirrors the project's raw-HealthKit-never-syncs rule).

### Green-light is a pure engine
- `GreenLightEngine` (pure struct, static methods) over `[VerdictEvent]`: green-light rate = (differing-verdict days where action≠keptPlan AND outcome=="right") / (differing-verdict days). Also compute activation rate (sessions with a verdict acted on / planned sessions) and Day-7 / Day-30 retention (inject `asOf`/calendar — deterministic, testable; do NOT bake `.now`). Surface in a small, quiet internal/profile analytics view (not a hero affordance).

### Post-session outcome + Sean-Ellis + WTP
- Post-session outcome: a lightweight self-report ("was the call right?" — right / wrong / unsure) captured after a planned session that had a verdict; stored on the VerdictEvent. No guilt copy.
- Sean-Ellis: an in-app prompt ("How would you feel if you could no longer use Tuwa?" → very / somewhat / not disappointed), shown at a sensible trigger (e.g. after N logged verdict sessions), answer stored locally. DESIGN.md-compliant.
- WTP / card-on-file: REUSE the existing `SubscriptionService` + `UpgradeSheet` (RevenueCat). Wire the validated-intent → existing paywall / trial start. The actual RevenueCat OFFERING config (trial→paid product) is EXTERNAL dashboard setup (RevenueCatConfig is gitignored) — the CODE path is buildable here; flag the dashboard config + real-charge testing as deferred-external/human.

### SC4 ordering guard
- Measurement must be wired + verified before the verdict surface reaches validation users. v2.0 is NOT yet shipped (push held, not on App Store), so this holds. Ensure `onDecisionRecorded` is wired to logging in THIS phase so no validation user can hit the verdict without a VerdictEvent being recorded. Note it in must_haves.

### DESIGN.md + conventions + gates
- Any UI (Sean-Ellis prompt, outcome capture, analytics view): 0pt corners (Rectangle), no shadows, Font.Tokens.*, 8pt grid, dark+light via ColorTokens, accent ONLY on dashboard hero (NOT here), en+zh-Hans strings.
- Pure-struct engine; @MainActor repository; additive-nullable schema, no migration; @MainActor stored-property test pattern (avoid iOS 26.1-sim deinit SIGABRT).
- New app-target .swift files = 4 explicit pbxproj entries each; tests auto-discover; no " 2.swift" dupes (delete any). Build gate exact sim id CAF84E71-BB64-491D-87C8-875A0143B26D ⇒ `** BUILD SUCCEEDED **`. Tests run (host does NOT crash). Commit on `main`, NEVER self-branch.
- Tests: VerdictEvent log written on each decision (via the hook), composite-only (no raw-biometric fields), GreenLightEngine math (differing/acted/right; activation; retention with injected dates), VerdictEvent excluded from sync DTOs, Sean-Ellis capture, no-guilt-copy grep guard.
</decisions>

<canonical_refs>
## Canonical References
- `.planning/research/plan-aware-thesis-pressure-test.md` — the green-light signal definition + WTP-is-the-real-risk + the 5-person validation framing
- `.planning/phases/44-*/44-0{1,2}-SUMMARY.md` — the `VerdictDecision` event shape + `onDecisionRecorded` hook
- Codebase: `WorkloadApp/ViewModels/TodayVerdictViewModel.swift` (onDecisionRecorded), `WorkloadApp/Services/VerdictDecision.swift`, `WorkloadApp/Models/SorenessLog.swift` + `CyclePredictionLog.swift` (local-only @Model analogs), `WorkloadApp/Services/SubscriptionService.swift` + `WorkloadApp/Views/Subscription/UpgradeSheet.swift` (RevenueCat), `WorkloadApp/App/WorkloadApp.swift` (schema), `WorkloadApp/Services/SyncService.swift` (confirm VerdictEvent excluded)
- `./CLAUDE.md`, `./DESIGN.md`
</canonical_refs>

<deferred>
## Deferred
RevenueCat dashboard offering config (trial→paid product) + real-charge testing (external/human). Real validation-cohort data + true calendar-elapsed Day-7/30 (needs real users/time — the COMPUTATION is built + tested here with injected dates). On-device visual UAT (human). MID/LONG horizons.
</deferred>

---
*Phase: 45-measurement-wtp-instrumentation*
*Context gathered: 2026-06-14 by orchestrator*
