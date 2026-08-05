---
gsd_state_version: 1.0
milestone: v2.0
milestone_name: Plan-Aware Decision Engine — TODAY Verdict Wedge
status: "Phase 45 (Measurement & WTP Instrumentation) COMPLETE on main, all 4 plans executed strictly serial 45-01→45-04. 45-01: VerdictEvent composite-only local @Model (verdict/planned+adjusted kg/delta/differed/action/region label/reason/confidence/outcome/dates — NO raw HRV/RHR/sleep/HealthKit; source-grep guarded), additive schema (no migration), local-only by omission (absent from SyncService); VerdictEventRepository @MainActor log/recordOutcome/fetchAll/fetchRecent/mostRecentAwaitingOutcome; pure GreenLightEngine.compute(events:asOf:calendar:) — green-light rate (differing-day collapse, keptPlan excluded, nil-on-no-signal), activation rate, Day-7/30 retention, all date-injected. 45-02: VM captures lastHeadlineVerdictRaw/RegionRaw (was discarded); WorkoutLog wires verdictVM.onDecisionRecorded → repository.log via a stable @State repository (SC4 — seam never nil, source-grep + integration tested); VerdictOutcomeSheet (no-guilt right/wrong/unsure) for past planned-days. 45-03: VerdictMeasurementView — quiet green-light/activation/retention readout (clock read once at boundary, engine stays injected; honest nil-states: still-learning/too-early/lapsed; no accent/shadow/RoundedRectangle), quiet Profile 'Validation' NavigationLink. 45-04: SeanEllisStore (local-only injectable UserDefaults, deterministic shouldPrompt — threshold 5, re-qualifies after another threshold of new events, no baked .now in gate); SeanEllisPromptSheet (very/somewhat/not equal-weight); WorkoutLog mounts the trigger and routes 'very disappointed' → existing UpgradeSheet(trigger:.athletePro) for the revealed WTP/card-on-file hop (UpgradeSheet+SubscriptionService UNCHANGED; RevenueCat dashboard trial→paid offering config flagged DEFERRED-EXTERNAL in-source). DESIGN-compliant + en+zh-Hans throughout. App build green on sim CAF84E71; all new test classes green (VerdictEventModel/Repository/GreenLightEngine/VerdictEventLogging/GreenLightSurface/SeanEllisStore) + regression green (TodayVerdictService/VerdictDecisionApplier/DualRunFlagFence); no \" 2.swift\" dupes (stray CrossModalFatigueEngineTests 2.swift deleted). METRIC-01/02/03 + SC4 satisfied."
stopped_at: "Phase 45 (all 4 plans) complete on main (UNPUSHED). Commits on main (NOT a branch): 45-01 (ea1be33 test, 0d4444f feat, b1dd74d feat, 65750a7 test, bab384d feat, c9ded73 docs); 45-02 (a87e156 feat, 6fafbfa feat, e0ac1f3 docs+dup-removal); 45-03 (0bf2530 feat, 3d1f84a feat); 45-04 (b88ae0d feat, e51bc58 feat). Plus this docs/state commit. App build green on sim CAF84E71-BB64-491D-87C8-875A0143B26D; new+regression test classes green; no \" 2.swift\" dupes. Deferred-external (human, NOT a blocker): RevenueCat dashboard trial→paid offering config on athlete_pro + real-charge testing (RevenueCatConfig gitignored). Deferred-human UAT: on-device visual UAT of VerdictMeasurementView, VerdictOutcomeSheet, SeanEllisPromptSheet (light/dark, equal-weight, no-guilt reads-calm). Carried from prior phases: 44-02 verdict-card visual UAT, 43 verdict-write UAT, 42-03 Plan-Today UAT, 41-03 gate-ack, 41-01 dual-run UI UAT. v2.0 phases 41-45 ALL complete on main, push held. Next: v2.0 WTP/validation-launch gate + the batched on-device UAT pass + push."
last_updated: "2026-06-14T22:30:00.000Z"
last_activity: 2026-06-14 — Phase 45 (measurement & WTP instrumentation) all 4 plans complete on main
progress:
  total_phases: 5
  completed_phases: 4
  total_plans: 11
  completed_plans: 11
  percent: 80
---

# Project State

> ## ⚠️ CORRECTION 2026-07-26 — read before trusting anything below
>
> The frontmatter `status` / `stopped_at` fields were written 2026-06-14 and were
> never updated when the v1.6 launch pushed main on 2026-07-21. Two agents were
> independently misled by them in one session. Verified directly from `git` and
> source on 2026-07-26:
>
> - **"push held" / "~190 commits ahead of origin" is FALSE.** `git rev-list
>   --left-right --count origin/main...main` → `0 0`. Local and origin are
>   identical. All v2.0 engines are on origin (`TodayVerdictEngine`,
>   `CrossModalFatigueEngine`, `GreenLightEngine`, et al.).
> - **The verdict surface is LIVE in production**, not flag-gated off.
>   `VerdictSurfaceActivation.isEnabled` defaults `false`, but that default is a
>   fence for bare reads (keeps the legacy byte-identical golden-snapshot tests
>   green). Production opts in unconditionally at `DashboardViewModel.swift:406`.
> - **Cross-modal drives the verdict** since 2026-07-08
>   (`CrossModalShadowGate.crossModalDrivesVerdict` defaults `true`, revertible).
> - **v1.6 build 17 was REJECTED 2026-07-25** — no Terms of Use (EULA) link in the
>   metadata description body; second rejection of that class. Listing fix landed
>   at `AppStoreMetadata.md:63` / `:103`.
> - **The binding blocker to users is deployment, not build.** `tuwa-website` main
>   is 1 commit ahead of its origin (`bfed11f`, Apple EULA clauses — unpushed,
>   therefore undeployed), and the live site still serves coach-era `/terms`,
>   `/privacy`, `/support`. The App Store description now cites `tuwa.app/terms`,
>   so resubmitting before that route is fixed invites a third rejection.
>
> The deferred-UAT list in `stopped_at` is still accurate and still unrun. It is
> consolidated into a single ordered device pass at
> `.planning/notes/preship-uat-script-v16.md`.
>
> Rule that came out of this: for build, push, or flag state, read the system
> (`git`, source) — never a planning doc. Established via the CLAUDE⇄CODEX pair
> board (`.pair/`).

## Project Reference

See: .planning/PROJECT.md (updated 2026-06-13)
See: .planning/ROADMAP.md (v2.0 phases 41-45 appended 2026-06-13)

**Core value (redefined 2026-06-12):** Readiness-driven modulation of a user-authored hybrid plan with periodization-position awareness — your plan, made safe and optimal. Never writes the program, never a chatbot.
**Current focus:** v2.0 wedge — the plan-aware TODAY verdict for a single planned strength session (go/modify/hold + adjusted top-set number + one-line why), suggest-and-confirm.

## Current Position

Phase: 44 — Suggest-and-Confirm Verdict Surface (autonomy + nocebo guards) — COMPLETE ✅ (2 plans)
Plan: 44-01 DONE ✅ (MOD-10/11/12 VerdictDecisionApplier + TodayVerdictViewModel — state/decision layer) · 44-02 DONE ✅ (MOD-10/11/12 TodayVerdictCard + WorkoutLog wiring + en/zh strings + guard test) — both plans complete
Status: Phase 44 executed sequentially on main. 44-01: VerdictDecision value types + pure VerdictDecisionApplier (accept→verdictAppliedAt, keep→athleteOverrode, effectiveTargetKg resolves adjusted only once accepted — authored targetWeightKg NEVER written, source template never mutated) + TodayVerdictViewModel @MainActor @Observable (assemble inputs → evaluateAndWrite slots → headline display; accept/keepPlan/feelOverride emit VerdictDecision via onDecisionRecorded; cold-start defers honestly). 44-02: TodayVerdictCard anti-nocebo surface (action+reason hero, equal-weight Accept/Keep via one shared builder, first-class feel-override, quiet confidence, verdict state via text label + desaturated hairline — never red gate/accent), mounted top of WorkoutLog only when a today-plan exists; 16 verdictCard.* keys en+zh-Hans; TodayVerdictCardGuardTests fences DESIGN + nocebo copy. App build green on sim CAF84E71; 42 combined tests green; no \" 2.swift\" dupes. Deferred to human: 44-02 on-device visual UAT.
Last activity: 2026-06-14 — Phase 44 (suggest-and-confirm verdict surface) complete

## v2.0 Roadmap Summary

| Phase | Goal | Requirements |
|-------|------|--------------|
| 41. Substrate Activation + Cross-Modal Fatigue Carry | Activate dormant PRS pipeline on a verdict surface + build directional cross-modal carry (shadow-gated before it drives the verdict) | ACT-01, ACT-02 |
| 42. Plan Input | Designate today's planned session + additive-nullable adjustable targets (no migration, no sync change) | PLAN-10, PLAN-11 |
| 43. TODAY Verdict Engine | Go/modify/hold + evidence-bounded adjusted top-set number + one-line reason | VERDICT-01, VERDICT-02, VERDICT-03 |
| 44. Suggest-and-Confirm Verdict Surface | Nocebo-safe, autonomy-respecting UX (accept/decline, feel-override, keep-my-plan, never a red gate) | MOD-10, MOD-11, MOD-12 |
| 45. Measurement & WTP Instrumentation ✅ | VerdictEvent log + green-light signal + Sean-Ellis/WTP — live BEFORE validation launch (COMPLETE 2026-06-14) | METRIC-01, METRIC-02, METRIC-03 |

**Execution order:** 41 → 42 → 43 → 44 → 45 (strict critical path; coarse granularity).
**Sequencing constraints:** cross-modal (Phase 41) must shadow-validate before driving the verdict; measurement (Phase 45) must be live before the Phase 44 surface reaches any validation user.

## Performance Metrics

**Velocity:**

- Total plans completed: 54+ (v1.0: 14, v1.1: 9+, v1.2: 11, v1.3: 10, v1.4: 12, v1.5: 6; v1.5.1/v1.5.2/v1.6 substrate landed since)
- Average duration: carried from prior milestones
- Total execution time: carried from prior milestones

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| v1.0 phases 1-4 | 14/14 | -- | -- |
| v1.1 phases 5-8 | 9+ | -- | -- |
| v1.2 phases 9-12 | 11/11 | -- | -- |
| 13-16 (v1.3) | 10/10 | -- | -- |
| 17-20 (v1.4) | 12/12 | -- | -- |
| 21-22 (v1.5) | 6/6 | -- | -- |
| 24-30 (v1.6 substrate, dormant/flag-OFF) | landed | -- | -- |
| 31-37 (v1.5.1 UI) | landed | -- | -- |
| 38-40 (v1.5.2 UX) | landed | -- | -- |
| 41-45 (v2.0) | P41-P44 complete | P41 34m · P42 27m · P43 3 plans · P44 65m (44-01 ~35m, 44-02 ~30m) | ~10 min |

*Updated after each plan completion*

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- [Core redefinition 2026-06-12]: Tuwa = plan-aware decision support engine (modulate USER-AUTHORED hybrid plan; never writes programs; no chat coach)
- [Redefinition validated 2026-06-13]: MODIFY-SCOPE against 51 real self-coached hybrid athletes + 5 adversarial kills — TODAY horizon = wedge, MID latent, LONG hold; WTP is the real open risk
- [Hard product constraint]: verdict is suggest-and-confirm, feel-overridable, number+reason — never a red "don't train" gate (nocebo + autonomy cracks)
- [v2-verdict-engine research]: ~70% of the verdict engine already built + tested green, flag-gated OFF (dormant v1.6 PRS stack) — v2.0 ACTIVATES, does not rebuild
- [v2-crossmodal research]: the ONE genuine engine gap is directional cross-modal fatigue carry (FatigueIndexEngine is whole-body today); anchor + saturating concave modifier, NOT linear stacking; shadow-validate before it drives the verdict
- [v2-crossmodal research]: plan input reuses PrescribedWorkout/WorkoutTemplate/TemplateSet with additive-nullable fields — no migration, no sync-payload change
- [Founder's-playbook gate]: measurement (VerdictEvent / green-light / WTP) must be instrumented BEFORE the verdict reaches validation users — prerequisite, not follow-up
- [41-02 build] CrossModalFatigueEngine ships the cross-modal formula: per-region carry = Σ(srpeLoad·β_region·decay(Δdays)) + StrengthLoadEngine.perRegion (acute window); above-personal-normal elevation via reused deadband; saturating-concave penalty maxPenalty·(1−e^(−k·E)) (anti-linear-stacking, bounded); exerciseAdjustment = systemicFactor·(1−regionPenalty), multiplicative. Elevation baseline uses RAW un-decayed per-day load (steady-state ⇒ ratio≈1 ⇒ no penalty); decay applies only to carry magnitude.
- [41-02 project] The MAIN APP TARGET is NOT a file-system-synchronized Xcode group (only WorkloadAppTests + ScreenshotTests are synced) — new WorkloadApp/ source files MUST be registered with 4 explicit pbxproj entries; tests under WorkloadAppTests/ auto-discover.
- [41-03 build] Cross-modal logs DARK as the 4th shadow arm by APPENDING to ShadowPredictor.registeredArms() (= [baseline, cycleAware, prs, crossModal]) — the sole extension point; ShadowAnalyticsService loop, the generic ShadowArmPrediction store, and pairs()/metricsReport()/pairedMAEDifferenceCI() validate it with ZERO analytics changes. The arm encodes the cross-modal hypothesis within the (outcome, series) contract: recency-weighted above-normal elevation proxy (deadbanded) → concave saturating bounded nudge (k=2, maxNudge=2), sign-correct (depresses recovery/wellness/completion, raises pain), leak-free.
- [41-03 build] CrossModalShadowGate.crossModalDrivesVerdict is a COMPUTED gate { _override ?? false } (default FALSE) — no stored flag to assign in production; only the test-only _override mutates inside withEnabled. validationSummary is report-only (reuses existing metrics, adds no statistics, never flips the gate). Verdict influence is fenced until an explicit human shadow-validation pass — never a code merge. Pattern mirrors PRSActivation/VerdictSurfaceActivation shape + ActivationGateEvaluator no-mutation discipline.
- [42-01 build] TemplateSet carries five additive-nullable verdict-target slots (adjustedTargetWeightKg, adjustedTargetRPE, verdictReason, verdictAppliedAt, athleteOverrode) as PROPERTY-LEVEL defaults (nil/false) — existing rows decode without migration, init/deepCopyGroups untouched, and the hand-rolled SyncService SetDTO is NOT extended so the slots never serialize into groupsJson (proven by encodeGroups→decodeGroups omission test). Verdict writes the FROZEN prescription copy, never the source template.
- [42-02 build] PlannedSessionRepository expresses "today's planned session" as an existing PrescribedWorkout (no new hierarchy): planFromTemplate uses deepCopyGroups() (frozen, source untouched), planManualLift builds a one-off graph (templateId nil), fetchTodaysPlannedSession = fetch-all + Swift filter ([startOfDay, nextDay), non-skipped). Self-coached ⇒ athleteId reused as coachId. NO sync/push (PrescribedWorkout absent from SyncService; dormant pushPrescribedWorkout NOT reintroduced).
- [42-02 test] FIRST @MainActor-class-in-XCTest in the suite hit an iOS 26.1-sim libswift_Concurrency back-deploy deinit crash (swift_task_deinitOnExecutorMainActorBackDeploy → SIGABRT) when the repository was a synchronous-test-method local. FIX: own the ModelContainer/ModelContext/repository as stored XCTestCase props set in setUp + cleared in tearDown. Production code unaffected. Standing pattern for future @MainActor-repo tests.
- [42-03 build] Plan-Today UI is reuse-first + DESIGN.md-strict: PlanTodaySheet's load-template path presents the EXISTING TemplatePickerSheet (→ planFromTemplate); manual path = ManualLiftEntrySheet (→ planManualLift). WorkoutLog "+" start flow untouched; new item added to the ellipsis menu. cardStyle/SharpTextFieldStyle/Rectangle/Font.Tokens/8pt grid, .design toggle (no Apple green), NO accent/shadow/RoundedRectangle (grep-clean). en+zh-Hans for all 17 planToday.* keys. Both view files registered (4 pbxproj entries each, EE4203/EE4204).
- [43-01 build] TodayVerdictEngine is a PURE DERIVED verdict (NOT a 4th model): go/modify/hold from intensityCap/volumeModifier/sessionType. Map: rest/activeRecovery⇒HOLD (holds planned number, nocebo guard); volumeModifier≥0.95⇒GO; [0.85,0.95)⇒MODIFY via back-off-set cut (top-set load KEPT, volume-cut-preferred); <0.85⇒MODIFY via LOAD trim interpolated −5%→−10% hard-clamped to the −10% ceiling. Adjusted weight plate-snapped via PUBLIC WeightFormatter.snapToIncrement (ProgressionEngine.roundToNearest is private — not used), never rounds up past plan, sub-increment delta⇒GO. Cross-modal read through CrossModalShadowGate.crossModalDrivesVerdict (default OFF ⇒ ×1.0, gate-off-identical test proves zero influence). Registered AC4301* (4 pbxproj entries).
- [43-02 build] VerdictReasonBuilder (pure): one-line reason = ReasoningEngine.explainDecision prefix(1) (+prefix(2) join only when within 0.7 of the leader's |contribution|). Confidence = readiness.confidence carried in its OWN field, NEVER folded into reasonLine. Cross-modal cause (CrossModalResult.dominantReason) named ONLY when crossModalDrivesVerdict==true AND the region's 0..1 perRegionElevation out-presses the leading explainDecision |contribution| (dominance proxy = raw elevation, the directly-comparable down-pressure signal — bounded regionPenalty 0..0.10 would never out-press). Cold-start (decisionInput nil OR deferToPlan) ⇒ fixed defer copy + deferredToPlan=true (no fabricated trim). Registered AC4302* (4 pbxproj entries).
- [43-03 build] PRSReadinessInputBuilder.build body renamed to buildDetailed(...)->BuiltReadiness?{input,readiness,strain} (surfaces the two fused results it previously DISCARDED — sources the live VERDICT-03 reason path); build(...) re-added as a thin delegate buildDetailed(...)?.input (Phase-41 DashboardViewModel.buildDualRunMessage + cold-start-nil fences stay byte-green). TodayVerdictService @MainActor: top set = max-targetWeightKg non-warmup TemplateSet, region = muscleGroup?.region ?? .fullBody, writes adjustedTargetWeightKg/adjustedTargetRPE/verdictReason ONLY (never verdictAppliedAt/athleteOverrode = Phase 44; never the source template), nil planned RPE⇒adjustedTargetRPE nil else downward-cap min(plannedRPE,intensityCap). Production wrapper evaluateTodaysPlannedSession sources the real DecisionInput via makeDecisionInput(built:recommendation:); cold-start⇒plan-equal suggestion + defer copy. PlannedSessionRepository held as a STORED prop in init (avoids the @MainActor back-deploy deinit SIGABRT). Periodization-position input consciously // DEFERRED (no plan-position field yet). Registered AC4303* (4 pbxproj entries for the service; PRSReadinessInputBuilder already registered).
- [44-01 build] VerdictDecision.swift (Foundation-only) carries the decision layer: FeelOverride{feelingStrong,feelingRough}, VerdictAction{accepted,keptPlan,feel(_)}, VerdictDecision (composite-only event Phase 45 logs), TodayVerdictDisplay (pure render value), and pure enum VerdictDecisionApplier — applyAccept⇒verdictAppliedAt set + athleteOverrode cleared; applyKeepPlan⇒athleteOverrode set + verdictAppliedAt cleared (non-destructive reverse); effectiveTargetKg resolves adjusted ONLY once accepted, else authored plan wins. The authored targetWeightKg is NEVER written and the source WorkoutTemplate is provably never mutated (unit-test: mutate the deepCopyGroups() frozen copy, original untouched). TodayVerdictViewModel @MainActor @Observable holds service+repos as STORED props (deinit-safety); refresh() mirrors DashboardViewModel input assembly, drives evaluateAndWrite(crossModalResult:nil — gate OFF), builds the SESSION-headline display; accept/keepPlan/feelOverride apply to EVERY exercise's top set, persist, rebuild, emit a VerdictDecision (onDecisionRecorded = Phase-45 seam); feel.strong⇒keep, feel.rough⇒accept only where an adjustment exists (never fabricate a trim). Cold-start (built==nil)⇒.deferred + still-learning note. Registered AA4401/AA4402 (4 pbxproj entries each).
- [44-02 build] TodayVerdictCard (presentational: display + weightUnit + 3 callbacks) is the anti-nocebo suggest-and-confirm surface — micro-cap header (NOT a score) → action hero (exercise + planned→adjusted number by POSITION not color + caption + text state label) → reason line → quiet text3 confidence → equal-weight decision row via ONE shared button builder (single "Got it" when nothing to accept; quiet confirmed line once decided) → first-class feel-override pills. Verdict state = TEXT LABEL + supplementary desaturated left hairline (zoneCaution adjusted / zoneLow deferred / none as-planned) — never zoneDanger, never accent. Mounted in WorkoutLog above the carousel inside SectionContainer, gated on vm.display!=nil (no plan ⇒ byte-unchanged); VM built once in .task, refreshed on athlete + on Plan-Today sheet dismiss. 16 verdictCard.* keys en+zh-Hans (calm/no-guilt). TodayVerdictCardGuardTests source-greps the card for DESIGN-banned tokens (RoundedRectangle/.cornerRadius/.shadow/ColorTokens.accent/.system(/.zoneDanger/Color.red/green) + nocebo copy — card doc-comments reworded so no banned literal appears in source. Registered AA4403 (4 pbxproj entries).

### Pending Todos

None yet.

### Blockers/Concerns

- Cross-modal magnitude (%) is a heuristic, LOW confidence — must shadow-calibrate against the athlete's own outcomes (region β / τ decay / penalty constants are priors only); never present as precise science.
- WTP is the genuine open risk — over-instrument Phase 45; capture revealed (card-on-file / trial→paid) over stated.
- Commoditization clock: Garmin "Neuromuscular Readiness" targeted 2026; Whoop Strength Trainer imports plans via screenshot — wedge is one feature-flag from erosion; lean on cross-modal + plan-ownership, move fast.
- Dormant v1.6 PRS substrate + v1.5/v1.5.1/v1.5.2 work is on `main`, largely UNPUSHED and UAT-deferred (see MEMORY handoff) — v2.0 activates that substrate; confirm build-green state before Phase 41.
- [41-01] On-device VISUAL UAT of the now-active dual-run card (light+dark render, provisional placement below hero) is DEFERRED to a human before Phase 41 close — Task 3 human-verify checkpoint; code-verifiable DESIGN.md/naming checks already PASS.
- [RESOLVED 41-02] The four dead orphan test files (REDSRiskEngineTests, CoachRelationshipModelTests, CoachRosterViewModelTests, InviteServiceTests) have been quarantined out (moved to .planning/quarantine/); the WorkloadAppTests target now COMPILES and runs — verified via `build-for-testing` green at the 41-02 baseline and a full RED→GREEN run of CrossModalFatigueEngineTests (22/22). The stripped-feature source purge (migration-aware) remains tracked in MEMORY as "dead inert code purge".
- [41-02] Cross-modal MAGNITUDE constants (β region coefficients, τ decay, k saturation, maxPenalty cap) are HEURISTIC priors documented in-source — must shadow-calibrate against the athlete's own next-day soreness before they can drive any user-facing number (Plan 03 / Phase 45). Engine is DARK and isolated for now.
- [41-03] Cross-modal channel now logs DARK as the crossModal shadow arm and is FENCED from the verdict by CrossModalShadowGate.crossModalDrivesVerdict (default OFF). The gate stays OFF until shadow data accumulates and a human reviews the validation signal (paired-MAE CI vs baseline, region-soreness next-day agreement) — a FUTURE human shadow-validation decision, never a code merge. Phase 43 may only consume the channel AFTER that pass. The Task 3 human-verify "gate acknowledged" checkpoint was verified at code level (no human available) — explicit human acknowledgement still deferred to Phase 41 close, alongside the 41-01 on-device dual-run UI UAT.
- [42-03] Plan-Today UI on-device VISUAL + FLOW UAT is DEFERRED to a human (no human available this run): confirm 0pt corners / no shadows / General Sans / 8pt rhythm / NO accent in both sheets (light + dark), walk Path A (load template) + Path B (enter lift) and confirm a today PrescribedWorkout is created, and confirm the "+" start flow is unchanged. Code-verifiable DESIGN.md + flow checks PASS; consolidated into the deferred on-device UAT batch. The Localizable.xcstrings diff in 8017e52 is large only because the catalog keys were re-sorted on write — content intact (17 keys added, build resolves all keys).
- [44-02] Suggest-and-confirm verdict CARD on-device VISUAL UAT is DEFERRED to a human (no human available this run): in light + dark confirm the card sits at the top of WorkoutLog, LEADS with action + reason (not a bare readiness number), reads CALM (no red/stop-sign/alarm color, 0pt corners, no shadow, General Sans, 8pt rhythm); Accept and "Keep my plan" are EQUAL visual weight; keep is one tap, leaves the planned number visibly unchanged, no guilt copy; Accept on an adjusted suggestion shows the adjustment in use without destroying the authored number; feel-override ("I feel strong"/"I feel rough") is an obvious affordance that updates the decision; a hold/low verdict reads as number+reason, never a "don't-train"/"rest-day" gate. Code-verifiable DESIGN + nocebo grep guards GREEN, build green, state transitions unit-tested, equal-weight enforced structurally via the shared button builder — consolidated into the deferred on-device UAT batch.

### Roadmap Evolution

- Phases 41-45 added 2026-06-13: v2.0 Plan-Aware Decision Engine (TODAY Verdict Wedge) — NEW milestone, APPENDED. Core-identity pivot but a tightly-scoped wedge. Derived from 13 requirements (ACT/PLAN/VERDICT/MOD/METRIC). Critical path: substrate activation + cross-modal (shadow-gated) → plan input → verdict engine → suggest-and-confirm UX → measurement → validation-ready. v1.6 algorithm substrate is ACTIVATED here (was flag-OFF dormant); prior milestone history (through Phase 40) preserved, not reset.

## Session Continuity

Last session: 2026-06-14 — Phase 44 (suggest-and-confirm verdict surface) executed end-to-end: VerdictDecisionApplier + TodayVerdictViewModel (state/decision layer) → TodayVerdictCard + WorkoutLog wiring + en/zh strings + DESIGN/nocebo guard test
Stopped at: Phase 44 (both plans) complete on main (UNPUSHED). 44-01 (28b49fa test, ba5c0dc feat, 1fb0792 feat, f9cb283 docs); 44-02 (6f9105e feat, 9ae5a4c feat, 8a4f000 test). App build green on sim CAF84E71; 42 combined tests green (8 applier + 7 VM + 2 guard + DualRunFlagFence + VerdictSurfaceActivation + TodayVerdictService); no " 2.swift" dupes; MOD-10/11/12 marked complete in REQUIREMENTS.md; ROADMAP phase-44 row Complete. Deferred to human: 44-02 on-device visual UAT (light/dark, equal-weight, reads-calm). Carried: 43 verdict-write UAT, 42-03 Plan-Today UAT, 41-03 gate-ack, 41-01 dual-run UI UAT. Next milestone work: Phase 45 (Measurement & WTP — VerdictEvent log + green-light + Sean-Ellis/WTP; wire verdictVM.onDecisionRecorded to the logger).
Resume file: .planning/phases/44-suggest-and-confirm-verdict-surface/44-02-SUMMARY.md
