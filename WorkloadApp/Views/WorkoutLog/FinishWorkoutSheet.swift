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

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // RPE section
                VStack(spacing: 8) {
                    Text("workout.prompt.rpe")
                        .font(.Tokens.body)
                        .foregroundStyle(ColorTokens.text1)

                    Text(String(format: String(localized: "workout.rpe.display", defaultValue: "RPE: %d"), Int(rpe)))
                        .font(.Tokens.pageTitle)
                        .monospacedDigit()
                        .foregroundStyle(ColorTokens.text1)

                    Slider(value: $rpe, in: 1...10, step: 1)
                        .tint(ColorTokens.text2)
                }

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

                // Template name field (visible when toggle is ON)
                if saveAsTemplate {
                    TextField("field.templateName", text: $templateName)
                        .textFieldStyle(SharpTextFieldStyle())
                        .transition(.opacity)
                }

                Spacer()
            }
            .padding(24)
            .background(ColorTokens.background)
            .navigationTitle("nav.finishWorkout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.keepEditing") { dismiss() }
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text2)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("action.finish") {
                        onFinish()
                        dismiss()
                    }
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text1)
                }
            }
            .animation(.easeOut(duration: 0.15), value: saveAsTemplate)
        }
        .interactiveDismissDisabled(true)
        .onAppear {
            if templateName.isEmpty {
                templateName = sessionName.isEmpty ? sportType.displayName : sessionName
            }
        }
    }
}
