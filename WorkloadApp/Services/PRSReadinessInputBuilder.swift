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
/// present signals; we NEVER mean-impute. If the strain channel cannot be honestly computed (the
/// real `FatigueResult` is unavailable — cold-start suppressed it), `build(...)` returns `nil` and
/// the caller leaves `dualRunMessage` nil rather than synthesizing inputs.
///
/// ## Purity
/// Foundation-only, deterministic, no SwiftData fetch, no baked-in `.now` — `asOf` + `calendar` are
/// injected (mirrors the engine convention). Flag-agnostic: it is only ever CALLED inside the
/// `if PRSActivation.isEnabled` guard in `DashboardViewModel`, so the flag-off cost is zero.
///
/// Copy is "Tuwa"-voice and NEVER says "injury prediction" (grep-guarded).
enum PRSReadinessInputBuilder {

    /// Recompute a REAL `AutoregulationEngine.ReadinessInput` from load() data, or `nil` when the
    /// strain channel cannot be honestly computed (no real `FatigueResult`).
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

        return AutoregulationEngine.ReadinessInput(
            readinessZone: readinessResult.zone,
            readiness: readinessResult.readiness,
            strainRiskZone: strainResult.zone,
            wellnessScore: wellnessScore,
            daysSinceLastRest: daysSinceRest,
            fatigueIndex: fatigue.index,
            acwrContextLabel: acwrContextLabel
        )
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

    // MARK: - ACWR → context label (GA-4: label only, "Tuwa"-voice, never injury prediction)

    private static func contextLabel(for zone: ACWRZone) -> String {
        switch zone {
        case .optimal: return "Load Steady"
        case .caution: return "Load Building"
        case .danger: return "Load High"
        case .undertrained: return "Building Base"
        case .noData: return ""
        }
    }
}
