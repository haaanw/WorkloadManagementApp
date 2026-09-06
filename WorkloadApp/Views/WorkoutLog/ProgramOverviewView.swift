import SwiftUI
import SwiftData

/// The program screen (v1.7.3 feature 6, epic 7 — gated demo §2, round 4).
///
/// Everything here is READ from the imported program and the athlete's log; Tuwa authors
/// none of it. Phases band the weeks when the file named them; a week row expands into its
/// days (trained / skipped / today / upcoming); the lift progression strip shows plan and
/// reality in one line; position is a movable cursor; the re-import door archives the
/// current block with history intact.
struct ProgramOverviewView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var athletes: [Athlete]
    @Query private var programs: [TrainingProgram]
    @Query private var templates: [WorkoutTemplate]
    @Query private var entries: [ScheduleEntry]
    @Query private var sessions: [WorkoutSession]

    @State private var expandedWeek: Int?
    @State private var showMovePosition = false
    @State private var showReimport = false
    @State private var programRepo: ProgramRepository?
    @State private var scheduleRepo: ScheduleRepository?

    private var athlete: Athlete? { athletes.first }
    private var program: TrainingProgram? {
        programs.first { $0.isActive && !$0.isArchived && $0.athleteId == athlete?.id }
    }
    private var templatesById: [UUID: WorkoutTemplate] {
        Dictionary(uniqueKeysWithValues: templates.map { ($0.id, $0) })
    }
    private var programEntries: [ScheduleEntry] {
        guard let program else { return [] }
        return entries.filter { $0.programId == program.id }
    }

    var body: some View {
        ScrollView {
            if let program {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    header(program)
                    statRow(program)
                    weeksCard(program)
                    liftProgression(program)
                    Button {
                        Haptics.tap()
                        showReimport = true
                    } label: {
                        Text("program.action.bringNew")
                            .font(.Tokens.body)
                            .foregroundStyle(ColorTokens.text1)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.sm)
                            .overlay(
                                RoundedRectangle(cornerRadius: CornerTokens.control)
                                    .stroke(ColorTokens.dividerStrong, lineWidth: 0.5)
                            )
                    }
                    .buttonStyle(.pressable)
                    Button {
                        Haptics.select()
                        showMovePosition = true
                    } label: {
                        Text("program.action.movePosition")
                            .font(.Tokens.label)
                            .foregroundStyle(ColorTokens.text2)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.xs)
                    }
                    .buttonStyle(.pressable)
                    NavigationLink {
                        TemplateListView()
                            .environment(container)
                    } label: {
                        Text("program.action.myTemplates")
                            .font(.Tokens.label)
                            .foregroundStyle(ColorTokens.text2)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.xs)
                    }
                }
                .padding(Spacing.sm)
            } else {
                emptyState
            }
        }
        .background(ColorTokens.background)
        .navigationTitle("program.nav.title")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if programRepo == nil {
                programRepo = ProgramRepository(modelContext: modelContext)
                scheduleRepo = ScheduleRepository(modelContext: modelContext)
            }
            if expandedWeek == nil { expandedWeek = program?.positionWeek }
        }
        .sheet(isPresented: $showMovePosition) {
            if let program {
                MovePositionSheet(program: program)
                    .environment(container)
            }
        }
        .sheet(isPresented: $showReimport) {
            ProgramImportSheet()
                .environment(container)
        }
    }

    // MARK: - Header + stats

    private func header(_ program: TrainingProgram) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(verbatim: program.name)
                .font(.Tokens.sectionHead)
                .foregroundStyle(ColorTokens.text1)
            Spacer()
            AnnotationLabel(importStamp(program))
        }
    }

    private func importStamp(_ program: TrainingProgram) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let date = formatter.string(from: program.importedAt).uppercased()
        return String(
            format: String(localized: "program.header.imported", defaultValue: "IMPORTED %@ · %@"),
            date, program.source.displayName.uppercased()
        )
    }

    private func statRow(_ program: TrainingProgram) -> some View {
        let adherence = ProgramInsightEngine.adherence(program: program, entries: programEntries)
        let volumeRatio = loggedVsPlannedVolume(program)
        return HStack(spacing: Spacing.xs) {
            statCell(
                value: "W\(program.positionWeek) · D\(program.positionDay)",
                key: "program.stat.position"
            )
            statCell(
                value: "\(adherence.trained) / \(adherence.planned)",
                key: "program.stat.trained"
            )
            statCell(
                value: volumeRatio.map { "\(Int(($0 * 100).rounded()))%" } ?? "—",
                key: "program.stat.volume"
            )
        }
    }

    private func statCell(value: String, key: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: value)
                .font(.Tokens.sectionTitle)
                .monospacedDigit()
                .foregroundStyle(ColorTokens.text1)
            AnnotationLabel(key: key, size: .small)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.sm)
        .cardStyle(horizontalPadding: 0, verticalPadding: 0)
    }

    /// Logged tonnage over planned tonnage for completed program days; nil before any.
    private func loggedVsPlannedVolume(_ program: TrainingProgram) -> Double? {
        let completed = programEntries.filter { $0.status == .completed }
        guard !completed.isEmpty else { return nil }
        let sessionById = Dictionary(uniqueKeysWithValues: sessions.map { ($0.id, $0) })
        var logged = 0.0
        var planned = 0.0
        for entry in completed {
            guard
                let sessionId = entry.completedSessionId,
                let session = sessionById[sessionId],
                let day = program.days.first(where: { $0.id == entry.programDayId }),
                let templateId = day.templateId,
                let template = templatesById[templateId]
            else { continue }
            logged += session.totalVolume
            planned += ProgramInsightEngine.plannedVolume(of: template)
        }
        guard planned > 0 else { return nil }
        return logged / planned
    }

    // MARK: - Weeks × phases

    private func weeksCard(_ program: TrainingProgram) -> some View {
        let volumes = (1...max(1, program.durationWeeks)).map {
            ProgramInsightEngine.weekVolume(program: program, week: $0, templates: templatesById)
        }
        let maxVolume = max(volumes.max() ?? 1, 1)
        return VStack(spacing: 0) {
            ForEach(1...max(1, program.durationWeeks), id: \.self) { week in
                if let phase = program.phase(forWeek: week), phase.startWeek == week {
                    HStack {
                        AnnotationLabel(phaseStamp(phase))
                        Spacer()
                    }
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xs)
                    .overlay(alignment: .top) {
                        if week > 1 { Rectangle().fill(ColorTokens.dividerStrong).frame(height: 0.5) }
                    }
                }
                weekRow(program, week: week, volume: volumes[week - 1], maxVolume: maxVolume)
                if expandedWeek == week {
                    weekDays(program, week: week)
                }
            }
        }
        .emphasisCardStyle(horizontalPadding: 0, verticalPadding: 0)
    }

    private func phaseStamp(_ phase: ProgramPhase) -> String {
        String(
            format: String(localized: "program.phase.stamp", defaultValue: "PHASE %lld · %@"),
            phase.orderIndex + 1, phase.name.uppercased()
        )
    }

    private func weekRow(_ program: TrainingProgram, week: Int, volume: Double, maxVolume: Double) -> some View {
        let current = program.positionWeek == week
        let done = weekIsDone(program, week: week)
        return Button {
            Haptics.select()
            withAnimation(Motion.resolved(Motion.state, reduceMotion: reduceMotion)) {
                expandedWeek = expandedWeek == week ? nil : week
            }
        } label: {
            HStack(spacing: Spacing.xs) {
                AnnotationLabel("W\(week)", color: current ? ColorTokens.text1 : ColorTokens.text3)
                    .frame(width: 32, alignment: .leading)
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(ColorTokens.surface)
                            .overlay(RoundedRectangle(cornerRadius: 2).stroke(ColorTokens.divider, lineWidth: 0.5))
                        RoundedRectangle(cornerRadius: 2)
                            .fill(ColorTokens.metricLoad.opacity(done ? 0.85 : 0.55))
                            .frame(width: proxy.size.width * (volume / maxVolume))
                    }
                }
                .frame(height: 8)
                AnnotationLabel(weekKicker(program, week: week, volume: volume), size: .small)
            }
            .padding(.horizontal, Spacing.sm)
            .frame(minHeight: 44)
            .background(current ? ColorTokens.surfaceEl2 : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: CornerTokens.control)
                    .stroke(current ? ColorTokens.text1 : Color.clear, lineWidth: 1)
                    .padding(.horizontal, 2)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
    }

    private func weekIsDone(_ program: TrainingProgram, week: Int) -> Bool {
        let weekDayIds = Set(program.days(inWeek: week).map(\.id))
        let weekEntries = programEntries.filter { entry in
            entry.programDayId.map(weekDayIds.contains) == true
        }
        guard !weekEntries.isEmpty else { return week < program.positionWeek }
        return weekEntries.allSatisfy { $0.status == .completed || $0.status == .canceled || $0.status == .moved }
            && weekEntries.contains { $0.status == .completed }
    }

    private func weekKicker(_ program: TrainingProgram, week: Int, volume: Double) -> String {
        var parts: [String] = []
        if volume > 0 {
            parts.append(volume >= 1000
                ? String(format: "%.1fK", volume / 1000)
                : String(format: "%.0f", volume))
        }
        if program.positionWeek == week {
            parts.append(String(localized: "program.week.now", defaultValue: "NOW"))
        } else if weekIsDone(program, week: week) {
            parts.append(String(localized: "program.week.done", defaultValue: "DONE"))
        }
        return parts.joined(separator: " · ")
    }

    private func weekDays(_ program: TrainingProgram, week: Int) -> some View {
        VStack(spacing: 0) {
            ForEach(program.days(inWeek: week), id: \.id) { day in
                HStack {
                    Text(verbatim: "D\(day.dayNumber) · \(day.title)")
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text2)
                    Spacer()
                    AnnotationLabel(dayStatus(program, day: day), size: .small)
                }
                .padding(.vertical, Spacing.xs)
                .overlay(alignment: .top) {
                    if day.dayNumber > 1 { Rectangle().fill(ColorTokens.divider).frame(height: 0.5) }
                }
            }
        }
        .padding(.leading, Spacing.lg)
        .padding(.trailing, Spacing.sm)
        .padding(.bottom, Spacing.xs)
    }

    private func dayStatus(_ program: TrainingProgram, day: ProgramDay) -> String {
        if let entry = programEntries.first(where: { $0.programDayId == day.id }) {
            switch entry.status {
            case .completed:
                return String(localized: "program.day.trained", defaultValue: "TRAINED")
            case .canceled:
                return String(localized: "program.day.skipped", defaultValue: "SKIPPED")
            case .moved:
                return String(localized: "program.day.moved", defaultValue: "MOVED")
            case .planned:
                if Calendar.current.isDate(entry.date, inSameDayAs: .now) {
                    return String(localized: "program.day.today", defaultValue: "TODAY")
                }
                return String(localized: "program.day.upcoming", defaultValue: "UPCOMING")
            }
        }
        let past = (day.weekNumber, day.dayNumber) < (program.positionWeek, program.positionDay)
        return past
            ? String(localized: "program.day.skipped", defaultValue: "SKIPPED")
            : String(localized: "program.day.upcoming", defaultValue: "UPCOMING")
    }

    // MARK: - Lift progression strip

    @ViewBuilder
    private func liftProgression(_ program: TrainingProgram) -> some View {
        if let lift = mainLift(program) {
            let sessionById = Dictionary(uniqueKeysWithValues: sessions.map { ($0.id, $0) })
            let points: [(week: Int, weightKg: Double?, logged: Bool)] =
                (1...max(1, program.durationWeeks)).map { week in
                    weekTopSet(program, week: week, lift: lift, sessionById: sessionById)
                }
            let maxWeight = max(points.compactMap(\.weightKg).max() ?? 1, 1)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack {
                    AnnotationLabel(String(
                        format: String(localized: "program.lift.stamp", defaultValue: "%1$@ · TOP SET ACROSS THE BLOCK · %2$@"),
                        lift.uppercased(),
                        (athlete?.weightUnit ?? .kg) == .kg ? "KG" : "LB"
                    ))
                    Spacer()
                    AnnotationLabel(key: "program.lift.source", size: .small)
                }
                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(points, id: \.week) { point in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(point.weightKg == nil
                                ? ColorTokens.surface
                                : ColorTokens.metricLoad.opacity(point.logged
                                    ? (point.week == program.positionWeek ? 0.85 : 0.55)
                                    : 0.0))
                            .overlay(
                                RoundedRectangle(cornerRadius: 2)
                                    .stroke(
                                        point.logged ? Color.clear : ColorTokens.divider,
                                        lineWidth: 0.5
                                    )
                            )
                            .frame(height: max(8, 56 * (point.weightKg ?? 0) / maxWeight))
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 56, alignment: .bottom)
                HStack(spacing: 4) {
                    ForEach(points, id: \.week) { point in
                        AnnotationLabel(
                            point.weightKg.map { weightLabel($0) } ?? "—",
                            size: .small
                        )
                        .frame(maxWidth: .infinity)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    }
                }
            }
            .padding(Spacing.sm)
            .cardStyle(horizontalPadding: 0, verticalPadding: 0)
        }
    }

    /// Bare numeral in the athlete's display unit (the unit rides in the strip's stamp).
    private func weightLabel(_ kg: Double) -> String {
        let value = WeightFormatter.displayValue(kg, unit: athlete?.weightUnit ?? .kg)
        return value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
    }

    /// The block's most frequent exercise — the "main lift" whose arc the strip shows.
    private func mainLift(_ program: TrainingProgram) -> String? {
        var counts: [String: Int] = [:]
        for day in program.days {
            guard let templateId = day.templateId, let template = templatesById[templateId] else { continue }
            for exercise in template.sortedGroups.flatMap(\.sortedExercises) {
                counts[exercise.exerciseName, default: 0] += 1
            }
        }
        return counts.max { $0.value < $1.value }?.key
    }

    private func weekTopSet(
        _ program: TrainingProgram,
        week: Int,
        lift: String,
        sessionById: [UUID: WorkoutSession]
    ) -> (week: Int, weightKg: Double?, logged: Bool) {
        // Logged wins: the actual top set from the week's completed sessions.
        let weekDayIds = Set(program.days(inWeek: week).map(\.id))
        let loggedWeights: [Double] = programEntries
            .filter { $0.status == .completed && $0.programDayId.map(weekDayIds.contains) == true }
            .compactMap { $0.completedSessionId.flatMap { sessionById[$0] } }
            .flatMap { session in
                session.sortedEntries
                    .filter { $0.exerciseName == lift }
                    .flatMap(\.sets)
                    .compactMap(\.weightKg)
            }
        if let top = loggedWeights.max() {
            return (week, top, true)
        }
        // Otherwise the plan's own number, outlined.
        let plannedWeights: [Double] = program.days(inWeek: week)
            .compactMap { $0.templateId.flatMap { templatesById[$0] } }
            .flatMap { $0.sortedGroups.flatMap(\.sortedExercises) }
            .filter { $0.exerciseName == lift }
            .flatMap(\.sortedSets)
            .filter { !$0.isWarmup }
            .compactMap(\.targetWeightKg)
        return (week, plannedWeights.max(), false)
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: Spacing.sm) {
            Text("program.empty.title")
                .font(.Tokens.sectionHead)
                .foregroundStyle(ColorTokens.text1)
            Text("program.empty.body")
                .font(.Tokens.body)
                .foregroundStyle(ColorTokens.text2)
                .multilineTextAlignment(.center)
            Button {
                Haptics.tap()
                showReimport = true
            } label: {
                Text("workoutLog.menu.bringProgram")
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text1)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.xs)
                    .overlay(Capsule().stroke(ColorTokens.divider, lineWidth: 0.5))
            }
            .buttonStyle(.pressable)
        }
        .padding(.vertical, Spacing.xl)
        .padding(.horizontal, Spacing.sm)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Move position sheet

/// "Move my position" (epic 7): the cursor is the athlete's to place; moving it
/// re-materializes the still-planned future from the chosen week/day.
struct MovePositionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let program: TrainingProgram

    @State private var week: Int = 1
    @State private var day: Int = 1
    @State private var programRepo: ProgramRepository?
    @State private var scheduleRepo: ScheduleRepository?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                InstrumentSheetHeader(title: "program.move.title") {
                    SheetHeaderButton(title: "action.cancel") { dismiss() }
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        AnnotationLabel(key: "program.move.weekStamp")
                        weekGrid
                        AnnotationLabel(key: "program.move.dayStamp")
                        dayGrid
                        PrimaryActionButton(title: "program.move.confirm") {
                            move()
                        }
                    }
                    .padding(Spacing.sm)
                }
                .background(ColorTokens.background)
            }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                week = program.positionWeek
                day = program.positionDay
                if programRepo == nil {
                    programRepo = ProgramRepository(modelContext: modelContext)
                    scheduleRepo = ScheduleRepository(modelContext: modelContext)
                }
            }
        }
    }

    private var weekGrid: some View {
        let columns = [GridItem(.adaptive(minimum: 56), spacing: 4)]
        return LazyVGrid(columns: columns, spacing: 4) {
            ForEach(1...max(1, program.durationWeeks), id: \.self) { value in
                selectCell(text: "W\(value)", selected: week == value) {
                    week = value
                    day = min(day, max(1, program.days(inWeek: value).count))
                }
            }
        }
    }

    private var dayGrid: some View {
        let dayCount = max(1, program.days(inWeek: week).count)
        let columns = [GridItem(.adaptive(minimum: 56), spacing: 4)]
        return LazyVGrid(columns: columns, spacing: 4) {
            ForEach(1...dayCount, id: \.self) { value in
                selectCell(text: "D\(value)", selected: day == value) {
                    day = value
                }
            }
        }
    }

    private func selectCell(text: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.select()
            action()
        } label: {
            Text(verbatim: text)
                .font(.Tokens.label)
                .monospacedDigit()
                .foregroundStyle(selected ? ColorTokens.text1 : ColorTokens.text2)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(
                    selected ? ColorTokens.surfaceEl2 : ColorTokens.surface,
                    in: RoundedRectangle(cornerRadius: CornerTokens.control)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CornerTokens.control)
                        .stroke(selected ? ColorTokens.text1 : ColorTokens.divider,
                                lineWidth: selected ? 1 : 0.5)
                )
        }
        .buttonStyle(.pressable)
    }

    private func move() {
        guard let programRepo, let scheduleRepo else { return }
        do {
            try ProgramScheduleService.movePosition(
                program, toWeek: week, day: day,
                programRepo: programRepo, scheduleRepo: scheduleRepo
            )
            Haptics.success()
            dismiss()
        } catch {
            print("MovePositionSheet error: \(error)")
            Haptics.warning()
        }
    }
}
