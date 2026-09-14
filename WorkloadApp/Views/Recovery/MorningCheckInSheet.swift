import SwiftUI
import SwiftData

// MARK: - The morning flow (v1.7.3 · U19)

/// The two things the app asks on a morning, in the one order that keeps the first one usable.
///
/// They were two sheets — the blinded 1–10 probe and the wellness ratings — presented
/// independently, both titled "Morning check". HAN met both on the same morning and read them
/// as duplicates. They are the opposite of duplicates: the ratings are 25% of the readiness
/// composite, while the probe is held-out evidence that no scoring engine may read
/// (`MorningReadinessProbeTests`). So they merge into one sheet rather than one of them being
/// deleted.
enum MorningCheckInStep: Equatable {
    /// The blinded 1–10 judgement (+ optional grip). Only ever first.
    case probe
    /// The wellness ratings that feed the score.
    case ratings
}

/// The step rules, pure so they can be tested without a view.
enum MorningCheckInFlow {

    /// `probeBlinding` is nil when the probe is not due this morning — validation off, already
    /// answered, or already skipped — and the sheet opens straight on the ratings.
    ///
    /// When it IS due the probe comes first, and that order is load-bearing: `wasBlinded`
    /// records only whether the DASHBOARD had drawn a score, so a ratings-first sheet (which
    /// carries its own wellness preview) would stamp a contaminated answer as blinded.
    static func initialStep(probeBlinding: Bool?) -> MorningCheckInStep {
        probeBlinding == nil ? .ratings : .probe
    }

    /// Answering and skipping both land on the ratings — a skipped probe is still a morning
    /// check-in. Skip stamps the day so the probe is not re-asked (round 8, HAN).
    static func stepAfterProbe() -> MorningCheckInStep { .ratings }

    /// The probe row is written only when the probe was due AND answered; a skip writes none.
    static func writesProbeRow(probeBlinding: Bool?, probeAnswered: Bool) -> Bool {
        probeBlinding != nil && probeAnswered
    }
}

// MARK: - The sheet

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

    // Step 1 — the probe. Nil `probeBlinding` means "not due"; the sheet is then the ratings
    // alone, which is what the `MorningCheckInPrompt` row opens on an ordinary morning.
    let probeBlinding: Bool?
    @State private var step: MorningCheckInStep
    @State private var probeAnswered = false
    @State private var probeReadiness = 6
    @State private var probeGripText = ""
    @State private var probeGripHand: MorningReadinessProbe.GripHand = .right
    @State private var probeShowGrip = false

    private enum SeedSource { case today, prior }

    private let defaultTags = ["Caffeine", "Alcohol", "Travel", "Stress"]

    private var athlete: Athlete? { athletes.first }
    var onSaved: (() -> Void)?

    /// The step is resolved in `init` rather than in `.task` so the probe is on screen from
    /// the first frame — a flash of the ratings would put a wellness preview in front of the
    /// blinded question.
    init(probeBlinding: Bool? = nil, onSaved: (() -> Void)? = nil) {
        self.probeBlinding = probeBlinding
        self.onSaved = onSaved
        _step = State(initialValue: MorningCheckInFlow.initialStep(probeBlinding: probeBlinding))
    }

    private var wellnessScore: Double {
        Double(sleepQuality + soreness + energy + stress) / 20.0 * 100.0
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                switch step {
                case .probe:  probeHeader
                case .ratings: ratingsHeader
                }
                switch step {
                case .probe:
                    ScrollView {
                        MorningProbeFields(
                            readiness: $probeReadiness,
                            gripText: $probeGripText,
                            gripHand: $probeGripHand,
                            showGrip: $probeShowGrip
                        )
                    }
                    .background(ColorTokens.background)
                case .ratings:
                    ratingsBody
                }
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

    /// Step 1's titlebar. Skip stamps the day and moves on; Next carries the answer forward to
    /// the one Save. The probe has its OWN title so the two steps never read alike (U19).
    private var probeHeader: some View {
        // Both slots LABELLED: an unlabeled trailing closure goes to `trailing` under Swift's
        // backward matching, which is how seven sheets silently grew a right-hand Cancel
        // (UAT round 1, U6).
        InstrumentSheetHeader(
            title: "probe.nav.title",
            leading: {
                SheetHeaderButton(title: "probe.action.skip") {
                    MorningProbeRecorder.stampSkippedToday()
                    probeAnswered = false
                    step = MorningCheckInFlow.stepAfterProbe()
                }
            },
            trailing: {
                SheetHeaderButton(title: "morning.action.next", emphasis: true) {
                    probeAnswered = true
                    step = MorningCheckInFlow.stepAfterProbe()
                }
            }
        )
    }

    /// Step 2's titlebar. The leading slot goes back to the probe when there was one, so an
    /// answer can be corrected before it is written; otherwise it dismisses.
    private var ratingsHeader: some View {
        InstrumentSheetHeader(
            title: "morning.nav.title",
            leading: {
                if probeBlinding == nil {
                    SheetHeaderButton(title: "action.cancel") { dismiss() }
                } else {
                    SheetHeaderButton(title: "morning.action.back") { step = .probe }
                }
            },
            trailing: {
                SheetHeaderButton(
                    title: "action.save",
                    emphasis: true,
                    isDisabled: athlete == nil
                ) { save() }
            }
        )
    }

    private var ratingsBody: some View {
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

    /// The sheet's ONE Save. It writes the wellness row and — when the probe was due and
    /// answered — the probe row, in a single pass, then re-runs the pipeline through `onSaved`
    /// exactly as the ratings-only save always has.
    private func save() {
        // Never persist a check-in without a resolved athlete: with athlete == nil the
        // today-upsert query is unscoped (could update another athlete's row) and a new
        // record would insert an orphan WellnessCheckIn (athlete = nil). Aligns save with
        // the already athlete-gated seed path.
        guard let athlete else { return }

        let probe: MorningCheckInRecorder.ProbeAnswer? = {
            guard MorningCheckInFlow.writesProbeRow(
                probeBlinding: probeBlinding,
                probeAnswered: probeAnswered
            ), let wasBlinded = probeBlinding else { return nil }
            return MorningCheckInRecorder.ProbeAnswer(
                readiness: probeReadiness,
                gripText: probeGripText,
                gripHand: probeGripHand,
                includeGrip: probeShowGrip,
                wasBlinded: wasBlinded
            )
        }()

        MorningCheckInRecorder.save(
            ratings: MorningCheckInRecorder.Ratings(
                sleepQuality: sleepQuality,
                soreness: soreness,
                energy: energy,
                stress: stress,
                notes: notes
            ),
            tags: MorningCheckInRecorder.TagSelection(
                selected: selectedTags,
                defaults: defaultTags,
                custom: customTagNames
            ),
            probe: probe,
            athlete: athlete,
            modelContext: modelContext
        )

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

// MARK: - The morning write

/// Both morning rows, written together.
///
/// Extracted from the sheet's `save()` when the two morning sheets merged (v1.7.3 · U19), so
/// the "one Save writes both rows" contract is a thing a test can run rather than a thing the
/// view body happens to do.
@MainActor
enum MorningCheckInRecorder {

    struct Ratings {
        var sleepQuality: Int
        var soreness: Int
        var energy: Int
        var stress: Int
        var notes: String
    }

    struct TagSelection {
        var selected: Set<String>
        var defaults: [String]
        var custom: [String]
    }

    struct ProbeAnswer {
        var readiness: Int
        var gripText: String
        var gripHand: MorningReadinessProbe.GripHand
        var includeGrip: Bool
        var wasBlinded: Bool
    }

    /// Write today's wellness check-in, and the probe row when one was answered. One
    /// `modelContext.save()` covers both.
    static func save(
        ratings: Ratings,
        tags: TagSelection,
        probe: ProbeAnswer?,
        athlete: Athlete,
        modelContext: ModelContext
    ) {
        if let probe {
            MorningProbeRecorder.record(
                readiness: probe.readiness,
                gripText: probe.gripText,
                gripHand: probe.gripHand,
                includeGrip: probe.includeGrip,
                wasBlinded: probe.wasBlinded,
                athlete: athlete,
                modelContext: modelContext
            )
        }

        // Upsert keyed on today's record so re-opening the sheet on a day the
        // user already checked in UPDATES that row instead of inserting a
        // duplicate same-day WellnessCheckIn (which would shadow the edit and
        // feed an arbitrary stale row into the recovery score).
        let checkIn: WellnessCheckIn
        if let existing = todayCheckIn(athlete: athlete, modelContext: modelContext) {
            checkIn = existing
        } else {
            checkIn = WellnessCheckIn(date: .now)
            checkIn.athlete = athlete
            modelContext.insert(checkIn)
        }

        checkIn.sleepQuality = ratings.sleepQuality
        checkIn.soreness = ratings.soreness
        checkIn.energy = ratings.energy
        checkIn.stress = ratings.stress
        checkIn.notes = ratings.notes.isEmpty ? nil : ratings.notes
        checkIn.updatedAt = .now

        // Reconcile today's behavior tags IN PLACE (v1.7.2 / audit M3).
        //
        // This used to delete every tag and re-create the whole set with fresh UUIDs on
        // each save. Sync is a full upsert keyed on id, so every re-open of the same day's
        // check-in left the previous set stranded on the server: the rows accumulated
        // without bound, and `BehaviorCorrelationEngine` — which counts rows — read the
        // orphans as real behaviour. Keeping the row and editing it means one row per
        // (day, tag) for good.
        let allTagNames = tags.defaults + tags.custom
        var carriedOver = Dictionary(
            checkIn.behaviorTags.map { ($0.tagName, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        for tagName in allTagNames {
            if let existingTag = carriedOver.removeValue(forKey: tagName) {
                existingTag.isActive = tags.selected.contains(tagName)
                existingTag.isCustom = !tags.defaults.contains(tagName)
                existingTag.wellnessCheckIn = checkIn
                existingTag.athlete = athlete
                existingTag.updatedAt = .now
            } else {
                let tag = BehaviorTag(
                    date: .now,
                    tagName: tagName,
                    isActive: tags.selected.contains(tagName),
                    isCustom: !tags.defaults.contains(tagName)
                )
                tag.wellnessCheckIn = checkIn
                tag.athlete = athlete
                modelContext.insert(tag)
            }
        }
        // Whatever is left carried a tag name the athlete has since removed from their
        // custom list. Tombstone it so the deletion reaches the server (audit H6) rather
        // than the row lingering there and being pulled back.
        for (_, removedTag) in carriedOver {
            SyncTombstone.record(
                rowId: removedTag.id,
                entity: .behaviorTags,
                athleteId: athlete.id,
                in: modelContext
            )
            modelContext.delete(removedTag)
        }

        try? modelContext.save()
    }

    /// Today's check-in for this athlete, newest write first.
    ///
    /// Fetches directly instead of constructing a `RecoveryRepository`: a `@MainActor`
    /// repository deallocated inside a SYNCHRONOUS call trips the libswift_Concurrency
    /// back-deploy deinit SIGABRT (the C-wdg-002 trap — the same reason
    /// `DashboardViewModel.deriveTodayPlanCTA` and `TodayVerdictViewModel` avoid it), and this
    /// save runs synchronously from a button. The filter mirrors
    /// `RecoveryRepository.fetchTodayWellnessCheckIn` — keep the two in step.
    private static func todayCheckIn(
        athlete: Athlete,
        modelContext: ModelContext
    ) -> WellnessCheckIn? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) else { return nil }
        let athleteId = athlete.id
        let descriptor = FetchDescriptor<WellnessCheckIn>(
            predicate: #Predicate { $0.date >= today && $0.date < tomorrow },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return ((try? modelContext.fetch(descriptor)) ?? [])
            .first { $0.athlete?.id == athleteId }
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
