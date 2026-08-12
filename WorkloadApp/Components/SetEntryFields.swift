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

/// Field-first set entry — the 2026-08-13 parliament spec (Codex + Grok, chaired).
///
/// Two large LABELED wells, and exactly three ways in, none provenance-dependent:
/// - **Tap → type.** Always the primary, visible path. Focus clears the buffer and the
///   prior value ghosts as the placeholder, so typing never appends to a seeded digit.
///   Commit on focus loss / toolbar Done / Next (round-3 reliability semantics).
/// - **Scrub the well.** Direction-locked horizontal drag anywhere on either well —
///   HAN's "scroll inside the box", adopted as a universal accelerator (never gated on
///   history). Detents: the house weight increment (2.5 kg / 5 lb) and 1 rep per 24 pt.
///   The numbered tape is retired; the well itself is the scrubber.
/// - **Weight chips.** −/＋ one increment; self-explanatory, kept for the plate-math loop.
///
/// MATERIALIZE ≠ LOG (the parliament's central ruling): everything above writes VALUES
/// only. Nothing here marks the set performed — the row's explicit Log action owns
/// `isDone`. Ghost rules: reps ghost = suggestion, else the universal 8; weight ghost =
/// suggestion only. Ghosts render `text3` and are never persisted untouched.
struct SetEntryFields: View {
    @Binding var weightKg: Double?
    @Binding var reps: Int?
    var unit: WeightUnit = .kg
    /// Suggested values (from `SetSuggestion`) rendered as ghosts until a real commit.
    var suggestedWeightKg: Double? = nil
    var suggestedReps: Int? = nil
    /// Bodyweight exercise (pull-ups, dips): 0 kg MEANS bodyweight (council ruling,
    /// 2026-08-13) — displayed as BW, never "0 kg"; positive values are ADDED load and
    /// read "+10". nil stays "never entered". The weight ghost defaults to BW.
    var isBodyweight: Bool = false

    var focus: FocusState<SetFocusField?>.Binding? = nil
    var rowId: UUID = UUID()

    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: Inline keypad buffers (round-3 semantics: seeded guard, commit on focus loss)

    @State private var weightText = ""
    @State private var weightSeeded = ""
    @State private var repsText = ""
    @State private var repsSeeded = ""

    // MARK: Scrub state (live values while a drag is in progress; the SwiftData
    // @Binding is written only on release)

    private let minReps = 1
    private let maxReps = 30
    /// Points of horizontal travel per detent.
    private let scrubPitch: CGFloat = 24
    @State private var dragWeight: Double? = nil
    @State private var dragReps: Int? = nil
    @State private var scrubStartX: CGFloat? = nil
    @State private var scrubBaseWeight: Double? = nil
    @State private var scrubBaseReps: Int? = nil
    /// Fractional progress toward the next detent [−0.5, 0.5] — slides the preview
    /// tape continuously with the finger (round 7: the next number APPROACHES, it
    /// doesn't teleport).
    @State private var scrubFraction: CGFloat = 0
    /// True only while a scrub gesture is live. `@GestureState` resets on END **and on
    /// CANCELLATION** — the round-7 "jumps to a random number" bug was a cancelled drag
    /// (the sheet's vertical scroll stealing the touch) leaving `scrubStartX` and the
    /// base anchored to a dead gesture, so the NEXT scrub measured against them.
    @GestureState private var weightScrubActive = false
    @GestureState private var repsScrubActive = false
    /// D13(a): scrub detents are silent; the ONLY per-adjustment haptic is the bound bump.
    private let limitHaptic = UIImpactFeedbackGenerator(style: .medium)

    /// Commit whatever a terminated weight scrub previewed and clear every anchor.
    /// Runs from `onEnded` AND from the `@GestureState` reset (cancellation) — nil
    /// guards make the second arrival a no-op.
    private func endWeightScrub() {
        if let v = dragWeight { commitWeight(display: v) }
        dragWeight = nil
        scrubStartX = nil
        scrubBaseWeight = nil
        scrubFraction = 0
    }

    private func endRepsScrub() {
        if let v = dragReps { commitReps(v) }
        dragReps = nil
        scrubStartX = nil
        scrubBaseReps = nil
        scrubFraction = 0
    }

    private var isEditingWeight: Bool { focus?.wrappedValue == .weight(rowId) }
    private var isEditingReps: Bool { focus?.wrappedValue == .reps(rowId) }
    private var isEditing: Bool { isEditingWeight || isEditingReps }

    // MARK: Derived

    private var increment: Double {
        switch unit {
        case .kg: return 2.5
        case .lbs: return 5
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
        let current = dragWeight ?? weightDisplay ?? weightGhostDisplay
        return !(isBodyweight && current == 0)
    }

    /// The reps reading: live scrub, else committed, else the ghost (suggestion, else
    /// the universal 8 — HAN's rule: every reps well starts somewhere scrubbable).
    private var repsGhost: Int { suggestedReps ?? 8 }
    private var repsShown: Int { dragReps ?? reps ?? repsGhost }

    private var repsIsGhost: Bool { dragReps == nil && reps == nil }
    private var weightIsGhost: Bool { dragWeight == nil && weightKg == nil }

    /// True on an exercise's very first set: nothing committed, nothing to suggest.
    private var isFirstEver: Bool {
        weightKg == nil && reps == nil && suggestedWeightKg == nil && suggestedReps == nil
    }

    private func fmt(_ v: Double) -> String {
        v == v.rounded() ? String(format: "%.0f", v) : String(format: "%.1f", v)
    }

    // MARK: Commit (materialize only — the Log action owns isDone)

    private func commitWeight(display: Double) {
        // Typed values keep their meaning; storage rounds to 0.25 in display units.
        // Chips and scrubs arrive pre-snapped to the house increment. On a bodyweight
        // movement, 0 is a REAL statement (BW), never an empty field.
        let rounded = (max(0, display) * 4).rounded() / 4
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
            HStack(alignment: .top, spacing: Spacing.xs) {
                weightField
                repsField
            }

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
    }

    // MARK: Weight field

    private var weightField: some View {
        VStack(alignment: .leading, spacing: Spacing.baselinePair) {
            AnnotationLabel(
                "\(LocalePinnedStrings.localized("setEntry.label.weight", locale: locale)) · \(unitLabel)",
                size: .small
            )
            well(isFocused: isEditingWeight) {
                if let dragging = dragWeight {
                    // Scrub tape (rounds 6–7, HAN): the neighbouring detents ride a
                    // strip that slides WITH the finger, so the next number visibly
                    // approaches and takes over at the crossing.
                    scrubTape(
                        labels: (-2...2).map { step -> String? in
                            let v = dragging + Double(step) * increment
                            return v >= 0 ? weightLabel(v) : nil
                        },
                        fraction: scrubFraction
                    )
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: Spacing.baselinePair) {
                        weightInput
                        if showsWeightUnit {
                            Text(unitLabel)
                                .font(.Tokens.annoSmall)
                                .foregroundStyle(ColorTokens.text3)
                        }
                    }
                }
            }
            .gesture(weightScrub)
            .onChange(of: weightScrubActive) { _, active in
                if !active { endWeightScrub() }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(String(localized: "setEntry.label.weight", defaultValue: "Weight"))
            .accessibilityValue(weightAccessibilityValue)
            .accessibilityAdjustableAction { direction in
                let base = weightDisplay ?? weightGhostDisplay ?? 0
                switch direction {
                case .increment: commitWeight(display: base + increment)
                case .decrement: commitWeight(display: max(0, base - increment))
                @unknown default: break
                }
            }
            HStack(spacing: Spacing.baselinePair) {
                if isBodyweight {
                    // One tap back to bodyweight from any added load.
                    nudgeChip(label: LocalePinnedStrings.localized("setEntry.bw", locale: locale)) {
                        Haptics.select()
                        commitWeight(display: 0)
                    }
                }
                nudgeChip(label: "−\(fmt(increment))") { nudgeWeight(-increment) }
                nudgeChip(label: "＋\(fmt(increment))") { nudgeWeight(increment) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var weightAccessibilityValue: String {
        let display = dragWeight ?? weightDisplay ?? weightGhostDisplay
        guard let display else {
            return String(localized: "weightPicker.unset.accessibility", defaultValue: "No weight set")
        }
        switch unit {
        case .kg:
            return String(format: String(localized: "weightPicker.value.kg.accessibility", defaultValue: "%@ kilograms"), fmt(display))
        case .lbs:
            return String(format: String(localized: "weightPicker.value.lb.accessibility", defaultValue: "%@ pounds"), fmt(display))
        }
    }

    @ViewBuilder private var weightInput: some View {
        if let focus {
            TextField(weightFieldPlaceholder, text: $weightText)
                .keyboardType(.decimalPad)
                .focused(focus, equals: .weight(rowId))
                .font(.Tokens.displayAction)
                .monospacedDigit()
                .multilineTextAlignment(.center)
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
                        if weightText != weightSeeded,
                           let typed = Double(weightText.replacingOccurrences(of: ",", with: ".")) {
                            commitWeight(display: typed)
                        }
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
                                if weightText != weightSeeded,
                                   let typed = Double(weightText.replacingOccurrences(of: ",", with: ".")) {
                                    commitWeight(display: typed)
                                }
                                weightSeeded = weightText
                                focus.wrappedValue = nil
                            }
                        }
                    }
                }
        } else {
            Text((dragWeight ?? weightDisplay ?? weightGhostDisplay).map(weightLabel) ?? "—")
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

    private func commitWeightAndAdvance() {
        if weightText != weightSeeded,
           let typed = Double(weightText.replacingOccurrences(of: ",", with: ".")) {
            commitWeight(display: typed)
        }
        weightSeeded = weightText
        focus?.wrappedValue = .reps(rowId)
    }

    /// Chips step from committed → ghost → zero (bodyweight is a legal base) and snap
    /// onto the house increment grid.
    private func nudgeWeight(_ delta: Double) {
        let base = weightDisplay ?? weightGhostDisplay ?? 0
        let snapped = WeightFormatter.snapToIncrement(base + delta, to: increment)
        Haptics.select()
        commitWeight(display: max(0, snapped))
    }

    /// HAN's "scroll inside the box": direction-locked horizontal drag, one house
    /// increment per detent. Deaf while any keypad is up (a grazing touch must never
    /// fight typing — round 3's law, carried forward).
    private var weightScrub: some Gesture {
        DragGesture(minimumDistance: 12)
            .updating($weightScrubActive) { _, active, _ in active = true }
            .onChanged { g in
                guard !isEditing else { return }
                if scrubStartX == nil {
                    // Horizontal dominance lock: mostly-vertical intent stays with the
                    // sheet's scroll.
                    guard abs(g.translation.width) > abs(g.translation.height) else { return }
                    scrubStartX = g.startLocation.x
                    scrubBaseWeight = weightDisplay ?? weightGhostDisplay ?? 0
                    limitHaptic.prepare()
                }
                guard let base = scrubBaseWeight, let startX = scrubStartX else { return }
                let rawSteps = (g.location.x - startX) / scrubPitch
                let steps = rawSteps.rounded()
                scrubFraction = min(0.5, max(-0.5, rawSteps - steps))
                let raw = max(0, base + Double(steps) * increment)
                let snapped = WeightFormatter.snapToIncrement(raw, to: increment)
                if snapped != dragWeight {
                    let previous = dragWeight
                    dragWeight = snapped
                    weightText = weightLabel(snapped)
                    if snapped == 0 && previous != 0 && previous != nil {
                        limitHaptic.impactOccurred()
                        limitHaptic.prepare()
                    }
                }
            }
            .onEnded { _ in endWeightScrub() }
    }

    // MARK: Reps field

    private var repsField: some View {
        VStack(alignment: .leading, spacing: Spacing.baselinePair) {
            AnnotationLabel(
                LocalePinnedStrings.localized("table.header.reps", locale: locale),
                size: .small
            )
            well(isFocused: isEditingReps) {
                if let dragging = dragReps {
                    scrubTape(
                        labels: (-2...2).map { step -> String? in
                            let v = dragging + step
                            return (minReps...maxReps).contains(v) ? "\(v)" : nil
                        },
                        fraction: scrubFraction
                    )
                } else {
                    repsInput
                }
            }
            .gesture(repsScrub)
            .onChange(of: repsScrubActive) { _, active in
                if !active { endRepsScrub() }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(String(localized: "repScrubber.accessibility", defaultValue: "Reps"))
            .accessibilityValue(
                String(format: String(localized: "repScrubber.value.accessibility", defaultValue: "%d reps"), repsShown)
            )
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: commitReps(repsShown + 1)
                case .decrement: commitReps(repsShown - 1)
                @unknown default: break
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private var repsInput: some View {
        if let focus {
            TextField("\(repsShown)", text: $repsText)
                .keyboardType(.numberPad)
                .focused(focus, equals: .reps(rowId))
                .font(.Tokens.displayAction)
                .monospacedDigit()
                .multilineTextAlignment(.center)
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

    private var repsScrub: some Gesture {
        DragGesture(minimumDistance: 12)
            .updating($repsScrubActive) { _, active, _ in active = true }
            .onChanged { g in
                guard !isEditing else { return }
                if scrubStartX == nil {
                    guard abs(g.translation.width) > abs(g.translation.height) else { return }
                    scrubStartX = g.startLocation.x
                    scrubBaseReps = reps ?? repsGhost
                    limitHaptic.prepare()
                }
                guard let base = scrubBaseReps, let startX = scrubStartX else { return }
                let rawSteps = (g.location.x - startX) / scrubPitch
                let steps = rawSteps.rounded()
                scrubFraction = min(0.5, max(-0.5, rawSteps - steps))
                let v = min(maxReps, max(minReps, base + Int(steps)))
                if v != dragReps {
                    let previous = dragReps
                    dragReps = v
                    repsText = "\(v)"
                    if (v == minReps || v == maxReps) && v != previous {
                        limitHaptic.impactOccurred()
                        limitHaptic.prepare()
                    }
                }
            }
            .onEnded { _ in endRepsScrub() }
    }

    // MARK: Scrub tape

    /// Cell pitch of the in-well preview tape.
    private let tapeCellWidth: CGFloat = 64

    /// The approach indicator (rounds 6–7, HAN): five detents on a strip that slides
    /// continuously with the finger — `labels[2]` is the live detent, enlarged in ink;
    /// neighbours are smaller `text3` at half opacity. The fractional drag remainder
    /// offsets the strip, so "6" visibly approaches while "5" is still current and the
    /// emphasis hands over exactly at the crossing. Out-of-range slots are blank.
    private func scrubTape(labels: [String?], fraction: CGFloat) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(labels.enumerated()), id: \.offset) { index, label in
                Text(label ?? " ")
                    .font(index == 2 ? .Tokens.displayAction : .Tokens.label)
                    .foregroundStyle(index == 2 ? ColorTokens.text1 : ColorTokens.text3)
                    .opacity(label == nil ? 0 : (index == 2 ? 1 : 0.55))
                    .frame(width: tapeCellWidth)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
        .monospacedDigit()
        .offset(x: -fraction * tapeCellWidth)
        .frame(maxWidth: .infinity)
        .clipped()
        .transition(.opacity)
    }

    // MARK: Shared well

    /// The input well: flat surface + hairline (the flattened-cell direction, HAN
    /// 2026-08-05), control-radius corners, an inset accent ring ONLY while its field
    /// owns the keyboard (accent = live state, its exclusive territory).
    private func well<Content: View>(isFocused: Bool, @ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(ColorTokens.surface)
            .clipShape(RoundedRectangle(cornerRadius: CornerTokens.control))
            .overlay(
                RoundedRectangle(cornerRadius: CornerTokens.control)
                    .stroke(isFocused ? ColorTokens.accent : ColorTokens.divider,
                            lineWidth: isFocused ? 1.5 : 0.5)
            )
            .contentShape(Rectangle())
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
}
