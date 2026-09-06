import SwiftUI
import SwiftData

/// The calendar spine's week strip (v1.7.3 feature 6, epic 6 — gated demo §1, round 4).
///
/// Seven day cells (Mon–Sun, ISO) over the training week. Any day cell opens its own
/// contextual action sheet — actions only, no explainer sentences (round-3 note 1), shown
/// only while a day is selected and closed by tapping the same day again (note 2).
/// Past days accept what actually happened (retroactive game/lift → carry); future days
/// accept decisions in advance (cancel now, reschedule via day picker, add a match now).
/// A canceled session stays visible, struck; the ledger lists the week's recorded changes.
struct ScheduleWeekSection: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(TabRouter.self) private var router
    @Query private var athletes: [Athlete]
    @Query private var entries: [ScheduleEntry]
    @Query private var sessions: [WorkoutSession]
    @Query private var programs: [TrainingProgram]

    /// Opens retroactive logging for a past day (pickup / scrimmage / off-plan lift).
    var onLogPastDay: (Date, ScheduleEntryKind) -> Void = { _, _ in }

    @State private var selectedDay: Date?
    @State private var showDayPicker = false
    @State private var scheduleRepo: ScheduleRepository?

    private var calendar: Calendar { Calendar(identifier: .iso8601) }
    private var athlete: Athlete? { athletes.first }
    private var activeProgram: TrainingProgram? {
        programs.first { $0.isActive && !$0.isArchived && $0.athleteId == athlete?.id }
    }

    // MARK: - Week window

    private var weekStart: Date {
        let today = calendar.startOfDay(for: .now)
        return calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
    }

    private var weekDays: [Date] {
        (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) }
    }

    private func entries(on day: Date) -> [ScheduleEntry] {
        guard let athleteId = athlete?.id else { return [] }
        return entries
            .filter { $0.athleteId == athleteId && calendar.isDate($0.date, inSameDayAs: day) }
            .sorted { $0.createdAt < $1.createdAt }
    }

    private func sessions(on day: Date) -> [WorkoutSession] {
        sessions.filter { calendar.isDate($0.sessionDate, inSameDayAs: day) }
    }

    // MARK: - Body

    var body: some View {
        SectionContainer {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                header
                dayGrid
                if let selectedDay {
                    daySheet(for: selectedDay)
                        .transition(.opacity)
                }
                ledger
            }
            .padding(.horizontal, Spacing.sm)
        }
        .onAppear {
            if scheduleRepo == nil {
                scheduleRepo = ScheduleRepository(modelContext: modelContext)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(verbatim: activeProgram?.name ?? String(localized: "schedule.header.week", defaultValue: "This week"))
                .font(.Tokens.sectionHead)
                .foregroundStyle(ColorTokens.text1)
            Spacer()
            if let program = activeProgram {
                AnnotationLabel(String(
                    format: String(localized: "schedule.header.position", defaultValue: "W%lld OF %lld"),
                    program.positionWeek, program.durationWeeks
                ))
            }
        }
    }

    // MARK: - Day grid

    private var dayGrid: some View {
        HStack(spacing: 4) {
            ForEach(weekDays, id: \.self) { day in
                dayCell(day)
            }
        }
        .accessibilityIdentifier("workoutLog.schedule.week")
    }

    private func dayCell(_ day: Date) -> some View {
        let today = calendar.isDate(day, inSameDayAs: .now)
        let selected = selectedDay.map { calendar.isDate($0, inSameDayAs: day) } ?? false
        let dayEntries = entries(on: day)
        let done = !sessions(on: day).isEmpty
            || dayEntries.contains { $0.status == .completed }
        let planned = dayEntries.first {
            $0.kind == .programSession && ($0.status == .planned || $0.status == .canceled)
        }
        let game = dayEntries.first {
            [.match, .scrimmage, .pickup].contains($0.kind) && $0.status == .planned
        }
        let offPlan = dayEntries.contains {
            ($0.isAdHoc || $0.movedFromDate != nil) && $0.status == .planned && $0.kind != .match
        }
        let mark = markText(planned: planned, game: game, done: done)

        return Button {
            Haptics.select()
            withAnimation(Motion.resolved(Motion.state, reduceMotion: reduceMotion)) {
                if selected {
                    selectedDay = nil
                } else {
                    selectedDay = day
                }
                showDayPicker = false
            }
        } label: {
            VStack(spacing: 4) {
                AnnotationLabel(key: weekdayKey(for: day), size: .small)
                HStack(spacing: 3) {
                    dot(done: done, planned: planned != nil || game != nil)
                    if offPlan {
                        Circle().fill(ColorTokens.accent).frame(width: 6, height: 6)
                    }
                }
                .frame(height: 8)
                Text(verbatim: mark.text)
                    .font(.Tokens.micro)
                    .monospacedDigit()
                    .strikethrough(mark.struck, color: ColorTokens.text3)
                    .foregroundStyle(mark.struck ? ColorTokens.text3 :
                        (game?.kind == .match ? ColorTokens.text1 : ColorTokens.text2))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: 64)
            .padding(.vertical, Spacing.xs)
            .background(
                selected ? ColorTokens.surfaceEl2 : ColorTokens.surfaceEl,
                in: RoundedRectangle(cornerRadius: CornerTokens.control)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerTokens.control)
                    .stroke(
                        selected ? ColorTokens.text1 : (today ? ColorTokens.accent : ColorTokens.divider),
                        lineWidth: selected || today ? 1 : 0.5
                    )
            )
        }
        .buttonStyle(.pressable)
    }

    private func dot(done: Bool, planned: Bool) -> some View {
        Circle()
            .fill(done ? ColorTokens.text2 : Color.clear)
            .overlay(
                Circle().stroke(
                    done ? Color.clear : (planned ? ColorTokens.text3 : Color.clear),
                    lineWidth: 1
                )
            )
            .frame(width: 6, height: 6)
    }

    private func markText(planned: ScheduleEntry?, game: ScheduleEntry?, done: Bool) -> (text: String, struck: Bool) {
        if let game {
            return (game.kind.displayName, false)
        }
        if let planned {
            if planned.status == .canceled || planned.status == .moved {
                return (planned.title, true)
            }
            return (planned.title, false)
        }
        if done {
            return (String(localized: "schedule.mark.done", defaultValue: "Done"), false)
        }
        return ("—", false)
    }

    private func weekdayKey(for day: Date) -> LocalizedStringKey {
        switch calendar.component(.weekday, from: day) {
        case 2: return "weekday.short.mon"
        case 3: return "weekday.short.tue"
        case 4: return "weekday.short.wed"
        case 5: return "weekday.short.thu"
        case 6: return "weekday.short.fri"
        case 7: return "weekday.short.sat"
        default: return "weekday.short.sun"
        }
    }

    // MARK: - Contextual day sheet (actions only)

    @ViewBuilder
    private func daySheet(for day: Date) -> some View {
        let today = calendar.startOfDay(for: .now)
        let dayStart = calendar.startOfDay(for: day)
        let dayEntries = entries(on: day)
        let planned = dayEntries.first { $0.kind == .programSession && $0.status != .moved }
        let match = dayEntries.first { $0.kind == .match && $0.status == .planned }

        VStack(spacing: 0) {
            HStack {
                AnnotationLabel(dayStamp(for: day, planned: planned, match: match), color: ColorTokens.text2)
                Spacer()
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            RowSeparator()

            if dayStart < today {
                pastDayActions(day: day)
            } else if calendar.isDate(day, inSameDayAs: today) {
                actionRow(title: "schedule.action.openProposal", kicker: "schedule.kicker.today") {
                    selectedDay = nil
                    // The proposal lives on the Today surface (slice 2) — hand off via the
                    // R9 router seam.
                    router.selection = .home
                }
            } else if let match {
                matchActions(match: match)
            } else if let planned {
                plannedDayActions(day: day, planned: planned)
            } else {
                restDayActions(day: day)
            }
        }
        .emphasisCardStyle(horizontalPadding: 0, verticalPadding: 0)
        .accessibilityIdentifier("workoutLog.schedule.daySheet")
    }

    private func dayStamp(for day: Date, planned: ScheduleEntry?, match: ScheduleEntry?) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE d MMM"
        var parts = [formatter.string(from: day).uppercased()]
        if let match { parts.append(match.kind.displayName) }
        else if let planned {
            parts.append(planned.title)
            if planned.status == .canceled { parts.append(planned.status.displayName) }
        }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder
    private func pastDayActions(day: Date) -> some View {
        actionRow(title: "schedule.action.addPickup", kicker: "schedule.kicker.carry") {
            selectedDay = nil
            onLogPastDay(day, .pickup)
        }
        RowSeparator()
        actionRow(title: "schedule.action.addScrimmage", kicker: "schedule.kicker.carryScrimmage") {
            selectedDay = nil
            onLogPastDay(day, .scrimmage)
        }
        RowSeparator()
        actionRow(title: "schedule.action.addOffPlanLift", kicker: "schedule.kicker.logsAsSession") {
            selectedDay = nil
            onLogPastDay(day, .offPlanLift)
        }
    }

    @ViewBuilder
    private func plannedDayActions(day: Date, planned: ScheduleEntry) -> some View {
        if planned.status == .canceled {
            actionRow(title: "schedule.action.restore", kicker: "schedule.kicker.undo") {
                guard let scheduleRepo else { return }
                try? scheduleRepo.restore(planned)
            }
        } else {
            actionRow(title: "schedule.action.cancel", kicker: "schedule.kicker.inAdvance") {
                guard let scheduleRepo else { return }
                try? scheduleRepo.cancel(planned)
            }
            RowSeparator()
            actionRow(title: "schedule.action.reschedule", kicker: "schedule.kicker.pickADay") {
                withAnimation(Motion.resolved(Motion.state, reduceMotion: reduceMotion)) {
                    showDayPicker.toggle()
                }
            }
            if showDayPicker {
                dayPicker(for: planned)
            }
            RowSeparator()
            actionRow(title: "schedule.action.addMatchInstead", kicker: "schedule.kicker.protected") {
                guard let scheduleRepo, let athleteId = athlete?.id else { return }
                try? scheduleRepo.cancel(planned)
                _ = try? scheduleRepo.addAdHoc(kind: .match, on: day, athleteId: athleteId)
            }
        }
    }

    @ViewBuilder
    private func restDayActions(day: Date) -> some View {
        actionRow(title: "schedule.action.addScrimmage", kicker: "schedule.kicker.carryScrimmage") {
            addAdHoc(.scrimmage, on: day)
        }
        RowSeparator()
        actionRow(title: "schedule.action.addPickup", kicker: "schedule.kicker.carry") {
            addAdHoc(.pickup, on: day)
        }
        RowSeparator()
        actionRow(title: "schedule.action.addExtraLift", kicker: "schedule.kicker.offPlan") {
            addAdHoc(.offPlanLift, on: day)
        }
        RowSeparator()
        actionRow(title: "schedule.action.addMatch", kicker: "schedule.kicker.protected") {
            addAdHoc(.match, on: day)
        }
    }

    @ViewBuilder
    private func matchActions(match: ScheduleEntry) -> some View {
        actionRow(title: "schedule.action.clearMatch", kicker: "") {
            guard let scheduleRepo else { return }
            try? scheduleRepo.remove(match)
            selectedDay = nil
        }
    }

    private func addAdHoc(_ kind: ScheduleEntryKind, on day: Date) {
        guard let scheduleRepo, let athleteId = athlete?.id else { return }
        _ = try? scheduleRepo.addAdHoc(kind: kind, on: day, athleteId: athleteId)
    }

    private func actionRow(
        title: LocalizedStringKey,
        kicker: LocalizedStringKey,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            HStack {
                Text(title)
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text1)
                Spacer()
                AnnotationLabel(key: kicker, size: .small)
            }
            .padding(.horizontal, Spacing.sm)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
    }

    // MARK: - Reschedule day picker

    private func dayPicker(for entry: ScheduleEntry) -> some View {
        HStack(spacing: 4) {
            ForEach(weekDays, id: \.self) { target in
                let past = calendar.startOfDay(for: target) < calendar.startOfDay(for: .now)
                let isSource = calendar.isDate(target, inSameDayAs: entry.date)
                Button {
                    Haptics.select()
                    guard let scheduleRepo else { return }
                    _ = try? scheduleRepo.reschedule(entry, to: target)
                    withAnimation(Motion.resolved(Motion.state, reduceMotion: reduceMotion)) {
                        showDayPicker = false
                        selectedDay = nil
                    }
                } label: {
                    AnnotationLabel(key: weekdayKey(for: target), size: .small,
                                    color: past || isSource ? ColorTokens.disabled : ColorTokens.text2)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(ColorTokens.surface, in: RoundedRectangle(cornerRadius: CornerTokens.control))
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerTokens.control)
                                .stroke(ColorTokens.divider, lineWidth: 0.5)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.pressable)
                .disabled(past || isSource)
            }
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.bottom, Spacing.xs)
        .accessibilityIdentifier("workoutLog.schedule.dayPicker")
    }

    // MARK: - Ledger

    @ViewBuilder
    private var ledger: some View {
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
        let changes = athlete.map { athlete in
            entries
                .filter {
                    $0.athleteId == athlete.id
                        && $0.date >= weekStart && $0.date < weekEnd
                        && ($0.status == .canceled || $0.status == .moved
                            || $0.isAdHoc || $0.movedFromDate != nil)
                }
                .sorted { $0.updatedAt < $1.updatedAt }
        } ?? []

        if !changes.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                AnnotationLabel(key: "schedule.ledger.stamp")
                ForEach(changes, id: \.id) { change in
                    Text(verbatim: ledgerLine(for: change))
                        .font(.Tokens.smallLabel)
                        .foregroundStyle(ColorTokens.text2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.sm)
            .cardStyle(horizontalPadding: 0, verticalPadding: 0)
        }
    }

    private func ledgerLine(for entry: ScheduleEntry) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        let day = formatter.string(from: entry.date).uppercased()
        switch entry.status {
        case .canceled:
            return "· \(day) — " + String(localized: "schedule.ledger.canceled", defaultValue: "\(entry.title) canceled in advance")
        case .moved:
            let target = entry.movedToDate.map { formatter.string(from: $0).uppercased() } ?? "—"
            return "· \(day) — " + String(localized: "schedule.ledger.moved", defaultValue: "\(entry.title) moved to \(target)")
        default:
            if entry.movedFromDate != nil {
                let source = entry.movedFromDate.map { formatter.string(from: $0).uppercased() } ?? "—"
                return "· \(day) — " + String(localized: "schedule.ledger.movedIn", defaultValue: "\(entry.title) moved from \(source)")
            }
            return "· \(day) — " + String(localized: "schedule.ledger.added", defaultValue: "\(entry.title) added")
        }
    }
}
