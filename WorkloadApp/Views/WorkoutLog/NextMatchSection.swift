import SwiftUI
import SwiftData

/// "Next match" — the first schedule-shaped plan object in the wedge (ADR-0002).
/// ONE optional scheduled match date on the athlete: set, change, clear. No recurrence,
/// no forecasting — the proximity rule (Stage 2) reads this date; this section never
/// touches the verdict engine.
///
/// Empty state ("No scheduled match") is a NORMAL state — the beachhead athlete's schedule
/// is mixed (league weeks and pickup-only weeks) — so it reads calm, never like a nag.
///
/// Expiry convention: the date stays visible through match day itself ("Match today");
/// the first appearance AFTER match day silently clears it back to the empty state.
/// Silent-clear (not a banner) because an expired date is not an error — the match
/// happened; the section simply returns to "no scheduled match".
///
/// DESIGN.md-compliant: Rectangle-only, hairline borders, no shadows, Font.Tokens,
/// ColorTokens, 8pt grid, NO accent (this is not a hero/live surface).
struct NextMatchSection: View {
    @Query private var athletes: [Athlete]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale
    @State private var showPicker = false

    private var athlete: Athlete? { athletes.first }

    var body: some View {
        SectionContainer(header: "nextMatch.section.header") {
            Group {
                if let date = athlete?.nextMatchDate {
                    scheduledRow(date: date)
                } else {
                    emptyRow
                }
            }
            .padding(.horizontal, Spacing.sm)
        }
        .onAppear(perform: expireIfPast)
        .sheet(isPresented: $showPicker) {
            NextMatchPickerSheet(
                initialDate: athlete?.nextMatchDate,
                onSet: { setMatchDate($0) }
            )
        }
    }

    // MARK: - Rows

    /// Calm empty state: a quiet statement + a quiet set action. No urgency, no accent.
    private var emptyRow: some View {
        HStack(spacing: Spacing.sm) {
            Text("nextMatch.empty.label")
                .font(.Tokens.label)
                .foregroundStyle(ColorTokens.text2)
            Spacer()
            Button {
                Haptics.tap()
                showPicker = true
            } label: {
                Text("nextMatch.empty.set")
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text1)
            }
            .buttonStyle(.pressable)
        }
        .cardStyle(verticalPadding: Spacing.sm)
    }

    private func scheduledRow(date: Date) -> some View {
        HStack(spacing: Spacing.sm) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(daysOutText(daysOut(to: date)))
                    .font(.Tokens.bodyMedium)
                    .monospacedDigit()
                    .foregroundStyle(ColorTokens.text1)
                Text(date.shortString(locale: locale))
                    .font(.Tokens.smallLabel)
                    .monospacedDigit()
                    .foregroundStyle(ColorTokens.text2)
            }
            Spacer()
            Button {
                Haptics.tap()
                showPicker = true
            } label: {
                Text("nextMatch.action.change")
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text1)
            }
            .buttonStyle(.pressable)
            Button {
                Haptics.tap()
                clearMatchDate()
            } label: {
                Text("nextMatch.action.clear")
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text2)
            }
            .buttonStyle(.pressable)
        }
        .cardStyle(verticalPadding: Spacing.sm)
    }

    // MARK: - Days-out copy

    /// Whole calendar days from today to the match (0 = match day).
    private func daysOut(to date: Date) -> Int {
        let cal = Calendar.current
        return cal.dateComponents(
            [.day],
            from: cal.startOfDay(for: .now),
            to: cal.startOfDay(for: date)
        ).day ?? 0
    }

    private func daysOutText(_ days: Int) -> String {
        switch days {
        case 0: return String(localized: "nextMatch.daysOut.today")
        case 1: return String(localized: "nextMatch.daysOut.tomorrow")
        default: return String(format: String(localized: "nextMatch.daysOut.inDays"), days)
        }
    }

    // MARK: - Mutations (local-only field — never bump updatedAt, never syncs)

    /// Normalized to start-of-day so proximity math (Stage 2) is deterministic.
    private func setMatchDate(_ date: Date) {
        guard let athlete else { return }
        athlete.nextMatchDate = Calendar.current.startOfDay(for: date)
        try? modelContext.save()
    }

    private func clearMatchDate() {
        guard let athlete else { return }
        athlete.nextMatchDate = nil
        try? modelContext.save()
    }

    /// Auto-expire: strictly before today ⇒ clear. Match day itself still shows.
    private func expireIfPast() {
        guard let athlete, let date = athlete.nextMatchDate else { return }
        let cal = Calendar.current
        if cal.startOfDay(for: date) < cal.startOfDay(for: .now) {
            athlete.nextMatchDate = nil
            try? modelContext.save()
        }
    }
}

// MARK: - Picker sheet

/// Plain graphical date picker — same native style as the existing PrescribeWorkoutSheet
/// scheduled-date field. Future dates only (a past "next match" is meaningless).
private struct NextMatchPickerSheet: View {
    let initialDate: Date?
    let onSet: (Date) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDate: Date = .now

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    DatePicker(
                        "",
                        selection: $selectedDate,
                        in: Calendar.current.startOfDay(for: .now)...,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .padding(.horizontal, Spacing.sm)
                }
                .padding(.vertical, Spacing.sm)
            }
            .background(ColorTokens.background)
            .navigationTitle("nextMatch.picker.navTitle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.cancel") { dismiss() }
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text2)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("nextMatch.picker.confirm") {
                        onSet(selectedDate)
                        dismiss()
                    }
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text1)
                }
            }
            .onAppear {
                if let initialDate { selectedDate = initialDate }
            }
        }
    }
}
