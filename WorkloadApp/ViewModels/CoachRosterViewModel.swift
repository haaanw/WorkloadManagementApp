import Foundation
import SwiftData

@MainActor
@Observable
final class CoachRosterViewModel {
    var linkedAthletes: [Athlete] = []
    var latestWorkloadSnapshot: [UUID: WorkloadSnapshot] = [:]
    var latestRecoverySnapshot: [UUID: RecoverySnapshot] = [:]
    var isLoading = false
    var errorMessage: String?

    func load(context: ModelContext, coachAthleteId: UUID) async {
        isLoading = true
        errorMessage = nil
        do {
            // 1. Find accepted relationships where this user is the coach
            let allRels = try context.fetch(FetchDescriptor<CoachAthleteRelationship>())
            let acceptedAthleteIds = Set(
                allRels
                    .filter { $0.coachId == coachAthleteId && $0.status == .accepted }
                    .map { $0.athleteId }
            )

            // 2. Fetch those athlete profiles
            let allAthletes = try context.fetch(FetchDescriptor<Athlete>())
            linkedAthletes = allAthletes.filter { acceptedAthleteIds.contains($0.id) }

            // 3. Latest workload snapshot per linked athlete (via relationship)
            for athlete in linkedAthletes {
                latestWorkloadSnapshot[athlete.id] = athlete.workloadSnapshots
                    .sorted { $0.snapshotDate > $1.snapshotDate }
                    .first
            }

            // 4. Latest recovery snapshot per linked athlete (via relationship)
            for athlete in linkedAthletes {
                latestRecoverySnapshot[athlete.id] = athlete.recoverySnapshots
                    .sorted { $0.date > $1.date }
                    .first
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
