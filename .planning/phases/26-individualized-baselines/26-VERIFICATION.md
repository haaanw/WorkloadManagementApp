---
phase: 26-individualized-baselines
verified: 2026-05-30T19:15:00Z
status: passed
score: 8/8 must-haves verified
overrides_applied: 0
---

# Phase 26: Individualized Baselines Verification Report

**Phase Goal:** Build the robust individualized-baseline substrate (per-signal robust EWMA + Welford/MAD baselines, prequential no-leak personal z-scores, Altini CV early-warning on innovations, composite 0–1 confidence, day-bucketed inputs, a local-only never-synced `BaselineState` @Model, a pure stateless engine, and a seeded convergence report) — parallel and gated OFF; the flat 7-day mean stays the LIVE baseline (D-01..D-04, substrate-only).

**Verified:** 2026-05-30T19:15:00Z
**Status:** passed
**Re-verification:** No — initial verification (HEAD b088e00, after the CV re-tune)
**Targeted build:** `xcodebuild build-for-testing -only-testing:WorkloadAppTests/BaselineTierFenceTests` → **TEST BUILD SUCCEEDED**

## Goal Achievement

### Observable Truths (the 8 must-have items)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `BaselineState` local-only @Model — one row/athlete, flattened sub-states, app+test schema, NO Codable, ABSENT from SyncService | ✓ VERIFIED | `BaselineState.swift:32-127`; app schema `WorkloadApp.swift:81`; test schema `BaselineStateModelTests.swift:21`; SyncService grep empty; no `Codable` conformance |
| 2 | Pure STATELESS `BaselineEngine` — EWMA(λ)/Welford-M2/MAD×1.4826/Huber-clip; detect-on-raw / update-on-clipped; σ-floor + cold-start nil; NO Date/RNG | ✓ VERIFIED | `BaselineEngine.swift` `lambda():196`, Welford `step():414-418`, MAD `robustScale():221-233`, Huber `step():404-408`, σ-floor `score():267`, cold-start nil `:256,263`; no `Date(`/`.now`/RNG in code (only doc comment) |
| 3 | Prequential no-leak — separate score/step, z=(y−μ_{t-1})/σ_{t-1}, tied to RecoveryPipeline:196-202, no-leak test exists | ✓ VERIFIED | `score()` & `step()` are separate methods (`:251`, `:379`); RecoveryPipeline cutoff `:196-202` present; `BaselineEngineTests.test_noLeakOrdering:190` asserts divergence |
| 4 | Altini CV on INNOVATIONS, 3-level hysteresis; re-tuned (short 11, elev 1.50, high 1.70, minValid 20) → stable reads normal, rising still fires | ✓ VERIFIED | `cvUpdate():285` on raw innovations; `nextCVLevel():314` hysteresis; constants `:143,148,151,156`; report summary: stable CV→elev/high = `—`, rising fires elev day 25 / high day 30 |
| 5 | Composite 0–1 confidence, ~14→60d ramp, NO population prior, stale/gap cut | ✓ VERIFIED | `confidence():342-359` product of count/recency/disp; `confFloorDays=14`/`confFullDays=60`; `staleHardCutDays` hard cut `:349`; invariant asserts (conf≈0 early, 0.9 only after day 50) pass |
| 6 | `DayBucketer` — morning-window median, sleep last-night, no carry-forward, GAP, dedup; `fetchRestingHRHistory(days:)` additive; W-1 guard owned by bucketer | ✓ VERIFIED | `bucketMorningWindow():62`, `bucketSleep():96`, GAP `:84,113`, dedup `:75`; `foldBuckets()` W-1 monotonic guard `:136-164`; `HealthKitService.fetchRestingHRHistory:211` (additive) |
| 7 | Seeded convergence report — deterministic SplitMix64 + fixed anchor, byte-reproducible (hash test), artifact committed, invariants pass | ✓ VERIFIED | `BaselineConvergenceReportTests.swift` SplitMix64 `:79`, anchor `Date(timeIntervalSince1970:0):43`, hash test `:615-620`, invariant asserts `:544-611`; artifact git-tracked at `artifacts/26-convergence-report.md` (clean) |
| 8 | TIER-FENCE — machine-enforced lock on live `.suffix(7)` mean + no substrate in live paths; live engines byte-unchanged; no shadow arm | ✓ VERIFIED | `BaselineTierFenceTests.swift:78-115` source-grep gate; `RecoveryScoreEngine.computeBaseline:244` `.suffix(7)`; no Phase-26 commit touched RecoveryScoreEngine/RecoveryPipeline/ShadowPredictor; `registeredArms():167` returns `[baseline, cycleAware]` only |

**Score:** 8/8 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `WorkloadApp/Models/BaselineState.swift` | local-only @Model carrier | ✓ VERIFIED | 127 lines, flattened HRV/RHR/sleep, no Codable, no statistics math |
| `WorkloadApp/Services/BaselineEngine.swift` | pure stateless engine | ✓ VERIFIED | 442 lines, all named constants, no Date/RNG/live-symbol references |
| `WorkloadApp/Services/DayBucketer.swift` | pure input reducer + W-1 guard | ✓ VERIFIED | 190 lines, median/GAP/dedup/foldBuckets, Foundation-only |
| `WorkloadApp/Services/HealthKitService.swift` | additive `fetchRestingHRHistory(days:)` | ✓ VERIFIED | `:211`, existing fetchers `:187,:356` intact |
| `WorkloadAppTests/BaselineStateModelTests.swift` | persistence + sync-omission tests | ✓ VERIFIED | asserts BaselineState never in SyncService `:160` |
| `WorkloadAppTests/BaselineEngineTests.swift` | numerics-vs-oracle + no-leak | ✓ VERIFIED | 20KB, `test_noLeakOrdering:190` |
| `WorkloadAppTests/DayBucketerTests.swift` | bucketing/gap/dedup tests | ✓ VERIFIED | present in synced test group |
| `WorkloadAppTests/BaselineTierFenceTests.swift` | machine-enforced fence | ✓ VERIFIED | 116 lines, comment-stripping grep gate |
| `WorkloadAppTests/BaselineConvergenceReportTests.swift` | seeded deterministic generator | ✓ VERIFIED | invariant + hash tests |
| `artifacts/26-convergence-report.md` | committed report artifact | ✓ VERIFIED | 40KB, git-tracked, clean working tree |

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| App `Schema` | `BaselineState` | `WorkloadApp.swift:81` registration | ✓ WIRED | additive lightweight migration |
| `DayBucketer.foldBuckets` | `BaselineEngine.step` | W-1 monotonic guard | ✓ WIRED | `:156`, fold-once-per-advanced-day |
| `BaselineState` | `SyncService` | (must be ABSENT) | ✓ FENCED | grep empty + test-asserted |
| Live recovery path | substrate types | (must be ABSENT) | ✓ FENCED | tier-fence test strips comments, asserts no BaselineEngine/DayBucketer/BaselineState in RecoveryPipeline |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| — | — | None | — | No TBD/FIXME/XXX/TODO/HACK/PLACEHOLDER in any Phase 26 source or test file |

### Tier-Fence Forensics (byte-unchanged claim)

Git log of the Phase 26 commit range (`3fc79b0..b088e00`) confirms **no Phase 26 commit** modified:
- `RecoveryScoreEngine.swift` (last touched `9e9e95f`, Phase 24)
- `RecoveryPipeline.swift` (last touched `9e9e95f`, Phase 24)
- `ShadowPredictor.swift` (last touched `47fb9db`, Phase 25)

The re-tune commit `b088e00` touched only `BaselineEngine.swift`, the convergence test, and the report artifact — all substrate, none of the live path. `registeredArms()` returns exactly `[baseline, cycleAware]` (no new predicting arm). `computeBaseline` body remains `.suffix(7)`.

### Build / Test Note

- Test target compiles: `build-for-testing` for `BaselineTierFenceTests` → **TEST BUILD SUCCEEDED** on iPhone 17 Pro Max (`8E872500-703D-4292-9758-38ADFCCFB126`).
- Test files show 0 explicit pbxproj references, which is **correct and expected** — the test target is an Xcode 16 `PBXFileSystemSynchronizedRootGroup` (`project.pbxproj:361-363`); control files (`RecoveryScoreEngineTests.swift` etc.) also show 0. Files are auto-included by filesystem membership.
- Executor reports full Phase 26 suite 30/30 green; not re-run per instruction.

### Human Verification Required

None for code correctness. The D-04 result checkpoint (`artifacts/26-convergence-report.md`) is an `autonomous: false` deliverable requiring the user's review of the markdown convergence report as the Phase 26 result checkpoint — this is a planned product-review gate, not a code gap.

### Gaps Summary

No gaps. All 8 substrate-only must-haves are delivered in code, machine-enforced where the tier-fence demands it, and the live recovery path is provably byte-unchanged. The CV re-tune (b088e00) is internally consistent across engine constants, the regenerated report, and the updated invariant test (which uses the conservative "instability fires no later than clean" discriminator). One stale doc-comment at `BaselineConvergenceReportTests.swift:556` still says the CV "over-fires on clean Gaussian noise" — this is cosmetic; the actual post-retune summary table shows stable = 0 firings and the asserted invariant remains the discriminator, so it does not affect correctness.

---

_Verified: 2026-05-30T19:15:00Z_
_Verifier: Claude (gsd-verifier)_
