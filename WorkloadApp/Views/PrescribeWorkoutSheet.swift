import SwiftUI
import SwiftData

struct PrescribeWorkoutSheet: View {
    let athlete: Athlete
    let coachId: UUID

    @Environment(AppContainer.self) private var container
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTemplate: WorkoutTemplate?
    @State private var scheduledDate: Date = Calendar.current.startOfDay(for: .now)
    @State private var notes = ""
    @State private var showTemplatePicker = false

    private var templates: [WorkoutTemplate] {
        (try? modelContext.fetch(
            FetchDescriptor<WorkoutTemplate>(
                predicate: #Predicate { $0.coachId == coachId },
                sortBy: [SortDescriptor(\.templateName)]
            )
        )) ?? []
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Template selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("coach.prescribe.fieldTemplate")
                            .font(.Tokens.micro)
                            .tracking(0.9)
                            .foregroundStyle(ColorTokens.text3)

                        Button {
                            showTemplatePicker = true
                        } label: {
                            HStack {
                                Text(selectedTemplate?.templateName ?? String(localized: "coach.prescribe.selectTemplatePlaceholder", defaultValue: "Select a template"))
                                    .font(.Tokens.body)
                                    .foregroundStyle(
                                        selectedTemplate == nil ? ColorTokens.text3 : ColorTokens.text1
                                    )
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.Tokens.label)
                                    .foregroundStyle(ColorTokens.text3)
                            }
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, Spacing.sm)
                            .background(ColorTokens.surface)
                            .overlay(Rectangle().stroke(ColorTokens.divider, lineWidth: 0.5))
                        }
                    }
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.sm)

                    Rectangle().fill(ColorTokens.divider).frame(height: 0.5)

                    // Template preview
                    if let template = selectedTemplate {
                        templatePreview(template)
                        Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
                    }

                    // Date picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("coach.prescribe.fieldScheduledDate")
                            .font(.Tokens.micro)
                            .tracking(0.9)
                            .foregroundStyle(ColorTokens.text3)

                        DatePicker(
                            "",
                            selection: $scheduledDate,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                    }
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.sm)

                    Rectangle().fill(ColorTokens.divider).frame(height: 0.5)

                    // Notes
                    VStack(alignment: .leading, spacing: 8) {
                        Text("coach.prescribe.fieldNotes")
                            .font(.Tokens.micro)
                            .tracking(0.9)
                            .foregroundStyle(ColorTokens.text3)

                        TextField("coach.prescribe.notes.placeholder", text: $notes, axis: .vertical)
                            .font(.Tokens.label)
                            .foregroundStyle(ColorTokens.text2)
                            .textFieldStyle(SharpTextFieldStyle())
                            .lineLimit(2...4)
                    }
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.sm)
                }
            }
            .background(ColorTokens.background)
            .navigationTitle("coach.nav.prescribeWorkout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.cancel") { dismiss() }
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text2)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("coach.action.assign") { assign() }
                        .font(.Tokens.label)
                        .foregroundStyle(
                            selectedTemplate == nil ? ColorTokens.text3 : ColorTokens.text1
                        )
                        .disabled(selectedTemplate == nil)
                }
            }
            .sheet(isPresented: $showTemplatePicker) {
                templatePickerSheet
            }
        }
    }

    private func templatePreview(_ template: WorkoutTemplate) -> some View {
        VStack(alignment: .leading, spacing: 0) {
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
                            .font(.Tokens.label)
                            .foregroundStyle(ColorTokens.text1)
                        Spacer()
                        Text("\(exercise.sets.count) sets")
                            .font(.Tokens.label)
                            .foregroundStyle(ColorTokens.text3)
                    }
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.baselinePair)
                }
            }
            .padding(.bottom, 8)
        }
    }

    private var templatePickerSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(templates, id: \.id) { template in
                        Button {
                            selectedTemplate = template
                            showTemplatePicker = false
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: Spacing.baselinePair) {
                                    Text(template.templateName)
                                        .font(.Tokens.body)
                                        .foregroundStyle(ColorTokens.text1)
                                    let count = template.groups.flatMap(\.exercises).count
                                    Text("\(count) exercise\(count == 1 ? "" : "s")")
                                        .font(.Tokens.label)
                                        .foregroundStyle(ColorTokens.text3)
                                }
                                Spacer()
                                if selectedTemplate?.id == template.id {
                                    Image(systemName: "checkmark")
                                        .font(.Tokens.label)
                                        .foregroundStyle(ColorTokens.text1)
                                }
                            }
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, Spacing.sm)
                        }
                        Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
                    }

                    if templates.isEmpty {
                        Text("coach.prescribe.noTemplates")
                            .font(.Tokens.body)
                            .foregroundStyle(ColorTokens.text3)
                            .padding(.vertical, 48)
                    }
                }
            }
            .background(ColorTokens.background)
            .navigationTitle("template.nav.select")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.cancel") { showTemplatePicker = false }
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text2)
                }
            }
        }
    }

    private func assign() {
        guard let template = selectedTemplate else { return }

        let prescription = PrescribedWorkout(
            coachId: coachId,
            athleteId: athlete.id,
            templateId: template.id,
            scheduledDate: scheduledDate,
            templateName: template.templateName,
            sportType: template.sportType,
            sessionType: template.sessionType,
            notes: notes.isEmpty ? nil : notes
        )

        // Deep-copy groups from template
        prescription.groups = template.deepCopyGroups()

        modelContext.insert(prescription)
        try? modelContext.save()

        Task {
            await container.syncService.pushPrescribedWorkout(prescription)
        }

        dismiss()
    }
}
