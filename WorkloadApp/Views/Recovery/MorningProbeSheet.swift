import SwiftUI
import SwiftData

/// The blinded morning probe: the athlete's own readiness judgement, and optionally a grip
/// reading, captured **before any score is on screen**.
///
/// Blinding is the entire point. Answering "how ready do you feel?" after seeing a number
/// makes the answer a reaction to that number, so the sheet is presented ahead of the
/// dashboard's reading and the row it writes records whether that actually held
/// (`wasBlinded`). An unblinded answer is kept as data but can never count as evidence.
///
/// Opt-in, never imposed: a daily question in front of the score is a real cost, so this only
/// appears for an athlete who has turned validation on in Profile.
struct MorningProbeSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    let athlete: Athlete?
    /// True when nothing scored has been rendered yet this session — recorded with the answer.
    let isBlinded: Bool
    var onSaved: (() -> Void)?

    @State private var readiness: Int = 6
    @State private var gripText: String = ""
    @State private var gripHand: MorningReadinessProbe.GripHand = .right
    @State private var showGrip = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    header

                    readinessSection

                    Rectangle().fill(ColorTokens.divider).frame(height: 0.5)

                    gripSection
                }
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.md)
            }
            .background(ColorTokens.background)
            .navigationTitle(Text("probe.nav.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("probe.action.save") { save() }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("probe.action.skip") { dismiss() }
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("probe.header.title")
                .font(.Tokens.pageTitle)
                .foregroundStyle(ColorTokens.text1)
            Text("probe.header.subtitle")
                .font(.Tokens.body)
                .foregroundStyle(ColorTokens.text2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var readinessSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("probe.readiness.question")
                .font(.Tokens.sectionHead)
                .foregroundStyle(ColorTokens.text1)

            HStack(spacing: Spacing.baselinePair) {
                ForEach(
                    MorningReadinessProbe.readinessMin...MorningReadinessProbe.readinessMax,
                    id: \.self
                ) { value in
                    Button {
                        Haptics.select()
                        readiness = value
                    } label: {
                        Text("\(value)")
                            .font(readiness == value ? .Tokens.bodyMedium : .Tokens.body)
                            .monospacedDigit()
                            .foregroundStyle(readiness == value ? ColorTokens.text1 : ColorTokens.text2)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .contentShape(RoundedRectangle(cornerRadius: CornerTokens.control))
                            .overlay(
                                RoundedRectangle(cornerRadius: CornerTokens.control).stroke(
                                    readiness == value ? ColorTokens.text1 : ColorTokens.divider,
                                    lineWidth: readiness == value ? 1 : 0.5
                                )
                            )
                    }
                    .buttonStyle(.pressable(scale: 1, opacity: 0.7))
                }
            }

            AnnotationLabel(key: "probe.readiness.scaleHint", size: .small)
        }
    }

    private var gripSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Toggle(isOn: $showGrip) {
                Text("probe.grip.toggle")
                    .font(.Tokens.sectionHead)
                    .foregroundStyle(ColorTokens.text1)
            }
            .tint(ColorTokens.accent)

            if showGrip {
                Text("probe.grip.protocol")
                    .font(.Tokens.smallLabel)
                    .foregroundStyle(ColorTokens.text2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: Spacing.sm) {
                    TextField("probe.grip.placeholder", text: $gripText)
                        .keyboardType(.decimalPad)
                        .font(.Tokens.body)
                        .monospacedDigit()
                        .padding(.horizontal, Spacing.sm)
                        .frame(height: 44)
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerTokens.control)
                                .stroke(ColorTokens.divider, lineWidth: 0.5)
                        )

                    Picker("probe.grip.hand", selection: $gripHand) {
                        ForEach(MorningReadinessProbe.GripHand.allCases) { hand in
                            Text(hand.displayName).tag(hand)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 140)
                }
            }
        }
    }

    private func save() {
        let day = Calendar.current.startOfDay(for: Date())
        // One probe per day: replace rather than accumulate, so a re-answer corrects the day
        // instead of creating a second, contradictory record.
        let existing = (try? modelContext.fetch(
            FetchDescriptor<MorningReadinessProbe>(predicate: #Predicate { $0.date == day })
        ))?.filter { $0.athlete?.id == athlete?.id } ?? []
        for stale in existing { modelContext.delete(stale) }

        let grip = showGrip ? Double(gripText.replacingOccurrences(of: ",", with: ".")) : nil
        let probe = MorningReadinessProbe(
            date: day,
            perceivedReadiness: readiness,
            gripStrengthKg: grip,
            gripHandRaw: grip != nil ? gripHand.rawValue : nil,
            gripAttemptCount: grip != nil ? MorningReadinessProbe.recommendedGripAttempts : nil,
            wasBlinded: isBlinded
        )
        probe.athlete = athlete
        modelContext.insert(probe)
        try? modelContext.save()
        onSaved?()
        dismiss()
    }
}
