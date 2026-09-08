import SwiftUI

/// Guided session mode (v1.7.3 feature 9) — the focused space after "Start this session".
///
/// HAN-gated demo round 3, variant A "Plate". The mode is active ONLY on the resolved-plan init
/// of `ActiveWorkoutSheet`: a session the app already knows the shape of can be walked one move
/// at a time, so the athlete never types from scratch, never recalls a number, and never leaves
/// the space to check the schedule. Every other way a session reaches the log keeps the ledger.
///
/// **Blocks, not lines** (round-2 gate: "less text, more components"). Each kind of information
/// gets its own component — a stat strip of three readout wells, the move name, a row of set
/// blocks, two readout wells over the rule, the pill, and the action pair — and almost no
/// sentence-shaped text survives on the plate. The landmarks (`○` target · `●` last · `▲` PR)
/// and the rule are taught once in the mode's first-use tutorial, never re-explained here.
///
/// **What it does NOT own.** The drafts, the finish sheet, the PR/spike banners, the zero-done
/// guard and the save are all still the sheet's — this view mutates `entries` through
/// `GuidedSessionEngine` and asks the sheet to finish. There is no second state model.
struct GuidedSessionView: View {

    // MARK: Inputs

    @Binding var entries: [ExerciseEntryDraft]
    /// The pair-cell jump, held by the sheet so the voice ingest resolves the same current slot
    /// the plate is showing. Cleared on every log or skip — a jump moves you for one set.
    @Binding var priorityEntryIndex: Int?
    let startTime: Date
    let weightUnit: WeightUnit
    /// Heaviest weight ever logged on a movement, in kg — the `▲` landmark. Resolved by the
    /// sheet from the athlete's records; this view stays pure presentation and never fetches.
    let prWeightKg: (String) -> Double?
    let voiceStartToken: Int
    let onUtterance: (String) async -> UtteranceOutcome
    /// Open the existing finish sheet (RPE + save-as-template). The zero-done guard still runs.
    let onFinish: () -> Void

    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Shared inline-keypad focus for the plate's two wells, so a weight commit advances to reps
    /// without dismissing the keyboard (the ledger row's §5.5 behaviour, one plate instead of N).
    @FocusState private var focusField: SetFocusField?

    private var engine: GuidedSessionEngine {
        GuidedSessionEngine(entries: entries, priorityEntryIndex: priorityEntryIndex)
    }

    // MARK: Body

    var body: some View {
        VStack(spacing: 0) {
            statStrip
            AreaRule()
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: Spacing.sm) {
                        if engine.isSessionComplete {
                            completionPlate
                        } else {
                            heroPlate
                        }
                    }
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.sm)
                    .animation(
                        Motion.resolved(Motion.entrance, reduceMotion: reduceMotion),
                        value: plateIdentity
                    )
                }
                .background(ColorTokens.background)
                .environment(\.setRowScroller) { id in
                    withAnimation(Motion.resolved(Motion.state, reduceMotion: reduceMotion)) {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }

            if !engine.isSessionComplete {
                nextBlock
            }

            // The docked capture control: voice is a first-class door into the same queue. An
            // utterance that names no movement fills the plate's CURRENT slot (the sheet routes
            // it), which is the only reading that makes sense while one move is on screen.
            VoiceDictationCard(
                startToken: voiceStartToken,
                isDocked: true,
                planAware: true,
                onUtterance: onUtterance
            )
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(ColorTokens.background)
        }
    }

    // MARK: - Stat strip

    /// Three readout wells: which move, how long the session has run, how long since the last
    /// set landed. After a log the SINCE SET clock IS the rest state — there is nothing else.
    private var statStrip: some View {
        TimelineView(.periodic(from: startTime, by: 1)) { context in
            HStack(spacing: Spacing.xs) {
                statWell(value: movePositionText, key: "guided.stat.move")
                statWell(
                    value: clock(context.date.timeIntervalSince(startTime)),
                    key: "guided.stat.elapsed"
                )
                statWell(value: sinceSetText(now: context.date), key: "guided.stat.sinceSet")
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
        }
        .background(ColorTokens.surface)
    }

    private func statWell(value: String, key: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: Spacing.baselinePair) {
            Text(value)
                .font(.Tokens.body)
                .monospacedDigit()
                .foregroundStyle(ColorTokens.text1)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            // `text2` rather than the annotation default: annotation never sits on a well in
            // `text3` (2.84:1, below the floor — DESIGN.md v6 rule 7).
            AnnotationLabel(key: key, size: .small, color: ColorTokens.text2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.xs)
        .padding(.vertical, Spacing.xs)
        .debossed(cornerRadius: CornerTokens.control)
    }

    private var movePositionText: String {
        let engine = self.engine
        guard let index = engine.currentEntryIndex else {
            return "\(engine.blocks.count) / \(engine.blocks.count)"
        }
        let position = engine.movePosition(entryIndex: index)
        return "\(position.index) / \(position.count)"
    }

    private func sinceSetText(now: Date) -> String {
        guard let last = lastLoggedAt else { return "—" }
        return clock(now.timeIntervalSince(last))
    }

    /// The newest `loggedAt` in the session — the anchor for the rest clock.
    private var lastLoggedAt: Date? {
        entries.flatMap(\.sets).compactMap(\.loggedAt).max()
    }

    // MARK: - Hero plate

    /// Changes when the plate hands over to another movement, so the surface re-enters instead
    /// of mutating in place.
    private var plateIdentity: UUID {
        guard let index = engine.currentEntryIndex, entries.indices.contains(index) else {
            return Self.completionIdentity
        }
        return entries[index].id
    }

    private static let completionIdentity = UUID()

    @ViewBuilder private var heroPlate: some View {
        if let slot = engine.current, entries.indices.contains(slot.entryIndex) {
            let entry = entries[slot.entryIndex]
            let position = engine.movePosition(entryIndex: slot.entryIndex)
            VStack(alignment: .leading, spacing: Spacing.sm) {
                AnnotationLabel(
                    String(
                        format: LocalePinnedStrings.localized(
                            "guided.hero.movePosition",
                            defaultValue: "%1$d of %2$d",
                            locale: locale
                        ),
                        position.index, position.count
                    )
                )
                .annotationReveal(index: 0)

                Text(entry.exerciseName)
                    .font(.Tokens.pageTitle)
                    .foregroundStyle(ColorTokens.text1)
                    .fixedSize(horizontal: false, vertical: true)

                if engine.isPaired(slot.entryIndex) {
                    pairCells(current: slot.entryIndex)
                }

                setBlocks(entryIndex: slot.entryIndex)

                editor(for: slot, entry: entry)

                PrimaryActionButton(title: "guided.action.logSet") { logCurrent() }
                    .accessibilityIdentifier("guided.logSet")

                actionPair(entryIndex: slot.entryIndex)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.md)
            .raised(cornerRadius: CornerTokens.card, isHero: true)
            .id(plateIdentity)
            .transition(.opacity)
        }
    }

    // MARK: Pair cells

    /// A superset's two movements as equal-weight butted cells — the same nocebo grammar the
    /// decision rows use, because choosing which half of a pair to do next is a decision, not a
    /// recommendation. Tapping the partner brings its next planned set forward for one set.
    private func pairCells(current: Int) -> some View {
        let block = engine.block(containing: current)
        return HStack(spacing: 0) {
            ForEach(Array(block.enumerated()), id: \.element) { offset, entryIndex in
                pairCell(entryIndex: entryIndex, isLive: entryIndex == current)
                if offset < block.count - 1 {
                    Rectangle()
                        .fill(ColorTokens.dividerStrong)
                        .frame(width: 0.5)
                        .accessibilityHidden(true)
                }
            }
        }
        .frame(minHeight: 44)
        .clipShape(RoundedRectangle(cornerRadius: CornerTokens.control))
        .overlay(
            RoundedRectangle(cornerRadius: CornerTokens.control)
                .stroke(ColorTokens.dividerStrong, lineWidth: 0.5)
        )
    }

    private func pairCell(entryIndex: Int, isLive: Bool) -> some View {
        let entry = entries[entryIndex]
        return Button {
            Haptics.tap()
            guard !isLive else { return }
            withAnimation(Motion.resolved(Motion.entrance, reduceMotion: reduceMotion)) {
                priorityEntryIndex = GuidedSessionEngine.jumpTarget(
                    to: entryIndex,
                    in: entries,
                    priorityEntryIndex: priorityEntryIndex
                )
            }
        } label: {
            VStack(spacing: Spacing.baselinePair) {
                Text("\(engine.tag(for: entryIndex)) · \(entry.exerciseName)")
                    .font(.Tokens.label)
                    .foregroundStyle(isLive ? ColorTokens.text1 : ColorTokens.text2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                AnnotationLabel(pairStatus(entryIndex: entryIndex, isLive: isLive), size: .small)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, Spacing.xs)
            .padding(.vertical, Spacing.xs)
            .background(isLive ? ColorTokens.surfaceEl2 : ColorTokens.surfaceEl)
            .contentShape(Rectangle())
        }
        .buttonStyle(.reliefPress(cornerRadius: 0))
        .accessibilityAddTraits(isLive ? [.isButton, .isSelected] : .isButton)
    }

    private func pairStatus(entryIndex: Int, isLive: Bool) -> String {
        if isLive {
            return LocalePinnedStrings.localized("guided.pair.live", defaultValue: "Live", locale: locale)
        }
        let sets = entries[entryIndex].sets
        guard let next = sets.firstIndex(where: { !$0.isDone && !$0.isSkipped }) else {
            return LocalePinnedStrings.localized("guided.pair.done", defaultValue: "Done", locale: locale)
        }
        let label = LocalePinnedStrings.localized("guided.pair.next", defaultValue: "Next", locale: locale)
        return "\(label) · \(setNumberText(next + 1))"
    }

    // MARK: Set blocks

    private enum SetBlockState { case logged, current, planned, skipped }

    /// One 44pt block per set of the move — the whole set indicator, replacing dots plus a
    /// count. Logged blocks are raised with a `zone-optimal` dot; the current block wears the
    /// travertine ring (live state = accent); planned is flat stone; skipped is dashed. No block
    /// is ever FILLED with a metric hue — the hue law holds.
    private func setBlocks(entryIndex: Int) -> some View {
        let sets = entries[entryIndex].sets
        return HStack(spacing: Spacing.xs) {
            ForEach(Array(sets.enumerated()), id: \.element.id) { index, set in
                setBlock(entryIndex: entryIndex, index: index, set: set)
            }
        }
    }

    @ViewBuilder private func setBlock(entryIndex: Int, index: Int, set: SetDraft) -> some View {
        let state = blockState(entryIndex: entryIndex, index: index, set: set)
        let content = HStack(spacing: Spacing.baselinePair) {
            if state == .logged {
                Circle()
                    .fill(ColorTokens.zoneOptimal)
                    .frame(width: 6, height: 6)
                    .accessibilityHidden(true)
            }
            blockLabel(index: index, set: set, state: state)
        }
        .frame(maxWidth: .infinity, minHeight: 44)

        switch state {
        case .logged:
            content.raised(cornerRadius: CornerTokens.control)
        case .current:
            content
                .background(
                    ColorTokens.surfaceEl2,
                    in: RoundedRectangle(cornerRadius: CornerTokens.control)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CornerTokens.control)
                        .stroke(ColorTokens.accent, lineWidth: 1.5)
                )
        case .planned:
            content
                .background(
                    ColorTokens.surface,
                    in: RoundedRectangle(cornerRadius: CornerTokens.control)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CornerTokens.control)
                        .stroke(ColorTokens.divider, lineWidth: 0.5)
                )
        case .skipped:
            content
                .background(
                    ColorTokens.surface,
                    in: RoundedRectangle(cornerRadius: CornerTokens.control)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CornerTokens.control)
                        .stroke(
                            ColorTokens.divider,
                            style: StrokeStyle(lineWidth: 0.5, dash: [4, 4])
                        )
                )
        }
    }

    @ViewBuilder private func blockLabel(index: Int, set: SetDraft, state: SetBlockState) -> some View {
        if set.isWarmup {
            AnnotationLabel(key: "guided.block.warmup", color: blockInk(state))
        } else if set.isExtra {
            AnnotationLabel("+", color: blockInk(state))
        } else {
            Text("\(index + 1)")
                .font(.Tokens.label)
                .monospacedDigit()
                .foregroundStyle(blockInk(state))
        }
    }

    private func blockInk(_ state: SetBlockState) -> Color {
        switch state {
        case .logged, .current: return ColorTokens.text1
        case .planned:          return ColorTokens.text3
        case .skipped:          return ColorTokens.disabled
        }
    }

    private func blockState(entryIndex: Int, index: Int, set: SetDraft) -> SetBlockState {
        if set.isDone { return .logged }
        if set.isSkipped { return .skipped }
        if engine.current == GuidedSessionEngine.Slot(entryIndex: entryIndex, setIndex: index) {
            return .current
        }
        return .planned
    }

    // MARK: Editor

    /// The plate's editor: the two-well set entry for weight/reps work, and the existing open
    /// ledger row for cardio and duration sets — the mode adds no second editor.
    @ViewBuilder private func editor(for slot: GuidedSessionEngine.Slot, entry: ExerciseEntryDraft) -> some View {
        if entry.exerciseCategory.inputMode == .weightReps {
            SetEntryFields(
                weightKg: $entries[slot.entryIndex].sets[slot.setIndex].weightKg,
                reps: $entries[slot.entryIndex].sets[slot.setIndex].reps,
                unit: weightUnit,
                suggestedWeightKg: suggestedWeightKg(for: slot),
                suggestedReps: suggestedReps(for: slot),
                lastSessionWeightKg: entry.sets[slot.setIndex].lastSessionWeightKg,
                lastSessionReps: entry.sets[slot.setIndex].lastSessionReps,
                prWeightKg: prWeightKg(entry.exerciseName),
                isBodyweight: entry.exerciseCategory == .bodyweight,
                layout: .wells,
                focus: $focusField,
                rowId: entry.sets[slot.setIndex].id
            )
            // The plate keeps ONE editor across a move's sets, so the editor is re-identified
            // per set — otherwise its keypad buffers and its expanded-field choice would carry
            // last set's state onto the next one.
            .id(entry.sets[slot.setIndex].id)
        } else {
            SetEntryRow(
                set: $entries[slot.entryIndex].sets[slot.setIndex],
                index: slot.setIndex,
                inputMode: entry.exerciseCategory.inputMode,
                weightUnit: weightUnit,
                exerciseName: entry.exerciseName,
                category: entry.exerciseCategory,
                prWeightKg: prWeightKg(entry.exerciseName),
                isOpen: true
            )
        }
    }

    // MARK: Action pair

    /// Skip move | + Extra set — a butted pair of equal-weight 44pt cells under the pill. Both
    /// are ordinary session facts, so neither is dressed as the recommended one.
    private func actionPair(entryIndex: Int) -> some View {
        HStack(spacing: 0) {
            actionCell(title: "guided.action.skipMove", identifier: "guided.skipMove") {
                skipMove(entryIndex: entryIndex)
            }
            Rectangle()
                .fill(ColorTokens.dividerStrong)
                .frame(width: 0.5)
                .accessibilityHidden(true)
            actionCell(title: "guided.action.extraSet", identifier: "guided.extraSet") {
                addExtraSet(entryIndex: entryIndex)
            }
        }
        .frame(minHeight: 44)
        .clipShape(RoundedRectangle(cornerRadius: CornerTokens.control))
        .overlay(
            RoundedRectangle(cornerRadius: CornerTokens.control)
                .stroke(ColorTokens.dividerStrong, lineWidth: 0.5)
        )
    }

    private func actionCell(
        title: LocalizedStringKey,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.Tokens.label)
                .foregroundStyle(ColorTokens.text1)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, minHeight: 44)
                .padding(.horizontal, Spacing.xs)
                .background(ColorTokens.surface)
                .contentShape(Rectangle())
        }
        .buttonStyle(.reliefPress(cornerRadius: 0))
        .accessibilityIdentifier(identifier)
    }

    // MARK: - Next block

    /// What follows, as two cells: the movement and its prescription, and how many sets the
    /// session still owes. Inside a pair the following slot is the partner, so the label reads
    /// THEN rather than NEXT.
    private var nextBlock: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: Spacing.baselinePair) {
                AnnotationLabel(key: nextLabelKey, size: .small)
                Text(nextMoveName)
                    .font(.Tokens.body)
                    .foregroundStyle(ColorTokens.text1)
                    .lineLimit(1)
                AnnotationLabel(nextPrescription, size: .small)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)

            AreaRule(axis: .vertical)

            VStack(spacing: Spacing.baselinePair) {
                Text("\(engine.plannedSetsLeft)")
                    .font(.Tokens.pageTitle)
                    .monospacedDigit()
                    .foregroundStyle(ColorTokens.text1)
                AnnotationLabel(key: "guided.next.left", size: .small)
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(ColorTokens.surface)
        }
        .background(ColorTokens.surfaceEl)
        .clipShape(RoundedRectangle(cornerRadius: CornerTokens.card))
        .overlay(
            RoundedRectangle(cornerRadius: CornerTokens.card)
                .stroke(ColorTokens.divider, lineWidth: 0.5)
        )
        .padding(.horizontal, Spacing.sm)
        .padding(.bottom, Spacing.xs)
        .accessibilityElement(children: .combine)
    }

    private var nextLabelKey: LocalizedStringKey {
        guard let next = engine.upNext, let current = engine.currentEntryIndex else {
            return "guided.next.then"
        }
        return engine.block(containing: current).contains(next.entryIndex)
            ? "guided.next.then"
            : "guided.next.label"
    }

    private var nextMoveName: String {
        guard let next = engine.upNext, entries.indices.contains(next.entryIndex) else {
            return LocalePinnedStrings.localized("guided.next.finish", defaultValue: "Finish", locale: locale)
        }
        return entries[next.entryIndex].exerciseName
    }

    private var nextPrescription: String {
        guard let next = engine.upNext,
              let current = engine.currentEntryIndex,
              entries.indices.contains(next.entryIndex) else {
            return LocalePinnedStrings.localized(
                "guided.next.lastMove",
                defaultValue: "Last move",
                locale: locale
            )
        }
        // Inside a pair the partner is mid-flight, so the honest unit is one set — the split the
        // shared formatter owns, because the lock screen's NEXT column states the same thing.
        return GuidedSessionFormatting.upNextLine(
            entry: entries[next.entryIndex],
            set: entries[next.entryIndex].sets[next.setIndex],
            setIndex: next.setIndex,
            isPairPartner: engine.block(containing: current).contains(next.entryIndex),
            unit: weightUnit,
            locale: locale
        )
    }

    // MARK: - Completion plate

    /// What the session actually was, move by move, before the finish sheet asks for an RPE.
    /// Deviations from the plan are stated (`▽`), skipped movements are named, and tapping a
    /// line reopens that movement — the way back into the session is the record itself.
    private var completionPlate: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            AnnotationLabel(completionStamp)
                .annotationReveal(index: 0)

            Text(
                String(
                    format: LocalePinnedStrings.localized(
                        "guided.complete.setsLogged",
                        defaultValue: "%d sets logged",
                        locale: locale
                    ),
                    loggedSetCount
                )
            )
            .font(.Tokens.pageTitle)
            .monospacedDigit()
            .foregroundStyle(ColorTokens.text1)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(entries.enumerated()), id: \.element.id) { index, _ in
                    AreaRule()
                    completionLine(entryIndex: index)
                }
            }

            PrimaryActionButton(title: "guided.action.finishSession") { onFinish() }
                .accessibilityIdentifier("guided.finishSession")

            Button {
                Haptics.tap()
                backToSession()
            } label: {
                Text("guided.action.backToSession")
                    .font(.Tokens.smallLabel)
                    .foregroundStyle(ColorTokens.text2)
                    .frame(maxWidth: .infinity, minHeight: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.pressable(scale: 1, opacity: 0.6))
            .accessibilityIdentifier("guided.backToSession")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.md)
        .raised(cornerRadius: CornerTokens.card, isHero: true)
        .id(plateIdentity)
        .transition(.opacity)
    }

    private var loggedSetCount: Int {
        entries.reduce(0) { $0 + $1.sets.filter(\.isDone).count }
    }

    private var completionStamp: String {
        let engine = self.engine
        let workedBlocks = engine.blocks.filter { block in
            block.contains { entries[$0].sets.contains(where: \.isDone) }
        }
        let moves = String(
            format: LocalePinnedStrings.localized(
                "guided.complete.moves",
                defaultValue: "%1$d of %2$d moves",
                locale: locale
            ),
            workedBlocks.count, engine.blocks.count
        )
        let elapsed = "\(LocalePinnedStrings.localized("guided.stat.elapsed", locale: locale)) \(clock(Date.now.timeIntervalSince(startTime)))"
        let title = LocalePinnedStrings.localized(
            "guided.complete.title",
            defaultValue: "Session complete",
            locale: locale
        )
        return "\(title) · \(moves) · \(elapsed)"
    }

    private func completionLine(entryIndex: Int) -> some View {
        let entry = entries[entryIndex]
        let done = entry.sets.filter(\.isDone)
        return Button {
            Haptics.tap()
            withAnimation(Motion.resolved(Motion.entrance, reduceMotion: reduceMotion)) {
                priorityEntryIndex = nil
                GuidedSessionEngine.reopen(&entries, entryIndex: entryIndex)
            }
        } label: {
            VStack(alignment: .leading, spacing: Spacing.baselinePair) {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                    AnnotationLabel(engine.tag(for: entryIndex), size: .small)
                        .frame(width: 28, alignment: .leading)
                    Text(entry.exerciseName)
                        .font(.Tokens.label)
                        .foregroundStyle(done.isEmpty ? ColorTokens.text2 : ColorTokens.text1)
                        .lineLimit(1)
                    Spacer(minLength: Spacing.xs)
                    if done.isEmpty {
                        AnnotationLabel(key: "guided.complete.skipped", size: .small)
                    } else {
                        AnnotationLabel(
                            summary(of: done, entry: entry),
                            size: .small,
                            color: ColorTokens.zoneOptimal
                        )
                    }
                }
                if !deviations(of: done, entry: entry).isEmpty {
                    AnnotationLabel(
                        deviations(of: done, entry: entry).joined(separator: " · "),
                        size: .small
                    )
                    .padding(.leading, Spacing.lg)
                }
            }
            .padding(.vertical, Spacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable(scale: 1, opacity: 0.6))
        .accessibilityHint(Text("guided.complete.reopenHint"))
    }

    /// "4 × 5 · 132.5 kg" — what the movement actually produced.
    private func summary(of done: [SetDraft], entry: ExerciseEntryDraft) -> String {
        guard let first = done.first else { return "" }
        let bodyweight = entry.exerciseCategory == .bodyweight
        return "\(done.count) × \(first.reps ?? 0) · \(weightText(first.weightKg, bodyweight: bodyweight))"
    }

    /// Every logged set that did not match what the plan asked of it, and every extra one. The
    /// comparison is against the set's OWN target, not against the move's first logged set:
    /// the line answers "where did the session leave the plan", which is what the athlete (and
    /// the next verdict) needs to see.
    private func deviations(of done: [SetDraft], entry: ExerciseEntryDraft) -> [String] {
        let bodyweight = entry.exerciseCategory == .bodyweight
        return done.enumerated().compactMap { index, set in
            let repsDiffer = set.targetReps.map { $0 != (set.reps ?? $0) } ?? false
            let weightDiffers = set.targetWeightKg.map { target in
                abs(target - (set.weightKg ?? target)) > 0.001
            } ?? false
            let differs = repsDiffer || weightDiffers
            guard differs || set.isExtra else { return nil }
            let glyph = set.isExtra && !differs ? "+" : "▽"
            return "\(glyph) \(setNumberText(index + 1)) · \(weightText(set.weightKg, bodyweight: bodyweight)) × \(set.reps ?? 0)"
        }
    }

    /// The quiet way out of the completion plate: reopen the last movement that produced work,
    /// which hands one fresh (ghosted, unlogged) set back to the plate. Nothing is recorded by
    /// coming back — an untouched extra set never saves.
    private func backToSession() {
        guard let entryIndex = entries.indices.reversed().first(where: {
            entries[$0].sets.contains(where: \.isDone)
        }) ?? entries.indices.last else { return }
        withAnimation(Motion.resolved(Motion.entrance, reduceMotion: reduceMotion)) {
            priorityEntryIndex = nil
            GuidedSessionEngine.reopen(&entries, entryIndex: entryIndex)
        }
    }

    // MARK: - Actions

    /// Accepting the ghosts IS the one-tap loop: whatever the athlete never edited is filled from
    /// the plan exactly as the ledger row's Log set fills it (reps fall back to the universal 8;
    /// a bodyweight movement with no suggestion records an explicit BW set).
    private func logCurrent() {
        guard let slot = engine.current, entries.indices.contains(slot.entryIndex) else { return }
        let entry = entries[slot.entryIndex]
        let set = entry.sets[slot.setIndex]

        let reps = set.reps ?? suggestedReps(for: slot) ?? 8
        var weight = set.weightKg
        if weight == nil {
            if let suggested = suggestedWeightKg(for: slot) {
                weight = suggested
            } else if entry.exerciseCategory == .bodyweight {
                weight = 0
            }
        }

        focusField = nil
        withAnimation(Motion.resolved(Motion.entrance, reduceMotion: reduceMotion)) {
            priorityEntryIndex = nil
            GuidedSessionEngine.log(&entries, slot: slot, weightKg: weight, reps: reps)
        }
        Haptics.success()
    }

    private func skipMove(entryIndex: Int) {
        focusField = nil
        withAnimation(Motion.resolved(Motion.entrance, reduceMotion: reduceMotion)) {
            priorityEntryIndex = nil
            GuidedSessionEngine.skipMove(&entries, entryIndex: entryIndex)
        }
        Haptics.tap()
    }

    private func addExtraSet(entryIndex: Int) {
        withAnimation(Motion.resolved(Motion.state, reduceMotion: reduceMotion)) {
            priorityEntryIndex = nil
            GuidedSessionEngine.addExtraSet(&entries, entryIndex: entryIndex)
        }
        Haptics.tap()
    }

    // MARK: - Suggestions (the same pure read the ledger row performs)

    private func lastSessionCandidate(_ set: SetDraft) -> SetSuggestion.Candidate? {
        let candidate = SetSuggestion.Candidate(
            weightKg: set.lastSessionWeightKg,
            reps: set.lastSessionReps,
            distanceMeters: set.lastSessionDistanceMeters,
            durationSeconds: set.lastSessionDurationSeconds
        )
        return candidate.isEmpty ? nil : candidate
    }

    private func suggestedWeightKg(for slot: GuidedSessionEngine.Slot) -> Double? {
        let entry = entries[slot.entryIndex]
        let set = entry.sets[slot.setIndex]
        return SetSuggestion.suggest(
            inputMode: entry.exerciseCategory.inputMode,
            exerciseName: entry.exerciseName,
            category: entry.exerciseCategory,
            templateTarget: set.targetWeightKg.map { SetSuggestion.Candidate(weightKg: $0) },
            inSessionPrevSet: nil,
            lastSessionSet: lastSessionCandidate(set),
            isPro: false,
            progressionSuggestion: nil
        ).centerWeightKg
    }

    private func suggestedReps(for slot: GuidedSessionEngine.Slot) -> Int? {
        let entry = entries[slot.entryIndex]
        let set = entry.sets[slot.setIndex]
        return SetSuggestion.suggest(
            inputMode: entry.exerciseCategory.inputMode,
            exerciseName: entry.exerciseName,
            category: entry.exerciseCategory,
            templateTarget: set.targetReps.map { SetSuggestion.Candidate(reps: $0) },
            inSessionPrevSet: nil,
            lastSessionSet: lastSessionCandidate(set),
            isPro: false,
            progressionSuggestion: nil
        ).reps
    }

    // MARK: - Formatting

    // The plate and the lock-screen Live Activity render the SAME set at the same moment, so the
    // composition rules live in one place (`GuidedSessionFormatting`) and both read them.

    private func clock(_ seconds: TimeInterval) -> String {
        GuidedSessionFormatting.clock(seconds)
    }

    private func weightText(_ kg: Double?, bodyweight: Bool) -> String {
        GuidedSessionFormatting.weightText(kg, bodyweight: bodyweight, unit: weightUnit, locale: locale)
    }

    private func setNumberText(_ oneBasedIndex: Int) -> String {
        GuidedSessionFormatting.setNumber(oneBasedIndex, locale: locale)
    }
}
