import SwiftUI
import SwiftData

struct TemplatePickerSheet: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var athletes: [Athlete]

    let onSelectTemplate: (WorkoutTemplate) -> Void
    let onStartBlank: () -> Void
    let onCreateTemplate: () -> Void

    // MARK: - Template Fetching

    private var templates: [WorkoutTemplate] {
        guard let athleteId = athletes.first?.id else { return [] }
        return (try? TemplateRepository(modelContext: modelContext)
            .fetchAthleteTemplates(athleteId: athleteId)) ?? []
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    if templates.isEmpty {
                        emptyState
                    } else {
                        templateGrid
                    }

                    // Start blank workout button (always visible)
                    Button {
                        dismiss()
                        onStartBlank()
                    } label: {
                        Text("action.startBlankWorkout")
                            .font(.Tokens.body)
                            .foregroundStyle(ColorTokens.text2)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                }
            }
            .background(ColorTokens.surfaceEl)
            .navigationTitle("nav.templates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.cancel") { dismiss() }
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text2)
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Text("empty.noTemplates")
                .font(.Tokens.sectionHead)
                .foregroundStyle(ColorTokens.text1)
            Text("empty.noTemplates.hint")
                .font(.Tokens.body)
                .foregroundStyle(ColorTokens.text2)
                .multilineTextAlignment(.center)
            Button {
                dismiss()
                onCreateTemplate()
            } label: {
                Text("action.createTemplate")
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text1)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 8)
                    .overlay(Rectangle().stroke(ColorTokens.divider, lineWidth: 0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Template Grid

    private var templateGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
            ForEach(templates, id: \.id) { template in
                templateCard(template)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    // MARK: - Template Card

    private func templateCard(_ template: WorkoutTemplate) -> some View {
        let exercises = template.sortedGroups.flatMap { $0.sortedExercises }
        let lastUsedText: String? = template.lastUsedAt.map {
            $0.formatted(.relative(presentation: .named))
        }

        return Button {
            dismiss()
            onSelectTemplate(template)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: template.sportType.systemImage)
                    .font(.system(size: 15))
                    .foregroundStyle(ColorTokens.text2)

                Text(template.templateName)
                    .font(.Tokens.body)
                    .foregroundStyle(ColorTokens.text1)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(String(format: String(localized: "template.exerciseCount", defaultValue: "%d exercises"), exercises.count))
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text2)

                if let lastUsed = lastUsedText {
                    Text(lastUsed)
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(ColorTokens.surface)
            .overlay(Rectangle().stroke(ColorTokens.divider, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(template.templateName), \(exercises.count) exercises\(lastUsedText.map { ", last used \($0)" } ?? "")")
    }
}
