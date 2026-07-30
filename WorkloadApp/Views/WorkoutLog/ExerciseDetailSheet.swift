import SwiftUI

/// Read-only movement detail presented from the picker's info affordance:
/// metadata (target / secondary muscles / equipment / category) plus numbered
/// step-by-step instructions from the bundled catalog when the name resolves
/// to a catalog record. Custom / legacy entries without catalog data show the
/// metadata only. The Select CTA picks the exercise and dismisses both sheets.
struct ExerciseDetailSheet: View {
    @Environment(\.dismiss) private var dismiss

    /// The definition as displayed in the picker — overrides already applied.
    let exercise: ExerciseDefinition
    /// Selects the exercise; the presenting picker dismisses both sheets.
    let onSelect: () -> Void

    /// Catalog record for instructions/secondary muscles (case-insensitive
    /// name lookup — nil for custom or legacy-only names).
    private var catalogEntry: CatalogExercise? {
        ExerciseCatalogStore.entry(named: exercise.name)
    }

    private var targetText: String? {
        guard let muscle = exercise.muscleGroup else { return nil }
        let regionName = muscle.region.displayName
        return muscle.displayName == regionName
            ? muscle.displayName
            : "\(muscle.displayName) · \(regionName)"
    }

    private var secondaryText: String? {
        guard let entry = catalogEntry, !entry.secondaryMuscles.isEmpty else { return nil }
        return entry.secondaryMuscles.map(\.capitalized).joined(separator: ", ")
    }

    private var equipmentText: String? {
        (exercise.equipment ?? catalogEntry?.equipment)?.capitalized
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        Text(exercise.name)
                            .font(.Tokens.pageTitle)
                            .foregroundStyle(ColorTokens.text1)
                            .fixedSize(horizontal: false, vertical: true)

                        metadataPlate

                        if let steps = catalogEntry?.localizedSteps(), !steps.isEmpty {
                            VStack(alignment: .leading, spacing: Spacing.sm) {
                                Text("exercise.detail.instructions")
                                    .font(.Tokens.sectionHead)
                                    .foregroundStyle(ColorTokens.text1)
                                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                                    stepRow(number: index + 1, text: step)
                                }
                            }
                        }
                    }
                    .padding(Spacing.sm)
                }
                BottomActionDock {
                    PrimaryActionButton(title: "exercise.detail.select") {
                        onSelect()
                    }
                }
            }
            .background(ColorTokens.background)
            .navigationTitle("exercise.nav.detail")
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

    private var metadataPlate: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if let targetText {
                metadataRow(String(localized: "exercise.detail.target"), targetText)
            }
            if let secondaryText {
                metadataRow(String(localized: "exercise.detail.secondaryMuscles"), secondaryText)
            }
            if let equipmentText {
                metadataRow(String(localized: "exercise.detail.equipment"), equipmentText)
            }
            metadataRow(String(localized: "exercise.detail.category"), exercise.category.displayName)
        }
        .dataPlate()
    }

    /// Annotation caption + working-voice value pair (v6): the caption is a machine key, so it
    /// renders through `AnnotationLabel`; `baselinePair` is the sanctioned 4pt label→value gap.
    /// The caption is resolved with `String(localized:)` because the primitive takes a `String`.
    private func metadataRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.baselinePair) {
            AnnotationLabel(label)
            Text(value)
                .font(.Tokens.body)
                .foregroundStyle(ColorTokens.text1)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func stepRow(number: Int, text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
            // Step ordinal — a machine index, so annotation (v6).
            AnnotationLabel("\(number)")
                .frame(width: Spacing.md, alignment: .trailing)
            Text(text)
                .font(.Tokens.body)
                .foregroundStyle(ColorTokens.text1)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
