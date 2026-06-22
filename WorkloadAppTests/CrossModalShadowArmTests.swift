import XCTest
import SwiftData
@testable import workload_management

/// Phase 41 (41-03, ACT-02) — the DARK cross-modal fatigue-carry arm in the shadow harness.
///
/// Covers: ShadowPredictor emits a fourth `"crossModal"` arm (shadow-only, independent of EVERY
/// activation flag); appending it leaves `baseline` / `cycleAware` / `prs` byte-identical (D-13
/// regression guard); `crossModalPrediction` is deterministic + niggle-nil; the verdict-influence
/// fence `CrossModalShadowGate.crossModalDrivesVerdict` defaults FALSE; the gate is REPORT-ONLY
/// (no `crossModalDrivesVerdict =` production assignment + `validationSummary` does not flip it);
/// and the shadow log models stay local-only / non-Codable (no sync-payload change).
@MainActor
final class CrossModalShadowArmTests: XCTestCase {

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

    // MARK: - 1. crossModal arm is registered as the FOURTH competing arm

    func test_registeredArms_includesCrossModal_asFourthArm() {
        let ids = ShadowPredictor.registeredArms().map(\.id)
        XCTAssertEqual(ids, ["baseline", "cycleAware", "prs", "crossModal"])
    }

    // MARK: - 2. crossModal arm runs regardless of EVERY activation flag

    func test_crossModalArm_runsRegardlessOfEveryActivationFlag() {
        // Shadow discipline: the crossModal arm logs UNCONDITIONALLY — independent of every flag.
        let armsBare = ShadowPredictor.registeredArms().map(\.id)
        XCTAssertTrue(armsBare.contains("crossModal"))

        let armsAllOn = PRSActivation.withEnabled(true) {
            PRSMasterActivation.withEnabled(true) {
                VerdictSurfaceActivation.withEnabled(true) {
                    CrossModalShadowGate.withEnabled(true) {
                        ShadowPredictor.registeredArms().map(\.id)
                    }
                }
            }
        }
        let armsAllOff = PRSActivation.withEnabled(false) {
            PRSMasterActivation.withEnabled(false) {
                VerdictSurfaceActivation.withEnabled(false) {
                    CrossModalShadowGate.withEnabled(false) {
                        ShadowPredictor.registeredArms().map(\.id)
                    }
                }
            }
        }
        XCTAssertEqual(armsAllOn, armsBare)
        XCTAssertEqual(armsAllOff, armsBare)
        XCTAssertTrue(armsAllOn.contains("crossModal"))
        XCTAssertTrue(armsAllOff.contains("crossModal"))
    }

    // MARK: - 3. Existing arms stay byte-identical after adding crossModal (D-13 regression guard)

    func test_existingArms_byteIdentical_afterAddingCrossModal() {
        // Fixed input series; the addition of the fourth arm must not perturb the first three.
        let series = [50.0, 52, 54, 53, 56]
        let ctx = CycleContext.none
        let arms = Dictionary(uniqueKeysWithValues: ShadowPredictor.registeredArms().map { ($0.id, $0) })

        for outcome in ShadowPredictor.Outcome.allCases where outcome != .niggleSeverity {
            let base = ShadowPredictor.baselinePrediction(series: series)
            let cycle = ShadowPredictor.cycleAwarePrediction(series: series, context: ctx, outcome: outcome)
            let prs = ShadowPredictor.prsPrediction(series: series, outcome: outcome)

            XCTAssertEqual(arms["baseline"]!.predict(outcome, series, ctx)!, base, accuracy: 1e-12)
            XCTAssertEqual(arms["cycleAware"]!.predict(outcome, series, ctx)!, cycle, accuracy: 1e-12)
            XCTAssertEqual(arms["prs"]!.predict(outcome, series, ctx)!, prs, accuracy: 1e-12)
        }
    }

    // MARK: - 4. crossModal prediction is deterministic + does not predict niggleSeverity

    func test_crossModalArm_isDeterministic() {
        let series = [50.0, 52, 54, 53, 56]
        let a = ShadowPredictor.crossModalPrediction(series: series, outcome: .recovery)
        let b = ShadowPredictor.crossModalPrediction(series: series, outcome: .recovery)
        XCTAssertEqual(a, b, accuracy: 1e-12)

        // Also via the registered arm closure (same value, deterministic).
        let arm = ShadowPredictor.registeredArms().first { $0.id == "crossModal" }!
        let c = arm.predict(.recovery, series, CycleContext.none)
        XCTAssertEqual(try XCTUnwrap(c), a, accuracy: 1e-12)
    }

    func test_crossModalArm_doesNotPredictNiggleSeverity() {
        let arm = ShadowPredictor.registeredArms().first { $0.id == "crossModal" }!
        XCTAssertNil(arm.predict(.niggleSeverity, [1, 2, 3, 4], CycleContext.none))
    }

    func test_crossModalArm_isGenuinelyDifferentFromBaseline_underElevation() {
        // A strongly rising series proxies above-normal cross-modal carry → the arm depresses the
        // next-day capacity outcome below pure baseline (run-loads-legs direction), and raises pain.
        let rising = [40.0, 45, 50, 56, 64]
        let baseRecovery = ShadowPredictor.baselinePrediction(series: rising)
        let cmRecovery = ShadowPredictor.crossModalPrediction(series: rising, outcome: .recovery)
        XCTAssertLessThan(cmRecovery, baseRecovery, "elevated carry depresses next-day recovery")

        let basePain = ShadowPredictor.baselinePrediction(series: rising)
        let cmPain = ShadowPredictor.crossModalPrediction(series: rising, outcome: .pain)
        XCTAssertGreaterThan(cmPain, basePain, "elevated carry raises next-day pain")
    }

    // MARK: - 5. Verdict-influence gate defaults OFF

    func test_crossModalVerdictGate_defaultsOff() {
        XCTAssertFalse(CrossModalShadowGate.crossModalDrivesVerdict,
                       "the cross-modal channel must be fenced from the verdict by default")
    }

    // MARK: - 6. Gate is REPORT-ONLY — no production flag mutation

    /// Source-level no-mutation grep (mirrors ActivationGateEvaluatorTests GA-7): resolve the gate
    /// source via #filePath parent traversal and assert it contains no `crossModalDrivesVerdict =`
    /// assignment outside the test-only `_override` inside `withEnabled`.
    func test_crossModalShadowGate_isReportOnly_noFlagMutation_sourceGrep() throws {
        let repoRoot = URL(fileURLWithPath: "\(#filePath)")
            .deletingLastPathComponent()   // WorkloadAppTests/
            .deletingLastPathComponent()   // <repo root>
        let source = repoRoot
            .appendingPathComponent("WorkloadApp/Services/CrossModalShadowGate.swift")
        let text = try String(contentsOf: source, encoding: .utf8)

        // The only assignment of the underlying flag state is the test-only `_override = ...` inside
        // `withEnabled`. There must be ZERO `crossModalDrivesVerdict =` assignment (the gate is a
        // computed property; assigning it is impossible, but we forbid the substring to guarantee no
        // future code introduces a stored-property assignment). Tolerate `==` comparisons.
        let pattern = "crossModalDrivesVerdict ="
        var searchRange = text.startIndex..<text.endIndex
        while let r = text.range(of: pattern, range: searchRange) {
            let afterEq = r.upperBound
            let isComparison = afterEq < text.endIndex && text[afterEq] == "="
            XCTAssertTrue(isComparison,
                          "CrossModalShadowGate must never assign crossModalDrivesVerdict (report-only)")
            searchRange = r.upperBound..<text.endIndex
        }
    }

    /// Behavioural no-mutation guard: calling the report-only `validationSummary` must NOT flip the
    /// verdict gate (it stays false), and the summary's mirrored flag reads false.
    func test_validationSummary_isReportOnly_doesNotFlipGate() throws {
        let ctx = try makeContext()
        let athlete = makeAthlete(ctx)
        // A handful of resolved rows carrying crossModal + baseline predictions for one outcome.
        for i in 0..<3 {
            let row = CyclePredictionLog(
                predictionDate: Calendar.current.date(byAdding: .day, value: -6 + i, to: Date())!,
                predictionHorizonDays: 1
            )
            row.athlete = athlete
            row.wellnessActual = 60
            let pBase = ShadowArmPrediction(armId: "baseline", outcome: .wellness, predicted: 58)
            pBase.log = row
            let pCM = ShadowArmPrediction(armId: "crossModal", outcome: .wellness, predicted: 59)
            pCM.log = row
            row.armPredictions = [pBase, pCM]
            ctx.insert(row)
        }
        let rows = try ctx.fetch(FetchDescriptor<CyclePredictionLog>())

        XCTAssertFalse(CrossModalShadowGate.crossModalDrivesVerdict) // before
        let summary = CrossModalShadowGate.validationSummary(resolvedRows: rows)
        XCTAssertFalse(CrossModalShadowGate.crossModalDrivesVerdict, "report-only: must not flip the gate")
        XCTAssertFalse(summary.crossModalDrivesVerdict, "summary mirrors the still-OFF gate")
        // The summary surfaces the EXISTING metrics for the crossModal arm (no new statistics).
        XCTAssertNotNil(summary.crossModalMetrics[.wellness])
    }

    // MARK: - 7. Shadow log models stay local-only (no sync-payload change)

    func test_cyclePredictionLog_isNotCodable_localOnly() {
        XCTAssertFalse((CyclePredictionLog.self as Any) is any Encodable.Type,
                       "CyclePredictionLog must not conform to Encodable (local-only)")
        XCTAssertFalse((CyclePredictionLog.self as Any) is any Decodable.Type,
                       "CyclePredictionLog must not conform to Decodable (local-only)")
        XCTAssertFalse((ShadowArmPrediction.self as Any) is any Encodable.Type,
                       "ShadowArmPrediction must not conform to Encodable (local-only)")
        XCTAssertFalse((ShadowArmPrediction.self as Any) is any Decodable.Type,
                       "ShadowArmPrediction must not conform to Decodable (local-only)")
    }
}
