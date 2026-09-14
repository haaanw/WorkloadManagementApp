import SwiftUI
import SwiftData

/// The blinded morning probe: the athlete's own readiness judgement, and optionally a grip
/// reading, captured **before any score is on screen**.
///
/// Blinding is the entire point. Answering "how ready do you feel?" after seeing a number
/// makes the answer a reaction to that number, so the probe is asked ahead of the dashboard's
/// reading and the row it writes records whether that actually held (`wasBlinded`). An
/// unblinded answer is kept as data but can never count as evidence
/// (VALIDATION-PROTOCOL §blinding).
///
/// Opt-in, never imposed: a daily question in front of the score is a real cost, so it is only
/// asked of an athlete who has turned validation on in Profile.
///
/// **Not a sheet any more (v1.7.3 · U19).** It used to present itself, beside
/// `MorningCheckInSheet`, and both titles read "Morning check" — two morning questionnaires,
/// one morning. The probe is now STEP 1 of the single `MorningCheckInSheet`, which is why what
/// survives here is the field group and the write. The step order is load-bearing: ratings
/// first would let the sheet's own wellness preview stand between the athlete and the
/// question, and `wasBlinded` only tracks whether the DASHBOARD drew a score.

// MARK: - The probe's fields

/// Step 1 of the morning sheet: the 1–10 judgement and the optional grip reading.
/// State lives in the host sheet so the answers survive the step change to the ratings.
struct MorningProbeFields: View {
    @Binding var readiness: Int
    @Binding var gripText: String
    @Binding var gripHand: MorningReadinessProbe.GripHand
    @Binding var showGrip: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            header

            readinessSection

            Rectangle().fill(ColorTokens.divider).frame(height: 0.5)

            gripSection
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.md)
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
}

// MARK: - The probe's write

/// Persisting the probe, kept apart from the view so the merged sheet's single Save can write
/// the probe row and the wellness row in one pass.
@MainActor
enum MorningProbeRecorder {

    /// UserDefaults key stamping the day an explicit "not today" was given.
    static let skippedDayKey = "morningProbeSkippedDay"

    /// Record the answer for today, replacing any earlier one.
    ///
    /// One probe per day: replace rather than accumulate, so a re-answer corrects the day
    /// instead of creating a second, contradictory record. Does NOT save the context — the
    /// caller's one save covers both rows.
    static func record(
        readiness: Int,
        gripText: String,
        gripHand: MorningReadinessProbe.GripHand,
        includeGrip: Bool,
        wasBlinded: Bool,
        athlete: Athlete?,
        modelContext: ModelContext
    ) {
        let day = Calendar.current.startOfDay(for: Date())
        let existing = (try? modelContext.fetch(
            FetchDescriptor<MorningReadinessProbe>(predicate: #Predicate { $0.date == day })
        ))?.filter { $0.athlete?.id == athlete?.id } ?? []
        for stale in existing { modelContext.delete(stale) }

        let grip = includeGrip ? Double(gripText.replacingOccurrences(of: ",", with: ".")) : nil
        let probe = MorningReadinessProbe(
            date: day,
            perceivedReadiness: readiness,
            gripStrengthKg: grip,
            gripHandRaw: grip != nil ? gripHand.rawValue : nil,
            gripAttemptCount: grip != nil ? MorningReadinessProbe.recommendedGripAttempts : nil,
            wasBlinded: wasBlinded
        )
        probe.athlete = athlete
        modelContext.insert(probe)
    }

    /// Stamp today as skipped.
    ///
    /// Round 8 (HAN): a bare dismiss recorded nothing, so the probe re-asked on every Home
    /// appearance. Skipping stamps the DAY — one ask per morning, answered or not. Tomorrow
    /// asks fresh.
    static func stampSkippedToday() {
        UserDefaults.standard.set(
            Calendar.current.startOfDay(for: .now).timeIntervalSinceReferenceDate,
            forKey: skippedDayKey
        )
    }

    /// True when today already carries an explicit skip.
    static func isSkippedToday(now: Date = .now) -> Bool {
        let day = Calendar.current.startOfDay(for: now).timeIntervalSinceReferenceDate
        return UserDefaults.standard.double(forKey: skippedDayKey) == day
    }
}
