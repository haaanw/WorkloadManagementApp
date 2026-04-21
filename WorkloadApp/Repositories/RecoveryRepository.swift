import Foundation
import SwiftData

@MainActor
final class RecoveryRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Upsert today's recovery snapshot, including computed baselines for ReasoningEngine.
    func upsertRecoverySnapshot(
        hrvSDNN: Double?,
        restingHR: Double?,
        sleepDurationMinutes: Double?,
        sleepScore: Double? = nil,
        bodyTemp: Double?,
        vo2Max: Double?,
        recoveryScore: Double,
        hrvBaseline: Double? = nil,
        restingHRBaseline: Double? = nil,
        dataSource: RecoveryDataSource = .healthKit
    ) throws {
        let today = Calendar.current.startOfDay(for: .now)
        let predicate = #Predicate<RecoverySnapshot> { $0.date == today }
        let descriptor = FetchDescriptor<RecoverySnapshot>(predicate: predicate)

        if let existing = try modelContext.fetch(descriptor).first {
            existing.hrvSDNN = hrvSDNN ?? existing.hrvSDNN
            existing.restingHR = restingHR ?? existing.restingHR
            existing.sleepDurationMinutes = sleepDurationMinutes ?? existing.sleepDurationMinutes
            existing.sleepScore = sleepScore ?? existing.sleepScore
            existing.bodyTemp = bodyTemp ?? existing.bodyTemp
            existing.vo2Max = vo2Max ?? existing.vo2Max
            existing.recoveryScore = recoveryScore
            existing.hrvBaseline = hrvBaseline ?? existing.hrvBaseline
            existing.restingHRBaseline = restingHRBaseline ?? existing.restingHRBaseline
            existing.updatedAt = .now
        } else {
            let snapshot = RecoverySnapshot(
                date: today,
                hrvSDNN: hrvSDNN,
                restingHR: restingHR,
                sleepDurationMinutes: sleepDurationMinutes,
                sleepScore: sleepScore,
                bodyTemp: bodyTemp,
                vo2Max: vo2Max,
                recoveryScore: recoveryScore,
                hrvBaseline: hrvBaseline,
                restingHRBaseline: restingHRBaseline,
                dataSource: dataSource
            )
            modelContext.insert(snapshot)
        }
        try modelContext.save()
    }

    /// Fetch today's recovery snapshot if it exists.
    func fetchTodaySnapshot() throws -> RecoverySnapshot? {
        let today = Calendar.current.startOfDay(for: .now)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        let predicate = #Predicate<RecoverySnapshot> { $0.date >= today && $0.date < tomorrow }
        let descriptor = FetchDescriptor<RecoverySnapshot>(predicate: predicate)
        return try modelContext.fetch(descriptor).first
    }

    func fetchRecoveryHistory(days: Int) throws -> [RecoverySnapshot] {
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: .now)!
        let predicate = #Predicate<RecoverySnapshot> { $0.date >= startDate }
        let descriptor = FetchDescriptor<RecoverySnapshot>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.date)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// Fetch recovery snapshots within a date range (for weekly summary computation).
    func fetchSnapshots(from startDate: Date, to endDate: Date) throws -> [RecoverySnapshot] {
        let predicate = #Predicate<RecoverySnapshot> { $0.date >= startDate && $0.date < endDate }
        let descriptor = FetchDescriptor<RecoverySnapshot>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.date)]
        )
        return try modelContext.fetch(descriptor)
    }

    func fetchTodayWellnessCheckIn() throws -> WellnessCheckIn? {
        let today = Calendar.current.startOfDay(for: .now)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        let predicate = #Predicate<WellnessCheckIn> { $0.date >= today && $0.date < tomorrow }
        let descriptor = FetchDescriptor<WellnessCheckIn>(predicate: predicate)
        return try modelContext.fetch(descriptor).first
    }
}
