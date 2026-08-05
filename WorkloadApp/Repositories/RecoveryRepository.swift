import Foundation
import SwiftData

@MainActor
final class RecoveryRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Backfill a night's sleep minutes onto the snapshot of the day the athlete WOKE, when
    /// that row exists and has no sleep yet.
    ///
    /// Why this exists (v1.7.1): sleep is attributed to its wake day, so a night whose wake
    /// day is not today is not written to today's row. Without a backfill the night would be
    /// lost entirely — open the app for the first time after midnight and the previous
    /// morning's session belongs to no row at all. That is worse than the wrong-day
    /// attribution it replaced.
    ///
    /// Deliberately narrow:
    /// - Only fills a row that already exists. A phantom row for a day the pipeline never
    ///   ran would carry a fabricated recovery score.
    /// - Only fills when `sleepDurationMinutes` is nil, so a value that day already measured
    ///   is never overwritten.
    /// - Does NOT recompute that day's `recoveryScore`. Rescoring a past day needs that
    ///   day's baselines, which are gone; the stored score stays the number the athlete saw.
    ///   The backfilled minutes serve the sleep trend, debt math, and the v2 shadow.
    ///
    /// - Returns: true when a row was filled.
    @discardableResult
    func backfillSleep(
        minutes: Double,
        wakeDay: Date,
        athlete: Athlete? = nil
    ) throws -> Bool {
        let day = Calendar.current.startOfDay(for: wakeDay)
        // Date-only #Predicate, athlete filtered in Swift: traversing the OPTIONAL to-one
        // `athlete` relationship inside a #Predicate crashes the SwiftData process rather than
        // throwing (the trap `RecoveryPipeline.runSleepV2Shadow` and `BaselineStateModelTests`
        // already document). Found the hard way — it took down the whole test host.
        let rows = try modelContext.fetch(
            FetchDescriptor<RecoverySnapshot>(predicate: #Predicate { $0.date == day })
        )
        let matching = athlete.map { a in rows.filter { $0.athlete?.id == a.id } } ?? rows
        guard let row = matching.first,
              row.sleepDurationMinutes == nil else { return false }
        row.sleepDurationMinutes = minutes
        row.updatedAt = .now
        try modelContext.save()
        return true
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
        athlete: Athlete? = nil,
        authoritativeHRV: Bool = false
    ) throws {
        let today = Calendar.current.startOfDay(for: .now)
        // Date-only #Predicate + Swift-side athlete filter — the optional to-one relationship
        // must never be traversed inside a #Predicate (see `backfillSleep`).
        let todayRows = try modelContext.fetch(
            FetchDescriptor<RecoverySnapshot>(predicate: #Predicate { $0.date == today })
        )
        let scoped = athlete.map { a in todayRows.filter { $0.athlete?.id == a.id } } ?? todayRows

        if let existing = scoped.first {
            // HRV is written AUTHORITATIVELY when the caller has done the daily reduction
            // itself (v1.7.1): the pipeline now knows whether today has a morning value, and
            // nil means "measured absent", not "not read". Coalescing there would leave a
            // stale midday reading on the row while the score was computed without it — the
            // row would show a number the score never used. Every other caller keeps the
            // protective coalesce, because for them nil really does mean "no reading taken".
            if authoritativeHRV {
                existing.hrvSDNN = hrvSDNN
            } else {
                existing.hrvSDNN = hrvSDNN ?? existing.hrvSDNN
            }
            // RHR keeps the coalesce even on the authoritative path: Apple refines the daily
            // value through the day, so a transient absence is not evidence that the day has
            // no resting heart rate.
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
