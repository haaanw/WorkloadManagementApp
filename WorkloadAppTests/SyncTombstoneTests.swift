import XCTest
import SwiftData
@testable import workload_management

/// v1.7.2 codebase audit — finding H6, "deletion resurrection".
///
/// Sync is a full upsert with no dirty flags, so the local store held no evidence that a
/// deletion had ever happened. Delete a workout, and the next pull read the row still
/// sitting on the server and put it straight back; deleting again just repeated the cycle.
///
/// A `SyncTombstone` is that missing evidence. These tests pin the properties the fix
/// depends on: the record is written in the SAME transaction as the delete (so an offline
/// delete is durable), a pull refuses to re-create a tombstoned id, and pruning never
/// touches a deletion the server has not been told about.
///
/// Toolchain note (mirrors `VerdictEventRepositoryTests`): the `@MainActor` repositories
/// and their `ModelContext` are held as stored properties and released in a plain,
/// non-throwing `tearDown`. Creating or releasing a `@MainActor` class inside a throwing
/// test method trips a libswift_Concurrency back-deploy deinit bug on the iOS 26.1
/// simulator (`swift_task_deinitOnExecutorMainActorBackDeploy` → libmalloc → SIGABRT).
@MainActor
final class SyncTombstoneTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!
    private var workouts: WorkoutRepository!
    private var templates: TemplateRepository!
    private var behaviorTags: BehaviorTagRepository!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let schema = Schema([
            Athlete.self, WorkoutSession.self, ExerciseEntry.self, SetRecord.self,
            WorkloadSnapshot.self, RecoverySnapshot.self, MenstrualCycleSnapshot.self,
            CyclePredictionLog.self, ShadowArmPrediction.self, SorenessLog.self,
            BaselineState.self, WellnessCheckIn.self, PersonalRecord.self,
            CoachAthleteRelationship.self, WorkoutTemplate.self, ExerciseGroup.self,
            TemplateExercise.self, TemplateSet.self, PrescribedWorkout.self,
            CustomExercise.self, BehaviorTag.self, TrainingProfile.self,
            SyncTombstone.self
        ])
        container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        context = ModelContext(container)
        workouts = WorkoutRepository(modelContext: context)
        templates = TemplateRepository(modelContext: context)
        behaviorTags = BehaviorTagRepository(modelContext: context)
    }

    override func tearDown() {
        workouts = nil
        templates = nil
        behaviorTags = nil
        context = nil
        container = nil
        super.tearDown()
    }

    private func makeAthlete() -> Athlete {
        let athlete = Athlete(displayName: "Test", sportType: .teamSport)
        context.insert(athlete)
        return athlete
    }

    // MARK: - Recording

    func testDeletingASessionRecordsATombstone() throws {
        let athlete = makeAthlete()
        let session = WorkoutSession(sessionDate: .now, sportType: .lifting)
        session.athlete = athlete
        context.insert(session)
        try context.save()
        let deletedId = session.id

        try workouts.deleteSession(session)

        let tombstones = SyncTombstone.all(in: context)
        XCTAssertEqual(tombstones.count, 1)
        XCTAssertEqual(tombstones.first?.rowId, deletedId)
        XCTAssertEqual(tombstones.first?.entity, .workouts)
        XCTAssertEqual(tombstones.first?.athleteId, athlete.id)
        XCTAssertEqual(tombstones.first?.isPushed, false,
                       "A fresh deletion has not reached the server yet")
    }

    func testDeletingATemplateRecordsATombstone() throws {
        let athlete = makeAthlete()
        let template = WorkoutTemplate(coachId: athlete.id, templateName: "Push A")
        context.insert(template)
        try context.save()
        let deletedId = template.id

        try templates.delete(template)

        let tombstones = SyncTombstone.all(in: context)
        XCTAssertEqual(tombstones.map(\.rowId), [deletedId])
        XCTAssertEqual(tombstones.first?.entity, .templates)
    }

    func testDeletingACustomBehaviorTagRecordsATombstone() throws {
        let athlete = makeAthlete()
        let tag = BehaviorTag(date: .now, tagName: "Late night", isActive: true, isCustom: true)
        tag.athlete = athlete
        context.insert(tag)
        try context.save()
        let deletedId = tag.id

        try behaviorTags.deleteCustomTag(named: "Late night", for: athlete)

        XCTAssertEqual(SyncTombstone.all(in: context).map(\.rowId), [deletedId])
    }

    /// The tombstone and the delete must land in one `save()`. If the tombstone needed its
    /// own save, a crash between the two would leave a deleted row with no record of the
    /// deletion — exactly the state the fix exists to prevent.
    func testTombstoneAndDeleteCommitTogether() throws {
        let athlete = makeAthlete()
        let session = WorkoutSession(sessionDate: .now, sportType: .lifting)
        session.athlete = athlete
        context.insert(session)
        try context.save()

        try workouts.deleteSession(session)

        XCTAssertFalse(context.hasChanges, "Deletion left uncommitted changes behind")
        let reread = ModelContext(container)
        XCTAssertEqual(SyncTombstone.all(in: reread).count, 1,
                       "The tombstone did not reach the store")
        XCTAssertEqual(
            (try reread.fetch(FetchDescriptor<WorkoutSession>())).count, 0
        )
    }

    func testRecordingTheSameRowTwiceKeepsOneTombstone() throws {
        let rowId = UUID()
        let athleteId = UUID()
        SyncTombstone.record(rowId: rowId, entity: .workouts, athleteId: athleteId, in: context)
        try context.save()
        SyncTombstone.record(rowId: rowId, entity: .workouts, athleteId: athleteId, in: context)
        try context.save()

        XCTAssertEqual(SyncTombstone.all(in: context).count, 1)
    }

    /// Two entities may not share a tombstone slot — the id space is per table.
    func testEntityIsPartOfTheIdentity() throws {
        let rowId = UUID()
        let athleteId = UUID()
        SyncTombstone.record(rowId: rowId, entity: .workouts, athleteId: athleteId, in: context)
        SyncTombstone.record(rowId: rowId, entity: .templates, athleteId: athleteId, in: context)
        try context.save()

        XCTAssertEqual(SyncTombstone.deletedRowIds(entity: .workouts, in: context), [rowId])
        XCTAssertEqual(SyncTombstone.deletedRowIds(entity: .templates, in: context), [rowId])
        XCTAssertTrue(SyncTombstone.deletedRowIds(entity: .personalRecords, in: context).isEmpty)
    }

    // MARK: - Reading

    func testPendingIsGroupedByEntityAndExcludesPushed() throws {
        let athleteId = UUID()
        SyncTombstone.record(rowId: UUID(), entity: .workouts, athleteId: athleteId, in: context)
        SyncTombstone.record(rowId: UUID(), entity: .workouts, athleteId: athleteId, in: context)
        SyncTombstone.record(rowId: UUID(), entity: .templates, athleteId: athleteId, in: context)
        SyncTombstone.record(
            rowId: UUID(), entity: .behaviorTags, athleteId: athleteId, in: context, isPushed: true
        )
        try context.save()

        let pending = SyncTombstone.pendingByEntity(in: context)
        XCTAssertEqual(pending[.workouts]?.count, 2)
        XCTAssertEqual(pending[.templates]?.count, 1)
        XCTAssertNil(pending[.behaviorTags], "A confirmed deletion is not pending")
    }

    // MARK: - Pruning

    func testPruneDropsOldConfirmedTombstonesOnly() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let old = now.addingTimeInterval(-SyncTombstone.retention - 1)
        let athleteId = UUID()

        let staleConfirmed = SyncTombstone(
            rowId: UUID(), entity: .workouts, athleteId: athleteId, deletedAt: old, isPushed: true
        )
        let staleUnpushed = SyncTombstone(
            rowId: UUID(), entity: .workouts, athleteId: athleteId, deletedAt: old, isPushed: false
        )
        let freshConfirmed = SyncTombstone(
            rowId: UUID(), entity: .workouts, athleteId: athleteId, deletedAt: now, isPushed: true
        )
        [staleConfirmed, staleUnpushed, freshConfirmed].forEach(context.insert)
        try context.save()

        SyncTombstone.prune(in: context, now: now)
        try context.save()

        let survivors = Set(SyncTombstone.all(in: context).map(\.rowId))
        XCTAssertFalse(survivors.contains(staleConfirmed.rowId))
        XCTAssertTrue(
            survivors.contains(staleUnpushed.rowId),
            "An unpushed tombstone IS the deletion intent — pruning it resurrects the row"
        )
        XCTAssertTrue(survivors.contains(freshConfirmed.rowId))
    }

    // MARK: - Source fences

    private func readSource(_ relativePath: String, file: StaticString = #filePath) -> String {
        let root = URL(fileURLWithPath: "\(file)")
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = root.appendingPathComponent(relativePath)
        guard let contents = try? String(contentsOf: url, encoding: .utf8) else {
            XCTFail("Fence could not resolve source at \(url.path)")
            return ""
        }
        return contents
    }

    /// Every pull loop that can re-create a deletable row must consult the tombstones
    /// first. A loop that forgets is exactly the resurrection defect, back for one entity.
    func testEveryDeletablePullLoopChecksTombstones() {
        let source = readSource("WorkloadApp/Services/SyncService.swift")
        XCTAssertFalse(source.isEmpty)

        for entity in ["workouts", "templates", "personalRecords", "behaviorTags", "wellnessCheckIns"] {
            XCTAssertTrue(
                source.contains("SyncTombstone.deletedRowIds(entity: .\(entity), in: context)"),
                "The \(entity) pull does not check tombstones — deleted rows will resurrect (audit H6)"
            )
        }
        XCTAssertEqual(
            source.components(separatedBy: "if tombstoned.contains(row.id) { continue }").count - 1,
            5,
            "Expected the tombstone skip on all five deletable pull loops"
        )
    }

    /// Deletions must settle before any row moves in either direction. Reversing the order
    /// lets this device push back a row another device deleted in the same cycle.
    func testTombstonesReconcileBeforeRowsMove() {
        let source = readSource("WorkloadApp/Services/SyncService.swift")
        XCTAssertFalse(source.isEmpty)

        for entryPoint in ["func pushAll(context: ModelContext) async {",
                           "func pullAll(context: ModelContext) async {"] {
            guard let start = source.range(of: entryPoint) else {
                return XCTFail("Could not find \(entryPoint) — re-point this fence")
            }
            let body = source[start.upperBound...]
            guard let reconcile = body.range(of: "await reconcileTombstones("),
                  let firstRowCall = body.range(of: "athleteId: athlete.id)") ?? body.range(of: "athlete: athlete)") else {
                return XCTFail("\(entryPoint) does not reconcile tombstones (audit H6)")
            }
            XCTAssertTrue(
                reconcile.lowerBound < firstRowCall.lowerBound,
                "\(entryPoint) moves rows before deletions settle (audit H6)"
            )
        }
    }

    /// The sign-out and account-deletion wipes must clear tombstones. They are keyed by
    /// athlete id rather than an `Athlete` relationship, so the cascade does not reach them
    /// — the same shape as the `ExerciseOverride` leak fixed in v1.6.
    func testSignOutClearsTombstones() {
        let source = readSource("WorkloadApp/App/AppContainer.swift")
        XCTAssertFalse(source.isEmpty)
        XCTAssertEqual(
            source.components(separatedBy: "SyncTombstone.all(in: modelContext)").count - 1, 2,
            "Expected the tombstone purge in BOTH signOut and deleteAccount"
        )
    }
}
