import Foundation

/// Phase 28, Wave 4 — PURE builder that RECOMPUTES a REAL `AutoregulationEngine.ReadinessInput`
/// from data already available on the Dashboard load path (PRS-28-04 / PRS-28-05).
///
/// ## Why recompute (the central gray-area decision)
/// There is NO live readiness/strain source to "reuse": `ReadinessFusionEngine.compute` and
/// `StrainRiskEngine.fuse` are called in unit tests only — never in any production file today.
/// `BaselineState` (@Model) is in the schema but is NEVER written in production (the `DayBucketer` /
/// `BaselineEngine.step` fold runs only in tests), so persisted personal z-scores do NOT exist at
/// runtime. The only non-fabricating option is to RECOMPUTE with the SAME engines over the
/// athlete's REAL history. This builder therefore:
///   - folds `BaselineEngine.step` over the athlete's REAL `recentSnapshots` HRV/RHR/sleep series
///     (ascending), then `score`s today's REAL raw value → a real personal z per signal;
///   - feeds those real z's into `ReadinessFusionEngine.compute` → real readiness (0-100) + zone;
///   - runs the REAL `StrengthLoadEngine` / `LoadDistributionEngine` over the athlete's real
///     sessions and fuses with the REAL `FatigueResult` via `StrainRiskEngine.fuse` → real
///     `StrainRiskZone`.
///
/// ## No fabrication
/// Every field traces to a real engine output or a real datum. Cold-start (`count < 2` or buffer
/// below `madMinValid`) yields a `nil` z — the fusion engine EXCLUDES it and renormalizes over the
/// present signals; we NEVER mean-impute. `build(...)` returns `nil` (defers, no fabricated verdict)
/// in EITHER honest-confidence case: (a) the strain channel cannot be honestly computed (the real
/// `FatigueResult` is unavailable — cold-start suppressed it); or (b) NO signal has a usable personal
/// baseline (all three personal z's are nil — pure cold-start with no history), so the readiness side
/// would be synthesized from nothing. In both the caller leaves `dualRunMessage` nil.
///
/// ## Purity
/// Foundation-only, deterministic, no SwiftData fetch, no baked-in `.now` — `asOf` + `calendar` are
/// injected (mirrors the engine convention). Flag-agnostic: it is only ever CALLED inside the
/// `if PRSActivation.isEnabled` guard in `DashboardViewModel`, so the flag-off cost is zero.
///
/// Copy is "Tuwa"-voice and NEVER frames a signal as harm-forecasting (grep-guarded).
enum PRSReadinessInputBuilder {

    /// The fully-surfaced readiness build (Phase 43-03): the collapsed `ReadinessInput` the
    /// autoregulation path consumes, PLUS the two FUSED results (`ReadinessFusionEngine.ReadinessResult`
    /// and `StrainRiskEngine.StrainRiskResult`) the verdict REASON path needs to assemble a real
    /// `ReasoningEngine.DecisionInput`. These two results are computed internally by the fold and were
    /// previously DISCARDED at the collapsed return — `buildDetailed` stops discarding them so the live
    /// VERDICT-03 reason path is sourced (not test-injected-only).
    struct BuiltReadiness {
        let input: AutoregulationEngine.ReadinessInput
        let readiness: ReadinessFusionEngine.ReadinessResult
        let strain: StrainRiskEngine.StrainRiskResult
    }

    /// Recompute a REAL `AutoregulationEngine.ReadinessInput` from load() data, or `nil` when the
    /// strain channel cannot be honestly computed (no real `FatigueResult`). Thin delegate: returns
    /// `buildDetailed(...)?.input` so the Phase-41 call site (`DashboardViewModel.buildDualRunMessage`)
    /// and the existing cold-start-nil behavior stay byte-compatible.
    static func build(
        recentSnapshots: [RecoverySnapshot],
        latestHRV: Double?,
        latestRHR: Double?,
        latestSleepMinutes: Double?,
        allSessions: [WorkoutSession],
        fatigueResult: FatigueIndexEngine.FatigueResult?,
        daysSinceRest: Int,
        wellnessScore: Double?,
        acwr: Double,
        acwrZone: ACWRZone,
        asOf: Date,
        calendar: Calendar
    ) -> AutoregulationEngine.ReadinessInput? {
        buildDetailed(
            recentSnapshots: recentSnapshots,
            latestHRV: latestHRV,
            latestRHR: latestRHR,
            latestSleepMinutes: latestSleepMinutes,
            allSessions: allSessions,
            fatigueResult: fatigueResult,
            daysSinceRest: daysSinceRest,
            wellnessScore: wellnessScore,
            acwr: acwr,
            acwrZone: acwrZone,
            asOf: asOf,
            calendar: calendar
        )?.input
    }

    /// Recompute the REAL readiness build AND surface the fused `ReadinessResult` + `StrainRiskResult`
    /// (no longer discarded). IDENTICAL cold-start/defer logic to the legacy `build(...)` — both nil
    /// guards (the strain-channel `FatigueResult` guard and the honest-confidence all-z-nil gate) are
    /// preserved verbatim. Returns `nil` in the SAME cold-start cases. The surfaced results feed the
    /// Phase 43-03 verdict reason path.
    static func buildDetailed(
        recentSnapshots: [RecoverySnapshot],
        latestHRV: Double?,
        latestRHR: Double?,
        latestSleepMinutes: Double?,
        allSessions: [WorkoutSession],
        fatigueResult: FatigueIndexEngine.FatigueResult?,
        daysSinceRest: Int,
        wellnessScore: Double?,
        acwr: Double,
        acwrZone: ACWRZone,
        asOf: Date,
        calendar: Calendar
    ) -> BuiltReadiness? {
        // Strain channel REQUIRES a real FatigueResult. Cold-start suppresses it → return nil
        // (no fabrication; the caller then leaves dualRunMessage nil).
        guard let fatigue = fatigueResult else { return nil }

        // ascending-by-date snapshot series (oldest → newest), so the EWMA fold is chronological.
        let ascending = recentSnapshots.sorted { $0.date < $1.date }

        // --- Readiness side: real personal z via BaselineEngine, then ReadinessFusionEngine -------
        let hrvZ = personalZ(
            series: ascending.compactMap(\.hrvSDNN),
            today: latestHRV,
            config: .hrv
        )
        let rhrZ = personalZ(
            series: ascending.compactMap(\.restingHR),
            today: latestRHR,
            config: .rhr
        )
        let sleepZ = personalZ(
            series: ascending.compactMap(\.sleepDurationMinutes),
            today: latestSleepMinutes,
            config: .sleep
        )

        // --- Honest-confidence gate (LOCKED: never fabricate a verdict on insufficient data) -------
        // A verdict requires a REAL personal baseline. `personalZ` returns nil whenever the signal is
        // in `BaselineEngine.score`'s cold-start regime — i.e. no μ yet (`count == 0`), `count < 2`,
        // or `madBuffer.count < madMinValid (5)` — the SAME documented "no usable baseline" convention
        // the engine already uses (BaselineEngine.swift §2.3); we reuse it rather than invent a
        // magic confidence cutoff. On pure cold-start ALL THREE z's are nil (every signal series is
        // empty → μ == nil), the readiness side is pure renormalization-over-nothing, and any verdict
        // would be fabricated from no personal data. So: defer (return nil) unless at least one signal
        // has a real, usable personal z. This is the conservative gate — it requires a genuine
        // baseline on ≥1 signal — and it is shadow-tunable (the threshold lives in the engine's
        // `madMinValid`, not here). With ≥14 days of REAL history at least HRV yields a non-nil z, so
        // a populated athlete still gets a verdict; an empty cold-start athlete defers, honestly.
        guard hrvZ != nil || rhrZ != nil || sleepZ != nil else { return nil }

        // Real composite confidence from the HRV state (today's bucket ⇒ daysSinceLastBucket 0).
        let hrvState = foldState(series: ascending.compactMap(\.hrvSDNN), config: .hrv)
        let confidence = BaselineEngine.confidence(state: hrvState, daysSinceLastBucket: 0)

        let readinessResult = ReadinessFusionEngine.compute(
            ReadinessFusionEngine.ReadinessInput(
                hrvZ: hrvZ,
                rhrZ: rhrZ,
                sleepZ: sleepZ,
                confidence: confidence
            )
        )

        // --- Strain side: real StrengthLoadEngine + LoadDistributionEngine + StrainRiskEngine -----
        let strengthLoad = StrengthLoadEngine.perMuscleStrengthLoad(
            sessions: allSessions,
            asOf: asOf,
            calendar: calendar
        )
        let loadDistribution = LoadDistributionEngine.distribution(
            sessions: allSessions,
            asOf: asOf,
            calendar: calendar
        )
        let strainResult = StrainRiskEngine.fuse(
            StrainRiskEngine.Input(
                strengthLoad: strengthLoad,
                loadDistribution: loadDistribution,
                fatigue: fatigue
            )
        )

        // --- ACWR demotion (GA-4): ACWR is a context LABEL only, never a decision input ----------
        let acwrContextLabel = contextLabel(for: acwrZone)

        let input = AutoregulationEngine.ReadinessInput(
            readinessZone: readinessResult.zone,
            readiness: readinessResult.readiness,
            strainRiskZone: strainResult.zone,
            wellnessScore: wellnessScore,
            daysSinceLastRest: daysSinceRest,
            fatigueIndex: fatigue.index,
            acwrContextLabel: acwrContextLabel
        )

        // Surface the fused results the verdict REASON path needs (no longer discarded).
        return BuiltReadiness(input: input, readiness: readinessResult, strain: strainResult)
    }

    // MARK: - Personal z (real BaselineEngine fold + score; nil while cold-start, NEVER imputed)

    /// Fold `BaselineEngine.step` over the real `series` (ascending) from a fresh state.
    private static func foldState(
        series: [Double],
        config: BaselineEngine.SignalConfig
    ) -> BaselineEngine.SignalState {
        var state = BaselineEngine.SignalState()
        for observation in series {
            state = BaselineEngine.step(state: state, observation: observation, config: config)
        }
        return state
    }

    /// Real personal z for one signal: fold the historical `series`, then `score` TODAY's real raw
    /// value against the baseline-as-of-history. Returns `nil` when `today` is absent OR while the
    /// baseline is in cold-start (the fusion engine then excludes + renormalizes — never imputes).
    private static func personalZ(
        series: [Double],
        today: Double?,
        config: BaselineEngine.SignalConfig
    ) -> Double? {
        guard let today else { return nil }
        let state = foldState(series: series, config: config)
        return BaselineEngine.score(state: state, observation: today, config: config).z
    }

    // MARK: - ACWR → context label (GA-4: label only, "Tuwa"-voice, never harm-forecasting)

    private static func contextLabel(for zone: ACWRZone) -> String {
        switch zone {
        case .optimal: return String(localized: "acwr.context.optimal", defaultValue: "Load Steady")
        case .caution: return String(localized: "acwr.context.caution", defaultValue: "Load Building")
        case .danger: return String(localized: "acwr.context.danger", defaultValue: "Load High")
        case .undertrained: return String(localized: "acwr.context.undertrained", defaultValue: "Building Base")
        case .noData: return ""
        }
    }
}
