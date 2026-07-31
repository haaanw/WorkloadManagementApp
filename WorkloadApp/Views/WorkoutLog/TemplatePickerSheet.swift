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
            VStack(spacing: 0) {
            InstrumentSheetHeader(title: "nav.templates") {
                SheetHeaderButton(title: "action.cancel") { dismiss() }
            }
            ScrollView {
                VStack(spacing: 0) {
                    if templates.isEmpty {
                        emptyState
                    } else {
                        templateGrid
                    }

                    // Start blank workout button (always visible)
                    Button {
                        Haptics.tap()
                        dismiss()
                        onStartBlank()
                    } label: {
                        Text("action.startBlankWorkout")
                            .font(.Tokens.body)
                            .foregroundStyle(ColorTokens.text2)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.sm)
                    }
                    .buttonStyle(.pressable)
                    .accessibilityIdentifier("templatePicker.startBlank")
                    .padding(.horizontal, Spacing.sm)
                    .padding(.top, Spacing.sm)
                }
            }
            .background(ColorTokens.surfaceEl)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Spacing.sm) {
            Text("empty.noTemplates")
                .font(.Tokens.sectionHead)
                .foregroundStyle(ColorTokens.text1)
            Text("empty.noTemplates.hint")
                .font(.Tokens.body)
                .foregroundStyle(ColorTokens.text2)
                .multilineTextAlignment(.center)
            Button {
                Haptics.tap()
                dismiss()
                onCreateTemplate()
            } label: {
                Text("action.createTemplate")
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text1)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.xs)
                    .overlay(Capsule().stroke(ColorTokens.divider, lineWidth: 0.5))
            }
            .buttonStyle(.pressable)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.md)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Template Grid

    private var templateGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: Spacing.sm), GridItem(.flexible(), spacing: Spacing.sm)], spacing: Spacing.sm) {
            ForEach(templates, id: \.id) { template in
                templateCard(template)
                    .accessibilityIdentifier("templatePicker.template")
            }
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.top, Spacing.sm)
    }

    // MARK: - Template Card

    private func templateCard(_ template: WorkoutTemplate) -> some View {
        let exercises = template.sortedGroups.flatMap { $0.sortedExercises }
        let lastUsedText: String? = template.lastUsedAt.map {
            $0.formatted(.relative(presentation: .named))
        }

        return Button {
            Haptics.select()
            dismiss()
            onSelectTemplate(template)
        } label: {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Image(systemName: template.sportType.systemImage)
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text2)

                Text(template.templateName)
                    .font(.Tokens.body)
                    .foregroundStyle(ColorTokens.text1)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                // A count and a timestamp — marginalia, so the annotation voice (v6).
                AnnotationLabel(
                    String(format: String(localized: "template.exerciseCount", defaultValue: "%d exercises"), exercises.count),
                    color: ColorTokens.text2
                )

                if let lastUsed = lastUsedText {
                    AnnotationLabel(lastUsed, color: ColorTokens.text2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.sm)
            .background(ColorTokens.surface, in: RoundedRectangle(cornerRadius: CornerTokens.card))
            .overlay(RoundedRectangle(cornerRadius: CornerTokens.card).stroke(ColorTokens.divider, lineWidth: 0.5))
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("\(template.templateName), \(exercises.count) exercises\(lastUsedText.map { ", last used \($0)" } ?? "")")
    }
}
