import SwiftUI
import SwiftData

/// Full preview of a shared template with Import Template CTA.
/// Shows template name, sport/session type, scheduled days, exercise groups,
/// and a sticky import button that creates a deep copy with weights stripped.
struct ShareImportPreviewSheet: View {
    let response: SharedTemplateResponse
    @Environment(AppContainer.self) private var container
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var athletes: [Athlete]

    @State private var isImporting = false
    @State private var importError: String?

    private var athlete: Athlete? { athletes.first }
    private var payload: TemplateSharePayload { response.payload }

    /// Decode groups from JSON for preview display (weights stripped to protect sharer privacy)
    private var previewGroups: [ExerciseGroup] {
        guard let json = payload.groups_json else { return [] }
        let groups = SyncService.decodeGroups(from: json)
        for group in groups {
            for exercise in group.exercises {
                for set in exercise.sets {
                    set.targetWeightKg = nil
                }
            }
        }
        return groups
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Banner
                        Text("template.label.shared")
                            .font(.Tokens.smallLabel)
                            .tracking(1.2)
                            .foregroundStyle(ColorTokens.text3)
                            .padding(.horizontal, 16)
                            .padding(.top, 16)

                        // Template name
                        Text(payload.template_name)
                            .font(.Tokens.sectionHead)
                            .foregroundStyle(ColorTokens.text1)
                            .padding(.horizontal, 16)
                            .padding(.top, 8)

                        // Sport + session type
                        if let sport = SportType(rawValue: payload.sport_type),
                           let session = SessionType(rawValue: payload.session_type) {
                            Text("\(sport.displayName) - \(session.displayName)")
                                .font(.Tokens.label)
                                .foregroundStyle(ColorTokens.text2)
                                .padding(.horizontal, 16)
                                .padding(.top, 8)
                        }

                        // Weekday row
                        weekdayRow(scheduledDays: payload.scheduled_days)
                            .padding(.horizontal, 16)
                            .padding(.top, 16)

                        // Divider
                        Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
                            .padding(.top, 16)

                        // Exercise groups
                        ForEach(previewGroups.sorted(by: { $0.orderIndex < $1.orderIndex }), id: \.id) { group in
                            Text(group.groupName.uppercased())
                                .font(.Tokens.smallLabel)
                                .tracking(1.2)
                                .foregroundStyle(ColorTokens.text3)
                                .padding(.horizontal, 16)
                                .padding(.top, 16)
                                .padding(.bottom, 8)

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
                        if let notes = payload.notes, !notes.isEmpty {
                            Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
                                .padding(.top, 16)
                            Text(notes)
                                .font(.Tokens.label)
                                .foregroundStyle(ColorTokens.text2)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                        }

                        // Bottom padding for sticky button
                        Spacer().frame(height: 80)
                    }
                }
                .background(ColorTokens.background)

                // Sticky Import button
                VStack(spacing: 0) {
                    Rectangle().fill(ColorTokens.divider).frame(height: 0.5)

                    if let importError {
                        Text(importError)
                            .font(.Tokens.smallLabel)
                            .foregroundStyle(ColorTokens.zoneDanger)
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                    }

                    Button {
                        Task { await importTemplate() }
                    } label: {
                        Group {
                            if isImporting {
                                ProgressView()
                                    .tint(ColorTokens.background)
                            } else {
                                Text("action.importTemplate")
                                    .font(.Tokens.bodyMedium)
                            }
                        }
                        .foregroundStyle(ColorTokens.background)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(ColorTokens.text1)
                    }
                    .disabled(isImporting)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
                .background(ColorTokens.background)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.close") { dismiss() }
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text2)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Helpers

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

    // MARK: - Import

    private func importTemplate() async {
        guard let athlete else {
            importError = String(localized: "share.error.import", defaultValue: "Could not import template. Try again.")
            return
        }
        isImporting = true
        importError = nil

        let _ = TemplateSharingService.importTemplate(
            from: response,
            forAthlete: athlete,
            context: modelContext
        )

        do {
            try modelContext.save()
        } catch {
            print("Import save error: \(error)")
            importError = String(localized: "share.error.import", defaultValue: "Could not import template. Try again.")
            isImporting = false
            return
        }

        isImporting = false
        dismiss()
    }
}
