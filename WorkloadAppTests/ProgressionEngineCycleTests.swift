import XCTest
@testable import workload_management

/// Phase 20 Plan 02 — ProgressionEngine late-luteal maintain bias (D-11) cycle overload tests.
final class ProgressionEngineCycleTests: XCTestCase {

    /// Green + optimal context → base progressionType .increase (detrainingLevel .none).
    private func increaseContext() -> ProgressionEngine.TrainingContext {
        ProgressionEngine.TrainingContext(
            recoveryZone: .green, recoveryScore: 85, volumeModifier: 1.0,
            intensityCap: 10, acwrZone: .optimal
        )
    }

    /// Two recent entries (within 7 days apart) producing a small positive progression rate.
    /// 100kg → 100.5kg over ~7 days ≈ 0.5 kg/week → marginal (< 1.0 threshold).
    private func marginalEntries() -> [ExerciseHistoryRecord] {
        let cal = Calendar.current
        let newest = cal.date(byAdding: .day, value: -2, to: .now)!
        let oldest = cal.date(byAdding: .day, value: -9, to: .now)!
        return [
            ExerciseHistoryRecord(date: newest, sets: [SetHistoryRecord(weightKg: 100.5, reps: 5, rpe: 8, durationSeconds: nil, distanceMeters: nil)]),
            ExerciseHistoryRecord(date: oldest, sets: [SetHistoryRecord(weightKg: 100.0, reps: 5, rpe: 8, durationSeconds: nil, distanceMeters: nil)])
        ]
    }

    /// Strong progression: 100kg → 110kg over ~7 days ≈ 10 kg/week → NOT marginal.
    private func strongEntries() -> [ExerciseHistoryRecord] {
        let cal = Calendar.current
        let newest = cal.date(byAdding: .day, value: -2, to: .now)!
        let oldest = cal.date(byAdding: .day, value: -9, to: .now)!
        return [
            ExerciseHistoryRecord(date: newest, sets: [SetHistoryRecord(weightKg: 110, reps: 5, rpe: 8, durationSeconds: nil, distanceMeters: nil)]),
            ExerciseHistoryRecord(date: oldest, sets: [SetHistoryRecord(weightKg: 100, reps: 5, rpe: 8, durationSeconds: nil, distanceMeters: nil)])
        ]
    }

    private func phaseCtx(_ phase: CyclePhase) -> CycleContext {
        CycleContext(
            phase: phase, confidence: 0.8, cycleDay: phase == .lateLuteal ? 26 : 10, cycleLength: 28,
            isOnHormonalContraceptive: false, isPregnant: false, isLactating: false
        )
    }

    private func base(_ entries: [ExerciseHistoryRecord]) -> ProgressionEngine.ExerciseSuggestion {
        ProgressionEngine.suggest(
            exerciseName: "Back Squat", category: .compound,
            context: increaseContext(), recentEntries: entries
        )
    }

    // MARK: - Precondition: base type is .increase for these fixtures

    func test_baseTypeIsIncrease_forMarginalAndStrong() {
        if case .increase = base(marginalEntries()).progressionType {} else { XCTFail("expected base .increase (marginal)") }
        if case .increase = base(strongEntries()).progressionType {} else { XCTFail("expected base .increase (strong)") }
    }

    // MARK: - wouldBiasToMaintain (D-11)

    func test_lateLuteal_marginalIncrease_wouldBias() {
        let entries = marginalEntries()
        XCTAssertTrue(ProgressionEngine.wouldBiasToMaintain(
            base: base(entries), category: .compound, recentEntries: entries, cycleContext: phaseCtx(.lateLuteal)))
    }

    func test_lateLuteal_strongIncrease_wouldNotBias() {
        let entries = strongEntries()
        XCTAssertFalse(ProgressionEngine.wouldBiasToMaintain(
            base: base(entries), category: .compound, recentEntries: entries, cycleContext: phaseCtx(.lateLuteal)))
    }

    func test_earlyLuteal_marginalIncrease_wouldNotBias() {
        // D-11: late luteal ONLY — early luteal must not bias.
        let entries = marginalEntries()
        XCTAssertFalse(ProgressionEngine.wouldBiasToMaintain(
            base: base(entries), category: .compound, recentEntries: entries, cycleContext: phaseCtx(.earlyLuteal)))
    }

    func test_follicular_marginalIncrease_wouldNotBias() {
        let entries = marginalEntries()
        XCTAssertFalse(ProgressionEngine.wouldBiasToMaintain(
            base: base(entries), category: .compound, recentEntries: entries, cycleContext: phaseCtx(.lateFollicular)))
    }

    // MARK: - Non-breaking + activation off

    /// D-12: nil context identical to base suggest(...).
    func test_nilContext_identicalToBase() {
        let entries = marginalEntries()
        let baseSug = base(entries)
        let cycle = ProgressionEngine.suggest(
            exerciseName: "Back Squat", category: .compound, context: increaseContext(),
            recentEntries: entries, cycleContext: nil, cyclesObserved: 5)
        XCTAssertEqual(baseSug.progressionType, cycle.progressionType)
        XCTAssertEqual(baseSug.rationale, cycle.rationale)
    }

    /// D-06: returned type UNCHANGED this phase (activation off) even for a late-luteal marginal increase.
    func test_lateLuteal_marginalIncrease_returnedTypeUnchanged_activationOff() {
        let entries = marginalEntries()
        let baseSug = base(entries)
        let cycle = ProgressionEngine.suggest(
            exerciseName: "Back Squat", category: .compound, context: increaseContext(),
            recentEntries: entries, cycleContext: phaseCtx(.lateLuteal), cyclesObserved: 5)
        XCTAssertEqual(baseSug.progressionType, cycle.progressionType)  // still .increase
    }
}
