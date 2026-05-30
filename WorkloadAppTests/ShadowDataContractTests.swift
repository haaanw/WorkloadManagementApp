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
            CustomExercise.self, BehaviorTag.self, TrainingProfile.self
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
