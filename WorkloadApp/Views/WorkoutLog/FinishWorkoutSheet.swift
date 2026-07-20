import SwiftUI

/// Custom finish dialog replacing the .alert("Finish Workout") in ActiveWorkoutSheet.
/// Includes RPE slider and optional save-as-template toggle with template name field.
struct FinishWorkoutSheet: View {
    @Binding var rpe: Double
    @Binding var saveAsTemplate: Bool
    @Binding var templateName: String
    let sessionName: String
    let sportType: SportType
    let onFinish: () -> Void
    @Environment(\.dismiss) private var dismiss
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
                .entranceReveal(index: 0)

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
                .entranceReveal(index: 1)
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
        .onAppear {
            // Warm the haptic generators: the imminent Finish triggers the save-commit feedback.
            Haptics.prepare()
            if templateName.isEmpty {
                templateName = sessionName.isEmpty ? sportType.displayName : sessionName
            }
        }
    }
}
