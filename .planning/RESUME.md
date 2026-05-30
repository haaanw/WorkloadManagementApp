# RESUME — session handoff (2026-05-30)

Context-window clear requested. This is the pickup point. Read this + STATE.md + the memory index first.

## Git state
- Branch `main`, synced: local `HEAD` == `origin/main` == `f159a21`. Everything committed + pushed.
- Pre-existing UNTRACKED files on disk (there since session start, NOT this session's work, leave as-is unless user asks): `WorkloadApp/Views/Coach/PrescribeWorkoutSheet.swift`, `WorkloadApp/Views/Coach/TemplateListView.swift`, a stray `.xcscheme`. Build is green with them present.
- Build: GREEN. Unit tests: **262 pass / 0 fail / 2 skip** (the 2 skips = iOS-26 sim SwiftData in-memory optional-relationship predicate limitation, not a bug). Sim test runs occasionally flake on launch (`FBSOpenApplicationServiceErrorDomain`) — just `xcrun simctl shutdown all` + reboot the sim and retry.
- Sim: iPhone 17 Pro Max `id=8E872500-703D-4292-9758-38ADFCCFB126`. Scheme `workload management`, project `workload management/workload management.xcodeproj`.
- IMPORTANT: agents' SourceKit "Cannot find type / No such module" diagnostics are routinely STALE — always verify "build green" with a real `xcodebuild`, never trust the diagnostic cascade.

## What shipped this session (all pushed)
1. **v1.4 + v1.5 phases 19-22** — cycle UI, shadow modifiers (DARK/gated off), radial picker, muscle taxonomy (33 values).
2. **v1.3 live-feedback fixes** — HealthKit re-prompt bug (persisted `hasRequestedHealthKitAccess` + non-blocking probe + revocation 3-state), UI hierarchy upgrade across ALL screens (DESIGN.md revised: raised dark surface/surfaceEl, card/section primitives in `Components/CardStyle.swift`), invite-coach redesign, ACWR copy demoted to load-context. Codex-reviewed, P1+P2 fixed.
3. **Test infra fixed** — tests never actually ran before (synced group pointed at a stub); now 262 run+pass; ScreenshotTests fixed (accessibility ids).
4. **Branding** — Tuwa confirmed everywhere (Faros/Tonus dead). Target user NARROWED to amateur serious/part-time athletes without pro coaching/physio (CLAUDE.md + PROJECT.md + memory).
5. **Algorithm milestone v1.6 STARTED** — researched → designed → triple-reviewed (codex×2 + competitor research) → converged "minimum-credible v1" → **Phase 24 (validation foundation) COMPLETE**.

## Algorithm v1 (v1.6 milestone) — the plan
Scope LOCKED + user-approved. See `.planning/research/algorithm-moat-design.md` + `competitive-algorithm-analysis.md` (both with codex addenda) + memory `project_algorithm_v1_locked`. ROADMAP Phases 24-29.
- **24 ✅ DONE** — validation data-contract + shadow-harness upgrade (predictionDate/targetDate split fixes same-day leak; pure `ShadowMetrics` calibration/Spearman/blocked-CV/block-bootstrap; generic `ExperimentalArm` interface + `ShadowArmPrediction` model; legacy columns kept PARALLEL as safe fallback; gated OFF, local-only).
- **25 NEXT** — soreness/tweak self-log (SwiftData model + small UI). Low-risk. Unlocks honest Strain-Risk validation. Also wire wellness-history + injury-count into the dashboard fatigue path (currently empty/hardcoded-0 — codex found this).
- **26** — individualized baselines (robust EWMA/Welford/MAD + Altini 60-day normal-band + CV early-warning; prequential no-leak z-scores; day-bucketed inputs). **First real scoring model — user wants a checkpoint at its result.**
- **27** — strength-load model: per-muscle hard sets + relative-intensity buckets (est-1RM/RPE/RIR from SetRecord/ExerciseEntry, NOT raw tonnage) fused with sRPE into Strain-Risk channel.
- **28** — Readiness fixed sign-constrained glass-box fusion + decision-level explanations (upgrade ReasoningEngine) + swap AutoregulationEngine matrix (recovery×ACWR)→(readiness×strain-risk) with dual-run + "method updated" messaging.
- **29** — shadow validation run + activation gates (MAE beat ≥3/4 w/ bootstrap CI, Spearman≥0.50, calibration∈[0.8,1.2]); activation flag stays OFF until gates pass.
- DROPPED from v1 (codex: unsound on consumer data): per-user Kalman Q/R learning, per-user logistic weight tuning. Honest positioning: wedge = fusion-to-prescription across strength+endurance, explained, on owned hardware — real positioning, NOT a durable moat (Bevel/Athlytic/WHOOP-Coach can copy fast). Defensibility = trust + transparency + strength-hybrid workflow quality.

## How to resume
The user chose "Continue — Phase 25, then 26" was NOT selected; they said "save progress, clear context, then resume." On resume, re-offer: continue with Phase 25 (soreness log) then 26 (baselines, checkpoint), or per user's direction. ALWAYS use the sub-agent-driven system (plan agent → execute agent → real build/test verify → /codex for adversarial review). See memory `feedback_subagent_driven`.

## Open items (user actions / outstanding)
- **Supabase deploy** (user's manual step): `supabase login` → `supabase link --project-ref <ref from dashboard Project Settings>General>Reference ID>` → `supabase functions deploy parse-workout`. Activates the 33-value muscle enum for LLM import. Function at `Supabase/functions/parse-workout/` (case-insensitive FS resolves to `supabase/functions/`).
- **Device QA** (user): review `.context/qa-screenshots/` (12 PNGs, 6 screens light+dark — visual brand sign-off for UI upgrade) + run `.context/DEVICE-QA-CHECKLIST.md` (HealthKit connect/revoke, radial-picker gestures, zh-Hans terms — needs real device).
- **Pre-existing**: AutoregulationEngine headlines are raw English literals (Phase-23 i18n gap) → reframed ACWR headline English-only in zh-Hans; the 2 Coach untracked files; the 2 skipped tests.
