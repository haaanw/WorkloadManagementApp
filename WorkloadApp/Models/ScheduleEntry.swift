import Foundation
import SwiftData

// MARK: - ScheduleEntry
//
// One dated item on the training calendar (v1.7.3 feature 6, epic 6). The schedule layer is
// deliberately LIGHTWEIGHT: a program session entry references its `ProgramDay` by id and
// carries no exercise content — the frozen deep copy is made only when the day is designated
// (reuse-first, PLAN-10). Editing laws from the gated demo:
//   - Cancellation is a recorded state (visible, struck, undoable) — never a deletion.
//   - A reschedule marks the source `.moved` (stays on its day, struck) and creates a fresh
//     `.planned` entry on the chosen day carrying `movedFromDate` for provenance.
//   - Advance match/scrimmage/pickup entries feed match proximity and carry; the earliest
//     future `.match` entry maintains `Athlete.nextMatchDate` so the verdict reads the
//     schedule with no engine change.
//   - Rest days are the absence of entries.

@Model
final class ScheduleEntry {
    @Attribute(.unique) var id: UUID
    var athleteId: UUID
    /// Start-of-day normalized (same convention as `Athlete.nextMatchDate`).
    var date: Date
    var kindRawValue: String
    var statusRawValue: String
    /// Display title — the program day's title for program sessions ("Heavy lower"),
    /// the kind's display name otherwise.
    var title: String

    // MARK: Program linkage (kind == .programSession)
    var programId: UUID?
    var programDayId: UUID?

    // MARK: Move provenance (the schedule-changes ledger reads these)
    var movedToDate: Date?
    var movedFromDate: Date?
    var canceledAt: Date?

    // MARK: Completion
    var completedSessionId: UUID?

    /// True for user-added entries (advance games, off-plan lifts) as opposed to entries
    /// materialized from the program — the ledger lists ad-hoc additions.
    var isAdHoc: Bool = false

    var durationMinutes: Int?
    var note: String?
    var isSynced: Bool = false
    var createdAt: Date
    var updatedAt: Date

    // MARK: Typed accessors (not stored by SwiftData)

    var kind: ScheduleEntryKind {
        get { ScheduleEntryKind(rawValue: kindRawValue) ?? .programSession }
        set { kindRawValue = newValue.rawValue }
    }

    var status: ScheduleEntryStatus {
        get { ScheduleEntryStatus(rawValue: statusRawValue) ?? .planned }
        set { statusRawValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        athleteId: UUID,
        date: Date,
        kind: ScheduleEntryKind,
        title: String,
        programId: UUID? = nil,
        programDayId: UUID? = nil,
        isAdHoc: Bool = false,
        durationMinutes: Int? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.athleteId = athleteId
        self.date = Calendar.current.startOfDay(for: date)
        self.kindRawValue = kind.rawValue
        self.statusRawValue = ScheduleEntryStatus.planned.rawValue
        self.title = title
        self.programId = programId
        self.programDayId = programDayId
        self.isAdHoc = isAdHoc
        self.durationMinutes = durationMinutes
        self.note = note
        self.createdAt = .now
        self.updatedAt = .now
    }

    /// Mark completed and link the logged session.
    func markCompleted(sessionId: UUID) {
        statusRawValue = ScheduleEntryStatus.completed.rawValue
        completedSessionId = sessionId
        updatedAt = .now
    }
}
