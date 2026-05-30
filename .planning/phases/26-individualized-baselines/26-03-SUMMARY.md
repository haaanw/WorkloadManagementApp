---
phase: 26-individualized-baselines
plan: 03
subsystem: baseline-substrate-input-layer
tags: [daybucketer, healthkit, tier-fence, idempotency, pure-struct]
requires: ["26-01 BaselineState", "26-02 BaselineEngine (median, SignalState, SignalConfig, step)"]
provides:
  - "DayBucketer (pure struct): bucketMorningWindow / bucketSleep -> [BucketedDay], median-of-morning-window, GAP-honest, dedup"
  - "DayBucketer.foldBuckets (W-1 idempotency owner): drives BaselineEngine.step once per advanced day"
  - "HealthKitService.fetchRestingHRHistory(days:) -> [(date,value)] (additive RHR mirror of fetchHRVHistory)"
  - "BaselineTierFenceTests (machine-enforced HIGH-risk invariant T-26-06)"
affects: ["26-04 (convergence report consumes DayBucketer output)"]
tech-stack:
  added: []
  patterns: ["pure Foundation-only struct with injected Calendar", "source-level grep-gate test via #filePath repo-root resolution + comment stripping"]
key-files:
  created:
    - WorkloadApp/Services/DayBucketer.swift
    - WorkloadAppTests/DayBucketerTests.swift
    - WorkloadAppTests/BaselineTierFenceTests.swift
  modified:
    - WorkloadApp/Services/HealthKitService.swift
    - "workload management/workload management.xcodeproj/project.pbxproj"
decisions:
  - "Comment-strip source before 'must NOT contain' tier-fence assertions — substrate type names appear in BaselineEngine doc comments (describing the fence) and would false-fail a naive contains()"
  - "W-1 idempotency guard implemented as DayBucketer.foldBuckets (the bucketer/caller), per 26-02's documented hand-off that the engine is dateless"
  - "morningWindowEndHour=11 lives as a DayBucketer static constant (BaselineConstants in 26-02 had no morning-window field); median reused from BaselineEngine.median"
metrics:
  duration: ~12m
  completed: 2026-05-30
---

# Phase 26 Plan 03: DayBucketer + RHR History + Tier-Fence Summary

Pure `DayBucketer` reduces raw HealthKit history to one gap-honest, dedup'd value per signal per calendar day (median morning window for HRV/RHR, last-night aggregate for sleep), owns the W-1 day-advance/idempotency guard, adds an additive `fetchRestingHRHistory(days:)`, and installs the machine-enforced tier fence proving the live 7-day mean is untouched.

## What was built

### Task 1 — DayBucketer + additive fetchRestingHRHistory (commit `66f4c6d`)
- **`DayBucketer`** — pure `struct`, Foundation-only, `Calendar` injected (used for `startOfDay` / `component(.hour)` only). No `import HealthKit`, no `Date.now`, no RNG.
  - **`BucketedDay { let date: Date /* startOfDay */; let value: Double? /* nil = GAP */ }`**, `Equatable`.
  - **`bucketMorningWindow(samples:rangeStart:rangeEnd:morningWindowEndHour:calendar:) -> [BucketedDay]`** — groups in-window samples (`hour < morningWindowEndHour`, default 11) by `startOfDay`; day value = `BaselineEngine.median(...)`; no in-window sample ⇒ GAP (`nil`). Ascending + dense over `[startOfDay(rangeStart) ... startOfDay(rangeEnd)]`.
  - **`bucketSleep(...)`** — one value/night keyed by `startOfDay(of: date)`, no morning-window filter (defensive intra-day median dedup).
  - **No carry-forward, no imputation; stale-sample dedup is structural** — a sample only lands on its own `startOfDay`, so a stale latest sample leaves later days as GAPs, never fake-stable repeats.
  - **Morning-window constant:** `static let morningWindowEndHour: Int = 11` on `DayBucketer` (26-02's `BaselineConstants` has no morning-window field; this is its home, tunable).
- **`HealthKitService.fetchRestingHRHistory(days:) -> [(date: Date, value: Double)]`** — mechanical mirror of `fetchHRVHistory(days:)`: `HKQuantityType(.restingHeartRate)`, same `fetchSamples(type:days:)` helper, `HKUnit.count().unitDivided(by: .minute())`. **Purely additive** — verified zero deletions vs `228130f`; existing fetches byte-unchanged.
- **pbxproj:** `DayBucketer.swift` → 4 app-target entries (`PBXBuildFile`, `PBXFileReference`, Services group, app `PBXSourcesBuildPhase`), IDs `DD2603...` mirroring BaselineEngine's `DD2602...`. Test files auto-included via synchronized `WorkloadAppTests` group.

### W-1 idempotency guard (this plan is the owner)
`DayBucketer.foldBuckets(state:buckets:config:calendar:) -> BaselineEngine.SignalState` drives `BaselineEngine.step` **exactly once per advanced bucketed day**:
- GAP days (`value == nil`) are **skipped** (no carry-forward).
- A day folds only when `startOfDay(day) > startOfDay(state.lastBucketedDate)` (strictly after, §2.4).
- Re-presenting the same or an older day is a **no-op** — the state passes through unchanged, so `foldBuckets(foldBuckets(s)) == foldBuckets(s)`. Each real fold stamps `lastBucketedDate = day`, advancing the monotonic cutoff. GAP days do not advance the cutoff.

### Task 2 — BaselineTierFenceTests (commit `b2ef962`)
Source-level grep-gate. Resolves files via `#filePath` → two parents up = repo root, then `appendingPathComponent("WorkloadApp/Services/...")`; **fails loudly** (`XCTFail`) if a path can't be read.
- `testLiveBaselineStillExists`: `RecoveryScoreEngine.swift` still contains the `computeBaseline(values: [Double]) -> Double?` signature **and** `.suffix(7)` (the trailing 7-day mean) → live baseline unchanged.
- `testSubstrateNotWiredLive`: comment-stripped `RecoveryPipeline.swift` contains none of `BaselineEngine` / `DayBucketer` / `BaselineState`.
- `testEngineDoesNotImportLivePath`: comment-stripped `BaselineEngine.swift` contains neither `RecoveryScoreEngine` nor `RecoveryPipeline` as code.

**Comment-stripping (deviation, Rule 1):** the fenced type names appear inside `BaselineEngine.swift` doc comments that *describe* the fence. The plan's literal "does NOT contain" assertion would false-fail on that prose. The test strips `//` and `/* */` comments before the "must NOT contain" checks, so it fires only on real code references — preserving the genuine regression-catch (a real wire-in still fails the test).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Comment-stripping in tier-fence "must NOT contain" assertions**
- **Found during:** Task 2
- **Issue:** `BaselineEngine.swift` lines 25/41/43 contain `RecoveryScoreEngine` / `RecoveryPipeline` inside doc comments documenting the fence; the plan's literal `XCTAssertFalse(contents.contains(...))` would have false-failed.
- **Fix:** added a `strippingComments(_:)` helper; "must NOT contain" assertions run on the comment-stripped source (the "must contain"/live-baseline check still runs on raw source). The test still genuinely fails if a real symbol reference is added.
- **Files:** WorkloadAppTests/BaselineTierFenceTests.swift
- **Commit:** b2ef962

## Verification

- `xcodebuild test ... -only-testing:WorkloadAppTests/DayBucketerTests` → **TEST SUCCEEDED**, 11/11 cases.
- `xcodebuild test ... -only-testing:WorkloadAppTests/BaselineTierFenceTests` → **TEST SUCCEEDED**, 3/3 cases.
- Combined run → **TEST SUCCEEDED**, 14/14 cases. Sim iPhone 17 Pro Max id `8E872500-703D-4292-9758-38ADFCCFB126`.
- Purity: `DayBucketer.swift` code has no `import HealthKit` / `.now` / `HKQuantityType` (only the doc comment mentions them).
- Additive HK: zero deletions in `HealthKitService.swift` vs `228130f`.
- xcstrings: no `Localizable.xcstrings` / `InfoPlist.xcstrings` churn appeared; nothing to discard.

## Self-Check: PASSED
- FOUND: WorkloadApp/Services/DayBucketer.swift
- FOUND: WorkloadAppTests/DayBucketerTests.swift
- FOUND: WorkloadAppTests/BaselineTierFenceTests.swift
- FOUND commit: 66f4c6d
- FOUND commit: b2ef962
