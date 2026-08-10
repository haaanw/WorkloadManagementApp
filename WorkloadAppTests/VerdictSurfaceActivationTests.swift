import XCTest
import SwiftData
@testable import workload_management

/// Phase 41 (ACT-01) — surface-scoped activation of the dormant PRS verdict-feeding pipeline.
///
/// Proves the Option-A activation contract:
///   - the app-wide `PRSActivation` / `PRSMasterActivation` defaults stay FALSE (legacy
///     byte-identical guarantee rides on this);
///   - `VerdictSurfaceActivation` defaults FALSE (the bare-call default-off semantics the three
///     named flag-off fence tests depend on);
///   - with both flags at default, `PRSDualRunSurface` is a byte-identical no-op (mirrors the
///     bare-call fence assertions);
///   - the surface flag ALONE (via the production opt-in mechanism `withEnabled(true)`) activates
///     the production path through the OR-guard;
///   - the explicit production opt-in `DashboardViewModel.activateVerdictSurface()` activates the
///     surface end-to-end over REAL history WITHOUT flipping any app-wide flag;
///   - on cold-start the opt-in DEFERS (honest-confidence) rather than fabricating a verdict.
///
/// Does NOT touch the three named flag-off fence tests
/// (`DualRunFlagFenceTests.test_flagOff_dualRunMessage_isNil`,
/// `DualRunFlagFenceTests.test_flagOff_adjust_isNoOp_workoutByteUnchanged`,
/// `DashboardViewModelDualRunTests.test_flagOff_dualRunMessage_nilAfterLoad`) nor the app-wide
/// golden-snapshot fences (`AutoregulationFlagFenceTests`, `BaselineTierFenceTests`).
@MainActor
final class VerdictSurfaceActivationTests: XCTestCase {

    // MARK: - In-memory store (mirrors DashboardViewModelDualRunTests)

    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            Athlete.self,
            WorkoutSession.self,
            ExerciseEntry.self,
            SetRecord.self,
            RecoverySnapshot.self,
            WorkloadSnapshot.self,
            WellnessCheckIn.self,
            TrainingProfile.self,
            PersonalRecord.self,
            SorenessLog.self,
            MenstrualCycleSnapshot.self,
            CyclePredictionLog.self,
            ShadowArmPrediction.self,
            BaselineState.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        return ModelContext(container)
    }

    // MARK: - Seeding helpers

    private func makeSet(
        weightKg: Double? = nil,
        reps: Int? = nil,
        rpe: Double? = nil,
        isWarmup: Bool = false
    ) -> SetRecord {
        SetRecord(reps: reps, weightKg: weightKg, rpe: rpe, rir: nil, isWarmup: isWarmup)
    }

    private func makeStrengthSession(date: Date, weightKg: Double) -> WorkoutSession {
        let session = WorkoutSession(sessionDate: date)
        let entry = ExerciseEntry(exerciseName: "Back Squat", muscleGroup: .quads)
        entry.sets = [
            makeSet(weightKg: weightKg, reps: 5, rpe: 8),
            makeSet(weightKg: weightKg, reps: 5, rpe: 8),
            makeSet(weightKg: weightKg, reps: 5, rpe: 9),
        ]
        session.exerciseEntries = [entry]
        return session
    }

    private func legacyRec() -> AutoregulationEngine.TrainingRecommendation {
        AutoregulationEngine.TrainingRecommendation(
            intensityCap: 10, volumeModifier: 1.0, sessionType: .power,
            warnings: [], headline: "Go Zone", detail: "Legacy headline."
        )
    }

    private func updatedRec() -> AutoregulationEngine.TrainingRecommendation {
        AutoregulationEngine.TrainingRecommendation(
            intensityCap: 6, volumeModifier: 0.5, sessionType: .activeRecovery,
            warnings: [], headline: "Light Day", detail: "Updated headline."
        )
    }

    private func makeWorkout() -> PrescribedWorkout {
        let w = PrescribedWorkout(
            coachId: UUID(), athleteId: UUID(),
            scheduledDate: Date(), templateName: "Test"
        )
        w.targetRPE = 9.0
        w.targetVolume = 100.0
        return w
    }

    /// A REAL FatigueResult via the real engine (so the strain channel is honest, not synthesized).
    private func makeRealFatigueResult() -> FatigueIndexEngine.FatigueResult {
        let input = FatigueIndexEngine.FatigueInput(
            recentSessionTSS: [60, 70, 80, 75, 65],
            baselineSessionTSS: 60,
            sessionsIn14Days: 6,
            baselineSessionsIn14Days: 4,
            trainingStreakDays: 4,
            daysSinceRestPeriod: nil,
            recentRecoveryScores: [60, 58, 55, 52, 50, 48, 45],
            recentWellnessScores: [60, 58, 55, 52, 50, 48, 45],
            softTissueInjuryCount: 0,
            daysSinceLastInjury: nil
        )
        return FatigueIndexEngine.compute(input: input)
    }

    // MARK: - 1. App-wide flags remain false by default

    func test_appWideFlags_remainFalseByDefault() {
        XCTAssertFalse(PRSActivation.isEnabled,
                       "app-wide PRSActivation must stay false by default (legacy byte-identical fences)")
        XCTAssertFalse(PRSMasterActivation.isEnabled,
                       "app-wide PRSMasterActivation must stay false by default (go-live gate untouched)")
    }

    // MARK: - 2. Surface flag defaults false

    func test_verdictSurface_defaultsFalse() {
        XCTAssertFalse(VerdictSurfaceActivation.isEnabled,
                       "VerdictSurfaceActivation must default false (the bare-call default-off semantics the fence tests depend on)")
    }

    // MARK: - 3. Both flags off → byte-identical no-op (mirrors the bare-call fences)

    func test_dualRunSurface_off_returnsNil_byteIdentical() {
        XCTAssertFalse(VerdictSurfaceActivation.isEnabled)
        XCTAssertFalse(PRSActivation.isEnabled)

        let msg = PRSDualRunSurface.dualRunMessage(legacy: legacyRec(), updated: updatedRec())
        XCTAssertNil(msg, "both flags off: dualRunMessage must be nil (byte-identical default)")

        let w = makeWorkout()
        let beforeRPE = w.targetRPE
        let beforeVol = w.targetVolume
        let result = PRSDualRunSurface.adjust(prescribedWorkout: w, with: updatedRec())
        XCTAssertNil(result, "both flags off: adjust must return nil")
        XCTAssertEqual(w.targetRPE, beforeRPE, "both flags off: workout RPE must be unchanged")
        XCTAssertEqual(w.targetVolume, beforeVol, "both flags off: workout volume must be unchanged")
    }

    // MARK: - 4. Surface flag ALONE activates the production path (PRSActivation stays default-false)

    func test_dualRunSurface_on_viaSurfaceFlag_producesMessage() {
        // PRSActivation left at default false; only the surface flag is on (the production
        // opt-in mechanism). The OR-guard must therefore activate the path.
        let msg = VerdictSurfaceActivation.withEnabled(true) {
            XCTAssertFalse(PRSActivation.isEnabled, "PRSActivation must stay false — surface flag alone activates the path")
            return PRSDualRunSurface.dualRunMessage(legacy: legacyRec(), updated: updatedRec())
        }
        let m = try? XCTUnwrap(msg)
        XCTAssertNotNil(m, "surface flag alone must activate the dual-run message via the OR-guard")
        XCTAssertEqual(m?.previousHeadline, "Go Zone")
        XCTAssertEqual(m?.updatedHeadline, "Light Day")
        XCTAssertFalse(m?.title.isEmpty ?? true)
        XCTAssertFalse(m?.explanation.isEmpty ?? true)
    }

    // MARK: - 5. Explicit production opt-in activates the surface end-to-end over real history

    // NOTE: declared `async` purely to give the @MainActor @Observable VM an enclosing concurrency
    // context for clean deinit (mirrors DashboardViewModelDualRunTests). The opt-in build itself is
    // SYNCHRONOUS inside activateVerdictSurface().
    func test_productionOptIn_activatesVerdictSurface_overRealHistory() async throws {
        let ctx = try makeContext()
        let athlete = Athlete(displayName: "Test")
        ctx.insert(athlete)

        // Seed sufficient real history so PRSReadinessInputBuilder.build returns non-nil:
        // 14 recovery snapshots (HRV/RHR/sleep series for personal-z) + strength sessions + a
        // wellness trend so the FatigueResult (strain channel) is honestly computed.
        let cal = Calendar.current
        for i in 0..<14 {
            let day = cal.date(byAdding: .day, value: -(13 - i), to: .now)!
            let snap = RecoverySnapshot(
                date: day,
                hrvSDNN: 55 + Double(i),
                restingHR: 52 - Double(i % 4),
                sleepDurationMinutes: 410 + Double(i * 4),
                recoveryScore: 60
            )
            snap.athlete = athlete
            ctx.insert(snap)

            let session = makeStrengthSession(date: day, weightKg: 100 + Double(i))
            session.athlete = athlete
            ctx.insert(session)

            // wellnessScore is computed from the 1–5 component ratings; seed varied components so
            // the FatigueIndexEngine wellness-trend channel has real (non-flat) data.
            let checkIn = WellnessCheckIn(
                date: day,
                sleepQuality: 3,
                soreness: 3,
                energy: 3 + (i % 2),
                stress: 3
            )
            checkIn.athlete = athlete
            ctx.insert(checkIn)
        }

        let vm = DashboardViewModel()
        // Bare load() snapshots the dual-run inputs but (flags default-off) leaves dualRunMessage nil.
        await vm.load(athlete: athlete, healthKitService: HealthKitService(), modelContext: ctx)
        XCTAssertNil(vm.dualRunMessage, "bare load() must leave dualRunMessage nil (production opt-in not yet called)")

        let legacy = try XCTUnwrap(vm.recommendation, "load() must compute the legacy recommendation")

        // Determinism guard (2026-08-10): load() runs the REAL RecoveryPipeline, whose
        // authoritative today-write CLEARS the seeded today-signals whenever the test host's
        // HealthKit query returns empty instead of throwing — and which of those happens
        // depends on how far the host app's own dashboard has progressed (pure scheduling;
        // the failure surfaced only when another suite ran first in the same clone). The
        // activation contract under test needs today's signals present, so re-assert the
        // seeded i=13 values; when the pipeline kept them this is a no-op.
        vm.latestHRV = vm.latestHRV ?? 68
        vm.latestRHR = vm.latestRHR ?? 51
        vm.latestSleepMinutes = vm.latestSleepMinutes ?? 462

        // Act — the explicit PRODUCTION opt-in (no app-wide flag flip).
        vm.activateVerdictSurface()

        // Assert — surface activated end-to-end over real history.
        XCTAssertFalse(PRSActivation.isEnabled, "production opt-in must not flip the app-wide PRSActivation flag")
        XCTAssertFalse(PRSMasterActivation.isEnabled, "production opt-in must not flip the app-wide PRSMasterActivation flag")
        let message = try XCTUnwrap(vm.dualRunMessage, "production opt-in must activate the verdict surface")
        XCTAssertEqual(message.previousHeadline, legacy.headline,
                       "previous headline must be the live legacy recommendation headline")
        XCTAssertFalse(message.updatedHeadline.isEmpty,
                       "updated headline (readiness × strain-risk) must be non-empty")
    }

    // MARK: - 6. Cold-start opt-in defers (honest-confidence — no fabricated verdict)

    func test_coldStart_optIn_defersToLegacy() async throws {
        let ctx = try makeContext()
        let athlete = Athlete(displayName: "ColdStart")
        ctx.insert(athlete)
        // No recovery/session history → cold-start → no real FatigueResult → builder returns nil.

        let vm = DashboardViewModel()
        await vm.load(athlete: athlete, healthKitService: HealthKitService(), modelContext: ctx)

        // Act — production opt-in over thin/empty data.
        vm.activateVerdictSurface()

        // Assert — honest-confidence deferral: no fabricated verdict.
        XCTAssertNil(vm.dualRunMessage,
                     "cold-start opt-in must defer (builder returns nil) rather than fabricate a verdict")
    }
}
