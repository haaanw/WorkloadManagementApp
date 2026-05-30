# RESUME — session handoff (2026-05-30, post Phase 25+26)

Context-clear requested. Pickup point. Read this + STATE.md + memory index (esp. [[project_v16_progress]] + [[feedback_gsd_execution_gotchas]]) first.

## Git state
- Branch `main`, **synced**: `HEAD` == `origin/main` == `09d339e`. Everything committed + PUSHED.
- Pre-existing UNTRACKED files (there since long ago, NOT this session, leave as-is): the 2 Coach views (`PrescribeWorkoutSheet.swift`, `TemplateListView.swift`), stray `.xcscheme`, `.context/`, `algorithm research file/`, etc. Build green with them.
- Sim iPhone 17 Pro Max id `8E872500-703D-4292-9758-38ADFCCFB126`; scheme `workload management`; project `workload management/workload management.xcodeproj`.
- Agent SourceKit "Cannot find type/module" diagnostics are routinely STALE — only real `xcodebuild` proves green. After any enum/shared-type change, run the FULL test suite (an executor missed a 3-test regression this session by only running its own suite).

## What shipped this session (all pushed)
v1.6 Algorithm Moat **Phases 25 + 26 complete** (sub-agent-driven: discuss→research→plan→plan-check→execute waves→verify, both with human checkpoints you approved; /codex GATE PASS on the risk items).
- **Phase 25 — Soreness/niggle self-log** (verifier PASS 6/6): local-only `SorenessLog` @Model + `NiggleType`; `.niggleSeverity` graded shadow outcome (target-day, 0-if-none, both arms nil); `NiggleInjuryDeriver` (DOMS-excluded, type∈{pain,tweak} AND (limitedTraining OR sev≥7), 28d) wired into Dashboard fatigue path (fixed hardcoded 0/nil/[] at DashboardViewModel ~:236/:252); `NiggleLogSheet` + Dashboard entry + non-blocking post-workout nudge.
- **Phase 26 — Individualized baselines, SUBSTRATE-ONLY** (verifier PASS 8/8): pure `BaselineEngine` (EWMA half-life→λ / Welford-M2 / MAD×1.4826 / Huber-clip; prequential no-leak z = score(t-1)→step(t); σ floor; Altini CV-on-innovations 3-level hysteresis, re-tuned cvShortWindow=11/cvElevated=1.50/cvHigh=1.70/cvMinValid=20 after report showed clean-noise over-fire; composite 0–1 confidence, NO population prior); `DayBucketer` (morning-window median, no carry-forward, GAP, stale-dedup) + additive `HealthKitService.fetchRestingHRHistory(days:)`; local-only `BaselineState` @Model; seeded byte-reproducible convergence report at `.planning/phases/26-individualized-baselines/artifacts/26-convergence-report.md` (robust μ beats flat 7-day mean 6/7 traces, ~6× less outlier movement).

**Invariants holding:** shadow harness gated OFF; live recovery score BYTE-UNCHANGED (machine-enforced `BaselineTierFenceTests` locks `RecoveryScoreEngine.computeBaseline` = `.suffix(7)`); NO predicting shadow arm yet (deferred to Phase 28); all new models local-only/never-synced (no Codable, absent from SyncService).

## NEXT — Phase 27 (start here)
**Phase 27: Strength-load model + Strain-Risk fusion.** Per-muscle hard sets + relative-intensity buckets (est-1RM / RPE / RIR from `SetRecord`/`ExerciseEntry`, NOT raw tonnage); fuse with sRPE/TRIMP endurance load + `FatigueIndexEngine` (FEA lineage) + Foster monotony/strain (completeness-gated) into the **Strain-Risk** channel. Honest "load-tolerance context / overreaching caution", NEVER "injury prediction".

**How to resume (sub-agent-driven, per [[feedback_subagent_driven]]):**
1. Phase 27 has NO dir yet → `/gsd-discuss-phase 27` (scouts + asks gray areas, creates the phase dir the parser needs).
2. Then `/gsd-plan-phase 27` (research→plan→plan-check), then `/gsd-execute-phase 27` — **run waves SERIAL** (commit directly to main, no branch) to avoid the parallel-executor collision hit this session ([[feedback_gsd_execution_gotchas]]). Tell executors to DISCARD xcstrings build churn.
3. Real `xcodebuild` verify each wave; full suite after shared-type changes; /codex review before push; user checkpoints for any UI + the Strain-Risk result.
4. Locked context to feed planners: `.planning/research/algorithm-moat-design.md` (esp. Layer-3 Strain-Risk + codex v1 verdict §299-327), `competitive-algorithm-analysis.md`, Phase 25 `SorenessLog`/`NiggleInjuryDeriver` (soft-tissue memory input), Phase 26 `BaselineState`/`BaselineEngine` (baseline substrate Strain-Risk consumes). Strain-Risk is a HEURISTIC flag in v1 (NOT the logistic fusion — that's Readiness in Phase 28).

## Open items (user actions / pre-existing, unchanged)
- Supabase deploy (manual): `supabase functions deploy parse-workout` (Phase 22 muscle-enum).
- Device QA backlog (`.context/qa-screenshots/`, `.context/DEVICE-QA-CHECKLIST.md`).
- App Store v1.0 status (submitted 2026-04-30) — see memory.
