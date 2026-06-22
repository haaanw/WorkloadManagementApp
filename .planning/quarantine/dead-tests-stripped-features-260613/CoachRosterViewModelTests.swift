import XCTest
import SwiftData
@testable import workload_management

@MainActor
final class CoachRosterViewModelTests: XCTestCase {

    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            Athlete.self, CoachAthleteRelationship.self,
            WorkloadSnapshot.self, RecoverySnapshot.self,
            WorkoutSession.self, ExerciseEntry.self, SetRecord.self,
            WellnessCheckIn.self, PersonalRecord.self
        ])
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    func test_load_returnsAcceptedLinkedAthletes() async throws {
        let context = try makeContext()
        let coachId = UUID()
        let athleteId = UUID()
        context.insert(Athlete(id: coachId, displayName: "Coach"))
        let client = Athlete(id: athleteId, displayName: "Athlete A", sportType: .running)
        context.insert(client)
        context.insert(CoachAthleteRelationship(
            coachId: coachId, athleteId: athleteId, status: .accepted
        ))
        try context.save()

        let vm = CoachRosterViewModel()
        await vm.load(context: context, coachAthleteId: coachId)

        XCTAssertEqual(vm.linkedAthletes.count, 1)
        XCTAssertEqual(vm.linkedAthletes.first?.id, athleteId)
    }

    func test_load_excludesPendingRelationships() async throws {
        let context = try makeContext()
        let coachId = UUID()
        let athleteId = UUID()
        context.insert(Athlete(id: coachId, displayName: "Coach"))
        context.insert(Athlete(id: athleteId, displayName: "Pending A"))
        context.insert(CoachAthleteRelationship(
            coachId: coachId, athleteId: athleteId, status: .pending
        ))
        try context.save()

        let vm = CoachRosterViewModel()
        await vm.load(context: context, coachAthleteId: coachId)

        XCTAssertTrue(vm.linkedAthletes.isEmpty)
    }

    func test_load_populatesLatestWorkloadSnapshot() async throws {
        let context = try makeContext()
        let coachId = UUID()
        let athleteId = UUID()
        context.insert(Athlete(id: coachId, displayName: "Coach"))
        let client = Athlete(id: athleteId, displayName: "Client")
        context.insert(client)
        context.insert(CoachAthleteRelationship(
            coachId: coachId, athleteId: athleteId, status: .accepted
        ))
        let older = WorkloadSnapshot(snapshotDate: .now.addingTimeInterval(-86400), acuteLoad: 50)
        older.athlete = client
        let newer = WorkloadSnapshot(snapshotDate: .now, acuteLoad: 100)
        newer.athlete = client
        context.insert(older)
        context.insert(newer)
        try context.save()

        let vm = CoachRosterViewModel()
        await vm.load(context: context, coachAthleteId: coachId)

        XCTAssertEqual(vm.latestWorkloadSnapshot[athleteId]?.acuteLoad, 100)
    }
}
