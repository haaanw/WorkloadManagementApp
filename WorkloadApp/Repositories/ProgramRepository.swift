import Foundation
import SwiftData

/// Persistence for `TrainingProgram` and its day templates (v1.7.3 feature 6).
///
/// Lifecycle law (epic 8): one active program at a time; bringing a new block archives the
/// old one WITH its history intact — programs are never deleted by replacement. The position
/// cursor is movable any time ("Move my position").
///
/// Fetch style: fetch-all + Swift filter, matching `PlannedSessionRepository` (avoids the
/// optional-relationship `#Predicate` trap).
@MainActor
final class ProgramRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Fetch

    /// The athlete's single active program, or nil.
    func fetchActiveProgram(athleteId: UUID) -> TrainingProgram? {
        allPrograms(athleteId: athleteId).first { $0.isActive && !$0.isArchived }
    }

    /// Archived programs, most recently archived first.
    func fetchArchivedPrograms(athleteId: UUID) -> [TrainingProgram] {
        allPrograms(athleteId: athleteId)
            .filter { $0.isArchived }
            .sorted { ($0.archivedAt ?? .distantPast) > ($1.archivedAt ?? .distantPast) }
    }

    func fetchProgram(id: UUID) -> TrainingProgram? {
        let descriptor = FetchDescriptor<TrainingProgram>()
        let all = (try? modelContext.fetch(descriptor)) ?? []
        return all.first { $0.id == id }
    }

    /// The `WorkoutTemplate` holding a program day's content, or nil.
    func template(for day: ProgramDay) -> WorkoutTemplate? {
        guard let templateId = day.templateId else { return nil }
        let descriptor = FetchDescriptor<WorkoutTemplate>()
        let all = (try? modelContext.fetch(descriptor)) ?? []
        return all.first { $0.id == templateId }
    }

    // MARK: - Save / lifecycle

    /// Insert a freshly imported program (not yet active — activation happens once the
    /// schedule mapping is decided).
    func save(_ program: TrainingProgram) throws {
        modelContext.insert(program)
        program.updatedAt = .now
        program.isSynced = false
        try modelContext.save()
    }

    /// Activate `program`, archiving any currently active program with history intact.
    /// Returns the archived predecessor, if there was one.
    @discardableResult
    func activate(_ program: TrainingProgram, startDate: Date, trainingWeekdays: [Int]) throws -> TrainingProgram? {
        let predecessor = fetchActiveProgram(athleteId: program.athleteId)
        if let predecessor, predecessor.id != program.id {
            predecessor.isActive = false
            predecessor.isArchived = true
            predecessor.archivedAt = .now
            predecessor.updatedAt = .now
            predecessor.isSynced = false
        }
        program.isActive = true
        program.isArchived = false
        program.startDate = Calendar.current.startOfDay(for: startDate)
        program.trainingWeekdays = trainingWeekdays
        program.updatedAt = .now
        program.isSynced = false
        try modelContext.save()
        return (predecessor?.id == program.id) ? nil : predecessor
    }

    /// Move the position cursor. Values are clamped to the block's bounds.
    func movePosition(_ program: TrainingProgram, toWeek week: Int, day: Int) throws {
        program.positionWeek = min(max(1, week), max(1, program.durationWeeks))
        let dayCount = max(1, program.days(inWeek: program.positionWeek).count)
        program.positionDay = min(max(1, day), dayCount)
        program.updatedAt = .now
        program.isSynced = false
        try modelContext.save()
    }

    /// Delete a program outright (user-initiated only — replacement archives instead).
    /// Records tombstones for the program and its day templates so sync forgets them too.
    func delete(_ program: TrainingProgram) throws {
        for day in program.days {
            if let template = template(for: day) {
                SyncTombstone.record(
                    rowId: template.id, entity: .templates,
                    athleteId: program.athleteId, in: modelContext
                )
                modelContext.delete(template)
            }
        }
        SyncTombstone.record(
            rowId: program.id, entity: .trainingPrograms,
            athleteId: program.athleteId, in: modelContext
        )
        modelContext.delete(program)
        try modelContext.save()
    }

    // MARK: - Private

    private func allPrograms(athleteId: UUID) -> [TrainingProgram] {
        let descriptor = FetchDescriptor<TrainingProgram>(
            sortBy: [SortDescriptor(\.importedAt, order: .reverse)]
        )
        let all = (try? modelContext.fetch(descriptor)) ?? []
        return all.filter { $0.athleteId == athleteId }
    }
}
