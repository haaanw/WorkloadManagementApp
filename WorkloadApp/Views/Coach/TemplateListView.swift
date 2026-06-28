import SwiftUI
import SwiftData

struct TemplateListView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.modelContext) private var modelContext
    @Query private var athletes: [Athlete]
    @State private var showEditor = false
    @State private var selectedTemplate: WorkoutTemplate?

    private var coachId: UUID? { athletes.first?.id }

    private var templates: [WorkoutTemplate] {
        guard let coachId else { return [] }
        return (try? modelContext.fetch(
            FetchDescriptor<WorkoutTemplate>(
                predicate: #Predicate { $0.coachId == coachId },
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
        )) ?? []
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if templates.isEmpty {
                    VStack(spacing: 8) {
                        Text("coach.template.empty.title")
                            .font(.Tokens.body)
                            .foregroundStyle(ColorTokens.text2)
                        Text("coach.template.empty.subtitle")
                            .font(.Tokens.label)
                            .foregroundStyle(ColorTokens.text3)
                    }
                    .padding(.vertical, 48)
                    .frame(maxWidth: .infinity)
                } else {
                    ForEach(templates, id: \.id) { template in
                        Button {
                            selectedTemplate = template
                            showEditor = true
                        } label: {
                            templateRow(template)
                        }
                        Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
                    }
                }

                Button {
                    selectedTemplate = nil
                    showEditor = true
                } label: {
                    Label("action.newTemplate", systemImage: "plus")
                        .font(.Tokens.body)
                        .foregroundStyle(ColorTokens.text1)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .background(ColorTokens.surface)

                Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
            }
        }
        .background(ColorTokens.background)
        .navigationTitle("Templates")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showEditor) {
            if let coachId {
                TemplateEditorSheet(
                    coachId: coachId,
                    existingTemplate: selectedTemplate
                )
                .environment(container)
            }
        }
    }

    private func templateRow(_ template: WorkoutTemplate) -> some View {
        VStack(alignment: .leading, spacing: Spacing.baselinePair) {
            HStack {
                Text(template.templateName)
                    .font(.Tokens.sectionHead)
                    .foregroundStyle(ColorTokens.text1)
                Spacer()
                Text(template.sessionType.displayName)
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text3)
            }

            let exerciseCount = template.groups.flatMap(\.exercises).count
            let groupCount = template.groups.count
            Text("\(groupCount) group\(groupCount == 1 ? "" : "s"), \(exerciseCount) exercise\(exerciseCount == 1 ? "" : "s")")
                .font(.Tokens.label)
                .foregroundStyle(ColorTokens.text2)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ColorTokens.surface)
    }
}
