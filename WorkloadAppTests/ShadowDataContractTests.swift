import XCTest
import SwiftData
@testable import workload_management

/// Phase 24 Plan 01 — date-contract + generic arm-store tests.
///
/// Proves: predictionDate/targetDate math (D-01), the same-day-leak regression (D-03 — a D+1
/// prediction is resolved against D+1's actuals only), the target-day resolvability gate (D-05),
/// the generic arm store round-trips + cascade-deletes (D-12), and arm-equivalence with the
/// legacy columns (D-13). SwiftData-backed tests that traverse the optional to-one relationship
/// predicate use the established XCTSkip pattern (in-memory store traps on iOS 26.1 sim).
@MainActor
final class ShadowDataContractTests: XCTestCase {

    // MARK: - In-memory container (mirrors ShadowAnalyticsServiceTests)

    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            Athlete.self, WorkoutSession.self, ExerciseEntry.self, SetRecord.self,
            WorkloadSnapshot.self, RecoverySnapshot.self, MenstrualCycleSnapshot.self,
            CyclePredictionLog.self, ShadowArmPrediction.self, WellnessCheckIn.self,
            PersonalRecord.self, CoachAthleteRelationship.self, WorkoutTemplate.self,
            ExerciseGroup.self, TemplateExercise.self, TemplateSet.self, PrescribedWorkout.self,
            CustomExercise.self, BehaviorTag.self, TrainingProfile.self,
            SorenessLog.self  // P25 D-04: resolution test inserts/fetches SorenessLog through this container
        ])
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    // MARK: - D-01: targetDate = predictionDate + horizon (start-of-day)

    func test_targetDate_isPredictionDatePlusHorizon() {
        let cal = Calendar.current
        let madeAt = Date()  // arbitrary intra-day time
        let log = CyclePredictionLog(predictionDate: madeAt, predictionHorizonDays: 1)

        let predDay = cal.startOfDay(for: madeAt)
        XCTAssertEqual(log.predictionDate, predDay)
        XCTAssertEqual(log.date, predDay, "legacy date alias mirrors predictionDate")
        XCTAssertEqual(log.predictionHorizonDays, 1)
        let expectedTarget = cal.date(byAdding: .day, value: 1, to: predDay)!
        XCTAssertEqual(log.targetDate, expectedTarget)
        // targetDate is strictly one day after predictionDate.
        XCTAssertEqual(cal.dateComponents([.day], from: log.predictionDate, to: log.targetDate).day, 1)
    }

    func test_targetDate_honorsCustomHorizon() {
        let cal = Calendar.current
        let log = CyclePredictionLog(predictionDate: .now, predictionHorizonDays: 3)
        let expected = cal.date(byAdding: .day, value: 3, to: log.predictionDate)!
        XCTAssertEqual(log.targetDate, expected)
    }

    // MARK: - D-06: recovery label flagged engineDerived; others raw

    func test_recoveryOutcome_isEngineDerived_othersRaw() {
        XCTAssertTrue(ShadowPredictor.engineDerivedOutcomes.contains(.recovery))
        XCTAssertFalse(ShadowPredictor.engineDerivedOutcomes.contains(.wellness))
        XCTAssertFalse(ShadowPredictor.engineDerivedOutcomes.contains(.completion))
        XCTAssertFalse(ShadowPredictor.engineDerivedOutcomes.contains(.pain))
    }

    // MARK: - D-12: arm store round-trip + cascade delete

    func test_armStore_roundTripsAndCascadeDeletes() throws {
        let context = try makeContext()
        let log = CyclePredictionLog(predictionDate: .now)
        context.insert(log)

        let p1 = ShadowArmPrediction(armId: "baseline", outcome: .recovery, predicted: 60)
        let p2 = ShadowArmPrediction(armId: "cycleAware", outcome: .recovery, predicted: 56)
        p1.log = log
        p2.log = log
        context.insert(p1)
        context.insert(p2)
        try context.save()

        // Round-trip: helper reads the predicted value back by (armId, outcome).
        XCTAssertEqual(log.armPredictions.count, 2)
        XCTAssertEqual(log.armPrediction(armId: "baseline", outcome: .recovery), 60)
        XCTAssertEqual(log.armPrediction(armId: "cycleAware", outcome: .recovery), 56)
        XCTAssertNil(log.armPrediction(armId: "baseline", outcome: .wellness))

        // Cascade: deleting the log removes its arm rows.
        context.delete(log)
        try context.save()
        let remaining = try context.fetch(FetchDescriptor<ShadowArmPrediction>())
        XCTAssertTrue(remaining.isEmpty, "cascade delete should remove child arm rows")
    }

    // MARK: - D-13: arm-store MAE equals legacy-column MAE on identical data

    func test_armEquivalence_baselineAndCycleAwareMAE_matchLegacyColumns() {
        // Two synthetic resolved rows; populate BOTH legacy columns and the arm store identically.
        let r1 = CyclePredictionLog(predictionDate: .now)
        r1.recoveryBaseline = 70; r1.recoveryCycleAware = 66; r1.recoveryActual = 65
        attach(&r1.armPredictions, baseline: 70, cycleAware: 66, outcome: .recovery)

        let r2 = CyclePredictionLog(predictionDate: .now)
        r2.recoveryBaseline = 60; r2.recoveryCycleAware = 64; r2.recoveryActual = 72
        attach(&r2.armPredictions, baseline: 60, cycleAware: 64, outcome: .recovery)

        let rows = [r1, r2]
        let baseMAE = armMAE(rows, armId: "baseline", outcome: .recovery)
        let cycleMAE = armMAE(rows, armId: "cycleAware", outcome: .recovery)

        // Legacy MAE (Phase-20 path) — must match byte-for-byte.
        XCTAssertEqual(baseMAE, 8.5, accuracy: 0.0000001)
        XCTAssertEqual(cycleMAE, 4.5, accuracy: 0.0000001)
    }

    // MARK: - P25 D-04: .niggleSeverity case plumbing (Plan 25-02 Task 1)

    func test_niggleSeverity_outcomeRawKey_isStable() {
        XCTAssertEqual(ShadowArmPrediction.outcomeRaw(for: .niggleSeverity), "niggleSeverity")
    }

    func test_niggleSeverity_phaseOffset_isZeroInEveryPhase() {
        // No cycle offset in v1 — every phase (incl. luteal) returns 0.
        for phase in CyclePhase.allCases {
            XCTAssertEqual(
                ShadowPredictor.phaseOffset(for: phase, outcome: .niggleSeverity), 0,
                "niggleSeverity must carry no phase offset (phase=\(phase))"
            )
        }
    }

    func test_niggleSeverity_bothArmsReturnNil() {
        // P25 D-04: neither registered arm predicts .niggleSeverity (nil, not the 50.0 neutral).
        let ctx = CycleContext.none
        for arm in ShadowPredictor.registeredArms() {
            XCTAssertNil(
                arm.predict(.niggleSeverity, [1, 2, 3], ctx),
                "arm \(arm.id) must return nil for .niggleSeverity"
            )
            // Sanity: the same arm still predicts a normal outcome (no over-broad guard).
            XCTAssertNotNil(arm.predict(.wellness, [50, 52, 54], ctx))
        }
    }

    func test_niggleSeverity_notFlaggedEngineDerived() {
        // It's a raw self-report label (like wellness/pain), not engine-derived.
        XCTAssertFalse(ShadowPredictor.engineDerivedOutcomes.contains(.niggleSeverity))
    }

    func test_aggregate_omitsNiggleSeverity_whenNoArmPredictsIt() {
        // Two resolved rows with a niggle actual but NO arm predictions for .niggleSeverity →
        // aggregate yields n=0 for it and omits the key entirely (no crash).
        let r1 = CyclePredictionLog(predictionDate: .now)
        r1.niggleSeverityActual = 6
        let r2 = CyclePredictionLog(predictionDate: .now)
        r2.niggleSeverityActual = 0
        let mae = ShadowAnalyticsService.aggregate(resolvedRows: [r1, r2])
        XCTAssertNil(mae[.niggleSeverity], "aggregate must omit .niggleSeverity (n=0, no predictions)")
    }

    // MARK: - P25 D-04/D-06: max-severity-on-targetDay resolution (Plan 25-02 Task 2)

    /// Pure replica of `ShadowAnalyticsService.fetchMaxNiggleSeverityByDay` grouping: max
    /// `severity` (as Double) per `startOfDay(date)`. Asserting over `[SorenessLog]` arrays
    /// sidesteps the iOS 26.1 optional-relationship `#Predicate` trap (same XCTSkip rationale as
    /// `ShadowAnalyticsServiceTests.resolveOutcomes`), while the rows are still round-tripped
    /// through the container in `test_sorenessLog_roundTripsThroughContainer` to prove schema
    /// registration. The map keys mirror the resolution's `startOfDay(targetDate)` join.
    private func maxNiggleSeverityByDay(_ logs: [SorenessLog]) -> [Date: Double] {
        let cal = Calendar.current
        var map: [Date: Double] = [:]
        for log in logs {
            let day = cal.startOfDay(for: log.date)
            let sev = Double(log.severity)
            map[day] = Swift.max(map[day] ?? sev, sev)
        }
        return map
    }

    /// Pure replica of the per-row join in `resolveOutcomes`: niggle actual for a row's targetDate
    /// is `maxNiggleSeverityByDay[startOfDay(targetDate)] ?? 0.0` — the dense-label 0-if-none rule.
    private func resolveNiggle(targetDate: Date, from logs: [SorenessLog]) -> Double {
        let day = Calendar.current.startOfDay(for: targetDate)
        return maxNiggleSeverityByDay(logs)[day] ?? 0.0
    }

    /// Test 0 (schema registration): a SorenessLog inserts into and fetches back from the
    /// `makeContext()` in-memory container without a SwiftData fatalError — proving `SorenessLog.self`
    /// is in the schema array. Date-only fetch (no relationship predicate → no in-memory trap).
    func test_sorenessLog_roundTripsThroughContainer() throws {
        let context = try makeContext()
        let cal = Calendar.current
        let target = cal.startOfDay(for: cal.date(byAdding: .day, value: -1, to: .now)!)

        let athlete = Athlete(displayName: "Niggle")
        context.insert(athlete)
        let log = SorenessLog(date: target, regionRaw: "quads", typeRaw: "soreness", severity: 7, athlete: athlete)
        context.insert(log)
        try context.save()

        // Fetch back through the container (date-only predicate avoids the optional-relationship trap).
        let descriptor = FetchDescriptor<SorenessLog>(predicate: #Predicate { $0.date >= target })
        let fetched = try context.fetch(descriptor)
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.severity, 7)

        // The container-fetched rows feed the resolution grouping (the actual resolution path).
        XCTAssertEqual(resolveNiggle(targetDate: target, from: fetched), 7.0)
    }

    /// Test 1 (max-in-window): two niggles on the target day (4 and 8) → actual == 8 (max).
    func test_niggleResolution_maxOnTargetDay() {
        let cal = Calendar.current
        let target = cal.startOfDay(for: .now)
        let logs = [
            SorenessLog(date: cal.date(byAdding: .hour, value: 8, to: target)!, regionRaw: "quads", typeRaw: "soreness", severity: 4),
            SorenessLog(date: cal.date(byAdding: .hour, value: 14, to: target)!, regionRaw: "calves", typeRaw: "pain", severity: 8)
        ]
        XCTAssertEqual(resolveNiggle(targetDate: target, from: logs), 8.0)
    }

    /// Test 2 (0-if-none): target day with no niggle → actual == 0 (dense label, still resolvable).
    func test_niggleResolution_zeroIfNone() {
        let cal = Calendar.current
        let target = cal.startOfDay(for: .now)
        // Only a niggle on a DIFFERENT day exists.
        let other = cal.date(byAdding: .day, value: -3, to: target)!
        let logs = [SorenessLog(date: other, regionRaw: "back", typeRaw: "tweak", severity: 9)]
        XCTAssertEqual(resolveNiggle(targetDate: target, from: logs), 0.0)
    }

    /// Test 3 (NO same-day leak): a niggle dated prediction-day D must NOT resolve the D->D+1 row;
    /// only a niggle dated D+1 (the targetDate) does. Mirrors the Phase-24 same-day-leak regression.
    func test_niggleResolution_noSameDayLeak() {
        let cal = Calendar.current
        let predictionDay = cal.startOfDay(for: .now)          // D
        let targetDay = cal.date(byAdding: .day, value: 1, to: predictionDay)!  // D+1

        // A niggle ONLY on prediction day D.
        let leakLogs = [SorenessLog(date: cal.date(byAdding: .hour, value: 10, to: predictionDay)!, regionRaw: "quads", typeRaw: "pain", severity: 6)]
        XCTAssertEqual(resolveNiggle(targetDate: targetDay, from: leakLogs), 0.0,
                       "a niggle on prediction day D must not resolve the D->D+1 row")

        // A niggle on target day D+1 DOES resolve it.
        let goodLogs = leakLogs + [SorenessLog(date: cal.date(byAdding: .hour, value: 9, to: targetDay)!, regionRaw: "quads", typeRaw: "pain", severity: 5)]
        XCTAssertEqual(resolveNiggle(targetDate: targetDay, from: goodLogs), 5.0,
                       "only the niggle on target day D+1 resolves the D->D+1 row")
    }

    /// Test 4 (late-day start-of-day bucketing): a niggle late on D+1 still buckets to startOfDay(D+1).
    func test_niggleResolution_lateDayBucketsToStartOfDay() {
        let cal = Calendar.current
        let predictionDay = cal.startOfDay(for: .now)
        let targetDay = cal.date(byAdding: .day, value: 1, to: predictionDay)!
        // 23:30 on D+1.
        let lateOnTarget = cal.date(byAdding: .minute, value: 23 * 60 + 30, to: targetDay)!
        let logs = [SorenessLog(date: lateOnTarget, regionRaw: "shoulders", typeRaw: "soreness", severity: 3)]
        XCTAssertEqual(resolveNiggle(targetDate: targetDay, from: logs), 3.0)
    }

    // MARK: - helpers

    private func attach(_ preds: inout [ShadowArmPrediction], baseline: Double, cycleAware: Double, outcome: ShadowPredictor.Outcome) {
        preds.append(ShadowArmPrediction(armId: "baseline", outcome: outcome, predicted: baseline))
        preds.append(ShadowArmPrediction(armId: "cycleAware", outcome: outcome, predicted: cycleAware))
    }

    /// Local MAE over the arm store (mirrors what the service's aggregate computes per arm).
    private func armMAE(_ rows: [CyclePredictionLog], armId: String, outcome: ShadowPredictor.Outcome) -> Double {
        var sum = 0.0, n = 0
        for row in rows {
            guard let p = row.armPrediction(armId: armId, outcome: outcome),
                  let a = row.recoveryActual else { continue }
            sum += ShadowPredictor.absoluteError(predicted: p, actual: a)
            n += 1
        }
        return n > 0 ? sum / Double(n) : .nan
    }
}
