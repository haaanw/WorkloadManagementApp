import Foundation

/// Computes seeded ATL/CTL values from training questionnaire inputs using the
/// steady-state EWMA shortcut. Used during the cold-start window before sufficient
/// real training data exists.
///
/// The engine is stateless and pure: given questionnaire answers, it produces
/// deterministic seeded workload values. Session TSS is delegated to the existing
/// `WorkloadCalculator.sessionTSS` formula for consistency.
///
/// Key formulas:
/// - Daily TSS = (sessionTSS * sessionsPerWeek) / 7
/// - Seeded ATL = dailyTSS * 7 (steady-state EWMA at atlLambda = 1/7)
/// - Seeded CTL = dailyTSS * 28 * ramp (steady-state EWMA at ctlLambda = 1/28, discounted)
/// - Ramp = max(0.3, min(1.0, weeksAtLevel / 6.0))
struct ColdStartEngine {

    // MARK: - Data Types

    /// Questionnaire inputs for cold-start seeding.
    struct SeedInput {
        /// Training sessions per week (0-14 reasonable range)
        let sessionsPerWeek: Int
        /// Average session duration in minutes (1-480 reasonable range)
        let avgDurationMinutes: Int
        /// Typical session RPE on 1-10 scale (clamped in computation)
        let typicalSRPE: Double
        /// Weeks at current training level (1-52 reasonable range)
        let weeksAtLevel: Int
    }

    /// Computed seed values from questionnaire inputs.
    struct SeedResult {
        /// Seeded Acute Training Load (7-day EWMA steady state)
        let seededATL: Double
        /// Seeded Chronic Training Load (28-day EWMA steady state, ramp-discounted)
        let seededCTL: Double
        /// Representative daily Training Stress Score
        let dailyTSS: Double
        /// Single session Training Stress Score
        let sessionTSS: Double
    }

    // MARK: - Computation

    /// Compute seeded ATL/CTL from questionnaire inputs using steady-state EWMA shortcut.
    ///
    /// - D-04: dailyTSS = (sessionTSS * sessionsPerWeek) / 7
    /// - D-05: CTL discounted by weeksAtLevel ramp factor
    /// - D-06: Session TSS delegates to `WorkloadCalculator.sessionTSS`
    ///
    /// Input validation:
    /// - RPE clamped to [1.0, 10.0]
    /// - Zero sessions or zero duration returns all-zero result
    ///
    /// - Parameter input: Questionnaire answers from the athlete
    /// - Returns: Seeded workload values for TrainingProfile storage
    static func computeSeed(input: SeedInput) -> SeedResult {
        // Input validation: clamp RPE to [1, 10]
        let clampedRPE = max(1.0, min(10.0, input.typicalSRPE))

        // Guard: zero sessions or zero duration means zero load
        guard input.sessionsPerWeek > 0, input.avgDurationMinutes > 0 else {
            return SeedResult(seededATL: 0, seededCTL: 0, dailyTSS: 0, sessionTSS: 0)
        }

        // D-06: Delegate to existing TSS formula
        let durationSeconds = input.avgDurationMinutes * 60
        let sessionTSS = WorkloadCalculator.sessionTSS(
            durationSeconds: durationSeconds,
            sessionRPE: clampedRPE
        )

        // D-04: Representative daily TSS
        let dailyTSS = (sessionTSS * Double(input.sessionsPerWeek)) / 7.0

        // Steady-state EWMA: at equilibrium, value = dailyInput / lambda
        // ATL lambda = 1/7, steady-state ATL = dailyTSS * 7
        let seededATL = dailyTSS * 7.0

        // D-05: CTL discount for athletes who recently changed programs
        // ramp linearly increases from 0.3 (floor) to 1.0 over 6 weeks
        let ramp = max(0.3, min(1.0, Double(input.weeksAtLevel) / 6.0))
        // CTL lambda = 1/28, steady-state CTL = dailyTSS * 28, then discounted
        let seededCTL = dailyTSS * 28.0 * ramp

        return SeedResult(
            seededATL: seededATL,
            seededCTL: seededCTL,
            dailyTSS: dailyTSS,
            sessionTSS: sessionTSS
        )
    }
}
