import SwiftUI
import SwiftData

/// Retroactive session entry for a past calendar day (v1.7.3 feature 6, epic 6 —
/// "past days accept what actually happened"). A pickup game, scrimmage, or off-plan
/// lift becomes a REAL `WorkoutSession` on that date and runs the workout pipeline, so
/// carry is honest — never a calendar-only note. Duration and sRPE are the athlete's
/// own statement; nothing is guessed (save stays disabled until an effort is chosen).
struct QuickPastSessionSheet: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var athletes: [Athlete]

    let day: Date
    let kind: ScheduleEntryKind

    @State private var durationMinutes: Int = 60
    @State private var rpe: Int?
    @State private var scheduleRepo: ScheduleRepository?

    private var athlete: Athlete? { athletes.first }

    private var matchTier: MatchTier? {
        switch kind {
        case .pickup: return .pickup
        case .scrimmage: return .scrimmage
        case .match: return .match
        case .programSession, .offPlanLift: return nil
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                InstrumentSheetHeader(title: "quickPast.nav.title", leading: {
                    SheetHeaderButton(title: "action.cancel") { dismiss() }
                })

                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            AnnotationLabel(dayStamp)
                            Text(verbatim: kind.displayName)
                                .font(.Tokens.sectionTitle)
                                .foregroundStyle(ColorTokens.text1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Spacing.sm)
                        .emphasisCardStyle()

                        durationRow
                        rpeRow

                        PrimaryActionButton(
                            title: "quickPast.action.save",
                            isDisabled: rpe == nil || athlete == nil
                        ) {
                            save()
                        }
                    }
                    .padding(Spacing.sm)
                }
                .background(ColorTokens.background)
            }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                if scheduleRepo == nil {
                    scheduleRepo = ScheduleRepository(modelContext: modelContext)
                }
            }
        }
    }

    private var dayStamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE d MMM"
        return formatter.string(from: day).uppercased()
    }

    private var durationRow: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            AnnotationLabel(key: "quickPast.duration.stamp")
            HStack(spacing: 4) {
                ForEach([30, 45, 60, 75, 90], id: \.self) { minutes in
                    Button {
                        Haptics.select()
                        durationMinutes = minutes
                    } label: {
                        Text(verbatim: "\(minutes)")
                            .font(.Tokens.label)
                            .monospacedDigit()
                            .foregroundStyle(durationMinutes == minutes ? ColorTokens.text1 : ColorTokens.text2)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(
                                durationMinutes == minutes ? ColorTokens.surfaceEl2 : ColorTokens.surface,
                                in: RoundedRectangle(cornerRadius: CornerTokens.control)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: CornerTokens.control)
                                    .stroke(
                                        durationMinutes == minutes ? ColorTokens.text1 : ColorTokens.divider,
                                        lineWidth: durationMinutes == minutes ? 1 : 0.5
                                    )
                            )
                    }
                    .buttonStyle(.pressable)
                }
            }
            AnnotationLabel(key: "quickPast.duration.unit", size: .small)
        }
    }

    private var rpeRow: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            AnnotationLabel(key: "quickPast.rpe.stamp")
            HStack(spacing: 4) {
                ForEach(1...10, id: \.self) { value in
                    Button {
                        Haptics.select()
                        rpe = value
                    } label: {
                        Text(verbatim: "\(value)")
                            .font(.Tokens.label)
                            .monospacedDigit()
                            .foregroundStyle(rpe == value ? ColorTokens.text1 : ColorTokens.text2)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(
                                rpe == value ? ColorTokens.surfaceEl2 : ColorTokens.surface,
                                in: RoundedRectangle(cornerRadius: CornerTokens.control)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: CornerTokens.control)
                                    .stroke(
                                        rpe == value ? ColorTokens.text1 : ColorTokens.divider,
                                        lineWidth: rpe == value ? 1 : 0.5
                                    )
                            )
                    }
                    .buttonStyle(.pressable)
                }
            }
        }
    }

    private func save() {
        guard let athlete, let rpe else { return }
        // Noon on the chosen day: unambiguous within the day, stable across time zones.
        let calendar = Calendar.current
        let sessionDate = calendar.date(
            byAdding: .hour, value: 12, to: calendar.startOfDay(for: day)
        ) ?? day

        let session = WorkoutSession(
            sessionDate: sessionDate,
            sessionName: kind.displayName,
            sportType: kind == .offPlanLift ? .lifting : .teamSport,
            durationSeconds: durationMinutes * 60,
            sessionRPE: Double(rpe),
            sessionType: kind == .offPlanLift ? .strength : .match
        )
        session.matchTier = MatchTier.persistedTier(
            sessionType: session.sessionType, selected: matchTier
        )
        session.athlete = athlete
        session.recalculateDerivedFields()
        modelContext.insert(session)

        do {
            _ = try WorkoutPipeline.processSession(
                session,
                athlete: athlete,
                modelContext: modelContext,
                syncService: container.syncService
            )
            // Ledger record: a completed ad-hoc entry linked to the session.
            if let scheduleRepo {
                let entry = try scheduleRepo.addAdHoc(
                    kind: kind, on: day, athleteId: athlete.id,
                    durationMinutes: durationMinutes
                )
                try scheduleRepo.markCompleted(entry, sessionId: session.id)
            }
            Haptics.success()
            dismiss()
        } catch {
            print("QuickPastSessionSheet save error: \(error)")
            Haptics.warning()
        }
    }
}
