import SwiftUI
import SwiftData

struct TemplateListView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.modelContext) private var modelContext
    @Query private var athletes: [Athlete]
    @State private var showEditor = false
    @State private var selectedTemplate: WorkoutTemplate?
    @State private var showProgramImport = false

    private var coachId: UUID? { athletes.first?.id }

    private var templates: [WorkoutTemplate] {
        guard let coachId else { return [] }
        return ((try? modelContext.fetch(
            FetchDescriptor<WorkoutTemplate>(
                predicate: #Predicate { $0.coachId == coachId },
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
        )) ?? [])
        // Program-day templates are the active block's working storage (v1.7.3
        // feature 6) — they live on the program screen, never in this list.
        .filter { !$0.isProgramDay }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if templates.isEmpty {
                    // Import-first empty state (R6): the spine is "bring YOUR plan";
                    // authoring a template is the quiet path below.
                    VStack(spacing: 8) {
                        Text("empty.noTemplates")
                            .font(.Tokens.body)
                            .foregroundStyle(ColorTokens.text2)
                        Text("template.empty.importFirst")
                            .font(.Tokens.label)
                            .foregroundStyle(ColorTokens.text3)
                            .multilineTextAlignment(.center)
                        Button {
                            Haptics.tap()
                            showProgramImport = true
                        } label: {
                            Text("workoutLog.menu.bringProgram")
                                .font(.Tokens.label)
                                .foregroundStyle(ColorTokens.text1)
                                .padding(.horizontal, Spacing.md)
                                .padding(.vertical, Spacing.xs)
                                .overlay(Capsule().stroke(ColorTokens.divider, lineWidth: 0.5))
                        }
                        .buttonStyle(.pressable)
                    }
                    .padding(.vertical, 48)
                    .frame(maxWidth: .infinity)
                } else {
                    ForEach(templates, id: \.id) { template in
                        Button {
                            Haptics.tap()
                            selectedTemplate = template
                            showEditor = true
                        } label: {
                            templateRow(template)
                        }
                        .buttonStyle(.pressable(scale: 1, opacity: 0.6))
                        Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
                    }
                }

                // U8 · authoring, DEMOTED not deleted. This is where the "Create template"
                // key went when it left the Log header and the Log empty-state hero: the LAST
                // row of the screen that already lists what the athlete owns. Templates remain
                // the storage format a parsed program resolves into, so the surface has to
                // exist — it just stops being sold ahead of the program.
                Button {
                    Haptics.tap()
                    selectedTemplate = nil
                    showEditor = true
                } label: {
                    Label("template.nav.newTemplate", systemImage: "plus")
                        .font(.Tokens.body)
                        .foregroundStyle(ColorTokens.text2)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.pressable(scale: 1, opacity: 0.6))
                .background(ColorTokens.surface)
                .accessibilityIdentifier("templates.newTemplate")

                Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
            }
        }
        .background(ColorTokens.background)
        .navigationTitle("nav.templates")
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
        .sheet(isPresented: $showProgramImport) {
            ProgramImportSheet()
                .environment(container)
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
        .padding(.vertical, Spacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ColorTokens.surface)
    }
}
