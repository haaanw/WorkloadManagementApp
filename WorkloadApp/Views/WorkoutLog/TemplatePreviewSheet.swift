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
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 4)

                    Text("\(template.sportType.displayName) - \(template.sessionType.displayName)")
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text2)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)

                    // Scheduled days
                    weekdayRow(scheduledDays: template.scheduledDays)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)

                    Rectangle().fill(ColorTokens.divider).frame(height: 0.5)

                    // Exercise list by group
                    ForEach(template.sortedGroups, id: \.id) { group in
                        Text(group.groupName.uppercased())
                            .font(.Tokens.micro)
                            .tracking(1.2)
                            .foregroundStyle(ColorTokens.text3)
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                            .padding(.bottom, 4)

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
                            .padding(.horizontal, 16)
                            .padding(.vertical, 4)
                        }
                    }

                    // Notes
                    if let notes = template.notes, !notes.isEmpty {
                        Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
                            .padding(.top, 8)

                        Text(notes)
                            .font(.Tokens.label)
                            .foregroundStyle(ColorTokens.text2)
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            .padding(.bottom, 16)
                    }
                }
            }
            .background(ColorTokens.background)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text2)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Edit Template") {
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
        return HStack(spacing: 8) {
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
