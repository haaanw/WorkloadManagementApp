import SwiftUI
import SwiftData

/// Optional, low-friction capture sheet for a localized **niggle** self-log (Phase 25).
///
/// This is a personal soreness/niggle log that gives load-tolerance context only — it makes no
/// medical claims. The sheet is intentionally separate from the daily `MorningCheckInSheet`
/// ritual (D-09) and is reached only on demand (Dashboard affordance, D-07) or via a
/// non-blocking post-workout nudge (D-08).
///
/// Region is picked at the coarse 7-region `MuscleRegion` granularity but stored as the
/// matching `MuscleGroup` alias rawValue (the 7 coarse cases round-trip by shared rawValue),
/// so Phase 27 can fuse the log per-muscle against the muscle taxonomy. The row is written
/// through the local-only `SorenessLogRepository` — it never syncs.
///
/// DESIGN contract: corners via `CornerTokens` (v3 Corner Law), no shadows, 8pt grid, `Font.Tokens.*` +
/// `ColorTokens.*`, and the limited-training Toggle uses the neutral design toggle style.
struct NiggleLogSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var athletes: [Athlete]

    @State private var selectedRegion: MuscleRegion = .legs
    @State private var selectedType: NiggleType = .soreness
    @State private var severity: Int = 3
    @State private var limitedTraining = false
    @State private var note = ""

    private var athlete: Athlete? { athletes.first }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    Text("niggle.heading")
                        .font(.Tokens.sectionHead)
                        .foregroundStyle(ColorTokens.text1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.md)

                    divider

                    // Region (coarse 7-region picker, stored as MuscleGroup alias)
                    regionRow

                    divider

                    // Type (DESIGN-compliant segmented control over NiggleType)
                    typeRow

                    divider

                    // Severity 0–10 (Rectangle segment bar)
                    severityRow

                    divider

                    // Limited training? (DesignToggleStyle — never Apple green)
                    limitedTrainingRow

                    divider

                    // Note (optional)
                    TextField("niggle.field.note.placeholder", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                        .textFieldStyle(SharpTextFieldStyle())
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.sm)

                    divider
                }
            }
            .background(ColorTokens.background)
            .navigationTitle("niggle.nav.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.cancel") { dismiss() }
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text2)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("action.save") { save() }
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text1)
                }
            }
            .onAppear { Haptics.prepare() }
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(ColorTokens.divider)
            .frame(height: 0.5)
    }

    // MARK: - Region

    private var regionRow: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("niggle.field.region")
                .font(.Tokens.body)
                .foregroundStyle(ColorTokens.text1)

            Menu {
                ForEach(MuscleRegion.allCases) { region in
                    Button {
                        if selectedRegion != region {
                            Haptics.select()
                            selectedRegion = region
                        }
                    } label: {
                        Label(region.displayName, systemImage: region.systemImage)
                    }
                }
            } label: {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: selectedRegion.systemImage)
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text2)
                    Text(selectedRegion.displayName)
                        .font(.Tokens.body)
                        .foregroundStyle(ColorTokens.text1)
                    Spacer()
                    MenuChevron()
                }
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(ColorTokens.surface, in: RoundedRectangle(cornerRadius: CornerTokens.control))
                .overlay(RoundedRectangle(cornerRadius: CornerTokens.control).stroke(ColorTokens.divider, lineWidth: 0.5))
            }
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.sm)
    }

    // MARK: - Type

    private var typeRow: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("niggle.field.type")
                .font(.Tokens.body)
                .foregroundStyle(ColorTokens.text1)

            HStack(spacing: 0) {
                ForEach(Array(NiggleType.allCases.enumerated()), id: \.element.id) { index, type in
                    Button {
                        if selectedType != type {
                            Haptics.select()
                            selectedType = type
                        }
                    } label: {
                        Text(type.displayName)
                            .font(selectedType == type ? .Tokens.labelMedium : .Tokens.label)
                            .foregroundStyle(selectedType == type ? ColorTokens.panelInk : ColorTokens.text2)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.sm)
                            .background(selectedType == type ? ColorTokens.text1 : ColorTokens.surface)
                    }
                    .buttonStyle(.plain)

                    if index < NiggleType.allCases.count - 1 {
                        Rectangle()
                            .fill(ColorTokens.divider)
                            .frame(width: 0.5)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: CornerTokens.control))
            .overlay(RoundedRectangle(cornerRadius: CornerTokens.control).stroke(ColorTokens.divider, lineWidth: 0.5))
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.sm)
    }

    // MARK: - Severity 0–10

    private var severityRow: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("niggle.field.severity")
                        .font(.Tokens.body)
                        .foregroundStyle(ColorTokens.text1)
                    Text("niggle.field.severity.hint")
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text2)
                }
                Spacer()
                Text("\(severity)/10")
                    .font(.Tokens.sectionHead)
                    .monospacedDigit()
                    .foregroundStyle(severityColor)
            }

            HStack(spacing: 4) {
                ForEach(0...10, id: \.self) { i in
                    Button {
                        if severity != i {
                            Haptics.select()
                            severity = i
                        }
                    } label: {
                        Rectangle()
                            .fill(i <= severity ? severityColor : ColorTokens.divider)
                            .frame(height: 4)
                    }
                    .buttonStyle(.pressable)
                }
            }

            HStack {
                Text("niggle.scale.severity.low")
                Spacer()
                Text("niggle.scale.severity.high")
            }
            .font(.Tokens.micro)
            .foregroundStyle(ColorTokens.text3)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.sm)
    }

    private var severityColor: Color {
        switch severity {
        case 0...3: ColorTokens.zoneOptimal
        case 4...6: ColorTokens.zoneCaution
        default:    ColorTokens.zoneDanger
        }
    }

    // MARK: - Limited training

    private var limitedTrainingRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("niggle.field.limitedTraining")
                    .font(.Tokens.body)
                    .foregroundStyle(ColorTokens.text1)
                Text("niggle.field.limitedTraining.subtitle")
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text2)
            }
            Spacer()
            Toggle("", isOn: $limitedTraining)
                .labelsHidden()
                .toggleStyle(.design)
                .onChange(of: limitedTraining) { _, _ in Haptics.tap() }
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.sm)
    }

    // MARK: - Save

    private func save() {
        let region = MuscleGroup(rawValue: selectedRegion.rawValue) ?? .fullBody
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let repo = SorenessLogRepository(modelContext: modelContext)
        repo.insert(
            region: region,
            type: selectedType,
            severity: severity,
            limitedTraining: limitedTraining,
            note: trimmed.isEmpty ? nil : trimmed,
            athlete: athlete
        )
        Haptics.success()
        dismiss()
    }
}
