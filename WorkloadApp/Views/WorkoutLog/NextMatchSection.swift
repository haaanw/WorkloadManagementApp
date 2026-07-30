import SwiftUI
import SwiftData
import Combine

/// "Next match" — the first schedule-shaped plan object in the wedge (ADR-0002).
/// ONE optional scheduled match date on the athlete: set, change, clear. No recurrence,
/// no forecasting — the proximity rule (Stage 2) reads this date; this section never
/// touches the verdict engine.
///
/// Empty state ("No scheduled match") is a NORMAL state — the beachhead athlete's schedule
/// is mixed (league weeks and pickup-only weeks) — so it reads calm, never like a nag.
///
/// Expiry convention: the date stays visible through match day itself ("Match today");
/// the first read AFTER match day silently clears it back to the empty state — checked
/// onAppear, on scenePhase → .active, and on the NSCalendarDayChanged notification (so a
/// view mounted across midnight expires too), and additionally clamped at the render read
/// site so a strictly-past date can never render negative days-out copy.
/// Silent-clear (not a banner) because an expired date is not an error — the match
/// happened; the section simply returns to "no scheduled match".
///
/// DESIGN.md-compliant: Rectangle-only, hairline borders, no shadows, Font.Tokens,
/// ColorTokens, 8pt grid, NO accent (this is not a hero/live surface).
struct NextMatchSection: View {
    @Query private var athletes: [Athlete]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var scenePhase
    @State private var showPicker = false

    private var athlete: Athlete? { athletes.first }

    var body: some View {
        SectionContainer(header: "nextMatch.section.header") {
            Group {
                // A strictly-past date reads as ABSENT at the read site (displayDaysOut == nil),
                // so the section can never render negative "Match in -1 days" copy even if the
                // view stays mounted across midnight before an expiry pass has run.
                if let date = athlete?.nextMatchDate,
                   let days = Self.displayDaysOut(nextMatchDate: date, asOf: .now, calendar: .current) {
                    scheduledRow(date: date, daysOut: days)
                } else {
                    emptyRow
                }
            }
            .padding(.horizontal, Spacing.sm)
        }
        .onAppear(perform: expireIfPast)
        // Re-run expiry when the app returns to foreground (the codebase's scenePhase idiom —
        // mirrors DashboardView) and when the calendar day changes while mounted (the
        // stayed-open-across-midnight case the onAppear pass misses).
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active { expireIfPast() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            expireIfPast()
        }
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

    private func scheduledRow(date: Date, daysOut: Int) -> some View {
        HStack(spacing: Spacing.sm) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(daysOutText(daysOut))
                    .font(.Tokens.bodyMedium)
                    .monospacedDigit()
                    .foregroundStyle(ColorTokens.text1)
                // The match date itself is a timestamp — annotation (v6). The days-out line
                // above stays the working voice: it is a phrase the app SAYS, not marginalia.
                AnnotationLabel(date.shortString(locale: locale), color: ColorTokens.text2)
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

    /// Whole calendar days from `asOf` to the match (0 = match day), or nil when the stored
    /// date is strictly past (expired ⇒ treated as absent — the empty state, never negative
    /// copy). This is the SINGLE read-site contract for rendering; injected clock/calendar
    /// keep it deterministic and testable (mirrors `TodayVerdictEngine.matchDaysAway`).
    static func displayDaysOut(nextMatchDate: Date?, asOf: Date, calendar: Calendar) -> Int? {
        guard let nextMatchDate else { return nil }
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: asOf),
            to: calendar.startOfDay(for: nextMatchDate)
        ).day ?? 0
        return days < 0 ? nil : days
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

    /// Auto-expire: strictly before today ⇒ clear. Match day itself still shows. Runs onAppear,
    /// on scenePhase → .active, and on NSCalendarDayChanged — the render path additionally
    /// clamps via `displayDaysOut`, so an expired date can never flash as negative copy between
    /// expiry passes.
    private func expireIfPast() {
        guard let athlete, let date = athlete.nextMatchDate else { return }
        if Self.displayDaysOut(nextMatchDate: date, asOf: .now, calendar: .current) == nil {
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
