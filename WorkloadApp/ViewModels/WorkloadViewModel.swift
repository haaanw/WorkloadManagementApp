import Foundation
import SwiftData

/// Time range options for workload trend charts (ANLYT-01).
enum TimeRange: String, CaseIterable, Identifiable {
    case fourWeeks = "4W"
    case twelveWeeks = "12W"
    case sixMonths = "6M"

    var id: String { rawValue }

    var days: Int {
        switch self {
        case .fourWeeks: return 28
        case .twelveWeeks: return 84
        case .sixMonths: return 180
        }
    }
}

/// Manages time-range state and fetches filtered workload/recovery snapshots for the Workload tab.
@MainActor
@Observable
final class WorkloadViewModel {
    var selectedRange: TimeRange = .fourWeeks
    var trendSnapshots: [WorkloadSnapshot] = []
    var correlationLoadSnapshots: [WorkloadSnapshot] = []
    var correlationRecoverySnapshots: [RecoverySnapshot] = []
    var isLoading = true

    func loadTrendData(modelContext: ModelContext) {
        isLoading = true
        let workloadRepo = WorkloadRepository(modelContext: modelContext)
        let recoveryRepo = RecoveryRepository(modelContext: modelContext)

        // Trend data filtered by selected range
        trendSnapshots = (try? workloadRepo.fetchSnapshots(last: selectedRange.days)) ?? []

        // Correlation data always 28 days
        correlationLoadSnapshots = (try? workloadRepo.fetchSnapshots(last: 28)) ?? []
        correlationRecoverySnapshots = (try? recoveryRepo.fetchRecoveryHistory(days: 28)) ?? []

        isLoading = false
    }
}
