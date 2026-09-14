import Foundation

/// v1.7.3 UAT round 3 (U25 / U26) — the pure **session cap** for a planned day that carries no
/// weighted top set.
///
/// ## Why it exists
/// Every verdict selector in the app keys on a set with `targetWeightKg > 0`
/// (`TodayVerdictService`, `TodayVerdictViewModel`). A basketball day, a run, a conditioning block
/// therefore produced NO verdict, no brief and no start door — the athlete's own plan went
/// unmodulated on exactly the days a sport-skill-primary athlete trains most. This engine gives
/// those days the same suggest-and-confirm shape the lift day already has, in the units that day
/// actually has: a **maximum RPE** and a **duration cap**.
///
/// ## It invents no decision model
/// Like `TodayVerdictEngine`, this is a DERIVED engine. The max RPE is the EXISTING
/// `AutoregulationEngine.TrainingRecommendation.intensityCap` — the app's own readiness × strain
/// matrix output — never a new number. The duration percentages are the only new tunables, and
/// they are the evidence-backed lever for a non-strength day: **cut duration, preserve intensity**
/// (Bosquet 2007 taper meta-analysis; medium-high). The budget arithmetic is session-RPE
/// (Foster 1998; high). No claim about harm is made anywhere, and nothing here looks past today.
///
/// ## The one invariant: a cap can only SHORTEN or LOWER
/// Every output is clamped against the plan. `maxRPE ≤ plannedRPE` whenever a planned RPE exists,
/// and `maxDurationSeconds ≤ plannedDurationSeconds` always. The engine can never hand back a
/// longer or harder session than the athlete wrote.
///
/// ## Pure / Foundation-only / dateless-by-injection
/// Static methods, no stored state, no `Date.now` / `Calendar.current` — `matchDaysAway` arrives
/// already computed (`TodayVerdictEngine.matchDaysAway`). Same input → identical output. Emits no
/// user-facing copy at all: the sentence is assembled by the surfaces, the same separation
/// `TodayVerdictEngine` / `VerdictReasonBuilder` already keep.
struct SessionCapEngine {

    // MARK: - Public types

    /// What the cap DID to the plan. The surfaces read this to pick their state word; the numbers
    /// are always in the two fields beside it.
    enum Shape: String, Equatable {
        /// The plan stands — nothing was shortened, nothing lowered.
        case asPlanned
        /// Duration and/or intensity were pulled in (the ordinary modulation).
        case capped
        /// A match is near, so the session is halved with its intensity kept (the taper lever).
        case taper
        /// Fatigue is saturated — the session collapses to a short, easy dose. Never a gate: the
        /// day still has a number and the athlete can keep their plan.
        case hold
    }

    /// The cap itself. `nil` in a field means "this day carries no such number" — never zero, and
    /// never a fabricated one (a plan with no duration gets no duration cap).
    struct SessionCap: Equatable {
        /// Maximum session RPE (1…10), whole — the recommendation's `intensityCap`, further capped
        /// by the plan's own RPE when it has one.
        let maxRPE: Int?
        /// Maximum session duration in seconds, whole minutes, never above the planned duration.
        let maxDurationSeconds: Int?
        /// The session-RPE load budget in arbitrary units: `maxDuration(min) × maxRPE`
        /// (Foster 1998). nil whenever either factor is absent.
        let loadBudgetAU: Double?
        let shape: Shape

        /// The cap in whole minutes — what every surface prints.
        var maxDurationMinutes: Int? {
            maxDurationSeconds.map { $0 / 60 }
        }

        /// True when the cap actually modulates the plan — the surfaces show the equal-weight
        /// Accept / Keep as planned pair only then.
        var modulatesPlan: Bool { shape != .asPlanned }
    }

    // MARK: - Tunable constants (the SINGLE home — mirrors TodayVerdictEngine.Constants)

    enum Constants {
        /// Strain elevated ⇒ hold ~85% of the planned duration.
        static let strainElevatedFactor: Double = 0.85
        /// Fatigue elevated ⇒ 80%.
        static let fatigueElevatedFactor: Double = 0.80
        /// Strain high ⇒ 70%.
        static let strainHighFactor: Double = 0.70
        /// Fatigue high / the recommendation has already dropped to active recovery ⇒ 60%,
        /// technical character.
        static let lowReadinessFactor: Double = 0.60
        /// A match inside the proximity window ⇒ half the session, intensity untouched.
        static let taperFactor: Double = 0.50
        /// Fatigue saturation ⇒ a short dose. The cap, never a floor.
        static let holdCeilingSeconds: Int = 30 * 60
        /// The RPE ceiling a hold carries, whatever the matrix said.
        static let holdMaxRPE: Int = 5
        /// Proximity window in calendar days — the SAME rule and the same constant family the
        /// verdict engine uses (ADR-0002: one date, one rule, no trajectory math).
        static let matchProximityDays: Int = TodayVerdictEngine.Constants.matchProximityDays
        /// Binary-representation guard for the minute floor. Far below any real rounding
        /// decision, so it rescues `62.999999999999` without ever promoting a genuine 76.5.
        static let minuteEpsilon: Double = 1e-6
    }

    // MARK: - Evaluate

    /// Derive today's session cap for a planned non-strength day.
    ///
    /// - Parameters:
    ///   - recommendation: the already-produced `TrainingRecommendation` — the SOLE intensity
    ///     input. Its `intensityCap` IS the max RPE.
    ///   - fatigueZone: the day's `FatigueIndexEngine` zone; nil ⇒ that row simply never engages.
    ///   - strainRiskZone: the day's `StrainRiskEngine` zone; nil ⇒ same.
    ///   - matchDaysAway: calendar days to the next scheduled match (from
    ///     `TodayVerdictEngine.matchDaysAway`); nil / expired / far ⇒ no taper.
    ///   - plannedDurationSeconds: the plan's own duration. nil or ≤ 0 ⇒ the cap is RPE-only;
    ///     the engine never invents a duration it was not given.
    ///   - plannedRPE: the plan's own RPE target, when it wrote one.
    ///   - sessionType: the planned session's type. A `.match` and a `.recovery` session keep
    ///     their planned duration — you do not leave a game at 60%, and the recovery dose IS the
    ///     short session — so only the RPE ceiling applies to them.
    static func evaluate(
        recommendation: AutoregulationEngine.TrainingRecommendation,
        fatigueZone: FatigueIndexEngine.FatigueZone?,
        strainRiskZone: StrainRiskZone?,
        matchDaysAway: Int?,
        plannedDurationSeconds: Int?,
        plannedRPE: Double?,
        sessionType: SessionType
    ) -> SessionCap {

        // --- Which rows engage. Each one only ever pulls DOWN; the strongest wins the number. ----
        var factor = 1.0
        var shape: Shape = .asPlanned

        if strainRiskZone == .elevated {
            factor = Swift.min(factor, Constants.strainElevatedFactor)
            shape = .capped
        }
        if fatigueZone == .elevated {
            factor = Swift.min(factor, Constants.fatigueElevatedFactor)
            shape = .capped
        }
        if strainRiskZone == .high {
            factor = Swift.min(factor, Constants.strainHighFactor)
            shape = .capped
        }
        // Low readiness reaches this engine as the recommendation the matrix already produced:
        // `.activeRecovery` IS the low-readiness / fatigue-modulated row. Reading it here keeps
        // the readiness channel in ONE place rather than re-deriving a zone.
        if fatigueZone == .high || recommendation.sessionType == .activeRecovery {
            factor = Swift.min(factor, Constants.lowReadinessFactor)
            shape = .capped
        }

        // Match proximity TAPERS: half the session, intensity kept (ADR-0002 / the microdose
        // shape in the units a non-strength day has). It outranks a plain cap for the state word
        // because "you have a match" is the athlete's actual reason.
        let matchNear = isMatchNear(daysAway: matchDaysAway) && sessionType != .match
        if matchNear {
            factor = Swift.min(factor, Constants.taperFactor)
            shape = .taper
        }

        // HOLD outranks everything, including a taper: a saturated body near a match still holds.
        // It is a SHORT EASY DOSE with a number, never "do not train" (the nocebo guard).
        let isHold = fatigueZone == .saturation || recommendation.sessionType == .rest
        if isHold {
            shape = .hold
        }

        // --- Max RPE: the matrix's own ceiling, then the plan, then the hold floor. --------------
        var rpeCeiling = recommendation.intensityCap
        if isHold {
            rpeCeiling = Swift.min(rpeCeiling, Double(Constants.holdMaxRPE))
        }
        // "Keep the intensity" is what a taper means — it adds no lowering of its own beyond
        // whatever the matrix already said.
        if let plannedRPE {
            rpeCeiling = Swift.min(rpeCeiling, plannedRPE)   // never above the plan
        }
        let maxRPE = clampedRPE(rpeCeiling)

        // --- Max duration: a percentage of the PLANNED duration, floored to whole minutes. ------
        let maxDurationSeconds = cappedDuration(
            plannedDurationSeconds: plannedDurationSeconds,
            factor: factor,
            isHold: isHold,
            sessionType: sessionType
        )

        // A cap that changed nothing is honestly "as planned" — never dressed as a modulation.
        // A HOLD is exempt: its framing is about the body, so it survives even on a day whose
        // planned numbers already sit under the ceiling.
        let resolvedShape: Shape = {
            guard shape != .asPlanned, shape != .hold else { return shape }
            let durationUnchanged = maxDurationSeconds == plannedDurationSeconds
                || (maxDurationSeconds == nil && plannedDurationSeconds == nil)
            let rpeUnchanged = plannedRPE.map { clampedRPE($0) == maxRPE } ?? false
            return (durationUnchanged && rpeUnchanged) ? .asPlanned : shape
        }()

        return SessionCap(
            maxRPE: maxRPE,
            maxDurationSeconds: maxDurationSeconds,
            loadBudgetAU: loadBudget(maxDurationSeconds: maxDurationSeconds, maxRPE: maxRPE),
            shape: resolvedShape
        )
    }

    // MARK: - Proximity (the same predicate the verdict engine uses)

    static func isMatchNear(daysAway: Int?) -> Bool {
        guard let daysAway else { return false }
        return daysAway >= 0 && daysAway <= Constants.matchProximityDays
    }

    // MARK: - Pieces

    /// Whole RPE, clamped to the published 1…10 scale. Rounded DOWN so a fractional ceiling can
    /// never be presented as the next rung up.
    private static func clampedRPE(_ value: Double) -> Int {
        let floored = Int(value.rounded(.down))
        return Swift.max(1, Swift.min(10, floored))
    }

    /// The duration cap, in whole minutes and never above the plan.
    ///
    /// `.match` and `.recovery` sessions are exempt from the percentage: a match is a match, and a
    /// recovery session is already the short dose — shortening either would be arithmetic, not
    /// advice. A hold still bounds them, because a hold is about the body, not the session label.
    private static func cappedDuration(
        plannedDurationSeconds: Int?,
        factor: Double,
        isHold: Bool,
        sessionType: SessionType
    ) -> Int? {
        guard let planned = plannedDurationSeconds, planned > 0 else { return nil }

        let exemptFromPercentage = (sessionType == .match || sessionType == .recovery)
        var capped = planned
        if !exemptFromPercentage, factor < 1.0 {
            // Floor to a whole minute, with a binary-representation guard: 5400 × 0.70 is
            // 3779.999999999999 in Double, and a bare truncation would quietly hand back 62
            // minutes where the rule says 63. The epsilon only ever rescues a value that is
            // already a whole minute — it can never round a real 76.5 up to 77.
            let scaledMinutes = Double(planned) * factor / 60.0
            capped = Int((scaledMinutes + Constants.minuteEpsilon).rounded(.down)) * 60
        }
        if isHold {
            capped = Swift.min(capped, Constants.holdCeilingSeconds)
        }
        // The invariant, belt-and-braces: a cap can only shorten.
        return Swift.max(0, Swift.min(capped, planned))
    }

    /// Session-RPE load budget (Foster 1998): minutes × RPE.
    private static func loadBudget(maxDurationSeconds: Int?, maxRPE: Int?) -> Double? {
        guard let seconds = maxDurationSeconds, seconds > 0, let rpe = maxRPE else { return nil }
        return (Double(seconds) / 60.0) * Double(rpe)
    }
}
