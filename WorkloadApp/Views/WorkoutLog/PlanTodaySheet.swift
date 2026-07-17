import SwiftUI
import SwiftData

/// Designation chooser for "today's planned session" (PLAN-10). Offers two paths, each creating
/// a `PrescribedWorkout` for today via `PlannedSessionRepository`:
///   - Load a template — reuses the EXISTING `TemplatePickerSheet`; `planFromTemplate` (frozen copy).
///   - Enter a lift — opens `ManualLiftEntrySheet`; `planManualLift` (one-off, templateId nil).
/// No verdict, no adjusted numbers — those are Phases 43/44. DESIGN.md-compliant: corners via
/// `CornerTokens` (v3 Corner Law), no shadows, Font.Tokens, 8pt grid, NO accent.
struct PlanTodaySheet: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var athletes: [Athlete]

    @State private var showTemplatePicker = false
    @State private var showManual = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text("planToday.chooser.subtitle")
                        .font(.Tokens.body)
                        .foregroundStyle(ColorTokens.text2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, Spacing.sm)

                    chooserRow(
                        title: "planToday.chooser.loadTemplate.title",
                        subtitle: "planToday.chooser.loadTemplate.subtitle",
                        systemImage: "doc.text"
                    ) {
                        showTemplatePicker = true
                    }

                    chooserRow(
                        title: "planToday.chooser.manual.title",
                        subtitle: "planToday.chooser.manual.subtitle",
                        systemImage: "pencil.and.list.clipboard"
                    ) {
                        showManual = true
                    }
                }
                .padding(.vertical, Spacing.md)
            }
            .background(ColorTokens.background)
            .navigationTitle("planToday.chooser.navTitle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.cancel") { dismiss() }
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text2)
                }
            }
            .sheet(isPresented: $showTemplatePicker) {
                TemplatePickerSheet(
                    onSelectTemplate: { template in
                        planFromTemplate(template)
                    },
                    onStartBlank: {
                        // No blank "plan" — funnel to the manual one-off entry instead.
                        showManual = true
                    },
                    onCreateTemplate: {
                        // Template authoring lives elsewhere; just close the picker.
                    }
                )
                .environment(container)
            }
            .sheet(isPresented: $showManual) {
                ManualLiftEntrySheet(onPlanned: { dismiss() })
            }
        }
    }

    private func chooserRow(
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: { Haptics.tap(); action() }) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: systemImage)
                    .font(.Tokens.body)
                    .foregroundStyle(ColorTokens.text2)
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(title)
                        .font(.Tokens.body)
                        .foregroundStyle(ColorTokens.text1)
                    Text(subtitle)
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text2)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
            }
            .cardStyle()
        }
        .buttonStyle(.pressable)
        .padding(.horizontal, Spacing.sm)
    }

    private func planFromTemplate(_ template: WorkoutTemplate) {
        guard let athleteId = athletes.first?.id else { return }
        let repo = PlannedSessionRepository(modelContext: modelContext)
        repo.planFromTemplate(template, athleteId: athleteId)
        dismiss()
    }
}
