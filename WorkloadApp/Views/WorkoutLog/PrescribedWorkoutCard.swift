import SwiftUI

struct PrescribedWorkoutCard: View {
    let prescription: PrescribedWorkout
    let onStart: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: Spacing.baselinePair) {
                    Text(prescription.templateName)
                        .font(.Tokens.sectionHead)
                        .foregroundStyle(ColorTokens.text1)

                    // A timestamp — annotation (v6).
                    AnnotationLabel(prescription.scheduledDate.formatted(date: .abbreviated, time: .omitted))
                }
                Spacer()
                // A session-type tag — marginalia, not speech.
                AnnotationLabel(prescription.sessionType.displayName, color: ColorTokens.text2)
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.top, Spacing.sm)
            .padding(.bottom, Spacing.xs)

            // Coach notes
            if let notes = prescription.notes, !notes.isEmpty {
                Text(notes)
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text2)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.bottom, Spacing.xs)
            }

            Rectangle().fill(ColorTokens.divider).frame(height: 0.5)

            // Exercise summary by group
            ForEach(prescription.sortedGroups, id: \.id) { group in
                // Group key — annotation. The manual `.uppercased()` is gone: the primitive owns
                // the case transform AND skips it for CJK, which the call site could not.
                AnnotationLabel(group.groupName)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.top, Spacing.xs)
                    .padding(.bottom, Spacing.baselinePair)

                ForEach(group.sortedExercises, id: \.id) { exercise in
                    HStack {
                        Text(exercise.exerciseName)
                            .font(.Tokens.label)
                            .foregroundStyle(ColorTokens.text1)
                        Spacer()
                        // The set spec ("3 × 5 @ 100KG") is a unitized machine string — annotation.
                        AnnotationLabel(setSummary(exercise))
                    }
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.baselinePair)
                }
            }

            Rectangle().fill(ColorTokens.divider).frame(height: 0.5)

            // Action buttons
            HStack(spacing: 0) {
                Button { Haptics.impact(); onStart() } label: {
                    Text("action.start")
                        .font(.Tokens.body)
                        .foregroundStyle(ColorTokens.text1)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.sm)
                }
                .buttonStyle(.pressable)

                Rectangle().fill(ColorTokens.divider).frame(width: 0.5, height: 44)

                Button { Haptics.tap(); onSkip() } label: {
                    Text("action.skip")
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text3)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.sm)
                }
                .buttonStyle(.pressable)
            }
        }
        .background(ColorTokens.surface, in: RoundedRectangle(cornerRadius: CornerTokens.card))
        .clipShape(RoundedRectangle(cornerRadius: CornerTokens.card))
        .overlay(RoundedRectangle(cornerRadius: CornerTokens.card).stroke(ColorTokens.divider, lineWidth: 0.5))
    }

    private func setSummary(_ exercise: TemplateExercise) -> String {
        let sets = exercise.sortedSets.filter { !$0.isWarmup }
        guard !sets.isEmpty else { return "\(exercise.sets.count) sets" }
        if let reps = sets.first?.targetReps, let weight = sets.first?.targetWeightKg {
            return "\(sets.count) × \(reps) @ \(Int(weight))kg"
        } else if let reps = sets.first?.targetReps {
            return "\(sets.count) × \(reps)"
        }
        return "\(sets.count) sets"
    }
}
