# GSD Debug Knowledge Base

Resolved debug sessions. Used by `gsd-debugger` to surface known-pattern hypotheses at the start of new investigations.

---

## dual-run-coldstart-fabricated-verdict — dual-run verdict surface fabricates a verdict on cold-start instead of deferring
- **Date:** 2026-06-13
- **Error patterns:** dualRunMessage, cold-start, verdict, honest-confidence, deferral, PRSReadinessInputBuilder, fatigueResult, baseline, fabricate, VerdictSurfaceActivation
- **Root cause:** PRSReadinessInputBuilder.build's only deferral guard was `guard let fatigue = fatigueResult`. On the cold-start path (no WorkloadSnapshot + no TrainingProfile → DashboardViewModel.isColdStartActive=false) FatigueIndexEngine.compute returns a NON-NIL neutral FatigueResult over empty inputs, so the strain-channel guard passed and the builder emitted a verdict synthesized from no personal data, violating the LOCKED honest-confidence deferral.
- **Fix:** Added a data-sufficiency guard in build() after computing the three personal z's — `guard hrvZ != nil || rhrZ != nil || sleepZ != nil else { return nil }`. personalZ is nil exactly in BaselineEngine.score's documented cold-start regime (μ==nil / count<2 / madBuffer<madMinValid=5), so pure cold-start defers. Reuses the engine's madMinValid convention rather than composite confidence (which is 0 even at 14 days due to the cCount floor and would over-defer populated-history tests).
- **Files changed:** WorkloadApp/Services/PRSReadinessInputBuilder.swift
---
