import Foundation

/// Pure, deterministic **directional cross-modal fatigue carry** model (Phase 41 / ACT-02).
///
/// This is the one genuinely new v2.0 engine. It answers the question `FatigueIndexEngine`
/// (whole-body) structurally cannot: *yesterday's hard run loads today's squat (legs) but
/// barely touches today's bench (chest).* It regionalizes endurance/conditioning sessions
/// (`sRPE × sportType → MuscleRegion`), folds in the existing per-region strength substrate
/// (`StrengthLoadEngine.perRegion`), normalizes against the athlete's OWN regional baseline
/// (so a habitual hard-runner isn't perpetually penalized), and converts the above-normal
/// elevation into a per-exercise multiplicative nudge through a saturating-concave modifier
/// that combines multiplicatively with systemic readiness.
///
/// ## Confidence posture (honest framing — non-negotiable)
/// - **DIRECTION** (run interferes with legs, spares upper body) is HIGH confidence: it is the
///   concurrent-training interference effect, established in meta-analyses and matching revealed
///   user behaviour (HybridLoad's "a run hits your squat hard but barely affects your bench").
/// - **MAGNITUDE** — the specific β coefficients, decay τ, saturation `k`, and `maxPenalty` cap —
///   is an honest **shadow-tuned HEURISTIC**, a prior to be calibrated against the user's own
///   next-day soreness and outcomes. It is NOT presented as precise science.
/// - This engine produces a training-load *adjustment* and a glass-box reason. It NEVER forecasts
///   harm to the body and never uses such language in any surfaced copy (string-audit tested).
///
/// ## Pure / Foundation-only / dateless-by-injection
/// Static methods only, no stored state, Foundation-only. No `Date.now` / `Calendar.current`:
/// every method that needs day math takes a passed-in `asOf: Date` and `calendar: Calendar`
/// (mirrors the `StrengthLoadEngine` / `BaselineEngine` dateless contract). Same input →
/// identical output, always. It reads `[WorkoutSession]` passed BY the caller — it never fetches
/// from SwiftData / HealthKit itself.
///
/// ## Reuse, do not reinvent
/// - Magnitude of a session = `WorkloadCalculator.srpeLoad(durationSeconds:sessionRPE:)`.
/// - Strength region attribution = `StrengthLoadEngine.perMuscleStrengthLoad(...).perRegion`.
/// - Acute-vs-chronic *elevation* shape (deadband + saturating clamp) = `StrengthLoadEngine`'s
///   `perMuscleElevation` philosophy, reusing `StrengthLoadEngine.Constants.elevationDeadband`.
/// - Region taxonomy = `MuscleGroup.region` / `MuscleRegion`.
///
/// ## Scope (this phase)
/// The engine exists and is unit-tested in ISOLATION only. It is NOT wired into any pipeline,
/// surface, or shadow log here — that is the next plan (the shadow-validation gate). The
/// `dominantReason` string is built but NOT surfaced this phase.
struct CrossModalFatigueEngine {

    // MARK: - Output

    /// Glass-box result of one cross-modal evaluation.
    ///
    /// `perRegionCarry` — decayed acute carry-over load per region (the magnitude that decays
    /// with recency). `perRegionElevation` — above-personal-normal elevation per region in 0…1
    /// (the deadband-normalised signal that actually drives the penalty). `systemicFactor` —
    /// the global readiness haircut in `[systemicMin, 1.0]`. `dominantReason` — a one-line,
    /// decomposable "why" assembled from the dominant contributing region; Tuwa-only copy,
    /// never an injury claim.
    struct CrossModalResult: Equatable {
        let perRegionCarry: [MuscleRegion: Double]
        let perRegionElevation: [MuscleRegion: Double]
        let systemicFactor: Double
        let dominantReason: String?

        /// Per-exercise multiplicative adjustment in (0, 1] for a planned exercise whose primary
        /// region is `region`: `systemicFactor · (1 − regionPenalty(E_region))`. A `.fullBody`
        /// exercise uses the MAX region elevation (the dominant loaded region — it does not get
        /// to spare itself). Regions with no elevation get only the (possibly neutral) systemic
        /// factor — this is the run-hits-squat-not-bench behaviour: chest ⇒ E≈0 ⇒ factor only.
        func exerciseAdjustment(forRegion region: MuscleRegion) -> Double {
            let elevation: Double
            if region == .fullBody {
                elevation = perRegionElevation.values.max() ?? 0
            } else {
                elevation = perRegionElevation[region] ?? 0
            }
            return systemicFactor * (1 - CrossModalFatigueEngine.regionPenalty(elevation))
        }
    }

    // MARK: - Named constants (the SINGLE home for every tunable — all HEURISTIC priors)

    enum Constants {
        /// Per-region β attribution coefficients per endurance/conditioning `SportType`.
        /// HEURISTIC priors (research §1.3): running loads legs ≈1.0; cycling legs ≈0.7 (less
        /// eccentric tissue damage); swimming back/shoulders ≈0.6 (spares legs); mixed-modality
        /// (crossfit / teamSport) is fullBody-distributed by a default profile; custom defaults
        /// to a light fullBody profile. A region absent from the map ⇒ that sport contributes
        /// ~zero carry to it (e.g. running ⇒ chest absent ⇒ chest carry 0). Calibrate in shadow.
        static func betaMap(for sport: SportType) -> [MuscleRegion: Double] {
            switch sport {
            case .running:
                return [.legs: 1.0]
            case .cycling:
                return [.legs: 0.7]
            case .swimming:
                return [.back: 0.6, .shoulders: 0.6]
            case .crossfit, .teamSport:
                // Mixed modality — distributed default profile (legs-dominant, upper present).
                return [.legs: 0.6, .back: 0.4, .shoulders: 0.3, .core: 0.3]
            case .custom:
                // Unknown modality — light fullBody-distributed prior.
                return [.fullBody: 0.5]
            case .lifting:
                // Strength is attributed by StrengthLoadEngine.perRegion, NOT this map.
                return [:]
            }
        }

        /// Per-region decay time-constant τ (days) for `decay(Δdays) = exp(−Δdays / τ)`.
        /// HEURISTIC priors: legs recover slower from eccentric running damage (τ ≈ 2.0d) than
        /// the upper body from pressing/pulling (τ ≈ 1.5d). Calibrate against next-day soreness.
        static let tauLegs: Double = 2.0
        static let tauUpper: Double = 1.5

        static func tau(for region: MuscleRegion) -> Double {
            region == .legs ? tauLegs : tauUpper
        }

        /// Saturation rate of the concave anchor+modifier. Larger ⇒ the first unit of carry-over
        /// costs more and additional carry-over saturates faster. HEURISTIC.
        static let k: Double = 2.0

        /// Maximum per-region penalty (cap). The worst leg case trims a planned set ≈10% — never
        /// catastrophic (nocebo guard). HEURISTIC bound, deliberately conservative.
        static let maxPenalty: Double = 0.10

        /// Systemic-readiness haircut floor: readiness 0 ⇒ a global ×0.85; readiness 100 ⇒ ×1.0.
        /// A mild whole-body attenuation, NOT a hard stop. HEURISTIC.
        static let systemicMin: Double = 0.85

        /// Personal-normal deadband — REUSED from StrengthLoadEngine so only ABOVE-personal-normal
        /// regional carry counts (a habitual hard-runner is not perpetually penalized).
        static let elevationDeadband: Double = StrengthLoadEngine.Constants.elevationDeadband

        /// Acute / chronic windows (days) — reuse the StrengthLoadEngine spans for one coherent
        /// per-region baseline. Acute = [0, acuteWindowDays); chronic-exclusive = [acute, chronic).
        static let acuteWindowDays: Int = StrengthLoadEngine.Constants.acuteWindowDays    // 7
        static let chronicWindowDays: Int = StrengthLoadEngine.Constants.chronicWindowDays // 28
    }

    // MARK: - Step 4: anchor + diminishing modifier (anti-linear-stacking core)

    /// Convert a 0…1 regional elevation `E` into a per-region penalty through a concave,
    /// saturating, bounded map: `maxPenalty · (1 − exp(−k · E))`.
    ///
    /// Concave by construction ⇒ two stacked stressors do NOT double-penalize (the first unit of
    /// carry-over costs the most). Bounded by `maxPenalty` ⇒ never catastrophic. This is the
    /// explicit answer to the "linear −10% −15% stacking is too aggressive" critique.
    static func regionPenalty(_ E: Double) -> Double {
        let e = max(0, E)
        return Constants.maxPenalty * (1 - exp(-Constants.k * e))
    }

    // MARK: - Step 4b: systemic combine factor

    /// Map systemic readiness 0…100 linearly into the haircut range `[systemicMin, 1.0]`:
    /// readiness 100 ⇒ 1.0 (no haircut); readiness 0 ⇒ `systemicMin`. A mild GLOBAL attenuation
    /// applied to every exercise, multiplicatively (never additive).
    static func systemicFactor(readiness: Double) -> Double {
        let r = min(100, max(0, readiness)) / 100.0
        return Constants.systemicMin + (1.0 - Constants.systemicMin) * r
    }

    // MARK: - Step 1+2: regional carry (decayed) and raw regional load (per window)

    /// Decayed acute carry-over load per region over the acute window: for each NON-strength
    /// session, `srpeLoad · β_region · decay(Δdays)`, summed per region; PLUS the existing
    /// per-region strength load (`StrengthLoadEngine.perRegion`) over the same window so a heavy
    /// squat day also accrues leg carry. Sessions with `sessionRPE == nil` contribute no
    /// endurance load (no fabrication). The decay weights make a run yesterday outweigh the same
    /// run three days ago, and a session outside the window contributes nothing.
    static func regionCarry(
        sessions: [WorkoutSession],
        asOf: Date,
        calendar: Calendar,
        windowDays: Int = Constants.acuteWindowDays
    ) -> [MuscleRegion: Double] {
        var carry: [MuscleRegion: Double] = [:]
        let to = calendar.startOfDay(for: asOf)

        for session in sessions where session.sportType != .lifting {
            guard let diff = dayDiff(from: session.sessionDate, to: to, calendar: calendar),
                  diff >= 0, diff < windowDays else { continue }
            guard let rpe = session.sessionRPE else { continue } // no RPE ⇒ no fabricated load
            let srpe = WorkloadCalculator.srpeLoad(durationSeconds: session.durationSeconds, sessionRPE: rpe)
            guard srpe > 0 else { continue }

            for (region, beta) in Constants.betaMap(for: session.sportType) where beta > 0 {
                let decayed = srpe * beta * decay(daysAgo: diff, region: region)
                carry[region, default: 0] += decayed
            }
        }

        // Fold in the existing per-region strength substrate over the same window.
        let strength = StrengthLoadEngine.perMuscleStrengthLoad(
            sessions: sessions, asOf: asOf, calendar: calendar,
            acuteWindowDays: windowDays, chronicWindowDays: Constants.chronicWindowDays
        )
        for (region, load) in strength.perRegion where load > 0 {
            carry[region, default: 0] += load
        }

        return carry
    }

    /// RAW (un-decayed) per-region endurance/conditioning load over a half-open day window
    /// `[lowerDayInclusive, upperDayExclusive)`, used for the personal-baseline elevation
    /// comparison (decay is a carry-magnitude concept, not a baseline concept — keeping the
    /// baseline un-decayed makes a steady-state athlete's acute/chronic ratio ≈ 1 ⇒ elevation 0).
    private static func rawRegionLoad(
        sessions: [WorkoutSession],
        asOf: Date,
        calendar: Calendar,
        lowerDayInclusive: Int,
        upperDayExclusive: Int
    ) -> [MuscleRegion: Double] {
        var load: [MuscleRegion: Double] = [:]
        let to = calendar.startOfDay(for: asOf)

        for session in sessions where session.sportType != .lifting {
            guard let diff = dayDiff(from: session.sessionDate, to: to, calendar: calendar),
                  diff >= lowerDayInclusive, diff < upperDayExclusive else { continue }
            guard let rpe = session.sessionRPE else { continue }
            let srpe = WorkloadCalculator.srpeLoad(durationSeconds: session.durationSeconds, sessionRPE: rpe)
            guard srpe > 0 else { continue }
            for (region, beta) in Constants.betaMap(for: session.sportType) where beta > 0 {
                load[region, default: 0] += srpe * beta
            }
        }
        return load
    }

    // MARK: - Step 3: regional elevation (above-personal-normal only)

    /// Per-region elevation in 0…1, normalising the acute regional endurance load against the
    /// athlete's OWN chronic-exclusive regional load using the SAME deadband+saturating shape as
    /// `StrengthLoadEngine.perMuscleElevation`. Per-day-normalised on EXACTLY-PARTITIONED windows
    /// (acute `[0, acute)`, chronic-exclusive `[acute, chronic)`) so a steady-state athlete gets
    /// ratio ≈ 1 ⇒ elevation 0 (only above-personal-normal carry counts — the personal moat).
    static func regionElevation(
        sessions: [WorkoutSession],
        asOf: Date,
        calendar: Calendar,
        acuteWindowDays: Int = Constants.acuteWindowDays,
        chronicWindowDays: Int = Constants.chronicWindowDays
    ) -> [MuscleRegion: Double] {
        let acuteRaw = rawRegionLoad(
            sessions: sessions, asOf: asOf, calendar: calendar,
            lowerDayInclusive: 0, upperDayExclusive: acuteWindowDays
        )
        let chronicRaw = rawRegionLoad(
            sessions: sessions, asOf: asOf, calendar: calendar,
            lowerDayInclusive: acuteWindowDays, upperDayExclusive: chronicWindowDays
        )

        let acuteDays = Double(max(1, acuteWindowDays))
        let chronicExclDays = Double(max(1, chronicWindowDays - acuteWindowDays))

        var elevation: [MuscleRegion: Double] = [:]
        let regions = Set(acuteRaw.keys).union(chronicRaw.keys)
        for region in regions {
            let acutePerDay = (acuteRaw[region] ?? 0) / acuteDays
            let chronicPerDay = (chronicRaw[region] ?? 0) / chronicExclDays
            // No chronic baseline ⇒ report elevation 0 (insufficient-baseline, never artefactual).
            let e = chronicPerDay > 0
                ? StrengthLoadEngine.perMuscleElevation(acute: acutePerDay, chronic: chronicPerDay)
                : 0
            if e > 0 { elevation[region] = e }
        }
        return elevation
    }

    // MARK: - Top-level compute

    /// Full cross-modal evaluation: decayed per-region carry, above-personal-normal per-region
    /// elevation, the systemic haircut factor, and a glass-box dominant-reason string. Use
    /// `result.exerciseAdjustment(forRegion:)` to get the per-exercise multiplicative nudge.
    ///
    /// - Parameters:
    ///   - sessions: athlete-scoped sessions (any length; windowed internally by date). The
    ///     caller supplies these — the engine never fetches from SwiftData.
    ///   - systemicReadiness: 0…100 systemic readiness (e.g. `ReadinessResult.readiness`), passed
    ///     as a plain `Double` to keep the engine decoupled from the readiness engine type.
    ///   - asOf / calendar: injected for determinism (no `Date.now` / `Calendar.current`).
    static func compute(
        sessions: [WorkoutSession],
        systemicReadiness: Double,
        asOf: Date,
        calendar: Calendar,
        acuteWindowDays: Int = Constants.acuteWindowDays,
        chronicWindowDays: Int = Constants.chronicWindowDays
    ) -> CrossModalResult {
        let carry = regionCarry(
            sessions: sessions, asOf: asOf, calendar: calendar, windowDays: acuteWindowDays
        )
        let elevation = regionElevation(
            sessions: sessions, asOf: asOf, calendar: calendar,
            acuteWindowDays: acuteWindowDays, chronicWindowDays: chronicWindowDays
        )
        let factor = systemicFactor(readiness: systemicReadiness)
        let reason = dominantReason(perRegionElevation: elevation, perRegionCarry: carry)

        return CrossModalResult(
            perRegionCarry: carry,
            perRegionElevation: elevation,
            systemicFactor: factor,
            dominantReason: reason
        )
    }

    // MARK: - Glass-box reason

    /// Build a one-line, decomposable "why" from the dominant elevated region. Tuwa-only copy —
    /// an adjusted-number rationale, NEVER an injury claim. Returns nil when nothing is elevated.
    static func dominantReason(
        perRegionElevation: [MuscleRegion: Double],
        perRegionCarry: [MuscleRegion: Double]
    ) -> String? {
        guard let (region, _) = perRegionElevation.max(by: { $0.value < $1.value }),
              (perRegionElevation[region] ?? 0) > 0 else { return nil }
        // Deterministic, decomposable to (region, elevation). No injury language.
        return "\(region.displayName.lowercased()) still loaded from recent cross-modal work"
    }

    // MARK: - Helpers

    /// `exp(−Δdays / τ_region)`. Recency weight: a run yesterday outweighs the same run three
    /// days ago; a run outside the window is filtered upstream (Δ never reaches here from there).
    static func decay(daysAgo: Int, region: MuscleRegion) -> Double {
        exp(-Double(daysAgo) / Constants.tau(for: region))
    }

    /// Whole-day difference from `from` to `to` on `calendar.startOfDay`, or nil if undefined.
    private static func dayDiff(from: Date, to: Date, calendar: Calendar) -> Int? {
        let fromDay = calendar.startOfDay(for: from)
        return calendar.dateComponents([.day], from: fromDay, to: to).day
    }
}
