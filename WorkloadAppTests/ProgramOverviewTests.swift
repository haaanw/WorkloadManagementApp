import XCTest
import SwiftData
@testable import workload_management

/// v1.7.3 · UAT round 3 — the Log-page lane (U21 / U22 / U23 / U24).
///
/// Three things are pinned here:
///
/// 1. **`WorkoutSession.volumeIsDistance`** — the discriminator that stops a 1.1 km walk
///    reading "1106 kg" in history (U22), plus the labels built on it.
/// 2. **`TemplateSetSummary`** — the folding rules for a planned exercise's set spec, the
///    content that U21/U24 asked the program page to finally show.
/// 3. **A source fence** — no Swift source under `Views/WorkoutLog` may print `" kg"` as a
///    literal again. That literal IS the U22 defect; a test that only checks today's two
///    call sites would let the third one back in.
@MainActor
final class ProgramOverviewTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let schema = Schema([
            Athlete.self, WorkoutSession.self, ExerciseEntry.self, SetRecord.self,
            WorkoutTemplate.self, ExerciseGroup.self, TemplateExercise.self, TemplateSet.self,
            TrainingProgram.self, ProgramPhase.self, ProgramDay.self,
            ScheduleEntry.self, SyncTombstone.self
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

    // MARK: - Fixtures

    private func makeSession(sport: SportType = .lifting) -> WorkoutSession {
        let session = WorkoutSession(sportType: sport, durationSeconds: 3600, sessionRPE: 6)
        context.insert(session)
        return session
    }

    private func attach(_ sets: [SetRecord], named name: String, to session: WorkoutSession) {
        let entry = ExerciseEntry(exerciseName: name)
        entry.sets = sets
        entry.session = session
        session.exerciseEntries.append(entry)
        context.insert(entry)
    }

    private func makeExercise(
        _ sets: [TemplateSet],
        category: ExerciseCategory = .compound
    ) -> TemplateExercise {
        let exercise = TemplateExercise(exerciseName: "Back squat", exerciseCategory: category)
        exercise.sets = sets
        context.insert(exercise)
        return exercise
    }

    // MARK: - U22 · volumeIsDistance

    func testWalkWithDistanceSetsReportsDistanceMode() throws {
        let session = makeSession(sport: .running)
        attach(
            [SetRecord(setIndex: 0, distanceMeters: 1106)],
            named: "Walk",
            to: session
        )
        session.recalculateDerivedFields()

        XCTAssertEqual(session.totalVolume, 1106, accuracy: 0.001,
                       "The stored field carries METRES for a distance session")
        XCTAssertTrue(session.volumeIsDistance)
    }

    func testLiftingSessionReportsTonnageNotDistance() throws {
        let session = makeSession()
        attach(
            [SetRecord(setIndex: 0, reps: 5, weightKg: 100)],
            named: "Back squat",
            to: session
        )
        session.recalculateDerivedFields()

        XCTAssertEqual(session.totalVolume, 500, accuracy: 0.001)
        XCTAssertFalse(session.volumeIsDistance)
    }

    /// A row that carries a volume but no local sets — a legacy session, a synced one, a
    /// fixture — is TONNAGE. The absence of sets says nothing about the unit, and reading it
    /// as distance quietly dropped such sessions out of the weekly tonnage sum.
    func testSetlessSessionWithAVolumeIsTonnage() throws {
        let session = makeSession()
        session.totalVolume = 2000

        XCTAssertFalse(session.volumeIsDistance)
        XCTAssertEqual(AnalyticsEngine.tonnage(of: [session]), 2000, accuracy: 0.001)

        let label = try XCTUnwrap(SessionWorkReading.label(
            for: session, unit: .kg, locale: Locale(identifier: "en_US")
        ))
        XCTAssertTrue(label.contains("kg"), "Expected kilograms, got \(label)")
        XCTAssertFalse(label.contains("km"), "A set-less row is not a distance — got \(label)")
    }

    func testSessionWithNoWorkIsNeitherTonnageNorDistance() throws {
        let session = makeSession(sport: .teamSport)
        session.recalculateDerivedFields()

        XCTAssertEqual(session.totalVolume, 0, accuracy: 0.001)
        XCTAssertFalse(session.volumeIsDistance,
                       "No work at all is not a distance reading — the caller falls to the load")
    }

    func testWalkLabelCarriesKilometresAndNeverKilograms() throws {
        let session = makeSession(sport: .running)
        attach([SetRecord(setIndex: 0, distanceMeters: 1106)], named: "Walk", to: session)
        session.recalculateDerivedFields()

        let label = try XCTUnwrap(SessionWorkReading.label(
            for: session, unit: .kg, locale: Locale(identifier: "en_US")
        ))
        XCTAssertTrue(label.contains("km"), "Expected kilometres, got \(label)")
        XCTAssertFalse(label.contains("kg"), "A walk must never read in kilograms — got \(label)")
        XCTAssertTrue(label.hasPrefix("1.1"), "Expected 1.1 km, got \(label)")
        XCTAssertEqual(SessionWorkReading.title(for: session),
                       String(localized: "metric.distance", defaultValue: "Distance"))
    }

    func testLiftingLabelIsTonnageInTheAthletesUnit() throws {
        let session = makeSession()
        attach([SetRecord(setIndex: 0, reps: 5, weightKg: 100)], named: "Back squat", to: session)
        session.recalculateDerivedFields()

        let metric = try XCTUnwrap(SessionWorkReading.label(
            for: session, unit: .kg, locale: Locale(identifier: "en_US")
        ))
        XCTAssertTrue(metric.contains("kg"), "Expected kilograms, got \(metric)")
        XCTAssertTrue(metric.hasPrefix("500"), "Expected 500 kg, got \(metric)")

        let imperial = try XCTUnwrap(SessionWorkReading.label(
            for: session, unit: .lbs, locale: Locale(identifier: "en_US")
        ))
        XCTAssertTrue(imperial.contains("lb"), "An lb athlete reads pounds — got \(imperial)")
        XCTAssertFalse(imperial.contains("500"),
                       "The value must CONVERT, not just relabel — got \(imperial)")
    }

    func testBareSkillImportFallsBackToTheSRPELoad() throws {
        let session = makeSession(sport: .teamSport)
        session.recalculateDerivedFields()   // 60 min × RPE 6 = 360 AU

        let label = try XCTUnwrap(SessionWorkReading.label(
            for: session, unit: .kg, locale: Locale(identifier: "en_US")
        ))
        XCTAssertTrue(label.contains("360"), "Expected the sRPE load, got \(label)")
        XCTAssertTrue(label.contains("AU"), "The load reading names its unit — got \(label)")
        XCTAssertFalse(label.contains("kg"))
    }

    func testSessionWithNoWorkAndNoRPEHasNoReading() throws {
        let session = WorkoutSession(sportType: .teamSport, durationSeconds: 3600)
        context.insert(session)
        session.recalculateDerivedFields()

        XCTAssertNil(SessionWorkReading.label(
            for: session, unit: .kg, locale: Locale(identifier: "en_US")
        ), "Nothing to say beats a zero")
    }

    // MARK: - U22 · the weekly tonnage sum

    func testWeeklyTonnageExcludesDistanceSessions() throws {
        let lift = makeSession()
        attach([SetRecord(setIndex: 0, reps: 5, weightKg: 100)], named: "Back squat", to: lift)
        lift.recalculateDerivedFields()

        let walk = makeSession(sport: .running)
        attach([SetRecord(setIndex: 0, distanceMeters: 1106)], named: "Walk", to: walk)
        walk.recalculateDerivedFields()

        XCTAssertEqual(AnalyticsEngine.tonnage(of: [lift, walk]), 500, accuracy: 0.001,
                       "1,106 metres are not 1,106 kilograms of weekly tonnage")

        let summary = AnalyticsEngine.computeWeeklySummary(
            currentWeekSessions: [lift, walk],
            previousWeekSessions: [],
            currentWeekRecoverySnapshots: [],
            previousWeekRecoverySnapshots: [],
            currentWeekWorkloadSnapshots: []
        )
        XCTAssertEqual(summary.totalVolume, 500, accuracy: 0.001)
        XCTAssertEqual(summary.sessionCount, 2, "The walk still counts as a session")
    }

    // MARK: - U21/U24 · set-summary folding

    func testLikeSetsFoldIntoOneSpec() throws {
        let exercise = makeExercise((0..<5).map {
            TemplateSet(setIndex: $0, targetReps: 5, targetWeightKg: 100)
        })
        XCTAssertEqual(TemplateSetSummary.line(for: exercise, unit: .kg), "5 × 5 @ 100 kg")
    }

    func testRampingLoadsListEveryStepUnderOneUnit() throws {
        let exercise = makeExercise([
            TemplateSet(setIndex: 0, targetReps: 3, targetWeightKg: 80),
            TemplateSet(setIndex: 1, targetReps: 3, targetWeightKg: 85),
            TemplateSet(setIndex: 2, targetReps: 3, targetWeightKg: 90)
        ])
        XCTAssertEqual(TemplateSetSummary.line(for: exercise, unit: .kg),
                       "3 × 3 @ 80 / 85 / 90 kg")
    }

    func testVariedRepsPrintTheListRatherThanACount() throws {
        let exercise = makeExercise([
            TemplateSet(setIndex: 0, targetReps: 5, targetWeightKg: 100),
            TemplateSet(setIndex: 1, targetReps: 5, targetWeightKg: 100),
            TemplateSet(setIndex: 2, targetReps: 3, targetWeightKg: 100)
        ])
        XCTAssertEqual(TemplateSetSummary.line(for: exercise, unit: .kg),
                       "5 / 5 / 3 @ 100 kg")
    }

    func testRPETargetTakesTheSlotWhenThereIsNoLoad() throws {
        let exercise = makeExercise((0..<4).map {
            TemplateSet(setIndex: $0, targetReps: 8, targetRPE: 8)
        })
        XCTAssertEqual(TemplateSetSummary.line(for: exercise, unit: .kg), "4 × 8 @ RPE 8")
    }

    func testRIRTargetRidesBesideTheLoad() throws {
        let exercise = makeExercise((0..<3).map {
            TemplateSet(setIndex: $0, targetReps: 6, targetWeightKg: 120, targetRIR: 2)
        })
        XCTAssertEqual(TemplateSetSummary.line(for: exercise, unit: .kg),
                       "3 × 6 @ 120 kg · 2 RIR")
    }

    func testBodyweightSetsPrintBW() throws {
        let exercise = makeExercise(
            (0..<3).map { TemplateSet(setIndex: $0, targetReps: 10) },
            category: .bodyweight
        )
        XCTAssertEqual(TemplateSetSummary.line(for: exercise, unit: .kg), "3 × 10 @ BW")
    }

    func testBodyweightWithAddedLoadSaysSo() throws {
        let exercise = makeExercise(
            (0..<3).map { TemplateSet(setIndex: $0, targetReps: 6, targetWeightKg: 10) },
            category: .bodyweight
        )
        XCTAssertEqual(TemplateSetSummary.line(for: exercise, unit: .kg), "3 × 6 @ BW + 10 kg")
    }

    func testWarmupSetsNeverEnterTheSpec() throws {
        let exercise = makeExercise([
            TemplateSet(setIndex: 0, targetReps: 8, targetWeightKg: 40, isWarmup: true),
            TemplateSet(setIndex: 1, targetReps: 5, targetWeightKg: 100),
            TemplateSet(setIndex: 2, targetReps: 5, targetWeightKg: 100)
        ])
        XCTAssertEqual(TemplateSetSummary.line(for: exercise, unit: .kg), "2 × 5 @ 100 kg")
    }

    func testWeightsFollowTheAthletesUnit() throws {
        let exercise = makeExercise((0..<5).map {
            TemplateSet(setIndex: $0, targetReps: 5, targetWeightKg: 100)
        })
        let line = TemplateSetSummary.line(for: exercise, unit: .lbs)
        XCTAssertTrue(line.contains("lbs"), "Expected pounds, got \(line)")
        XCTAssertFalse(line.contains("100 "), "The numeral must convert — got \(line)")
    }

    func testASetlessExerciseSaysHowManySetsItHas() throws {
        let exercise = makeExercise([
            TemplateSet(setIndex: 0, targetReps: 10, isWarmup: true)
        ])
        XCTAssertEqual(TemplateSetSummary.line(for: exercise, unit: .kg), "SETS: 1")
    }

    // MARK: - U22 · source fence

    /// No Swift source under `Views/WorkoutLog` may hold a string literal that prints a
    /// hard-coded kilogram unit. Weights reach the screen through `WeightFormatter`, which
    /// follows the athlete's unit, or through `SessionWorkReading`, which first asks whether
    /// the number is even a weight.
    func testNoHardCodedKilogramLiteralInWorkoutLogViews() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // WorkloadAppTests/
            .deletingLastPathComponent()   // repo root
            .appendingPathComponent("WorkloadApp/Views/WorkoutLog")

        let fm = FileManager.default
        let enumerator = try XCTUnwrap(fm.enumerator(at: root, includingPropertiesForKeys: nil))
        // A quoted run containing a kg unit token: "%.0f kg", "60 kg × 8", "0kg".
        let pattern = try NSRegularExpression(pattern: "\"[^\"\\n]*[0-9fdli@%\\s×x][ ]?[Kk][Gg][^\"\\n]*\"")

        var offenders: [String] = []
        var scanned = 0
        for case let url as URL in enumerator where url.pathExtension == "swift" {
            scanned += 1
            let text = try String(contentsOf: url, encoding: .utf8)
            for (index, line) in text.components(separatedBy: .newlines).enumerated() {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.hasPrefix("//") else { continue }
                let range = NSRange(line.startIndex..., in: line)
                if pattern.firstMatch(in: line, range: range) != nil {
                    offenders.append("\(url.lastPathComponent):\(index + 1) — \(trimmed)")
                }
            }
        }

        XCTAssertGreaterThan(scanned, 5, "Fence enumeration looks broken")
        XCTAssertTrue(offenders.isEmpty, """
            Hard-coded kilogram literal(s) in Views/WorkoutLog. Route the number through \
            WeightFormatter (weights) or SessionWorkReading (a session's work, which may not \
            be a weight at all — U22):
            \(offenders.joined(separator: "\n"))
            """)
    }
}
