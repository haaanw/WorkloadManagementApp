import SwiftUI
import SwiftData

/// Minimal one-off "today's lift" entry form (PLAN-10, manual path). Captures a lift name and
/// target weight / reps / optional RPE, then creates today's `PrescribedWorkout` (templateId nil)
/// via `PlannedSessionRepository.planManualLift`. No verdict, no adjusted numbers — those are
/// Phases 43/44. DESIGN.md-compliant: corners via `CornerTokens` (v3 Corner Law — fields via
/// SharpTextFieldStyle), no shadows, Font.Tokens, 8pt grid, NO accent (accent per Accent Rule v3).
struct ManualLiftEntrySheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var athletes: [Athlete]

    /// Called after the plan is created, so the parent can dismiss its own flow.
    var onPlanned: () -> Void

    @State private var liftName: String = ""
    @State private var weightText: String = ""
    @State private var repsText: String = ""
    @State private var rpeEnabled: Bool = false
    @State private var rpe: Double = 8

    private var trimmedName: String {
        liftName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canPlan: Bool {
        !trimmedName.isEmpty && athletes.first != nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    // Lift name
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("planToday.manual.nameLabel")
                            .font(.Tokens.label)
                            .foregroundStyle(ColorTokens.text2)
                        TextField("planToday.manual.namePlaceholder", text: $liftName)
                            .textFieldStyle(SharpTextFieldStyle())
                    }

                    // Target weight + reps
                    HStack(spacing: Spacing.sm) {
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text("planToday.manual.weightLabel")
                                .font(.Tokens.label)
                                .foregroundStyle(ColorTokens.text2)
                            TextField("planToday.manual.weightPlaceholder", text: $weightText)
                                .textFieldStyle(SharpTextFieldStyle())
                                .keyboardType(.decimalPad)
                        }
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text("planToday.manual.repsLabel")
                                .font(.Tokens.label)
                                .foregroundStyle(ColorTokens.text2)
                            TextField("planToday.manual.repsPlaceholder", text: $repsText)
                                .textFieldStyle(SharpTextFieldStyle())
                                .keyboardType(.numberPad)
                        }
                    }

                    // Optional RPE
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Toggle(isOn: $rpeEnabled) {
                            Text("planToday.manual.rpeToggle")
                                .font(.Tokens.label)
                                .foregroundStyle(ColorTokens.text1)
                        }
                        .toggleStyle(.design)

                        if rpeEnabled {
                            HStack(spacing: Spacing.sm) {
                                Text(String(format: String(localized: "planToday.manual.rpeValue", defaultValue: "RPE %d"), Int(rpe)))
                                    .font(.Tokens.body)
                                    .monospacedDigit()
                                    .foregroundStyle(ColorTokens.text1)
                                Slider(value: $rpe, in: 1...10, step: 1)
                                    .tint(ColorTokens.text2)
                                    .onChange(of: rpe) { _, _ in Haptics.select() }
                            }
                        }
                    }
                }
                .padding(Spacing.md)
            }
            .onAppear { Haptics.prepare() }
            .background(ColorTokens.background)
            .navigationTitle("planToday.manual.navTitle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.cancel") { dismiss() }
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text2)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("planToday.action.planToday") { plan() }
                        .font(.Tokens.label)
                        .foregroundStyle(canPlan ? ColorTokens.text1 : ColorTokens.text3)
                        .disabled(!canPlan)
                }
            }
        }
    }

    private func plan() {
        guard let athleteId = athletes.first?.id, !trimmedName.isEmpty else { return }
        let weight = Double(weightText.replacingOccurrences(of: ",", with: "."))
        let reps = Int(repsText)
        let repo = PlannedSessionRepository(modelContext: modelContext)
        repo.planManualLift(
            athleteId: athleteId,
            liftName: trimmedName,
            targetWeightKg: weight,
            targetReps: reps,
            targetRPE: rpeEnabled ? rpe : nil
        )
        Haptics.success()
        onPlanned()
        dismiss()
    }
}
