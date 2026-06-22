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
        dataSource: RecoveryDataSource = .healthKit,
        athlete: Athlete? = nil
    ) throws {
        let today = Calendar.current.startOfDay(for: .now)
        let descriptor: FetchDescriptor<RecoverySnapshot>
        if let athlete {
            let athleteId = athlete.id
            descriptor = FetchDescriptor<RecoverySnapshot>(
                predicate: #Predicate { $0.date == today && $0.athlete?.id == athleteId }
            )
        } else {
            descriptor = FetchDescriptor<RecoverySnapshot>(
                predicate: #Predicate { $0.date == today }
            )
        }

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
            existing.athlete = athlete ?? existing.athlete
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
            snapshot.athlete = athlete
            modelContext.insert(snapshot)
        }
        try modelContext.save()
    }

    /// Fetch today's recovery snapshot if it exists.
    func fetchTodaySnapshot(athlete: Athlete? = nil) throws -> RecoverySnapshot? {
        let today = Calendar.current.startOfDay(for: .now)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        let descriptor: FetchDescriptor<RecoverySnapshot>
        if let athlete {
            let athleteId = athlete.id
            descriptor = FetchDescriptor<RecoverySnapshot>(
                predicate: #Predicate { $0.date >= today && $0.date < tomorrow && $0.athlete?.id == athleteId }
            )
        } else {
            descriptor = FetchDescriptor<RecoverySnapshot>(
                predicate: #Predicate { $0.date >= today && $0.date < tomorrow }
            )
        }
        return try modelContext.fetch(descriptor).first
    }

    /// Fetch recovery snapshots within a date window, sorted ascending.
    /// Accepts an arbitrary `days` span; callers may request multi-cycle windows
    /// (e.g. ~3 menstrual cycles) for same-phase baseline grouping (Plan 18-02).
    func fetchRecoveryHistory(days: Int, athlete: Athlete? = nil) throws -> [RecoverySnapshot] {
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: .now)!
        let descriptor: FetchDescriptor<RecoverySnapshot>
        if let athlete {
            let athleteId = athlete.id
            descriptor = FetchDescriptor<RecoverySnapshot>(
                predicate: #Predicate { $0.date >= startDate && $0.athlete?.id == athleteId },
                sortBy: [SortDescriptor(\.date)]
            )
        } else {
            descriptor = FetchDescriptor<RecoverySnapshot>(
                predicate: #Predicate { $0.date >= startDate },
                sortBy: [SortDescriptor(\.date)]
            )
        }
        return try modelContext.fetch(descriptor)
    }

    /// Fetch recovery snapshots within a date range (for weekly summary computation).
    func fetchSnapshots(from startDate: Date, to endDate: Date, athlete: Athlete? = nil) throws -> [RecoverySnapshot] {
        let descriptor: FetchDescriptor<RecoverySnapshot>
        if let athlete {
            let athleteId = athlete.id
            descriptor = FetchDescriptor<RecoverySnapshot>(
                predicate: #Predicate {
                    $0.date >= startDate && $0.date < endDate && $0.athlete?.id == athleteId
                },
                sortBy: [SortDescriptor(\.date)]
            )
        } else {
            descriptor = FetchDescriptor<RecoverySnapshot>(
                predicate: #Predicate { $0.date >= startDate && $0.date < endDate },
                sortBy: [SortDescriptor(\.date)]
            )
        }
        return try modelContext.fetch(descriptor)
    }

    func fetchLatestSnapshot(athlete: Athlete? = nil) throws -> RecoverySnapshot? {
        let descriptor: FetchDescriptor<RecoverySnapshot>
        if let athlete {
            let athleteId = athlete.id
            descriptor = FetchDescriptor<RecoverySnapshot>(
                predicate: #Predicate { $0.athlete?.id == athleteId },
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
        } else {
            descriptor = FetchDescriptor<RecoverySnapshot>(
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
        }
        return try modelContext.fetch(descriptor).first
    }

    func fetchTodayWellnessCheckIn(athlete: Athlete? = nil) throws -> WellnessCheckIn? {
        let today = Calendar.current.startOfDay(for: .now)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        let descriptor: FetchDescriptor<WellnessCheckIn>
        if let athlete {
            let athleteId = athlete.id
            descriptor = FetchDescriptor<WellnessCheckIn>(
                predicate: #Predicate { $0.date >= today && $0.date < tomorrow && $0.athlete?.id == athleteId }
            )
        } else {
            descriptor = FetchDescriptor<WellnessCheckIn>(
                predicate: #Predicate { $0.date >= today && $0.date < tomorrow }
            )
        }
        return try modelContext.fetch(descriptor).first
    }

    /// Fetch the most recent wellness check-in (newest first), regardless of date.
    /// Read-only "latest prior" query for pre-filling the morning check-in sheet;
    /// the caller prefers today's via `fetchTodayWellnessCheckIn` and falls back here.
    func fetchLatestWellnessCheckIn(athlete: Athlete? = nil) throws -> WellnessCheckIn? {
        let descriptor: FetchDescriptor<WellnessCheckIn>
        if let athlete {
            let athleteId = athlete.id
            descriptor = FetchDescriptor<WellnessCheckIn>(
                predicate: #Predicate { $0.athlete?.id == athleteId },
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
        } else {
            descriptor = FetchDescriptor<WellnessCheckIn>(
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
        }
        return try modelContext.fetch(descriptor).first
    }
}
