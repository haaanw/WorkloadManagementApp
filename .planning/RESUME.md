# RESUME — session handoff (2026-05-31, v1.6 27/28/29 verification-complete)

Read this + STATE.md + memory [[project_v16_progress]] + [[feedback_gsd_execution_gotchas]] + [[feedback_verify_before_claiming]] + [[feedback_subagent_driven]] FIRST.

## Git state
- Branch `main`, **NOT pushed**. origin/main = `2efce31` (Phases 25+26). Local HEAD = `2cd41aa` (Phase 29 docs). **24 commits ahead.**
- Phase 27: `4fc4ffa` `0fa3207` `75ba4cf` `f61719e`.
- Phase 28: `b9d3e56` `8446260` `fef8183` `64efc06` `a14422e` `eb10579` (+ doc commits). All behind `PRSActivation` (default FALSE).
- Phase 29: `7f5b03e` (PRSMasterActivation flag default FALSE + report-only ActivationGateEvaluator), `cb23fab` (shadow-validation report), docs `eb1fa0a`/`2cd41aa`.
- Sim: iPhone 17 Pro Max `8E872500-703D-4292-9758-38ADFCCFB126` (iOS 26.1, only installed runtime, alive). Boot before xcodebuild. Project `workload management/workload management.xcodeproj`, scheme `workload management`.

## What is DONE + verified (by me, real xcodebuild — NOT agent reports)
- **xcodebuild green:** 430 unit/0 fail at HEAD `90cec6b`; full Phase-29 run 448/0 (lone red `ScreenshotTests.test03_Recovery` = XCUITest flake, re-ran GREEN isolated). All fence families green: BaselineTierFence, AutoregulationFlagFence (4/4), DualRunFlagFence (7/7), ShadowDataContract, ShadowPredictor.
- **All 3 phases gated:** gsd-verifier PASS (27: 4/4 inv; 28: 4/4 inv; 29: 11/11 + 4/4 inv); adversarial code review 0 CRITICAL each; **codex review GATE PASS** (no P1).
- **Invariants hold:** live recovery score + live recommendation byte-identical with flags off; new models/columns local-only/never-synced; NOTHING activated; PRSActivation + PRSMasterActivation default FALSE.

## NEXT — resume here
1. **Phase 30 (shadow-engine quality fixes)** — user chose fix-now. 6 findings (all shadow/display/flag-on, none live), full spec in ROADMAP "### Phase 30". Run via gated workflow (plan→check→exec→build→verify→review), SERIAL, commit-local-only, fences must stay green, nothing activated. Findings: (1) StrainRiskEngine soft-tissue/rest-debt double-count; (2) LoadDistributionEngine endurance/strength scale-mismatch; (3) StrengthLoadEngine chronic⊇acute ~4× ratio; (4) StrengthLoadEngine RIR Int-truncation; (5) StrainRiskEngine easy-set coverage denominator; (6) PRSDualRunSurface targetVolume-nil first-time prescription.
2. **Phase 28 human UI visual review (OWED, user task)** — DEBUG build, enable PRSActivation, confirm dual-run "method updated" surface + real-workout adjustment render per DESIGN.md (0pt corners, no shadows, General Sans, 8pt grid, accent only on hero), say "Tuwa", NEVER "injury prediction". Wave-4 DashboardView wiring still deferred (PRSDualRunCard exists, call-site not wired).
3. **Push** — 24 commits, HELD until UI review. **NEVER push without user approval.**

## Phase 30 findings — full review provenance
Codex P2/P3: PRSDualRunSurface:75-79 (flag-on volume-nil), StrengthLoadEngine:256-257 (chronic⊇acute), StrengthLoadEngine:119 (RIR trunc), StrainRiskEngine:200-204 (easy-set coverage). Workflow adversarial review ALSO found (codex missed): StrainRiskEngine soft-tissue/rest-debt double-count (components 3+5+6), LoadDistributionEngine Foster-series scale mismatch. Phase-29 review minor (non-blocking, optional in P30): maturity-n uses PRS-only count vs paired-CI count; no-mutation grep guard misses spaceless assignment; dead `withEnabled` helper.

## Invariants (must keep holding)
shadow harness gated OFF; live recovery score byte-unchanged (`BaselineTierFenceTests`); live recommendation byte-unchanged with flags off (`AutoregulationFlagFenceTests` + `DualRunFlagFenceTests`); new models local-only/never-synced (no Codable, absent from SyncService); NO live activation; master flag FALSE; NEVER push without user approval; name is **Tuwa** (never Faros/Tonus/Tutrice in user copy).

## Open items (pre-existing)
- Supabase deploy (manual): `supabase functions deploy parse-workout` (Phase 22 muscle-enum).
- Device QA backlog (`.context/`). App Store v1.0 submitted 2026-04-30.
- ROADMAP v1.6 phases use bullet (not `### Phase NN:`) format → gsd-sdk roadmap.get-phase returns malformed for 24-29; milestone-wide, non-blocking. Phase 30 added as `### Phase 30:` heading.
- Pre-existing untracked files (Coach views, xcscheme, research dirs) — leave as-is, build green with them.
- Workflow scripts: `.claude/wf-phases-28-29-gates.js` (the gates run that produced this state).
