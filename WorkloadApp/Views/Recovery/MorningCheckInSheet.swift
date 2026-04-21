import SwiftUI
import SwiftData

struct MorningCheckInSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppContainer.self) private var container
    @Query private var athletes: [Athlete]
    @State private var sleepQuality = 3
    @State private var soreness = 3
    @State private var energy = 3
    @State private var stress = 3
    @State private var notes = ""
    @State private var selectedTags: Set<String> = []
    @State private var showingTagManagement = false
    @State private var customTagNames: [String] = []

    private let defaultTags = ["Caffeine", "Alcohol", "Travel", "Stress"]

    private var athlete: Athlete? { athletes.first }
    var onSaved: (() -> Void)?

    private var wellnessScore: Double {
        Double(sleepQuality + soreness + energy + stress) / 20.0 * 100.0
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    Text("How are you feeling this morning?")
                        .font(.Tokens.sectionHead)
                        .foregroundStyle(ColorTokens.text1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 24)

                    Rectangle()
                        .fill(ColorTokens.divider)
                        .frame(height: 0.5)

                    WellnessSlider(
                        title: "Sleep Quality",
                        subtitle: "How well did you sleep?",
                        value: $sleepQuality,
                        lowLabel: "Terrible",
                        highLabel: "Great"
                    )

                    Rectangle()
                        .fill(ColorTokens.divider)
                        .frame(height: 0.5)

                    WellnessSlider(
                        title: "Muscle Soreness",
                        subtitle: "How sore are you?",
                        value: $soreness,
                        lowLabel: "Very Sore",
                        highLabel: "Fresh"
                    )

                    Rectangle()
                        .fill(ColorTokens.divider)
                        .frame(height: 0.5)

                    WellnessSlider(
                        title: "Energy / Mood",
                        subtitle: "How's your energy level?",
                        value: $energy,
                        lowLabel: "Exhausted",
                        highLabel: "Energized"
                    )

                    Rectangle()
                        .fill(ColorTokens.divider)
                        .frame(height: 0.5)

                    WellnessSlider(
                        title: "Stress Level",
                        subtitle: "How stressed are you?",
                        value: $stress,
                        lowLabel: "Very Stressed",
                        highLabel: "Relaxed"
                    )

                    Rectangle()
                        .fill(ColorTokens.divider)
                        .frame(height: 0.5)

                    // BEHAVIORS section (D-03, D-04)
                    VStack(alignment: .leading, spacing: 16) {
                        Text("BEHAVIORS")
                            .font(.Tokens.micro)
                            .tracking(1.2)
                            .textCase(.uppercase)
                            .foregroundStyle(ColorTokens.text3)

                        FlowLayout(spacing: 8) {
                            ForEach(defaultTags, id: \.self) { tag in
                                BehaviorTagChip(
                                    label: tag,
                                    isSelected: selectedTags.contains(tag),
                                    action: { toggleTag(tag) }
                                )
                            }

                            // Custom tags (Pro only, D-05)
                            ForEach(customTagNames, id: \.self) { tag in
                                BehaviorTagChip(
                                    label: tag,
                                    isSelected: selectedTags.contains(tag),
                                    action: { toggleTag(tag) }
                                )
                            }
                        }

                        // Manage Tags button (Pro only, D-05)
                        if container.subscriptionService.isPro {
                            Button {
                                showingTagManagement = true
                            } label: {
                                Text("Manage Tags")
                                    .font(.Tokens.label)
                                    .foregroundStyle(ColorTokens.text2)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)

                    Rectangle()
                        .fill(ColorTokens.divider)
                        .frame(height: 0.5)

                    // Notes field
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                        .font(.Tokens.body)
                        .foregroundStyle(ColorTokens.text1)
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)

                    Rectangle()
                        .fill(ColorTokens.divider)
                        .frame(height: 0.5)

                    // Score preview
                    HStack {
                        Text("WELLNESS SCORE")
                            .font(.Tokens.micro)
                            .tracking(1.2)
                            .foregroundStyle(ColorTokens.text3)
                        Spacer()
                        Text("\(Int(wellnessScore))/100")
                            .font(.Tokens.sectionHead)
                            .monospacedDigit()
                            .foregroundStyle(wellnessScoreColor)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
            }
            .background(ColorTokens.background)
            .navigationTitle("Morning Check-in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text2)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text1)
                }
            }
        }
        .task {
            if let athlete = athlete {
                let repo = BehaviorTagRepository(modelContext: modelContext)
                customTagNames = (try? repo.fetchCustomTagNames(for: athlete)) ?? []
            }
        }
        .sheet(isPresented: $showingTagManagement) {
            CustomTagManagementSheet(
                customTagNames: $customTagNames,
                athlete: athlete,
                modelContext: modelContext
            )
        }
    }

    private var wellnessScoreColor: Color {
        wellnessScore >= 67 ? ColorTokens.zoneOptimal : wellnessScore >= 34 ? ColorTokens.zoneCaution : ColorTokens.zoneDanger
    }

    private func save() {
        let checkIn = WellnessCheckIn(
            date: .now,
            sleepQuality: sleepQuality,
            soreness: soreness,
            energy: energy,
            stress: stress,
            notes: notes.isEmpty ? nil : notes
        )
        checkIn.athlete = athlete
        modelContext.insert(checkIn)

        // Create behavior tags for all available tags (D-04, D-06)
        let allTagNames = defaultTags + customTagNames
        for tagName in allTagNames {
            let tag = BehaviorTag(
                date: .now,
                tagName: tagName,
                isActive: selectedTags.contains(tagName),
                isCustom: !defaultTags.contains(tagName)
            )
            tag.wellnessCheckIn = checkIn
            tag.athlete = athlete
            modelContext.insert(tag)
        }

        try? modelContext.save()
        onSaved?()
        dismiss()
    }

    private func toggleTag(_ tag: String) {
        if selectedTags.contains(tag) {
            selectedTags.remove(tag)
        } else {
            selectedTags.insert(tag)
        }
    }
}

struct WellnessSlider: View {
    let title: String
    let subtitle: String
    @Binding var value: Int
    let lowLabel: String
    let highLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.Tokens.body)
                        .foregroundStyle(ColorTokens.text1)
                    Text(subtitle)
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text2)
                }
                Spacer()
                Text("\(value)/5")
                    .font(.Tokens.sectionHead)
                    .monospacedDigit()
                    .foregroundStyle(scoreColor)
            }

            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { i in
                    Button {
                        value = i
                    } label: {
                        Rectangle()
                            .fill(i <= value ? scoreColor : ColorTokens.divider)
                            .frame(height: 4)
                            .overlay(alignment: .center) {
                                Text("\(i)")
                                    .font(.Tokens.micro)
                                    .foregroundStyle(i <= value ? ColorTokens.background : ColorTokens.text3)
                                    .opacity(0) // hidden — bar is the indicator
                            }
                    }
                }
            }

            HStack {
                Text(lowLabel)
                Spacer()
                Text(highLabel)
            }
            .font(.Tokens.micro)
            .foregroundStyle(ColorTokens.text3)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(ColorTokens.surface)
    }

    private var scoreColor: Color {
        switch value {
        case 1...2: ColorTokens.zoneDanger
        case 3:     ColorTokens.zoneCaution
        case 4...5: ColorTokens.zoneOptimal
        default:    ColorTokens.text3
        }
    }
}

// MARK: - FlowLayout (file-private, single-use for tag chips)

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: ProposedViewSize(width: bounds.width, height: bounds.height), subviews: subviews)
        for (index, subview) in subviews.enumerated() {
            subview.place(
                at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: y + rowHeight), positions)
    }
}

// MARK: - Custom Tag Management (D-05, Pro-gated)

private struct CustomTagManagementSheet: View {
    @Binding var customTagNames: [String]
    let athlete: Athlete?
    let modelContext: ModelContext
    @State private var newTagName = ""
    @Environment(\.dismiss) private var dismiss

    private let maxCustomTags = 8
    private let maxTagLength = 20

    var body: some View {
        NavigationStack {
            List {
                ForEach(customTagNames, id: \.self) { tag in
                    Text(tag)
                        .font(.Tokens.body)
                        .foregroundStyle(ColorTokens.text1)
                }
                .onDelete(perform: deleteTag)

                if customTagNames.count < maxCustomTags {
                    HStack {
                        TextField("Tag name", text: $newTagName)
                            .font(.Tokens.body)
                            .onChange(of: newTagName) { _, new in
                                if new.count > maxTagLength {
                                    newTagName = String(new.prefix(maxTagLength))
                                }
                            }
                        Button("Add") { addTag() }
                            .font(.Tokens.label)
                            .disabled(newTagName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } else {
                    Text("Maximum \(maxCustomTags) custom tags")
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text2)
                }
            }
            .navigationTitle("Manage Tags")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(.Tokens.label)
                }
            }
        }
    }

    private func addTag() {
        let trimmed = newTagName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !customTagNames.contains(trimmed) else { return }
        customTagNames.append(trimmed)
        newTagName = ""
    }

    private func deleteTag(at offsets: IndexSet) {
        guard let athlete = athlete else { return }
        let repo = BehaviorTagRepository(modelContext: modelContext)
        for index in offsets {
            let tagName = customTagNames[index]
            try? repo.deleteCustomTag(named: tagName, for: athlete)
        }
        customTagNames.remove(atOffsets: offsets)
    }
}
