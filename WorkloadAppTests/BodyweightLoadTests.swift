import XCTest
import SwiftData
@testable import workload_management

/// v1.7.2 codebase audit — bodyweight "option C".
///
/// The v1.7.1 set-entry convention made the ROW honest (`0 kg` on a `.bodyweight` movement
/// means bodyweight; `nil` means never entered) and left the MATH wrong: 0 × 10 is 0, so
/// three sets of ten pull-ups registered no volume and a pure-calisthenics session reported
/// an external load of zero. The missing quantity was the athlete's body mass.
@MainActor
final class BodyweightLoadTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let schema = Schema([
            Athlete.self, WorkoutSession.self, ExerciseEntry.self, SetRecord.self,
            WorkloadSnapshot.self, RecoverySnapshot.self, WellnessCheckIn.self,
            PersonalRecord.self, BaselineState.self
        ])
        container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = ModelContext(container)
    }

    override func tearDown() {
        context = nil
        container = nil
        super.tearDown()
    }

    // MARK: - The resolver

    func testExternalMovementsAreUnchanged() {
        for category in [ExerciseCategory.compound, .isolation, .plyometric, .drill] {
            XCTAssertEqual(
                BodyweightLoad.effectiveLoadKg(
                    weightKg: 100, category: category,
                    exerciseName: "Back Squat", bodyMassKg: 80
                ),
                100,
                "\(category) must never be touched by the bodyweight rule"
            )
        }
    }

    /// nil in, nil out. Inventing a load from body mass would turn a forgotten field into data
    /// — the exact confusion the 0-vs-nil convention exists to prevent.
    func testUnenteredWeightStaysNil() {
        XCTAssertNil(
            BodyweightLoad.effectiveLoadKg(
                weightKg: nil, category: .bodyweight,
                exerciseName: "Pull-Up", bodyMassKg: 80
            )
        )
    }

    func testPureBodyweightSetCarriesBodyMass() throws {
        XCTAssertEqual(
            try XCTUnwrap(BodyweightLoad.effectiveLoadKg(
                weightKg: 0, category: .bodyweight,
                exerciseName: "Pull-Up", bodyMassKg: 80
            )),
            80, accuracy: 0.001
        )
    }

    func testAddedLoadStacksOnTopOfBodyMass() throws {
        XCTAssertEqual(
            try XCTUnwrap(BodyweightLoad.effectiveLoadKg(
                weightKg: 10, category: .bodyweight,
                exerciseName: "Weighted Dip", bodyMassKg: 80
            )),
            90, accuracy: 0.001
        )
    }

    func testMovementFractionsApply() throws {
        let mass = 80.0
        let cases: [(String, Double)] = [
            ("Pull-Up", 1.00), ("Chin Up", 1.00), ("Muscle-Up", 1.00), ("Ring Dip", 1.00),
            ("Inverted Row", 0.60),
            ("Push-Up", 0.65), ("Press Up", 0.65),
            ("Bodyweight Squat", 0.60), ("Walking Lunge", 0.60), ("Pistol Squat", 0.60),
            // A hanging leg raise hangs the whole body but MOVES the legs — the fraction
            // describes what is lifted, not what is suspended.
            ("Sit-Up", 0.40), ("Hanging Leg Raise", 0.40),
            ("Nordic Hamstring Curl", BodyweightLoad.defaultFraction)
        ]
        for (name, fraction) in cases {
            XCTAssertEqual(
                try XCTUnwrap(BodyweightLoad.effectiveLoadKg(
                    weightKg: 0, category: .bodyweight, exerciseName: name, bodyMassKg: mass
                )),
                mass * fraction, accuracy: 0.001,
                "\(name) resolved to the wrong fraction of body mass"
            )
        }
    }

    /// No body mass on file → the pre-v1.7.2 answer. Degrading to the old number is honest;
    /// guessing a body mass is not.
    func testNoBodyMassDegradesToAddedLoadOnly() {
        XCTAssertEqual(
            BodyweightLoad.effectiveLoadKg(
                weightKg: 0, category: .bodyweight, exerciseName: "Pull-Up", bodyMassKg: nil
            ),
            0
        )
        XCTAssertEqual(
            BodyweightLoad.effectiveLoadKg(
                weightKg: 12, category: .bodyweight, exerciseName: "Pull-Up", bodyMassKg: 0
            ),
            12
        )
    }

    /// The default is mid-range on purpose: over-stating load feeds an inflated ACWR, and an
    /// inflated ACWR tells an athlete to back off a session they could have trained.
    func testDefaultFractionIsConservative() {
        XCTAssertGreaterThan(BodyweightLoad.defaultFraction, 0.4)
        XCTAssertLessThan(BodyweightLoad.defaultFraction, 1.0)
    }

    // MARK: - Through the session

    private func makeSession(bodyMassKg: Double?) -> WorkoutSession {
        let athlete = Athlete(displayName: "Test", sportType: .teamSport)
        athlete.bodyMassKg = bodyMassKg
        context.insert(athlete)

        let session = WorkoutSession(sessionDate: .now, sportType: .lifting)
        session.athlete = athlete
        let entry = ExerciseEntry(exerciseName: "Pull-Up", exerciseCategory: .bodyweight)
        entry.sets = (0..<3).map { SetRecord(setIndex: $0, reps: 10, weightKg: 0) }
        session.exerciseEntries = [entry]
        context.insert(session)
        return session
    }

    /// The headline case: 3 × 10 pull-ups at 80 kg is 2400 kg of work, not zero.
    func testBodyweightSessionNoLongerReportsZeroVolume() throws {
        let session = makeSession(bodyMassKg: 80)
        try context.save()

        session.recalculateDerivedFields()

        XCTAssertEqual(session.totalVolume, 2400, accuracy: 0.001)
        XCTAssertEqual(session.externalLoad, 2400, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(session.exerciseEntries.first?.totalVolume), 2400, accuracy: 0.001)
    }

    func testBodyweightSessionWithoutBodyMassKeepsTheOldNumber() throws {
        let session = makeSession(bodyMassKg: nil)
        try context.save()

        session.recalculateDerivedFields()

        XCTAssertEqual(session.totalVolume, 0,
                       "Without a body mass on file the answer must be the pre-v1.7.2 one")
    }

    func testWarmupSetsAreStillExcluded() throws {
        let session = makeSession(bodyMassKg: 80)
        session.exerciseEntries.first?.sets.first?.isWarmup = true
        try context.save()

        session.recalculateDerivedFields()

        XCTAssertEqual(session.totalVolume, 1600, accuracy: 0.001)
    }

    /// A barbell session must produce exactly the number it always did.
    func testBarbellSessionIsUnchanged() throws {
        let athlete = Athlete(displayName: "Test", sportType: .teamSport)
        athlete.bodyMassKg = 80
        context.insert(athlete)
        let session = WorkoutSession(sessionDate: .now, sportType: .lifting)
        session.athlete = athlete
        let entry = ExerciseEntry(exerciseName: "Back Squat", exerciseCategory: .compound)
        entry.sets = (0..<3).map { SetRecord(setIndex: $0, reps: 5, weightKg: 100) }
        session.exerciseEntries = [entry]
        context.insert(session)
        try context.save()

        session.recalculateDerivedFields()

        XCTAssertEqual(session.totalVolume, 1500, accuracy: 0.001)
    }

    // MARK: - Fences

    /// Body mass is a RAW HealthKit value, not a composite score. The privacy invariant says it
    /// never leaves the device.
    func testBodyMassIsNeverSynced() throws {
        let root = URL(fileURLWithPath: "\(#filePath)")
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: root.appendingPathComponent("WorkloadApp/Services/SyncService.swift"),
            encoding: .utf8
        )
        XCTAssertFalse(
            source.contains("bodyMass"),
            "Body mass reached SyncService — raw HealthKit values must never leave the device"
        )
    }

    /// Personal records and e1RM are deliberately untouched: giving a pull-up an e1RM overnight
    /// would mint a burst of "records" against a stored value of zero.
    func testEstimated1RMStillIgnoresBodyweight() {
        let set = SetRecord(setIndex: 0, reps: 10, weightKg: 0)
        XCTAssertNil(set.estimated1RM)
    }
}
