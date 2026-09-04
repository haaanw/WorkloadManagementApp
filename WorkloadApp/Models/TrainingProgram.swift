import Foundation
import SwiftData

// MARK: - TrainingProgram
//
// The imported, user-authored training block (v1.7.3 feature 6, epic 1). Tuwa never writes
// the program — it holds structure (weeks, days, phases), a movable position cursor, and
// lifecycle state (active / archived-on-replace). Day content lives in per-day
// `WorkoutTemplate`s (flagged `isProgramDay`) referenced by id, so the existing frozen-copy
// designation path (`PlannedSessionRepository.planFromTemplate`) and the whole verdict →
// resolved-plan machinery run unchanged on program days.

@Model
final class TrainingProgram {
    @Attribute(.unique) var id: UUID
    var athleteId: UUID
    var name: String
    var sourceRawValue: String
    var importedAt: Date

    // MARK: Duration (the read → ask → suggest ladder)
    var durationWeeks: Int
    var durationSourceRawValue: String

    // MARK: Schedule mapping
    /// The Monday-of-week-1 anchor once the program is activated; nil while pending.
    var startDate: Date?
    /// ISO 8601 weekdays (1=Mon...7=Sun) the athlete trains; drives materialization.
    var trainingWeekdays: [Int] = []

    // MARK: Position cursor (movable any time — "Move my position")
    var positionWeek: Int = 1
    var positionDay: Int = 1

    // MARK: Lifecycle
    var isActive: Bool = false
    var isArchived: Bool = false
    var archivedAt: Date? = nil
    /// The transition decision taken at activation (eased entry vs as written); nil = none needed.
    var entryModeRawValue: String? = nil

    var notes: String?
    var isSynced: Bool = false
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \ProgramPhase.program)
    var phases: [ProgramPhase] = []

    @Relationship(deleteRule: .cascade, inverse: \ProgramDay.program)
    var days: [ProgramDay] = []

    // MARK: Typed accessors (not stored by SwiftData)

    var source: ProgramSource {
        get { ProgramSource(rawValue: sourceRawValue) ?? .manual }
        set { sourceRawValue = newValue.rawValue }
    }

    var durationSource: ProgramDurationSource {
        get { ProgramDurationSource(rawValue: durationSourceRawValue) ?? .asked }
        set { durationSourceRawValue = newValue.rawValue }
    }

    var entryMode: ProgramEntryMode? {
        get { entryModeRawValue.flatMap(ProgramEntryMode.init(rawValue:)) }
        set { entryModeRawValue = newValue?.rawValue }
    }

    /// Phases sorted by their order in the block.
    var sortedPhases: [ProgramPhase] {
        phases.sorted { $0.orderIndex < $1.orderIndex }
    }

    /// Days sorted week-major, then day.
    var sortedDays: [ProgramDay] {
        days.sorted {
            ($0.weekNumber, $0.dayNumber) < ($1.weekNumber, $1.dayNumber)
        }
    }

    /// The days of one week, in day order.
    func days(inWeek week: Int) -> [ProgramDay] {
        sortedDays.filter { $0.weekNumber == week }
    }

    /// The phase a week belongs to, when the file named phases.
    func phase(forWeek week: Int) -> ProgramPhase? {
        sortedPhases.first { $0.startWeek <= week && week <= $0.endWeek }
    }

    init(
        id: UUID = UUID(),
        athleteId: UUID,
        name: String,
        source: ProgramSource,
        durationWeeks: Int,
        durationSource: ProgramDurationSource,
        importedAt: Date = .now,
        notes: String? = nil
    ) {
        self.id = id
        self.athleteId = athleteId
        self.name = name
        self.sourceRawValue = source.rawValue
        self.durationWeeks = durationWeeks
        self.durationSourceRawValue = durationSource.rawValue
        self.importedAt = importedAt
        self.notes = notes
        self.createdAt = .now
        self.updatedAt = .now
    }
}

// MARK: - ProgramPhase
//
// A named band of weeks read from the file's own words (intro / build / peak / deload).
// A phase-less file simply has no rows — weeks render flat.

@Model
final class ProgramPhase {
    @Attribute(.unique) var id: UUID
    var name: String
    var startWeek: Int
    var endWeek: Int
    var orderIndex: Int

    var program: TrainingProgram?

    init(
        id: UUID = UUID(),
        name: String,
        startWeek: Int,
        endWeek: Int,
        orderIndex: Int = 0
    ) {
        self.id = id
        self.name = name
        self.startWeek = startWeek
        self.endWeek = endWeek
        self.orderIndex = orderIndex
    }
}

// MARK: - ProgramDay
//
// One training day of the block ("W3 · D2 · Heavy lower"). Content is a per-day
// `WorkoutTemplate` (referenced by id, matching the `PrescribedWorkout.templateId` pattern)
// so day content edits ride the existing template editor + sync.

@Model
final class ProgramDay {
    @Attribute(.unique) var id: UUID
    var weekNumber: Int
    var dayNumber: Int
    var title: String
    var templateId: UUID?

    var program: TrainingProgram?

    init(
        id: UUID = UUID(),
        weekNumber: Int,
        dayNumber: Int,
        title: String,
        templateId: UUID? = nil
    ) {
        self.id = id
        self.weekNumber = weekNumber
        self.dayNumber = dayNumber
        self.title = title
        self.templateId = templateId
    }
}
