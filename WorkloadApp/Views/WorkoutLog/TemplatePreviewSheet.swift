import SwiftUI
import SwiftData

struct TemplatePreviewSheet: View {
    let template: WorkoutTemplate
    var onEdit: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    Text(template.templateName)
                        .font(.Tokens.sectionHead)
                        .foregroundStyle(ColorTokens.text1)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.top, Spacing.sm)
                        .padding(.bottom, Spacing.baselinePair)

                    Text("\(template.sportType.displayName) - \(template.sessionType.displayName)")
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text2)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.bottom, Spacing.sm)

                    // Scheduled days
                    weekdayRow(scheduledDays: template.scheduledDays)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.bottom, Spacing.sm)

                    Rectangle().fill(ColorTokens.divider).frame(height: 0.5)

                    // Exercise list by group
                    ForEach(template.sortedGroups, id: \.id) { group in
                        Text(group.groupName.uppercased())
                            .font(.Tokens.micro)
                            .tracking(0.9)
                            .foregroundStyle(ColorTokens.text3)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.top, Spacing.sm)
                            .padding(.bottom, Spacing.baselinePair)

                        ForEach(group.sortedExercises, id: \.id) { exercise in
                            HStack {
                                Text(exercise.exerciseName)
                                    .font(.Tokens.body)
                                    .foregroundStyle(ColorTokens.text1)
                                Spacer()
                                Text(setSummary(exercise))
                                    .font(.Tokens.label)
                                    .foregroundStyle(ColorTokens.text2)
                                    .monospacedDigit()
                            }
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, Spacing.xs)
                        }
                    }

                    // Notes
                    if let notes = template.notes, !notes.isEmpty {
                        Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
                            .padding(.top, Spacing.xs)

                        Text(notes)
                            .font(.Tokens.label)
                            .foregroundStyle(ColorTokens.text2)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.top, Spacing.xs)
                            .padding(.bottom, Spacing.sm)
                    }
                }
            }
            .background(ColorTokens.background)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.cancel") { dismiss() }
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text2)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("action.editTemplate") {
                        Haptics.tap()
                        onEdit()
                        dismiss()
                    }
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text1)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Weekday Row

    private func weekdayRow(scheduledDays: [Int]) -> some View {
        let days = ["M", "T", "W", "T", "F", "S", "S"]
        return HStack(spacing: Spacing.xs) {
            ForEach(Array(days.enumerated()), id: \.offset) { index, initial in
                let isoDay = index + 1
                Text(initial)
                    .font(.Tokens.label)
                    .foregroundStyle(scheduledDays.contains(isoDay)
                        ? ColorTokens.text1
                        : ColorTokens.text3)
            }
        }
    }

    // MARK: - Set Summary

    private func setSummary(_ exercise: TemplateExercise) -> String {
        let sets = exercise.sortedSets.filter { !$0.isWarmup }
        guard !sets.isEmpty else { return "\(exercise.sets.count) sets" }
        if let reps = sets.first?.targetReps, let weight = sets.first?.targetWeightKg {
            return "\(sets.count) x \(reps) @ \(Int(weight))kg"
        } else if let reps = sets.first?.targetReps {
            return "\(sets.count) x \(reps)"
        }
        return "\(sets.count) sets"
    }
}
