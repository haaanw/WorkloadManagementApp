import Foundation
import SwiftData

// (`TimeRange` moved to `TrendsViewModel.swift` with the Trends merge — the range
// control and the enum outlive this tab.)

/// Manages time-range state and fetches filtered workload/recovery snapshots for the Workload tab.
@MainActor
@Observable
final class WorkloadViewModel {
    var selectedRange: TimeRange = .fourWeeks
    var trendSnapshots: [WorkloadSnapshot] = []
    var correlationLoadSnapshots: [WorkloadSnapshot] = []
    var correlationRecoverySnapshots: [RecoverySnapshot] = []
    var isLoading = true

    func loadTrendData(modelContext: ModelContext, athlete: Athlete) {
        isLoading = true
        let workloadRepo = WorkloadRepository(modelContext: modelContext)
        let recoveryRepo = RecoveryRepository(modelContext: modelContext)

        // Trend data filtered by selected range
        trendSnapshots = (try? workloadRepo.fetchSnapshots(last: selectedRange.days, athlete: athlete)) ?? []

        // Correlation data always 28 days
        correlationLoadSnapshots = (try? workloadRepo.fetchSnapshots(last: 28, athlete: athlete)) ?? []
        correlationRecoverySnapshots = (try? recoveryRepo.fetchRecoveryHistory(days: 28, athlete: athlete)) ?? []

        isLoading = false
    }
}
