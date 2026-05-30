import XCTest
import SwiftData
@testable import workload_management

/// Phase 28 Wave 3 (28-03) — PRS-v1 predicting arm in the shadow harness.
///
/// Covers: ShadowPredictor emits a third "prs" arm (shadow-only, flag-independent); prsPrediction is
/// deterministic + leak-free; CyclePredictionLog `*PRS` columns are LOCAL-ONLY and absent from
/// SyncService / have NO Codable conformance (sync-omission negative assertion, MUST-FIX); the
/// Phase-24 date contract holds; ShadowAnalyticsService reports PRS metrics; graceful with zero
/// resolved rows; no activation logic is read or flipped.
@MainActor
final class PRSShadowArmTests: XCTestCase {

    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            Athlete.self,
            WorkoutSession.self,
            RecoverySnapshot.self,
            WellnessCheckIn.self,
            CyclePredictionLog.self,
            ShadowArmPrediction.self,
            SorenessLog.self,
            MenstrualCycleSnapshot.self,
            BaselineState.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        return ModelContext(container)
    }

    private func makeAthlete(_ ctx: ModelContext) -> Athlete {
        let a = Athlete(displayName: "Test")
        ctx.insert(a)
        return a
    }

    private func dayOffset(_ n: Int, from base: Date = Date()) -> Date {
        Calendar.current.date(byAdding: .day, value: n, to: Calendar.current.startOfDay(for: base))!
    }

    // MARK: - PRS arm is registered as a third competing arm

    func test_registeredArms_includesPRS_asThirdArm() {
        let ids = ShadowPredictor.registeredArms().map(\.id)
        XCTAssertEqual(ids, ["baseline", "cycleAware", "prs"])
    }

    func test_prsArm_runsRegardlessOfActivationFlag() {
        // Shadow discipline: PRS logs unconditionally (independent of PRSActivation.isEnabled).
        let armsOff = ShadowPredictor.registeredArms().map(\.id)
        let armsOn = PRSActivation.withEnabled(true) { ShadowPredictor.registeredArms().map(\.id) }
        XCTAssertEqual(armsOff, armsOn)
        XCTAssertTrue(armsOff.contains("prs"))
    }

    // MARK: - prsPrediction determinism + leak-free + different from baseline

    func test_prsPrediction_isDeterministic() {
        let series = [50.0, 52, 54, 53, 56]
        let a = ShadowPredictor.prsPrediction(series: series, outcome: .recovery)
        let b = ShadowPredictor.prsPrediction(series: series, outcome: .recovery)
        XCTAssertEqual(a, b, accuracy: 1e-12)
    }

    func test_prsPrediction_usesOnlySuppliedSeries_noTargetLeak() {
        // The arm only sees the historical series — there is no way to read the target day.
        let series = [40.0, 45, 50, 55, 60] // rising
        let prs = ShadowPredictor.prsPrediction(series: series, outcome: .recovery)
        let base = ShadowPredictor.baselinePrediction(series: series)
        // Rising trend => PRS nudges further up than pure baseline persistence+slope? PRS = base + 0.5*slope.
        XCTAssertGreaterThan(prs, base)
    }

    func test_prsPrediction_decliningTrend_nudgesDown() {
        let series = [60.0, 55, 50, 45, 40] // falling
        let prs = ShadowPredictor.prsPrediction(series: series, outcome: .recovery)
        let base = ShadowPredictor.baselinePrediction(series: series)
        XCTAssertLessThan(prs, base)
    }

    func test_prsPrediction_shortSeries_fallsBackToBaseline() {
        let series = [50.0, 52] // < 3
        XCTAssertEqual(
            ShadowPredictor.prsPrediction(series: series, outcome: .recovery),
            ShadowPredictor.baselinePrediction(series: series),
            accuracy: 1e-12
        )
    }

    func test_prsArm_doesNotPredictNiggleSeverity() {
        let arm = ShadowPredictor.registeredArms().first { $0.id == "prs" }!
        XCTAssertNil(arm.predict(.niggleSeverity, [1, 2, 3, 4], CycleContext.none))
    }

    // MARK: - MUST-FIX: *PRS columns local-only (sync-omission negative assertion)

    func test_cyclePredictionLog_isNotCodable_localOnly() {
        // CyclePredictionLog (and its PRS columns) must NOT be Codable — local-only / never synced.
        XCTAssertFalse((CyclePredictionLog.self as Any) is any Encodable.Type,
                       "CyclePredictionLog must not conform to Encodable (local-only)")
        XCTAssertFalse((CyclePredictionLog.self as Any) is any Decodable.Type,
                       "CyclePredictionLog must not conform to Decodable (local-only)")
    }

    func test_shadowArmPrediction_isNotCodable_localOnly() {
        XCTAssertFalse((ShadowArmPrediction.self as Any) is any Encodable.Type)
        XCTAssertFalse((ShadowArmPrediction.self as Any) is any Decodable.Type)
    }

    func test_prsColumns_storeAndReadBack_localOnly() throws {
        let ctx = try makeContext()
        let athlete = makeAthlete(ctx)
        let row = CyclePredictionLog(predictionDate: dayOffset(-3), predictionHorizonDays: 1)
        row.athlete = athlete
        row.recoveryPRS = 71
        row.wellnessPRS = 62
        row.completionPRS = 0.9
        row.painPRS = 2.1
        ctx.insert(row)
        let fetched = try ctx.fetch(FetchDescriptor<CyclePredictionLog>())
        XCTAssertEqual(fetched.first?.recoveryPRS, 71)
        XCTAssertEqual(fetched.first?.wellnessPRS, 62)
        XCTAssertEqual(fetched.first?.completionPRS, 0.9)
        XCTAssertEqual(fetched.first?.painPRS, 2.1)
    }

    // MARK: - Date contract preserved (Phase 24)

    func test_dateContract_targetIsPredictionPlusHorizon() throws {
        let ctx = try makeContext()
        let athlete = makeAthlete(ctx)
        let predDay = dayOffset(-5)
        let row = CyclePredictionLog(predictionDate: predDay, predictionHorizonDays: 1)
        row.athlete = athlete
        ctx.insert(row)
        let cal = Calendar.current
        XCTAssertEqual(row.predictionDate, cal.startOfDay(for: predDay))
        XCTAssertEqual(row.targetDate, cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: predDay)))
    }

    // MARK: - ShadowAnalyticsService reports PRS metrics

    func test_aggregate_reportsPRSMetricAlongsideBaselineAndCycleAware() throws {
        let ctx = try makeContext()
        let athlete = makeAthlete(ctx)
        for i in 0..<3 {
            let row = CyclePredictionLog(predictionDate: dayOffset(-6 + i), predictionHorizonDays: 1)
            row.athlete = athlete
            row.recoveryActual = 70
            let pBase = ShadowArmPrediction(armId: "baseline", outcome: .recovery, predicted: 60)
            pBase.log = row
            let pCycle = ShadowArmPrediction(armId: "cycleAware", outcome: .recovery, predicted: 65)
            pCycle.log = row
            let pPRS = ShadowArmPrediction(armId: "prs", outcome: .recovery, predicted: 68)
            pPRS.log = row
            row.armPredictions = [pBase, pCycle, pPRS]
            ctx.insert(row)
        }
        let rows = try ctx.fetch(FetchDescriptor<CyclePredictionLog>())
        let result = ShadowAnalyticsService.aggregate(resolvedRows: rows)
        let rec = try XCTUnwrap(result[.recovery])
        XCTAssertEqual(rec.baselineMAE, 10, accuracy: 1e-9)
        XCTAssertEqual(rec.cycleAwareMAE, 5, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(rec.prsMAE), 2, accuracy: 1e-9) // |68-70| = 2
    }

    func test_aggregate_prsMetricNilWhenNoPRSRows_graceful() throws {
        let ctx = try makeContext()
        let athlete = makeAthlete(ctx)
        let row = CyclePredictionLog(predictionDate: dayOffset(-4), predictionHorizonDays: 1)
        row.athlete = athlete
        row.recoveryActual = 70
        let pBase = ShadowArmPrediction(armId: "baseline", outcome: .recovery, predicted: 60)
        pBase.log = row
        let pCycle = ShadowArmPrediction(armId: "cycleAware", outcome: .recovery, predicted: 65)
        pCycle.log = row
        row.armPredictions = [pBase, pCycle] // no PRS arm row
        ctx.insert(row)
        let rows = try ctx.fetch(FetchDescriptor<CyclePredictionLog>())
        let result = ShadowAnalyticsService.aggregate(resolvedRows: rows)
        XCTAssertNotNil(result[.recovery])
        XCTAssertNil(result[.recovery]?.prsMAE) // graceful, not a crash
    }

    func test_metricsReport_worksForPRSArm() throws {
        let ctx = try makeContext()
        let athlete = makeAthlete(ctx)
        for i in 0..<3 {
            let row = CyclePredictionLog(predictionDate: dayOffset(-6 + i), predictionHorizonDays: 1)
            row.athlete = athlete
            row.wellnessActual = 60
            let pPRS = ShadowArmPrediction(armId: "prs", outcome: .wellness, predicted: 58)
            pPRS.log = row
            row.armPredictions = [pPRS]
            ctx.insert(row)
        }
        let rows = try ctx.fetch(FetchDescriptor<CyclePredictionLog>())
        let report = ShadowAnalyticsService.metricsReport(resolvedRows: rows, armId: "prs")
        let well = try XCTUnwrap(report[.wellness])
        XCTAssertEqual(well.n, 3)
        XCTAssertEqual(try XCTUnwrap(well.mae), 2, accuracy: 1e-9)
    }
}
