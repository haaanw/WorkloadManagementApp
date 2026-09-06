import Foundation
import SwiftData

/// Maps an active `TrainingProgram` onto calendar dates as lightweight `ScheduleEntry` rows
/// (v1.7.3 feature 6, epics 1+6).
///
/// Materialize ≠ log ≠ freeze: an entry carries no exercise content — the frozen deep copy
/// (`PlannedSessionRepository.planFromTemplate`) is made only when the day is designated.
/// Past days are never materialized (history is sessions, not plans), and re-materialization
/// after a position move touches only still-`.planned` future entries — canceled, moved, and
/// completed entries are records and stay.
@MainActor
struct ProgramScheduleService {

    /// ISO calendar so weeks anchor on Monday regardless of device locale.
    private static var isoCalendar: Calendar { Calendar(identifier: .iso8601) }

    // MARK: - Pure mapping

    /// Sensible default training weekdays for a days-per-week count (ISO 1=Mon...7=Sun).
    static func defaultWeekdays(daysPerWeek: Int) -> [Int] {
        switch daysPerWeek {
        case ...1: return [2]                    // Tue
        case 2: return [2, 5]                    // Tue Fri
        case 3: return [1, 3, 5]                 // Mon Wed Fri
        case 4: return [1, 2, 4, 5]              // Mon Tue Thu Fri
        case 5: return [1, 2, 3, 5, 6]           // Mon Tue Wed Fri Sat
        case 6: return [1, 2, 3, 4, 5, 6]        // Mon–Sat
        default: return [1, 2, 3, 4, 5, 6, 7]
        }
    }

    /// The Monday (start of ISO week) containing `date`, at start of day.
    static func weekAnchor(containing date: Date) -> Date {
        let calendar = isoCalendar
        let day = calendar.startOfDay(for: date)
        let interval = calendar.dateInterval(of: .weekOfYear, for: day)
        return interval?.start ?? day
    }

    /// The calendar date of program week `week`, day-slot `day` (both 1-based), given the
    /// anchor Monday of `anchorWeek`. Day slots take the sorted training weekdays in order;
    /// overflow days (a week with more sessions than weekdays) land on the days after the
    /// last slot, capped at Sunday.
    static func date(
        forWeek week: Int,
        day: Int,
        anchorMonday: Date,
        anchorWeek: Int,
        trainingWeekdays: [Int]
    ) -> Date? {
        let calendar = isoCalendar
        guard let weekMonday = calendar.date(
            byAdding: .day, value: (week - anchorWeek) * 7, to: anchorMonday
        ) else { return nil }

        let slots = trainingWeekdays.sorted().filter { (1...7).contains($0) }
        let weekday: Int
        if slots.isEmpty {
            weekday = min(day, 7)
        } else if day <= slots.count {
            weekday = slots[day - 1]
        } else {
            weekday = min(slots[slots.count - 1] + (day - slots.count), 7)
        }
        return calendar.date(byAdding: .day, value: weekday - 1, to: weekMonday)
    }

    /// Build (without inserting) the planned entries for `program` from its position cursor
    /// forward. Days whose computed date falls before `today` are skipped — the past is
    /// history, not a plan.
    static func materializedEntries(
        for program: TrainingProgram,
        asOf today: Date = .now
    ) -> [ScheduleEntry] {
        guard let startDate = program.startDate else { return [] }
        let anchorMonday = weekAnchor(containing: startDate)
        let todayStart = isoCalendar.startOfDay(for: today)
        var entries: [ScheduleEntry] = []

        for day in program.sortedDays {
            if day.weekNumber < program.positionWeek { continue }
            if day.weekNumber == program.positionWeek && day.dayNumber < program.positionDay { continue }
            guard let dayDate = date(
                forWeek: day.weekNumber,
                day: day.dayNumber,
                anchorMonday: anchorMonday,
                anchorWeek: program.positionWeek,
                trainingWeekdays: program.trainingWeekdays
            ) else { continue }
            if dayDate < todayStart { continue }
            entries.append(ScheduleEntry(
                athleteId: program.athleteId,
                date: dayDate,
                kind: .programSession,
                title: day.title,
                programId: program.id,
                programDayId: day.id
            ))
        }
        return entries
    }

    // MARK: - Orchestration

    /// Activate `program` (archiving any predecessor with history intact) and materialize
    /// its schedule from the position cursor forward.
    ///
    /// Repositories are parameters, never method locals: a `@MainActor` class deallocated
    /// mid-synchronous-call trips the iOS 26.1 back-deploy deinit SIGABRT. Callers own the
    /// instances (stored/`@State` properties, the ActiveWorkoutSheet pattern).
    static func activate(
        _ program: TrainingProgram,
        startDate: Date = .now,
        trainingWeekdays: [Int]? = nil,
        programRepo: ProgramRepository,
        scheduleRepo: ScheduleRepository
    ) throws {
        let weekdays = trainingWeekdays ?? inferredWeekdays(for: program)
        if let predecessor = try programRepo.activate(
            program, startDate: startDate, trainingWeekdays: weekdays
        ) {
            // The old block's future plans dissolve; its records stay.
            try scheduleRepo.deletePlannedProgramEntries(
                programId: predecessor.id, from: startDate, athleteId: program.athleteId
            )
        }
        try scheduleRepo.insert(materializedEntries(for: program, asOf: startDate))
    }

    /// Move the position cursor and re-materialize the still-planned future.
    static func movePosition(
        _ program: TrainingProgram,
        toWeek week: Int,
        day: Int,
        asOf today: Date = .now,
        programRepo: ProgramRepository,
        scheduleRepo: ScheduleRepository
    ) throws {
        try programRepo.movePosition(program, toWeek: week, day: day)
        // Re-anchor the block so the new position week is the current week.
        program.startDate = isoCalendar.startOfDay(for: today)
        try scheduleRepo.deletePlannedProgramEntries(
            programId: program.id, from: today, athleteId: program.athleteId
        )
        try scheduleRepo.insert(materializedEntries(for: program, asOf: today))
    }

    /// The connection wire (epic 1 → verdict): if today has a planned program entry and no
    /// designation exists yet, designate it — the frozen deep copy of the day's template —
    /// so `TodayVerdictService` reads the program day with no changes of its own.
    /// Returns the (existing or new) designation, or nil when today has nothing planned.
    @discardableResult
    static func ensureTodayDesignation(
        athleteId: UUID,
        plannedSessionRepo: PlannedSessionRepository,
        scheduleRepo: ScheduleRepository,
        programRepo: ProgramRepository
    ) -> PrescribedWorkout? {
        if let existing = plannedSessionRepo.fetchTodaysPlannedSession(athleteId: athleteId) {
            return existing
        }
        guard
            let entry = scheduleRepo.plannedProgramEntry(on: .now, athleteId: athleteId),
            let programId = entry.programId,
            let program = programRepo.fetchProgram(id: programId),
            let day = program.days.first(where: { $0.id == entry.programDayId }),
            let template = programRepo.template(for: day)
        else { return nil }
        let prescription = plannedSessionRepo.planFromTemplate(template, athleteId: athleteId)
        // The eased entry chosen at import (epic 8) shapes week 1's working copies:
        // one back-off trimmed per lift, top sets as written. The program's own
        // templates stay untouched.
        if program.entryMode == .eased && day.weekNumber == 1 {
            try? plannedSessionRepo.trimOneBackoffPerExercise(
                prescription,
                reason: String(
                    localized: "program.easedEntry.reason",
                    defaultValue: "Eased entry — week 1: one back-off trimmed, top set as written."
                )
            )
        }
        return prescription
    }

    /// Completion hook: when a session saves, mark the day's program entry completed and
    /// advance the position cursor past the completed day (never backwards — a make-up
    /// session for an earlier day leaves the cursor alone).
    static func recordProgramCompletion(
        sessionId: UUID,
        sessionDate: Date,
        athleteId: UUID,
        scheduleRepo: ScheduleRepository,
        programRepo: ProgramRepository
    ) {
        guard
            let entry = scheduleRepo.plannedProgramEntry(on: sessionDate, athleteId: athleteId),
            let programId = entry.programId,
            let program = programRepo.fetchProgram(id: programId),
            let day = program.days.first(where: { $0.id == entry.programDayId })
        else { return }
        try? scheduleRepo.markCompleted(entry, sessionId: sessionId)

        let cursorIsBehind = (program.positionWeek, program.positionDay) <= (day.weekNumber, day.dayNumber)
        guard cursorIsBehind else { return }
        let ordered = program.sortedDays
        if let index = ordered.firstIndex(where: { $0.id == day.id }), index + 1 < ordered.count {
            let next = ordered[index + 1]
            try? programRepo.movePosition(program, toWeek: next.weekNumber, day: next.dayNumber)
        } else {
            // Block finished — cursor rests on its last day.
            try? programRepo.movePosition(program, toWeek: day.weekNumber, day: day.dayNumber)
        }
    }

    /// The typical sessions-per-week of the block, read from its own structure.
    static func inferredWeekdays(for program: TrainingProgram) -> [Int] {
        let counts = (1...max(1, program.durationWeeks)).map { program.days(inWeek: $0).count }
        let typical = counts.filter { $0 > 0 }.max() ?? 3
        return defaultWeekdays(daysPerWeek: typical)
    }
}
