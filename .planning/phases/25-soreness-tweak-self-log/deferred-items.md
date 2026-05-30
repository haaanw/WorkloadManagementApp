# Deferred Items — Phase 25

## Pre-existing test failures (out of scope for 25-04)

Discovered while running the full `xcodebuild test` suite during plan 25-04 execution.
These failures are in **Phase 24 algorithm-moat code** and are unrelated to the 25-04 niggle
UI (NiggleLogSheet, Dashboard affordance, post-workout nudge). My changed files touch none of
the shadow/predictor/algorithm sources. Per the executor SCOPE BOUNDARY rule, these are logged,
not fixed, by 25-04.

Failing tests (target `WorkloadAppTests/ShadowPredictorTests`):
- `test_baselineArm_equalsBaselinePrediction_byteIdentical()`
- `test_cycleAwareArm_collapsesToBaseline_forUnknownPhase()`
- `test_cycleAwareArm_equalsCycleAwarePrediction_byteIdentical()`

Last commit to touch `WorkloadAppTests/ShadowPredictorTests.swift`: `9e9e95f` (feat(24-01)).
Deterministic (fails in isolation), so not a sim flake. Should be triaged by a Phase 24
follow-up, not Phase 25.

App `xcodebuild build` is **green**; all other test suites (FatigueIndexEngine, Subscription
gating, ProgressionEngine, ScreenshotTests, etc.) pass.
