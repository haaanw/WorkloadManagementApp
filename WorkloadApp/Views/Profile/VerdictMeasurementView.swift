import SwiftUI
import SwiftData

/// Phase 45 Plan 03 (METRIC-02) — the quiet, internal **validation-signal readout**.
///
/// Runs `GreenLightEngine` over the current athlete's logged `VerdictEvent`s and shows the green-light
/// rate alongside the activation rate and Day-7 / Day-30 retention. This is the founder's-playbook
/// readout that proves whether the verdict earns its keep — deliberately QUIET: a flat row list, no
/// hero number, no accent, no chart. It reads honestly: when there is no signal yet it shows a
/// still-learning placeholder, never a fabricated 0% / 100%.
///
/// ## Date determinism
/// The pure engine stays date-injected. This view reads `.now` + `Calendar.current` EXACTLY ONCE at
/// the boundary and passes them into `GreenLightEngine.compute(events:asOf:calendar:)` — the only place
/// `.now` / `.current` appear in the green-light path.
///
/// DESIGN.md (hard): 0pt corners (Rectangle only), no shadows, `Font.Tokens.*`, 8pt grid, light-only
/// via `ColorTokens`. The reserved hero accent is FORBIDDEN here.
struct VerdictMeasurementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var athletes: [Athlete]

    private var metrics: GreenLightEngine.GreenLightMetrics {
        let repository = VerdictEventRepository(modelContext: modelContext)
        let events = repository.fetchAll(athlete: athletes.first)
        // Read the clock ONCE at the boundary; the engine itself stays injected.
        return GreenLightEngine.compute(events: events, asOf: .now, calendar: .current)
    }

    /// v2.1 dogfood — the pre-registered criteria 1–3 readout (differing days / followed % /
    /// felt-right %) over the same event log. Same boundary rule: `.now`/`.current` read here once.
    private var dogfood: FeltRightPromptEngine.DogfoodSummary {
        let repository = VerdictEventRepository(modelContext: modelContext)
        let events = repository.fetchAll(athlete: athletes.first)
        return FeltRightPromptEngine.summary(events: events, asOf: .now, calendar: .current)
    }

    var body: some View {
        let m = metrics
        let d = dogfood
        ScrollView {
            VStack(spacing: 0) {
                SectionHeader(title: "measurement.title")
                    .padding(.top, Spacing.md)
                    .padding(.bottom, Spacing.sm)

                VStack(spacing: 0) {
                    statRow(
                        label: "measurement.greenLight.label",
                        value: percentText(m.greenLightRate),
                        context: m.greenLightRate == nil
                            ? nil
                            : String(
                                format: String(localized: "measurement.greenLight.context",
                                               defaultValue: "on %d differing-verdict days"),
                                m.differingDays
                            )
                    )
                    rowHairline()
                    statRow(
                        label: "measurement.activation.label",
                        value: percentText(m.activationRate),
                        context: m.activationRate == nil
                            ? nil
                            : String(
                                format: String(localized: "measurement.activation.context",
                                               defaultValue: "across %d logged verdicts"),
                                m.totalEvents
                            )
                    )
                    rowHairline()
                    statRow(
                        label: "measurement.retention.day7",
                        value: retentionText(m.day7Retention),
                        context: nil
                    )
                    rowHairline()
                    statRow(
                        label: "measurement.retention.day30",
                        value: retentionText(m.day30Retention),
                        context: nil
                    )
                }
                .cardStyle(horizontalPadding: 0, verticalPadding: 0)
                .padding(.horizontal, Spacing.sm)

                // Honest caption — these are pre-validation internal signals.
                Text("measurement.caption")
                    .font(.Tokens.smallLabel)
                    .foregroundStyle(ColorTokens.text3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.top, Spacing.sm)

                // v2.1 — the pre-registered n=1 dogfood criteria (1–4). Same quiet grammar:
                // flat rows, honest nil-states, no accent, no chart.
                SectionHeader(title: "measurement.dogfood.title")
                    .padding(.top, Spacing.lg)
                    .padding(.bottom, Spacing.sm)

                VStack(spacing: 0) {
                    statRow(
                        label: "measurement.dogfood.differingDays",
                        value: Text(verbatim: "\(d.differingDays)").monospacedDigit(),
                        context: nil
                    )
                    rowHairline()
                    statRow(
                        label: "measurement.dogfood.followed.label",
                        value: percentText(d.followedRate),
                        context: d.followedRate == nil
                            ? nil
                            : String(
                                format: String(localized: "measurement.dogfood.followed.context",
                                               defaultValue: "%1$d of %2$d days"),
                                d.followedDays, d.differingDays
                            )
                    )
                    rowHairline()
                    statRow(
                        label: "measurement.dogfood.feltRight.label",
                        value: percentText(d.feltRightRate),
                        context: (d.ratedDays + d.missedDays) == 0
                            ? nil
                            : String(
                                format: String(localized: "measurement.dogfood.feltRight.context",
                                               defaultValue: "%1$d rated · %2$d missed"),
                                d.ratedDays, d.missedDays
                            )
                    )
                    rowHairline()
                    // Criterion 4 — proximity microdoses (a raw count, not a rate: the ≥2
                    // threshold is judged against the count itself).
                    statRow(
                        label: "measurement.dogfood.proximity.label",
                        value: Text(verbatim: "\(d.proximityMicrodoseDays)").monospacedDigit(),
                        context: d.proximityMicrodoseDays == 0
                            ? nil
                            : String(
                                format: String(localized: "measurement.dogfood.proximity.context",
                                               defaultValue: "%1$d followed"),
                                d.proximityMicrodoseFollowedDays
                            )
                    )
                }
                .cardStyle(horizontalPadding: 0, verticalPadding: 0)
                .padding(.horizontal, Spacing.sm)

                Spacer()
            }
        }
        .background(ColorTokens.background)
        .navigationTitle("measurement.navTitle")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Rows

    @ViewBuilder
    private func statRow(label: LocalizedStringKey, value: Text, context: String?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
            VStack(alignment: .leading, spacing: Spacing.baselinePair) {
                Text(label)
                    .font(.Tokens.body)
                    .foregroundStyle(ColorTokens.text1)
                if let context {
                    Text(verbatim: context)
                        .font(.Tokens.smallLabel)
                        .foregroundStyle(ColorTokens.text2)
                }
            }
            Spacer()
            value
                .font(.Tokens.body)
                .monospacedDigit()
                .foregroundStyle(ColorTokens.text1)
        }
        .padding(.horizontal, Spacing.sm)
        .frame(minHeight: 48)
    }

    private func rowHairline() -> some View {
        Rectangle()
            .fill(ColorTokens.divider)
            .frame(height: 0.5)
            .padding(.leading, Spacing.sm)
    }

    // MARK: - Formatting (honest nil-states)

    /// A percentage with no fabricated 0% — `nil` becomes the still-learning placeholder.
    private func percentText(_ rate: Double?) -> Text {
        guard let rate else {
            return Text("measurement.learning")
                .foregroundStyle(ColorTokens.text3)
        }
        let pct = Int((rate * 100).rounded())
        return Text(verbatim: "\(pct)%")
    }

    /// true ⇒ "retained", false ⇒ "lapsed", nil ⇒ "too early".
    private func retentionText(_ value: Bool?) -> Text {
        switch value {
        case .some(true):
            return Text("measurement.retained")
        case .some(false):
            return Text("measurement.lapsed")
                .foregroundStyle(ColorTokens.text2)
        case .none:
            return Text("measurement.tooEarly")
                .foregroundStyle(ColorTokens.text3)
        }
    }
}
