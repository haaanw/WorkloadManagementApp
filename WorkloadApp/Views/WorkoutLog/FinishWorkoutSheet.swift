import SwiftUI

/// Custom finish dialog replacing the .alert("Finish Workout") in ActiveWorkoutSheet.
/// Includes RPE slider and optional save-as-template toggle with template name field.
struct FinishWorkoutSheet: View {
    @Binding var rpe: Double
    @Binding var saveAsTemplate: Bool
    @Binding var templateName: String
    let sessionName: String
    let sportType: SportType
    /// What is about to be committed (v1.7.2): the athlete reads the session before signing
    /// it off, rather than being asked for an RPE about work they can no longer see.
    ///
    /// Deliberately three facts the sheet can state without re-deriving engine math. Volume is
    /// NOT among them: `WorkoutSession.recalculateDerivedFields` computes it from
    /// `SetRecord.effectiveLoadKg`, which is bodyweight- and body-mass-aware, and a second
    /// implementation over drafts would eventually disagree with the number that gets saved.
    let exerciseCount: Int
    let loggedSetCount: Int
    let elapsed: TimeInterval
    let onFinish: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
            InstrumentSheetHeader(title: "nav.finishWorkout") {
                SheetHeaderButton(title: "action.keepEditing") { dismiss() }
            } trailing: {
                SheetHeaderButton(title: "action.finish", emphasis: true) {
                    onFinish()
                    dismiss()
                }
            }
            VStack(spacing: Spacing.md) {
                summary
                    .entranceReveal(index: 0)

                Rectangle()
                    .fill(ColorTokens.divider)
                    .frame(height: 0.5)

                // RPE section
                VStack(spacing: Spacing.xs) {
                    Text("workout.prompt.rpe")
                        .font(.Tokens.body)
                        .foregroundStyle(ColorTokens.text1)

                    Text(String(format: String(localized: "workout.rpe.display", defaultValue: "RPE: %d"), Int(rpe)))
                        .font(.Tokens.pageTitle)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .foregroundStyle(ColorTokens.text1)

                    Slider(
                        value: $rpe,
                        in: 1...10,
                        step: 1,
                        onEditingChanged: { isEditing in
                            if !isEditing { Haptics.select() }
                        }
                    )
                        .tint(ColorTokens.text2)
                }
                .entranceReveal(index: 1)

                Rectangle()
                    .fill(ColorTokens.divider)
                    .frame(height: 0.5)

                // Save as template toggle
                Toggle(isOn: $saveAsTemplate) {
                    Text("action.saveAsTemplate")
                        .font(.Tokens.body)
                        .foregroundStyle(ColorTokens.text1)
                }
                .tint(ColorTokens.text2)
                .entranceReveal(index: 2)
                .onChange(of: saveAsTemplate) { _, _ in Haptics.select() }

                // Template name field (visible when toggle is ON)
                if saveAsTemplate {
                    TextField("field.templateName", text: $templateName)
                        .textFieldStyle(SharpTextFieldStyle())
                        .transition(.opacity)
                }

                Spacer()
            }
            .padding(Spacing.md)
            .background(ColorTokens.background)
            .animation(Motion.resolved(Motion.state, reduceMotion: reduceMotion), value: saveAsTemplate)
            .animation(Motion.resolved(Motion.state, reduceMotion: reduceMotion), value: rpe)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .interactiveDismissDisabled(true)
        .presentationDetents([.medium, .large])
        .onAppear {
            // Warm the haptic generators: the imminent Finish triggers the save-commit feedback.
            Haptics.prepare()
            if templateName.isEmpty {
                templateName = sessionName.isEmpty ? sportType.displayName : sessionName
            }
        }
    }

    // MARK: - Summary

    /// What is about to be saved, stated before the athlete signs it off. Counts are the working
    /// voice (they are the session's data); the row keys are annotation.
    private var summary: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            AnnotationLabel(key: "workout.finish.summary")
            VStack(spacing: 0) {
                summaryRow(key: "workout.finish.exercises", value: "\(exerciseCount)")
                Rectangle()
                    .fill(ColorTokens.divider)
                    .frame(height: 0.5)
                summaryRow(key: "workout.finish.setsLogged", value: "\(loggedSetCount)")
                Rectangle()
                    .fill(ColorTokens.divider)
                    .frame(height: 0.5)
                // NOT `workout.label.elapsed`: that string is written for the annotation voice,
                // which uppercases at the token, so reusing it here rendered a lowercase
                // "elapsed" beside "Exercises" and "Sets logged".
                summaryRow(
                    key: "workout.finish.duration",
                    value: Date.durationString(seconds: Int(elapsed), locale: locale)
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func summaryRow(key: LocalizedStringKey, value: String) -> some View {
        HStack {
            Text(key)
                .font(.Tokens.body)
                .foregroundStyle(ColorTokens.text2)
            Spacer(minLength: Spacing.sm)
            Text(value)
                .font(.Tokens.body)
                .monospacedDigit()
                .foregroundStyle(ColorTokens.text1)
        }
        .padding(.vertical, Spacing.xs)
        .accessibilityElement(children: .combine)
    }
}
