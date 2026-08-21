import SwiftUI
import UIKit

/// Identifies which inline keypad field in a single `.weightReps` set row currently
/// holds focus. Lets the weight keypad advance to the reps keypad without dismiss /
/// re-summon (§5.5 in-flow focus advance). Hashable + per-row `id` so the same enum can
/// disambiguate multiple rows sharing one `@FocusState`. (Moved here from the retired
/// `WeightBlockPicker`.)
enum SetFocusField: Hashable {
    case weight(UUID)
    case reps(UUID)
}

/// Scrolls a set row clear of the keyboard. The sheet injects a closure bound to its
/// `ScrollViewReader`; a row calls it when one of its fields takes focus — SwiftUI's
/// automatic keyboard avoidance surfaces only the bare field, leaving the row's label
/// and chips buried under the pad (HAN UAT round 4).
private struct SetRowScrollerKey: EnvironmentKey {
    static let defaultValue: (@MainActor (UUID) -> Void)? = nil
}

extension EnvironmentValues {
    var setRowScroller: (@MainActor (UUID) -> Void)? {
        get { self[SetRowScrollerKey.self] }
        set { self[SetRowScrollerKey.self] = newValue }
    }
}

/// Set entry, variant B "Bench" — HAN-gated 2026-08-22 from the v1.7.2 logging demos.
///
/// **What changed and why.** Rounds 1–8 of the 1.7.1 UAT made the row correct; the value
/// landscape was still invisible until your thumb was already down, which is HAN's standing
/// critique: *you cannot know where a swipe lands before touching it.* Bench answers it by
/// giving ONE field the full width, and with it a `ScrubRule` — an always-drawn tick scale
/// with a fixed accent needle. At rest it states what is one detent away, five away, and
/// where the values that already mean something to this athlete sit. The other field waits
/// as a compact readout; tapping it hands over the rule.
///
/// Three ways in, unchanged in spirit from the field-first spec, but no longer sharing a
/// surface:
/// - **Tap the reading → type.** Focus clears the buffer and the prior value ghosts as the
///   placeholder, so typing never appends to a seeded digit. Commit on focus loss / toolbar
///   Done / Next (round-3 reliability semantics).
/// - **Drag the rule → scrub.** The rule travels WITH the thumb, so dragging right lowers the
///   reading — the physical convention a visible scale forces, and the one behaviour change
///   this redesign makes. One house increment (2.5 kg / 5 lb) or one rep per detent.
/// - **Chips.** −/＋ one increment; self-explanatory, kept for the plate-math loop.
///
/// Splitting tap from drag onto separate surfaces retires the round-3 hazard where a grazing
/// touch on the well fought the keypad: the numeral types, the rule scrubs.
///
/// MATERIALIZE ≠ LOG (the 2026-08-13 parliament's central ruling) is untouched: everything
/// here writes VALUES only. Nothing marks the set performed — the row's explicit Log action
/// owns `isDone`. Ghost rules unchanged: reps ghost = suggestion, else the universal 8;
/// weight ghost = suggestion only (BW on bodyweight movements). Ghosts render `text3` and are
/// never persisted untouched.
struct SetEntryFields: View {
    @Binding var weightKg: Double?
    @Binding var reps: Int?
    var unit: WeightUnit = .kg
    /// Suggested values (from `SetSuggestion`) rendered as ghosts until a real commit, and as
    /// the `○` landmark on the rule.
    var suggestedWeightKg: Double? = nil
    var suggestedReps: Int? = nil
    /// Last session's non-warmup values — the `●` landmark. Measured, so a filled glyph.
    var lastSessionWeightKg: Double? = nil
    var lastSessionReps: Int? = nil
    /// Bodyweight exercise (pull-ups, dips): 0 kg MEANS bodyweight (council ruling,
    /// 2026-08-13) — displayed as BW, never "0 kg"; positive values are ADDED load and
    /// read "+10". nil stays "never entered". The weight ghost defaults to BW.
    var isBodyweight: Bool = false

    var focus: FocusState<SetFocusField?>.Binding? = nil
    var rowId: UUID = UUID()

    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: Which field holds the rule

    /// Bench's one piece of new state: which field is expanded. Never persisted — a set row
    /// always opens on weight, because weight is the number an athlete changes first.
    private enum BenchField { case weight, reps }
    @State private var bench: BenchField = .weight

    // MARK: Inline keypad buffers (round-3 semantics: seeded guard, commit on focus loss)

    @State private var weightText = ""
    @State private var weightSeeded = ""
    @State private var repsText = ""
    @State private var repsSeeded = ""

    // MARK: Scrub state

    private let minReps = 1
    private let maxReps = 30
    /// Points of travel per detent. Round 8 set 44 pt (one thumb-width) on a scrub with NO
    /// visible scale, where the only way to feel control was to make each detent expensive.
    /// The rule shows the landing before you commit to it, so the pitch buys landscape
    /// instead: at 30 pt a full-width rule states ±6 detents at rest.
    private let scrubPitch: CGFloat = 30
    /// Live value while a drag is in progress; the `@Binding` is written only on release.
    /// One set of anchors, because Bench expands exactly one field at a time.
    @State private var dragValue: Double? = nil
    @State private var scrubStartX: CGFloat? = nil
    @State private var scrubBase: Double? = nil
    /// Fractional progress toward the next detent [−0.5, 0.5] — slides the rule continuously
    /// with the finger (round 7: the next number APPROACHES, it doesn't teleport).
    @State private var scrubFraction: CGFloat = 0
    /// True only while a scrub gesture is live. `@GestureState` resets on END **and on
    /// CANCELLATION** — the round-7 "jumps to a random number" bug was a cancelled drag
    /// (the sheet's vertical scroll stealing the touch) leaving `scrubStartX` and the base
    /// anchored to a dead gesture, so the NEXT scrub measured against them.
    @GestureState private var scrubActive = false
    /// D13(a): scrub detents are silent; the ONLY per-adjustment haptic is the bound bump.
    private let limitHaptic = UIImpactFeedbackGenerator(style: .medium)

    private var isEditingWeight: Bool { focus?.wrappedValue == .weight(rowId) }
    private var isEditingReps: Bool { focus?.wrappedValue == .reps(rowId) }
    private var isEditing: Bool { isEditingWeight || isEditingReps }

    // MARK: Derived — weight

    private var increment: Double {
        switch unit {
        case .kg: return 2.5
        case .lbs: return 5
        }
    }

    /// The rule's domain, in DISPLAY units. A plate-loaded lift tops out well below these.
    private var weightRange: ClosedRange<Double> {
        switch unit {
        case .kg: return 0...300
        case .lbs: return 0...660
        }
    }

    private var unitLabel: String {
        switch unit {
        case .kg: return String(localized: "unit.kg", defaultValue: "kg")
        case .lbs: return String(localized: "unit.lb", defaultValue: "lb")
        }
    }

    /// Weight in display units; nil when unset.
    private var weightDisplay: Double? {
        weightKg.map { WeightFormatter.displayValue($0, unit: unit) }
    }

    private var weightGhostDisplay: Double? {
        guard weightKg == nil else { return nil }
        if let s = suggestedWeightKg {
            return WeightFormatter.displayValue(s, unit: unit)
        }
        // A bodyweight movement's natural resting point is BW itself.
        return isBodyweight ? 0 : nil
    }

    /// The reading the weight field shows: live scrub, else committed, else ghost, else the
    /// range floor so the rule always has somewhere to stand.
    private var weightShown: Double {
        (bench == .weight ? dragValue : nil) ?? weightDisplay ?? weightGhostDisplay ?? 0
    }

    private var weightIsGhost: Bool {
        !(bench == .weight && dragValue != nil) && weightKg == nil
    }

    /// The working-voice label for a weight reading: BW for bodyweight-at-zero, a
    /// "+10"-style added-load reading on bodyweight movements, a plain numeral otherwise.
    private func weightLabel(_ display: Double) -> String {
        if isBodyweight {
            if display == 0 {
                return LocalePinnedStrings.localized("setEntry.bw", locale: locale)
            }
            return "+\(fmt(display))"
        }
        return fmt(display)
    }

    /// The unit suffix is noise beside "BW"; show it only for numeric readings.
    private var showsWeightUnit: Bool {
        !(isBodyweight && weightShown == 0)
    }

    // MARK: Derived — reps

    /// The reps reading: live scrub, else committed, else the ghost (suggestion, else
    /// the universal 8 — HAN's rule: every reps well starts somewhere scrubbable).
    private var repsGhost: Int { suggestedReps ?? 8 }
    private var repsShown: Int {
        if bench == .reps, let dragValue { return Int(dragValue.rounded()) }
        return reps ?? repsGhost
    }
    private var repsIsGhost: Bool {
        !(bench == .reps && dragValue != nil) && reps == nil
    }

    /// True on an exercise's very first set: nothing committed, nothing to suggest.
    private var isFirstEver: Bool {
        weightKg == nil && reps == nil && suggestedWeightKg == nil && suggestedReps == nil
    }

    private func fmt(_ v: Double) -> String {
        v == v.rounded() ? String(format: "%.0f", v) : String(format: "%.1f", v)
    }

    private func clamp(_ v: Double, _ r: ClosedRange<Double>) -> Double {
        min(r.upperBound, max(r.lowerBound, v))
    }

    // MARK: Commit (materialize only — the Log action owns isDone)

    private func commitWeight(display: Double) {
        // Typed values keep their meaning; storage rounds to 0.25 in display units.
        // Chips and scrubs arrive pre-snapped to the house increment. On a bodyweight
        // movement, 0 is a REAL statement (BW), never an empty field.
        let rounded = (clamp(display, weightRange) * 4).rounded() / 4
        weightKg = WeightFormatter.toKg(rounded, from: unit)
        weightText = weightLabel(rounded)
        weightSeeded = weightText
    }

    private func commitReps(_ v: Int) {
        let clamped = min(maxReps, max(minReps, v))
        reps = clamped
        repsText = "\(clamped)"
        repsSeeded = repsText
    }

    // MARK: Body

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(alignment: .center, spacing: Spacing.xs) {
                AnnotationLabel(activeFieldLabel, size: .small)
                Spacer(minLength: Spacing.xs)
                waitingField
            }

            plate

            chips

            if isFirstEver {
                // The cold-start answer in words, not blank squares: say what happens
                // instead of implying it.
                Text("setEntry.hint.firstSet")
                    .font(.Tokens.smallLabel)
                    .foregroundStyle(ColorTokens.text2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .animation(Motion.resolved(Motion.state, reduceMotion: reduceMotion), value: reps)
        .animation(Motion.resolved(Motion.state, reduceMotion: reduceMotion), value: weightKg)
        .animation(Motion.resolved(Motion.state, reduceMotion: reduceMotion), value: bench)
        .onChange(of: scrubActive) { _, active in
            if !active { endScrub() }
        }
        // Typing a field is a statement about which field you are working on, so the rule
        // follows the keyboard — including the weight pad's Next, which advances to reps.
        .onChange(of: focus?.wrappedValue) { _, newValue in
            switch newValue {
            case .weight(rowId): bench = .weight
            case .reps(rowId): bench = .reps
            default: break
            }
        }
    }

    private var activeFieldLabel: String {
        switch bench {
        case .weight:
            return "\(LocalePinnedStrings.localized("setEntry.label.weight", locale: locale)) · \(unitLabel)"
        case .reps:
            return LocalePinnedStrings.localized("table.header.reps", locale: locale)
        }
    }

    // MARK: The expanded field — reading over rule

    private var plate: some View {
        VStack(spacing: 0) {
            reading
            rule
        }
        .frame(maxWidth: .infinity)
        .background(ColorTokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: CornerTokens.control))
        .overlay(
            RoundedRectangle(cornerRadius: CornerTokens.control)
                .stroke(isEditing ? ColorTokens.accent : ColorTokens.divider,
                        lineWidth: isEditing ? 1.5 : 0.5)
        )
    }

    /// The reading is the TYPE surface. Tapping it raises the keypad; it never scrubs.
    @ViewBuilder private var reading: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.baselinePair) {
            switch bench {
            case .weight:
                weightInput
                if showsWeightUnit {
                    Text(unitLabel)
                        .font(.Tokens.annoSmall)
                        .foregroundStyle(ColorTokens.text3)
                }
            case .reps:
                repsInput
            }
        }
        .frame(maxWidth: .infinity, minHeight: 48)
        .contentShape(Rectangle())
        .onTapGesture {
            guard let focus else { return }
            focus.wrappedValue = bench == .weight ? .weight(rowId) : .reps(rowId)
        }
    }

    /// The rule is the SCRUB surface. Always drawn, so the landscape exists at rest.
    private var rule: some View {
        ScrubRule(
            range: bench == .weight ? weightRange : Double(minReps)...Double(maxReps),
            step: bench == .weight ? increment : 1,
            value: bench == .weight ? weightShown : Double(repsShown),
            fraction: scrubFraction,
            pitch: scrubPitch,
            majorEvery: 2,
            // A reps rule's floor is 1, so its even numerals sit one detent in.
            majorOffset: bench == .weight ? 0 : 1,
            landmarks: landmarks,
            numeralText: { value in
                bench == .weight ? self.fmt(value) : String(Int(value.rounded()))
            },
            accessibilityLabel: Text(accessibilityLabelText)
        )
        .padding(.bottom, Spacing.xs)
        .contentShape(Rectangle())
        .gesture(scrub)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabelText)
        .accessibilityValue(accessibilityValueText)
        .accessibilityAdjustableAction { direction in
            switch bench {
            case .weight:
                let base = weightDisplay ?? weightGhostDisplay ?? 0
                switch direction {
                case .increment: commitWeight(display: base + increment)
                case .decrement: commitWeight(display: base - increment)
                @unknown default: break
                }
            case .reps:
                switch direction {
                case .increment: commitReps(repsShown + 1)
                case .decrement: commitReps(repsShown - 1)
                @unknown default: break
                }
            }
        }
    }

    /// The values that already mean something on this movement. `●` is measured (last
    /// session), `○` is proposed (the suggestion) — the v6 filled/open distinction.
    private var landmarks: [ScrubRule.Landmark] {
        var marks: [ScrubRule.Landmark] = []
        switch bench {
        case .weight:
            if let suggested = suggestedWeightKg {
                marks.append(.init(
                    value: WeightFormatter.displayValue(suggested, unit: unit),
                    glyph: "○",
                    label: LocalePinnedStrings.localized("setEntry.landmark.target", locale: locale),
                    priority: 1
                ))
            }
            if let last = lastSessionWeightKg {
                marks.append(.init(
                    value: WeightFormatter.displayValue(last, unit: unit),
                    glyph: "●",
                    label: LocalePinnedStrings.localized("setEntry.landmark.last", locale: locale),
                    priority: 2
                ))
            }
        case .reps:
            if let suggested = suggestedReps {
                marks.append(.init(
                    value: Double(suggested),
                    glyph: "○",
                    label: LocalePinnedStrings.localized("setEntry.landmark.target", locale: locale),
                    priority: 1
                ))
            }
            if let last = lastSessionReps {
                marks.append(.init(
                    value: Double(last),
                    glyph: "●",
                    label: LocalePinnedStrings.localized("setEntry.landmark.last", locale: locale),
                    priority: 2
                ))
            }
        }
        return marks
    }

    // MARK: The waiting field

    /// The field that does not hold the rule, as a compact readout. Tapping it hands the rule
    /// over — it does NOT raise the keyboard, so swapping fields never costs a keypad dismiss.
    private var waitingField: some View {
        Button {
            Haptics.select()
            bench = bench == .weight ? .reps : .weight
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                AnnotationLabel(waitingFieldLabel, size: .small)
                Text(waitingFieldValue)
                    .font(.Tokens.sectionHead)
                    .monospacedDigit()
                    .foregroundStyle(waitingFieldIsGhost ? ColorTokens.text3 : ColorTokens.text1)
            }
            .padding(.horizontal, Spacing.xs)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
            .overlay(
                RoundedRectangle(cornerRadius: CornerTokens.control)
                    .stroke(ColorTokens.divider, lineWidth: 0.5)
            )
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(waitingFieldLabel)
        .accessibilityValue(waitingFieldValue)
        .accessibilityHint(Text("setEntry.hint.swapField"))
    }

    private var waitingFieldLabel: String {
        switch bench {
        case .weight: return LocalePinnedStrings.localized("table.header.reps", locale: locale)
        case .reps: return "\(LocalePinnedStrings.localized("setEntry.label.weight", locale: locale)) · \(unitLabel)"
        }
    }

    private var waitingFieldValue: String {
        switch bench {
        case .weight: return "\(reps ?? repsGhost)"
        case .reps: return (weightDisplay ?? weightGhostDisplay).map(weightLabel) ?? "—"
        }
    }

    private var waitingFieldIsGhost: Bool {
        switch bench {
        case .weight: return reps == nil
        case .reps: return weightKg == nil
        }
    }

    // MARK: Chips

    private var chips: some View {
        HStack(spacing: Spacing.baselinePair) {
            if bench == .weight && isBodyweight {
                // One tap back to bodyweight from any added load.
                nudgeChip(label: LocalePinnedStrings.localized("setEntry.bw", locale: locale)) {
                    Haptics.select()
                    commitWeight(display: 0)
                }
            }
            let delta = bench == .weight ? increment : 1
            nudgeChip(label: "−\(fmt(delta))") { nudge(-delta) }
            nudgeChip(label: "＋\(fmt(delta))") { nudge(delta) }
        }
    }

    /// Chips step from committed → ghost → floor and snap onto the house increment grid.
    private func nudge(_ delta: Double) {
        Haptics.select()
        switch bench {
        case .weight:
            let base = weightDisplay ?? weightGhostDisplay ?? 0
            let snapped = WeightFormatter.snapToIncrement(base + delta, to: increment)
            commitWeight(display: snapped)
        case .reps:
            commitReps(repsShown + Int(delta))
        }
    }

    private func nudgeChip(label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.Tokens.label)
                .monospacedDigit()
                .foregroundStyle(ColorTokens.text2)
                .frame(maxWidth: .infinity, minHeight: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .background(ColorTokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: CornerTokens.control))
        .overlay(
            RoundedRectangle(cornerRadius: CornerTokens.control)
                .stroke(ColorTokens.divider, lineWidth: 0.5)
        )
    }

    // MARK: Scrub — one gesture, because Bench expands one field

    /// Direction-locked horizontal drag on the rule. The rule travels WITH the thumb, so a
    /// rightward drag brings lower numbers under the needle — the convention any visible
    /// scale forces, and the one behaviour this redesign inverts. Deaf while a keypad is up
    /// (a grazing touch must never fight typing — round 3's law, carried forward).
    private var scrub: some Gesture {
        DragGesture(minimumDistance: 12)
            .updating($scrubActive) { _, active, _ in active = true }
            .onChanged { g in
                guard !isEditing else { return }
                if scrubStartX == nil {
                    // Horizontal dominance lock: mostly-vertical intent stays with the
                    // sheet's scroll.
                    guard abs(g.translation.width) > abs(g.translation.height) else { return }
                    scrubStartX = g.startLocation.x
                    scrubBase = bench == .weight
                        ? (weightDisplay ?? weightGhostDisplay ?? 0)
                        : Double(reps ?? repsGhost)
                    limitHaptic.prepare()
                }
                guard let base = scrubBase, let startX = scrubStartX else { return }
                let step = bench == .weight ? increment : 1
                let range = bench == .weight
                    ? weightRange
                    : Double(minReps)...Double(maxReps)
                // Negated: the scale follows the thumb.
                let rawSteps = -(g.location.x - startX) / scrubPitch
                let steps = rawSteps.rounded()
                let raw = base + steps * step
                // Past a bound the reading stops but the remainder would keep sliding the
                // rule, so the scale would drift away from a needle that no longer moves.
                let pastFloor = raw <= range.lowerBound && rawSteps < 0
                let pastCeiling = raw >= range.upperBound && rawSteps > 0
                scrubFraction = (pastFloor || pastCeiling)
                    ? 0
                    : min(0.5, max(-0.5, rawSteps - steps))
                let snapped = bench == .weight
                    ? WeightFormatter.snapToIncrement(clamp(raw, range), to: step)
                    : clamp(raw.rounded(), range)
                if snapped != dragValue {
                    let previous = dragValue
                    dragValue = snapped
                    syncBuffer(snapped)
                    let atBound = snapped == range.lowerBound || snapped == range.upperBound
                    if atBound, previous != nil, previous != snapped {
                        limitHaptic.impactOccurred()
                        limitHaptic.prepare()
                    }
                }
            }
            .onEnded { _ in endScrub() }
    }

    /// Commit whatever a terminated scrub previewed and clear every anchor. Runs from
    /// `onEnded` AND from the `@GestureState` reset (cancellation) — nil guards make the
    /// second arrival a no-op.
    private func endScrub() {
        if let v = dragValue {
            switch bench {
            case .weight: commitWeight(display: v)
            case .reps: commitReps(Int(v.rounded()))
            }
        }
        dragValue = nil
        scrubStartX = nil
        scrubBase = nil
        scrubFraction = 0
    }

    private func syncBuffer(_ v: Double) {
        switch bench {
        case .weight: weightText = weightLabel(v)
        case .reps: repsText = "\(Int(v.rounded()))"
        }
    }

    // MARK: Weight input

    @ViewBuilder private var weightInput: some View {
        if let focus {
            TextField(weightFieldPlaceholder, text: $weightText)
                .keyboardType(.decimalPad)
                .focused(focus, equals: .weight(rowId))
                .font(.Tokens.displayAction)
                .monospacedDigit()
                .multilineTextAlignment(.center)
                .fixedSize()
                .foregroundStyle(weightIsGhost && !isEditingWeight ? ColorTokens.text3 : ColorTokens.text1)
                .onChange(of: focus.wrappedValue) { oldValue, newValue in
                    if newValue == .weight(rowId) {
                        // Focus clears the buffer — the prior value ghosts as the
                        // placeholder. Seeding it as TEXT made typing APPEND ("8" →
                        // type 12 → "812"), the classic phantom-value generator.
                        weightText = ""
                        weightSeeded = ""
                    } else if oldValue == .weight(rowId) {
                        // The decimal pad has no return key — focus loss IS the commit
                        // path, guarded so focus-and-dismiss commits nothing.
                        commitTypedWeight()
                        syncWeightWell()
                    }
                }
                .onSubmit { commitWeightAndAdvance() }
                .onAppear { syncWeightWell() }
                .onChange(of: weightKg) { _, _ in if !isEditingWeight { syncWeightWell() } }
                .toolbar {
                    // The decimal pad's missing return key, supplied. Contributed only
                    // while THIS field owns focus so rows never stack duplicates.
                    if isEditingWeight {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button(String(localized: "action.next", defaultValue: "Next")) {
                                commitWeightAndAdvance()
                            }
                            Button(String(localized: "action.done", defaultValue: "Done")) {
                                commitTypedWeight()
                                weightSeeded = weightText
                                focus.wrappedValue = nil
                            }
                        }
                    }
                }
        } else {
            Text(weightLabel(weightShown))
                .font(.Tokens.displayAction)
                .monospacedDigit()
                .foregroundStyle(weightIsGhost ? ColorTokens.text3 : ColorTokens.text1)
        }
    }

    /// Placeholder while focused-empty: the value the athlete is replacing.
    private var weightFieldPlaceholder: String {
        (weightDisplay ?? weightGhostDisplay).map(weightLabel) ?? "—"
    }

    /// Keep the (unfocused) weight buffer showing the committed-else-ghost value.
    private func syncWeightWell() {
        weightText = (weightDisplay ?? weightGhostDisplay).map(weightLabel) ?? ""
    }

    private func commitTypedWeight() {
        guard weightText != weightSeeded,
              let typed = Double(weightText.replacingOccurrences(of: ",", with: ".")) else { return }
        commitWeight(display: typed)
    }

    private func commitWeightAndAdvance() {
        commitTypedWeight()
        weightSeeded = weightText
        bench = .reps
        focus?.wrappedValue = .reps(rowId)
    }

    // MARK: Reps input

    @ViewBuilder private var repsInput: some View {
        if let focus {
            TextField("\(repsShown)", text: $repsText)
                .keyboardType(.numberPad)
                .focused(focus, equals: .reps(rowId))
                .font(.Tokens.displayAction)
                .monospacedDigit()
                .multilineTextAlignment(.center)
                .fixedSize()
                .foregroundStyle(repsIsGhost && !isEditingReps ? ColorTokens.text3 : ColorTokens.text1)
                .onChange(of: focus.wrappedValue) { oldValue, newValue in
                    if newValue == .reps(rowId) {
                        repsText = ""
                        repsSeeded = ""
                    } else if oldValue == .reps(rowId) {
                        if repsText != repsSeeded, let typed = Int(repsText) {
                            commitReps(typed)
                        }
                        syncRepsWell()
                    }
                }
                .onSubmit { commitRepsKeypad() }
                .onAppear { syncRepsWell() }
                .onChange(of: reps) { _, _ in if !isEditingReps { syncRepsWell() } }
                .toolbar {
                    if isEditingReps {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button(String(localized: "action.done", defaultValue: "Done")) {
                                commitRepsKeypad()
                            }
                        }
                    }
                }
        } else {
            Text("\(repsShown)")
                .font(.Tokens.displayAction)
                .monospacedDigit()
                .contentTransition(.numericText())
                .foregroundStyle(repsIsGhost ? ColorTokens.text3 : ColorTokens.text1)
                .animation(Motion.resolved(Motion.digitRoll, reduceMotion: reduceMotion), value: repsShown)
        }
    }

    /// Keep the (unfocused) reps buffer showing the committed-else-ghost value.
    private func syncRepsWell() {
        repsText = "\(reps ?? repsGhost)"
    }

    private func commitRepsKeypad() {
        if repsText != repsSeeded, let typed = Int(repsText) {
            commitReps(typed)
        }
        repsSeeded = repsText
        focus?.wrappedValue = nil
    }

    // MARK: Accessibility

    private var accessibilityLabelText: String {
        switch bench {
        case .weight: return String(localized: "setEntry.label.weight", defaultValue: "Weight")
        case .reps: return String(localized: "repScrubber.accessibility", defaultValue: "Reps")
        }
    }

    private var accessibilityValueText: String {
        switch bench {
        case .weight:
            switch unit {
            case .kg:
                return String(format: String(localized: "weightPicker.value.kg.accessibility", defaultValue: "%@ kilograms"), fmt(weightShown))
            case .lbs:
                return String(format: String(localized: "weightPicker.value.lb.accessibility", defaultValue: "%@ pounds"), fmt(weightShown))
            }
        case .reps:
            return String(format: String(localized: "repScrubber.value.accessibility", defaultValue: "%d reps"), repsShown)
        }
    }
}
