import Foundation
import SwiftData

/// Persistence + editing rules for the training calendar (v1.7.3 feature 6, epic 6).
///
/// Editing laws (gated demo, round 4):
///   - Cancel = recorded state (`.canceled`, struck, undoable) — never a deletion.
///   - Reschedule = day picker: source goes `.moved` (stays visible on its day), a fresh
///     `.planned` entry lands on the chosen day with `movedFromDate` provenance.
///   - Advance games (match / scrimmage / pickup) and off-plan lifts are ad-hoc entries.
///   - The earliest future `.match` entry maintains `Athlete.nextMatchDate`, so the verdict's
///     match proximity reads the schedule with no engine change.
///
/// Fetch style: fetch-all + Swift filter (the `#Predicate` optional-relationship trap).
@MainActor
final class ScheduleRepository {
    private let modelContext: ModelContext
    private let calendar = Calendar.current

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Fetch

    /// All entries in [start, end), sorted by date then creation.
    func entries(from start: Date, to end: Date, athleteId: UUID) -> [ScheduleEntry] {
        let startDay = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        return allEntries(athleteId: athleteId)
            .filter { $0.date >= startDay && $0.date < endDay }
            .sorted { ($0.date, $0.createdAt) < ($1.date, $1.createdAt) }
    }

    /// Entries on one calendar day.
    func entries(on date: Date, athleteId: UUID) -> [ScheduleEntry] {
        let day = calendar.startOfDay(for: date)
        guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { return [] }
        return entries(from: day, to: next, athleteId: athleteId)
    }

    /// Today's still-planned program session entry, if any.
    func plannedProgramEntry(on date: Date, athleteId: UUID) -> ScheduleEntry? {
        entries(on: date, athleteId: athleteId)
            .first { $0.kind == .programSession && $0.status == .planned }
    }

    /// The earliest future full-match entry date (start-of-day), or nil.
    func upcomingMatchDate(athleteId: UUID, asOf now: Date = .now) -> Date? {
        let today = calendar.startOfDay(for: now)
        return allEntries(athleteId: athleteId)
            .filter { $0.kind == .match && $0.status == .planned && $0.date >= today }
            .map(\.date)
            .min()
    }

    // MARK: - Editing

    /// Add an ad-hoc entry (advance game, off-plan lift). Saves.
    @discardableResult
    func addAdHoc(
        kind: ScheduleEntryKind,
        on date: Date,
        athleteId: UUID,
        title: String? = nil,
        durationMinutes: Int? = nil,
        note: String? = nil
    ) throws -> ScheduleEntry {
        let entry = ScheduleEntry(
            athleteId: athleteId,
            date: date,
            kind: kind,
            title: title ?? kind.displayName,
            isAdHoc: true,
            durationMinutes: durationMinutes,
            note: note
        )
        modelContext.insert(entry)
        if kind == .match {
            syncNextMatchDate(athleteId: athleteId)
        }
        try modelContext.save()
        return entry
    }

    /// Cancel a planned entry in advance — recorded, struck, undoable.
    func cancel(_ entry: ScheduleEntry) throws {
        entry.status = .canceled
        entry.canceledAt = .now
        entry.updatedAt = .now
        entry.isSynced = false
        if entry.kind == .match {
            syncNextMatchDate(athleteId: entry.athleteId)
        }
        try modelContext.save()
    }

    /// Undo a cancellation.
    func restore(_ entry: ScheduleEntry) throws {
        entry.status = .planned
        entry.canceledAt = nil
        entry.updatedAt = .now
        entry.isSynced = false
        if entry.kind == .match {
            syncNextMatchDate(athleteId: entry.athleteId)
        }
        try modelContext.save()
    }

    /// Move a planned entry to any chosen day. The source records the move (struck on its
    /// day); the destination is a fresh planned entry carrying provenance. Returns the
    /// destination entry.
    @discardableResult
    func reschedule(_ entry: ScheduleEntry, to date: Date) throws -> ScheduleEntry {
        let destination = ScheduleEntry(
            athleteId: entry.athleteId,
            date: date,
            kind: entry.kind,
            title: entry.title,
            programId: entry.programId,
            programDayId: entry.programDayId,
            isAdHoc: entry.isAdHoc,
            durationMinutes: entry.durationMinutes,
            note: entry.note
        )
        destination.movedFromDate = entry.date
        modelContext.insert(destination)

        entry.status = .moved
        entry.movedToDate = destination.date
        entry.updatedAt = .now
        entry.isSynced = false

        if entry.kind == .match {
            syncNextMatchDate(athleteId: entry.athleteId)
        }
        try modelContext.save()
        return destination
    }

    /// Mark an entry completed and link the logged session.
    func markCompleted(_ entry: ScheduleEntry, sessionId: UUID) throws {
        entry.markCompleted(sessionId: sessionId)
        entry.isSynced = false
        try modelContext.save()
    }

    /// Remove an entry outright (e.g. "Clear the match"). Records a tombstone so a pull
    /// cannot resurrect it. Program sessions should be canceled, not removed — but the
    /// method does not police the caller.
    func remove(_ entry: ScheduleEntry) throws {
        let athleteId = entry.athleteId
        let wasMatch = entry.kind == .match
        SyncTombstone.record(
            rowId: entry.id, entity: .scheduleEntries,
            athleteId: athleteId, in: modelContext
        )
        modelContext.delete(entry)
        if wasMatch {
            syncNextMatchDate(athleteId: athleteId)
        }
        try modelContext.save()
    }

    /// Replace all still-planned program entries from `date` forward for `programId`.
    /// Used by re-materialization after a position move; past days and decided states
    /// (canceled/moved/completed) are untouched history.
    func deletePlannedProgramEntries(programId: UUID, from date: Date, athleteId: UUID) throws {
        let cutoff = calendar.startOfDay(for: date)
        let doomed = allEntries(athleteId: athleteId).filter {
            $0.programId == programId && $0.status == .planned && $0.date >= cutoff
        }
        for entry in doomed {
            SyncTombstone.record(
                rowId: entry.id, entity: .scheduleEntries,
                athleteId: athleteId, in: modelContext
            )
            modelContext.delete(entry)
        }
        try modelContext.save()
    }

    /// Insert materialized program entries. Saves once.
    func insert(_ entries: [ScheduleEntry]) throws {
        for entry in entries {
            modelContext.insert(entry)
        }
        try modelContext.save()
    }

    // MARK: - Ledger

    /// The week's recorded schedule changes (canceled, moved, ad-hoc additions), newest last.
    func changes(from start: Date, to end: Date, athleteId: UUID) -> [ScheduleEntry] {
        entries(from: start, to: end, athleteId: athleteId).filter {
            $0.status == .canceled || $0.status == .moved || $0.isAdHoc || $0.movedFromDate != nil
        }
    }

    // MARK: - Match date bridge

    /// Recompute `Athlete.nextMatchDate` from the schedule's earliest planned future match.
    /// Does not save — callers save as part of their own transaction.
    func syncNextMatchDate(athleteId: UUID, asOf now: Date = .now) {
        let descriptor = FetchDescriptor<Athlete>()
        let athletes = (try? modelContext.fetch(descriptor)) ?? []
        guard let athlete = athletes.first(where: { $0.id == athleteId }) else { return }
        athlete.nextMatchDate = upcomingMatchDate(athleteId: athleteId, asOf: now)
    }

    // MARK: - Private

    private func allEntries(athleteId: UUID) -> [ScheduleEntry] {
        let descriptor = FetchDescriptor<ScheduleEntry>()
        let all = (try? modelContext.fetch(descriptor)) ?? []
        return all.filter { $0.athleteId == athleteId }
    }
}
