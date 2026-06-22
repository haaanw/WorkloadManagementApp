import Foundation
import SwiftData

/// Phase 45 Plan 01 — persistence for the **local-only, composite-only** `VerdictEvent` log
/// (METRIC-01). Mirrors `SorenessLogRepository`'s posture: reads/writes on-device only, never
/// encodes/uploads/syncs (the type name appears nowhere in `SyncService.swift`).
///
/// ## Conventions
/// - `log(...)` constructs + inserts the row **and saves** (self-contained, matching
///   `SorenessLogRepository.insert`). Callers need not call `save()` themselves.
/// - Fetches return **newest-first** by `decidedAt`.
/// - To dodge the iOS 26.1 in-memory SwiftData trap on optional to-one relationship `#Predicate`,
///   the value-only filters (date window / outcome nil) are applied in the `FetchDescriptor` and the
///   optional `athlete` relationship is filtered in Swift **after** the fetch — never via an
///   `athlete?.id` predicate.
@MainActor
final class VerdictEventRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Construct, insert, and save a new composite verdict event. Returns the inserted row.
    @discardableResult
    func log(
        decidedAt: Date,
        planDate: Date,
        verdictKindRaw: String,
        plannedTopSetKg: Double,
        adjustedTopSetKg: Double?,
        deltaKg: Double,
        differed: Bool,
        actionRaw: String,
        regionRaw: String,
        reasonLine: String,
        confidenceNote: String?,
        athlete: Athlete?
    ) -> VerdictEvent {
        let event = VerdictEvent(
            decidedAt: decidedAt,
            planDate: planDate,
            verdictKindRaw: verdictKindRaw,
            plannedTopSetKg: plannedTopSetKg,
            adjustedTopSetKg: adjustedTopSetKg,
            deltaKg: deltaKg,
            differed: differed,
            actionRaw: actionRaw,
            regionRaw: regionRaw,
            reasonLine: reasonLine,
            confidenceNote: confidenceNote,
            athlete: athlete
        )
        modelContext.insert(event)
        try? modelContext.save()
        return event
    }

    /// Record the post-session self-report ("right" / "wrong" / "unsure") onto an event and save.
    func recordOutcome(_ outcomeRaw: String, for event: VerdictEvent, at date: Date = .now) {
        event.outcomeRaw = outcomeRaw
        event.outcomeRecordedAt = date
        event.updatedAt = date
        try? modelContext.save()
    }

    /// All events, newest-first by `decidedAt`. Athlete filtered in Swift (no relationship predicate).
    func fetchAll(athlete: Athlete?) -> [VerdictEvent] {
        let descriptor = FetchDescriptor<VerdictEvent>(
            sortBy: [SortDescriptor(\.decidedAt, order: .reverse)]
        )
        let rows = (try? modelContext.fetch(descriptor)) ?? []
        guard let athlete else { return rows }
        let athleteId = athlete.id
        return rows.filter { $0.athlete?.id == athleteId }
    }

    /// Events whose `decidedAt` is within the last `days` (inclusive of the start-of-day boundary),
    /// newest-first. Athlete filtered in Swift.
    func fetchRecent(days: Int, athlete: Athlete?) -> [VerdictEvent] {
        let calendar = Calendar.current
        let windowStart = calendar.startOfDay(
            for: calendar.date(byAdding: .day, value: -days, to: .now) ?? .now
        )
        let descriptor = FetchDescriptor<VerdictEvent>(
            predicate: #Predicate { $0.decidedAt >= windowStart },
            sortBy: [SortDescriptor(\.decidedAt, order: .reverse)]
        )
        let rows = (try? modelContext.fetch(descriptor)) ?? []
        guard let athlete else { return rows }
        let athleteId = athlete.id
        return rows.filter { $0.athlete?.id == athleteId }
    }

    /// The newest un-resolved event (`outcomeRaw == nil`) whose `planDate` is strictly before
    /// `before` — drives the post-session outcome prompt (`before` is normally start-of-day today).
    /// Athlete filtered in Swift.
    func mostRecentAwaitingOutcome(athlete: Athlete?, before: Date) -> VerdictEvent? {
        let descriptor = FetchDescriptor<VerdictEvent>(
            predicate: #Predicate { $0.outcomeRaw == nil && $0.planDate < before },
            sortBy: [SortDescriptor(\.decidedAt, order: .reverse)]
        )
        let rows = (try? modelContext.fetch(descriptor)) ?? []
        guard let athlete else { return rows.first }
        let athleteId = athlete.id
        return rows.first { $0.athlete?.id == athleteId }
    }

    func save() throws {
        try modelContext.save()
    }
}
