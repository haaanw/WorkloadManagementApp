import Foundation

/// OnboardingV2 screen-9 math (C1): the reveal computes **in memory and persists
/// nothing** — no `Athlete` exists before screen 10, and a provisional local athlete
/// would break the sync identity guard and the zombie logic. It reuses the exact live
/// pieces `RecoveryPipeline` uses — the 90-day HealthKit fetches, `ReadinessInputReducer`,
/// `RecoveryScoreEngine` — so the number shown here and the first real snapshot written
/// after signup come from the same math and agree.
///
/// The branch predicate is a DAY COUNT, not an engine value (C2): `BaselineEngine`'s 0–1
/// confidence composite is exactly 0.0 at 14 observed days, and the robust estimator is
/// the dark v2 arm — a monetization gate must not depend on an unvalidated engine. The
/// floor constant is still read from `BaselineEngine` so the two can never drift.
@MainActor
struct OnboardingRevealService {

    struct Reveal: Equatable {
        enum ConfidenceBucket: String {
            case floor, partial, full
        }

        /// Trend-free score (the reveal has no history of its own scores).
        let score: Double?
        let zone: RecoveryZone?
        /// Today's morning HRV and the prior-days baseline — composites of the athlete's
        /// own data, displayed only; nothing here is persisted or sent anywhere.
        let hrvToday: Double?
        let hrvBaseline: Double?
        /// Distinct PRIOR wake-days carrying an HRV daily reduction in the 90-day window —
        /// the C2 branch predicate's input.
        let observedPriorHRVDays: Int

        /// Real branch = enough observed history for an honest baseline AND at least one
        /// physiological input actually landed today's score.
        var isRealBranch: Bool {
            observedPriorHRVDays >= BaselineEngine.BaselineConstants.confFloorDays
                && score != nil
        }

        /// The bucket shown on screen 9 and sent to analytics — mapped from the same day
        /// count as the branch (C2): <14 floor, 14–59 partial, ≥60 full.
        var confidenceBucket: ConfidenceBucket {
            if observedPriorHRVDays >= BaselineEngine.BaselineConstants.confFullDays { return .full }
            if observedPriorHRVDays >= BaselineEngine.BaselineConstants.confFloorDays { return .partial }
            return .floor
        }

        /// The degraded screen states a DATE, not a vague promise (spec §4): today plus
        /// the mornings still missing to reach the floor.
        func firstRealNumberDate(now: Date, calendar: Calendar = .current) -> Date {
            let missing = max(1, BaselineEngine.BaselineConstants.confFloorDays - observedPriorHRVDays)
            return calendar.date(byAdding: .day, value: missing, to: calendar.startOfDay(for: now)) ?? now
        }

        static let degraded = Reveal(
            score: nil, zone: nil, hrvToday: nil, hrvBaseline: nil, observedPriorHRVDays: 0
        )
    }

    /// The fetch window mirrors the live pipeline's baseline window source
    /// (`DashboardViewModel` / `RecoveryPipeline` pull 90 days).
    static let windowDays = 90

    static func compute(
        healthKitService: HealthKitService,
        now: Date = .now,
        calendar: Calendar = .current
    ) async -> Reveal {
        guard healthKitService.isAvailable, healthKitService.hasRequestedAccess else {
            return .degraded
        }

        let hrvSamples = (try? await healthKitService.fetchHRVHistory(days: windowDays)) ?? []
        let rhrSamples = (try? await healthKitService.fetchRestingHRHistory(days: windowDays)) ?? []

        // Same authoritative-cycle bookkeeping as the pipeline: reads were attempted, so
        // the connection state reflects what actually came back (drives screen 9's branch
        // copy and keeps the re-ask guard honest for a user who granted with no data).
        healthKitService.updateObservedData(!hrvSamples.isEmpty || !rhrSamples.isEmpty)

        return reveal(
            hrvSamples: hrvSamples,
            rhrSamples: rhrSamples,
            now: now,
            calendar: calendar
        )
    }

    /// Pure scoring half, separated so tests can drive it with fixture samples and no
    /// HealthKit. Sleep and wellness are absent by construction pre-auth; the engine
    /// renormalizes over what is present (its documented contract).
    static func reveal(
        hrvSamples: [(date: Date, value: Double)],
        rhrSamples: [(date: Date, value: Double)],
        now: Date,
        calendar: Calendar
    ) -> Reveal {
        let hrvReduced = ReadinessInputReducer.hrv(
            samples: hrvSamples, windowDays: windowDays, now: now, calendar: calendar
        )
        let rhrReduced = ReadinessInputReducer.rhr(
            samples: rhrSamples, windowDays: windowDays, now: now, calendar: calendar
        )

        let hrvBaseline = RecoveryScoreEngine.computeBaseline(values: hrvReduced.priorDays)
        let rhrBaseline = RecoveryScoreEngine.computeBaseline(values: rhrReduced.priorDays)

        let hasPhysiology = hrvReduced.today != nil || rhrReduced.today != nil
            || hrvBaseline != nil || rhrBaseline != nil
        guard hasPhysiology else {
            return Reveal(
                score: nil, zone: nil, hrvToday: nil, hrvBaseline: nil,
                observedPriorHRVDays: hrvReduced.priorDatedDays.count
            )
        }

        let result = RecoveryScoreEngine.compute(input: RecoveryScoreEngine.RecoveryInput(
            hrvSDNN: hrvReduced.today,
            restingHR: rhrReduced.today,
            sleepDurationMinutes: nil,
            wellnessScore: nil,
            hrvBaseline: hrvBaseline,
            restingHRBaseline: rhrBaseline,
            recentScores: []
        ))

        return Reveal(
            score: result.score,
            zone: result.zone,
            hrvToday: hrvReduced.today,
            hrvBaseline: hrvBaseline,
            observedPriorHRVDays: hrvReduced.priorDatedDays.count
        )
    }
}
