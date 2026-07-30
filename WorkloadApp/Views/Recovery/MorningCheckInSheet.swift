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
    @State private var isPrefilled = false
    @State private var didSeed = false
    @State private var seedSource: SeedSource? = nil

    private enum SeedSource { case today, prior }

    private let defaultTags = ["Caffeine", "Alcohol", "Travel", "Stress"]

    private var athlete: Athlete? { athletes.first }
    var onSaved: (() -> Void)?

    private var wellnessScore: Double {
        Double(sleepQuality + soreness + energy + stress) / 20.0 * 100.0
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                InstrumentSheetHeader(title: "morning.nav.title") {
                    SheetHeaderButton(title: "action.cancel") { dismiss() }
                } trailing: {
                    SheetHeaderButton(title: "action.save", emphasis: true, isDisabled: athlete == nil) { save() }
                }
                ScrollView {
                    VStack(spacing: 0) {
                        Text("morning.checkin.heading")
                        .font(.Tokens.sectionHead)
                        .foregroundStyle(ColorTokens.text1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 24)

                    if isPrefilled {
                        Text(seedSource == .today ? "morning.editing.today.hint" : "morning.prefill.hint")
                            .font(.Tokens.label)
                            .foregroundStyle(ColorTokens.text3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.bottom, Spacing.sm)
                    }

                    Rectangle()
                        .fill(ColorTokens.divider)
                        .frame(height: 0.5)

                    WellnessSlider(
                        title: String(localized: "morning.field.sleepQuality", defaultValue: "Sleep Quality"),
                        subtitle: String(localized: "morning.field.sleepQuality.subtitle", defaultValue: "How well did you sleep?"),
                        value: $sleepQuality,
                        lowLabel: String(localized: "morning.scale.sleep.low", defaultValue: "Terrible"),
                        highLabel: String(localized: "morning.scale.sleep.high", defaultValue: "Great")
                    )

                    Rectangle()
                        .fill(ColorTokens.divider)
                        .frame(height: 0.5)

                    WellnessSlider(
                        title: String(localized: "morning.field.soreness", defaultValue: "Muscle Soreness"),
                        subtitle: String(localized: "morning.field.soreness.subtitle", defaultValue: "How sore are you?"),
                        value: $soreness,
                        lowLabel: String(localized: "morning.scale.soreness.low", defaultValue: "Very Sore"),
                        highLabel: String(localized: "morning.scale.soreness.high", defaultValue: "Fresh")
                    )

                    Rectangle()
                        .fill(ColorTokens.divider)
                        .frame(height: 0.5)

                    WellnessSlider(
                        title: String(localized: "morning.field.energy", defaultValue: "Energy / Mood"),
                        subtitle: String(localized: "morning.field.energy.subtitle", defaultValue: "How's your energy level?"),
                        value: $energy,
                        lowLabel: String(localized: "morning.scale.energy.low", defaultValue: "Exhausted"),
                        highLabel: String(localized: "morning.scale.energy.high", defaultValue: "Energized")
                    )

                    Rectangle()
                        .fill(ColorTokens.divider)
                        .frame(height: 0.5)

                    WellnessSlider(
                        title: String(localized: "morning.field.stress", defaultValue: "Stress Level"),
                        subtitle: String(localized: "morning.field.stress.subtitle", defaultValue: "How stressed are you?"),
                        value: $stress,
                        lowLabel: String(localized: "morning.scale.stress.low", defaultValue: "Very Stressed"),
                        highLabel: String(localized: "morning.scale.stress.high", defaultValue: "Relaxed")
                    )

                    Rectangle()
                        .fill(ColorTokens.divider)
                        .frame(height: 0.5)

                    // BEHAVIORS section (D-03, D-04)
                    VStack(alignment: .leading, spacing: 16) {
                        Text("morning.section.behaviors")
                            .font(.Tokens.sectionHead)
                            .foregroundStyle(ColorTokens.text1)

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
                                Text("morning.action.manageTags")
                                    .font(.Tokens.label)
                                    .foregroundStyle(ColorTokens.text2)
                            }
                            .buttonStyle(.pressable)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)

                    Rectangle()
                        .fill(ColorTokens.divider)
                        .frame(height: 0.5)

                    // Notes field — machined field: grows a debossed focus well (v4.2).
                    FormField(
                        placeholder: "morning.field.notes.placeholder",
                        text: $notes,
                        axis: .vertical,
                        alignment: .leading,
                        lineLimit: 3...6
                    )
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.sm)

                    Rectangle()
                        .fill(ColorTokens.divider)
                        .frame(height: 0.5)

                    // Score preview
                    HStack {
                        Text("morning.section.wellnessScore")
                            .font(.Tokens.sectionHead)
                            .foregroundStyle(ColorTokens.text1)
                        Spacer()
                        // v6 contrast rule: zone-colored text below 24pt may sit only on a CARD
                        // plane, and a ReadoutWell is a DEBOSSED well (v6's re-tuned
                        // `zone-optimal` measures 4.01:1 there — below the 4.5:1 small-text
                        // floor). This preview also carried its state by COLOR ALONE, with no
                        // zone label anywhere near it, which the nocebo guard forbids. Inking
                        // the reading fixes both: the number is the information.
                        ReadoutWell(
                            value: "\(Int(wellnessScore))/100",
                            widthTemplate: "100/100"
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
                }
                .background(ColorTokens.background)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .task {
            Haptics.prepare()
            if let athlete = athlete {
                let repo = BehaviorTagRepository(modelContext: modelContext)
                customTagNames = (try? repo.fetchCustomTagNames(for: athlete)) ?? []
            }
            seedFromPriorCheckIn()
        }
        .sheet(isPresented: $showingTagManagement) {
            CustomTagManagementSheet(
                customTagNames: $customTagNames,
                athlete: athlete,
                modelContext: modelContext
            )
        }
    }

    /// Seed sliders + active behavior tags from today's check-in (editing today) or, failing that,
    /// the most recent prior check-in. Notes are intentionally NOT carried (day-specific). Runs once;
    /// guarded by `didSeed` so a re-fired `.task` never clobbers user edits.
    private func seedFromPriorCheckIn() {
        // Wait for @Query to resolve a real athlete before latching `didSeed`,
        // otherwise an unscoped fetch could seed from the wrong athlete in a
        // coach+athlete multi-user context and permanently block a correct re-seed.
        guard !didSeed, let athlete else { return }
        didSeed = true

        let repo = RecoveryRepository(modelContext: modelContext)
        let source: WellnessCheckIn
        if let today = try? repo.fetchTodayWellnessCheckIn(athlete: athlete) {
            source = today
            seedSource = .today
        } else if let prior = try? repo.fetchLatestWellnessCheckIn(athlete: athlete) {
            source = prior
            seedSource = .prior
        } else {
            return
        }

        sleepQuality = source.sleepQuality
        soreness = source.soreness
        energy = source.energy
        stress = source.stress
        // Only restore tags that are still available (defaults + current custom),
        // so a since-deleted custom tag can't linger as an unrenderable selection.
        let available = Set(defaultTags + customTagNames)
        selectedTags = Set(source.behaviorTags.filter { $0.isActive }.map { $0.tagName })
            .intersection(available)
        // notes intentionally left empty (day-specific, not carried forward)
        isPrefilled = true
    }

    private func save() {
        // Never persist a check-in without a resolved athlete: with athlete == nil the
        // today-upsert query is unscoped (could update another athlete's row) and a new
        // record would insert an orphan WellnessCheckIn (athlete = nil). Aligns save with
        // the already athlete-gated seed path.
        guard let athlete else { return }

        let repo = RecoveryRepository(modelContext: modelContext)

        // Upsert keyed on today's record so re-opening the sheet on a day the
        // user already checked in UPDATES that row instead of inserting a
        // duplicate same-day WellnessCheckIn (which would shadow the edit and
        // feed an arbitrary stale row into the recovery score).
        let checkIn: WellnessCheckIn
        if let existing = try? repo.fetchTodayWellnessCheckIn(athlete: athlete) {
            checkIn = existing
        } else {
            checkIn = WellnessCheckIn(date: .now)
            checkIn.athlete = athlete
            modelContext.insert(checkIn)
        }

        checkIn.sleepQuality = sleepQuality
        checkIn.soreness = soreness
        checkIn.energy = energy
        checkIn.stress = stress
        checkIn.notes = notes.isEmpty ? nil : notes
        checkIn.updatedAt = .now

        // Replace today's behavior tags rather than appending a second set
        // (cascade-delete the old ones, then recreate from current selection).
        for old in checkIn.behaviorTags {
            modelContext.delete(old)
        }
        checkIn.behaviorTags = []

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
        Haptics.success()
        onSaved?()
        dismiss()
    }

    private func toggleTag(_ tag: String) {
        Haptics.tap()
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
                VStack(alignment: .leading, spacing: Spacing.baselinePair) {
                    Text(title)
                        .font(.Tokens.body)
                        .foregroundStyle(ColorTokens.text1)
                    Text(subtitle)
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text2)
                }
                Spacer()
                // Reading inked, not zone-tinted: a ReadoutWell is a debossed well, and v6's
                // re-tuned zone colors fall below the 4.5:1 small-text floor there (see the
                // score preview above). The segment bar below keeps the zone color — marks are
                // unrestricted by the contrast rule — so the state channel is intact.
                ReadoutWell(value: "\(value)/5", widthTemplate: "5/5")
            }

            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { i in
                    Button {
                        if value != i {
                            Haptics.select()
                            value = i
                        }
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
                    .buttonStyle(.pressable)
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
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.sm)
        .background(ColorTokens.surfaceEl)
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
            VStack(spacing: 0) {
                InstrumentSheetHeader(title: "tags.nav.title") {
                    EmptyView()
                } trailing: {
                    SheetHeaderButton(title: "action.done", emphasis: true) { dismiss() }
                }
                List {
                    ForEach(customTagNames, id: \.self) { tag in
                        Text(tag)
                            .font(.Tokens.body)
                            .foregroundStyle(ColorTokens.text1)
                    }
                    .onDelete(perform: deleteTag)

                    if customTagNames.count < maxCustomTags {
                        HStack {
                            TextField("tags.field.name.placeholder", text: $newTagName)
                                .font(.Tokens.body)
                                .onChange(of: newTagName) { _, new in
                                    if new.count > maxTagLength {
                                        newTagName = String(new.prefix(maxTagLength))
                                    }
                                }
                            Button("action.add") { addTag() }
                                .font(.Tokens.label)
                                .disabled(newTagName.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    } else {
                        Text(String(format: String(localized: "tags.max.message", defaultValue: "Maximum %d custom tags"), maxCustomTags))
                            .font(.Tokens.label)
                            .foregroundStyle(ColorTokens.text2)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
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
