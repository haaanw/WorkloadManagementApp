import Foundation
import SwiftData

/// Orchestrates post-workout data flow: PR detection → workload calculation → snapshot upsert.
@MainActor
struct WorkoutPipeline {

    struct PipelineResult {
        let snapshot: WorkloadCalculator.WorkloadResult
        let newPRs: [PersonalRecord]
        let weeklyVolume: Double
        let spikeAlert: WorkloadCalculator.SpikeAlert?
    }

    /// Run after every workout save.
    static func processSession(
        _ session: WorkoutSession,
        athlete: Athlete,
        modelContext: ModelContext,
        syncService: SyncService? = nil
    ) throws -> PipelineResult {
        let workoutRepo = WorkoutRepository(modelContext: modelContext)
        let workloadRepo = WorkloadRepository(modelContext: modelContext)

        // 1. Detect PRs
        let existingPRs = athlete.personalRecords
        let newPRs = PRDetector.detectPRs(session: session, existingPRs: existingPRs)
        for pr in newPRs {
            pr.athlete = athlete
            modelContext.insert(pr)
        }

        // 2. Fetch last 35 days of sessions, build daily load array
        let sessions = try workoutRepo.fetchSessions(last: 35)
        let dailyLoads = buildDailyLoads(from: sessions, days: 35)

        // 3. Compute EWMA workload history
        let workloadHistory = WorkloadCalculator.computeHistoryEWMA(loads: dailyLoads)
        let latestResult: WorkloadCalculator.WorkloadResult
        if let last = workloadHistory.last {
            latestResult = last
        } else {
            latestResult = WorkloadCalculator.WorkloadResult(
                date: .now, atl: 0, ctl: 0, acwr: 0, tsb: 0
            )
        }

        // 4. Compute weekly volume
        let weeklyVol = WorkloadCalculator.weeklyVolume(
            sessions: sessions.map { (date: $0.sessionDate, volume: $0.totalVolume) }
        )

        // 5. Detect session spike (compare current session TSS to recent average)
        let priorTSSValues = sessions
            .filter { $0.persistentModelID != session.persistentModelID }
            .map { $0.trainingStress }
        let spikeAlert = WorkloadCalculator.detectSessionSpike(
            sessionTSS: session.trainingStress,
            recentSessionTSSValues: priorTSSValues
        )

        // 6. Upsert snapshot
        try workloadRepo.upsertSnapshot(
            latestResult,
            weeklyVolume: weeklyVol,
            loadSource: athlete.loadMetricPreference
        )

        // Link today's snapshot to athlete
        let today = Calendar.current.startOfDay(for: .now)
        let predicate = #Predicate<WorkloadSnapshot> { $0.snapshotDate == today }
        let descriptor = FetchDescriptor<WorkloadSnapshot>(predicate: predicate)
        if let snap = try modelContext.fetch(descriptor).first {
            snap.athlete = athlete
        }

        // 7. Stamp session with current ATL/CTL
        session.acuteLoad = latestResult.atl
        session.chronicLoad = latestResult.ctl
        try modelContext.save()

        if let syncService {
            let athleteId = athlete.id
            Task {
                await syncService.pushWorkloadSnapshots(context: modelContext, athleteId: athleteId)
            }
        }

        return PipelineResult(
            snapshot: latestResult,
            newPRs: newPRs,
            weeklyVolume: weeklyVol,
            spikeAlert: spikeAlert
        )
    }

    /// Recompute full workload history (e.g., after session deletion).
    static func recomputeHistory(
        athlete: Athlete,
        modelContext: ModelContext
    ) throws {
        let workoutRepo = WorkoutRepository(modelContext: modelContext)
        let workloadRepo = WorkloadRepository(modelContext: modelContext)

        let sessions = try workoutRepo.fetchSessions(last: 35)
        let dailyLoads = buildDailyLoads(from: sessions, days: 35)
        let history = WorkloadCalculator.computeHistoryEWMA(loads: dailyLoads)

        if let latest = history.last {
            let weeklyVol = WorkloadCalculator.weeklyVolume(
                sessions: sessions.map { (date: $0.sessionDate, volume: $0.totalVolume) }
            )
            try workloadRepo.upsertSnapshot(
                latest,
                weeklyVolume: weeklyVol,
                loadSource: athlete.loadMetricPreference
            )
        }
    }

    // MARK: - Helpers

    /// Build a contiguous array of daily loads (including 0 for rest days).
    private static func buildDailyLoads(from sessions: [WorkoutSession], days: Int) -> [WorkloadCalculator.DailyLoad] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        // Group sessions by day
        var dailyTSS: [Date: Double] = [:]
        for session in sessions {
            let day = calendar.startOfDay(for: session.sessionDate)
            dailyTSS[day, default: 0] += session.trainingStress
        }

        // Build contiguous array from (days) ago to today
        var loads: [WorkloadCalculator.DailyLoad] = []
        for i in stride(from: days, through: 0, by: -1) {
            let date = calendar.date(byAdding: .day, value: -i, to: today)!
            let tss = dailyTSS[date] ?? 0
            loads.append(WorkloadCalculator.DailyLoad(date: date, tss: tss))
        }
        return loads
    }
}
