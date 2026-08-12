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

/// Field-first set entry — HAN-gated variant C of the 2026-08-12 design demos.
///
/// Two large LABELED wells, typing primary (commit-on-focus-loss + keyboard Done/Next,
/// the round-3 reliability semantics), plus:
/// - weight: two nudge chips that STATE their own delta ("−2.5 kg" / "＋2.5 kg") —
///   replacing the three unlabeled tiles whose blank cold-start read as mystery squares;
/// - reps: a numbered TAPE — the numerals themselves ride under a fixed accent needle,
///   the current one enlarged in ink, mirrored live into the reps well while dragging —
///   replacing the bare axis nobody could read (HAN UAT round 3).
///
/// Commit semantics are unchanged from the retired components: a commit from any path
/// (typing, chip, tape) calls `onCommit`, which marks the set done — the established
/// isDone persistence gate. Typed weights are kept as typed (rounded to 0.25 kg), only
/// the CHIPS walk the house increment grid; snapping what the athlete typed is hostile.
struct SetEntryFields: View {
    @Binding var weightKg: Double?
    @Binding var reps: Int?
    var unit: WeightUnit = .kg
    /// Suggested values (from `SetSuggestion`) rendered as ghosts until a real commit.
    var suggestedWeightKg: Double? = nil
    var suggestedReps: Int? = nil
    /// Called on every real commit — marks the set done (established gate).
    var onCommit: () -> Void = {}

    var focus: FocusState<SetFocusField?>.Binding? = nil
    var rowId: UUID = UUID()

    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: Inline keypad buffers (round-3 semantics: seeded guard, commit on focus loss)

    @State private var weightText = ""
    @State private var weightSeeded = ""
    @State private var repsText = ""
    @State private var repsSeeded = ""

    // MARK: Tape state

    private let minReps = 1
    private let maxReps = 30
    private let tapePitch: CGFloat = 44
    /// Live drag value while a tape drag is in progress; isolated so per-pixel motion
    /// never writes the SwiftData `@Binding`.
    @State private var dragValue: Int? = nil
    @State private var dragStartValue: Int? = nil
    @State private var dragStartX: CGFloat? = nil
    /// D13(a): silent detents; the ONLY per-adjustment haptic is the 1/30 limit bump.
    private let limitHaptic = UIImpactFeedbackGenerator(style: .medium)

    private var isEditingWeight: Bool { focus?.wrappedValue == .weight(rowId) }
    private var isEditingReps: Bool { focus?.wrappedValue == .reps(rowId) }

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
        guard weightKg == nil, let s = suggestedWeightKg else { return nil }
        return WeightFormatter.displayValue(s, unit: unit)
    }

    /// The value the tape needle sits on: live drag, else committed, else ghost, else a
    /// mid-range resting point (8 — starting a first drag from 1 makes every set a
    /// cross-country journey).
    private var tapeValue: Int {
        dragValue ?? reps ?? suggestedReps ?? 8
    }

    private var repsIsGhost: Bool { dragValue == nil && reps == nil && suggestedReps != nil }
    private var weightIsGhost: Bool { weightKg == nil && weightGhostDisplay != nil }

    /// True on an exercise's very first set: nothing committed, nothing to suggest.
    private var isFirstEver: Bool {
        weightKg == nil && reps == nil && suggestedWeightKg == nil && suggestedReps == nil
    }

    private func fmt(_ v: Double) -> String {
        v == v.rounded() ? String(format: "%.0f", v) : String(format: "%.1f", v)
    }

    // MARK: Commit

    private func commitWeight(display: Double) {
        // Typed/chip values keep their meaning; storage rounds to 0.25 in display units.
        let rounded = (max(0, display) * 4).rounded() / 4
        weightKg = WeightFormatter.toKg(rounded, from: unit)
        if isEditingWeight {
            weightText = fmt(rounded)
            weightSeeded = weightText
        }
        onCommit()
    }

    private func commitReps(_ v: Int) {
        let clamped = min(maxReps, max(minReps, v))
        reps = clamped
        if isEditingReps {
            repsText = "\(clamped)"
            repsSeeded = repsText
        }
        onCommit()
    }

    // MARK: Body

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(alignment: .top, spacing: Spacing.xs) {
                weightField
                repsField
            }

            tape

            if isFirstEver {
                // The cold-start answer in words, not blank squares (variant B's lesson,
                // kept in C): say what happens instead of implying it.
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
                HStack(alignment: .firstTextBaseline, spacing: Spacing.baselinePair) {
                    weightInput
                    Text(unitLabel)
                        .font(.Tokens.annoSmall)
                        .foregroundStyle(ColorTokens.text3)
                }
            }
            HStack(spacing: Spacing.baselinePair) {
                nudgeChip(label: "−\(fmt(increment))") { nudgeWeight(-increment) }
                nudgeChip(label: "＋\(fmt(increment))") { nudgeWeight(increment) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private var weightInput: some View {
        if let focus {
            TextField("—", text: $weightText)
                .keyboardType(.decimalPad)
                .focused(focus, equals: .weight(rowId))
                .font(.Tokens.displayAction)
                .monospacedDigit()
                .multilineTextAlignment(.center)
                .foregroundStyle(weightIsGhost && !isEditingWeight ? ColorTokens.text3 : ColorTokens.text1)
                .onChange(of: focus.wrappedValue) { oldValue, newValue in
                    if newValue == .weight(rowId) {
                        weightText = weightDisplay.map(fmt) ?? ""
                        weightSeeded = weightText
                    } else if oldValue == .weight(rowId) {
                        // Round 3: the decimal pad has no return key — focus loss IS the
                        // commit path, guarded so focus-and-dismiss commits nothing.
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
            Text(weightDisplay.map(fmt) ?? weightGhostDisplay.map(fmt) ?? "—")
                .font(.Tokens.displayAction)
                .monospacedDigit()
                .foregroundStyle(weightIsGhost ? ColorTokens.text3 : ColorTokens.text1)
        }
    }

    /// Keep the (unfocused) weight buffer showing the committed-else-ghost value.
    private func syncWeightWell() {
        weightText = weightDisplay.map(fmt) ?? weightGhostDisplay.map(fmt) ?? ""
    }

    private func commitWeightAndAdvance() {
        if let typed = Double(weightText.replacingOccurrences(of: ",", with: ".")) {
            commitWeight(display: typed)
        }
        weightSeeded = weightText
        focus?.wrappedValue = .reps(rowId)
    }

    /// Chips step from committed → ghost → zero (bodyweight is a legal base) and snap
    /// onto the house increment grid — the chips are the plate-math path, typing is not.
    private func nudgeWeight(_ delta: Double) {
        let base = weightDisplay ?? weightGhostDisplay ?? 0
        let snapped = WeightFormatter.snapToIncrement(base + delta, to: increment)
        Haptics.select()
        commitWeight(display: max(0, snapped))
    }

    // MARK: Reps field

    private var repsField: some View {
        VStack(alignment: .leading, spacing: Spacing.baselinePair) {
            AnnotationLabel(
                LocalePinnedStrings.localized("table.header.reps", locale: locale),
                size: .small
            )
            well(isFocused: isEditingReps) {
                repsInput
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private var repsInput: some View {
        if let focus {
            TextField("—", text: $repsText)
                .keyboardType(.numberPad)
                .focused(focus, equals: .reps(rowId))
                .font(.Tokens.displayAction)
                .monospacedDigit()
                .multilineTextAlignment(.center)
                .foregroundStyle(repsIsGhost && !isEditingReps ? ColorTokens.text3 : ColorTokens.text1)
                .onChange(of: focus.wrappedValue) { oldValue, newValue in
                    if newValue == .reps(rowId) {
                        repsText = (reps ?? suggestedReps).map { "\($0)" } ?? ""
                        repsSeeded = repsText
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
                .onChange(of: dragValue) { _, newValue in
                    // The live mirror: the well shows every tape movement as it happens.
                    if let v = newValue, !isEditingReps { repsText = "\(v)" }
                }
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
            Text(dragValue.map { "\($0)" } ?? (reps ?? suggestedReps).map { "\($0)" } ?? "—")
                .font(.Tokens.displayAction)
                .monospacedDigit()
                .contentTransition(.numericText())
                .foregroundStyle(repsIsGhost ? ColorTokens.text3 : ColorTokens.text1)
                .animation(Motion.resolved(Motion.digitRoll, reduceMotion: reduceMotion), value: dragValue)
        }
    }

    private func syncRepsWell() {
        repsText = (reps ?? suggestedReps).map { "\($0)" } ?? ""
    }

    private func commitRepsKeypad() {
        if let typed = Int(repsText) {
            commitReps(typed)
        }
        repsSeeded = repsText
        focus?.wrappedValue = nil
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

    // MARK: Tape

    /// The numbered tape: numerals ride at fixed pitch under a fixed accent needle in
    /// the tick zone (never through the digits), current numeral enlarged in ink,
    /// neighbours in `text3`, edges faded. Detents are silent; the only haptic is the
    /// limit bump on newly reaching 1 or 30 (D13(a)).
    private var tape: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let center = width / 2
            // Half-pitch correction: cell n's CENTER (not its left edge) sits under the needle.
            let offset = center - CGFloat(tapeValue - minReps) * tapePitch - tapePitch / 2

            ZStack(alignment: .bottomLeading) {
                HStack(spacing: 0) {
                    ForEach(minReps...maxReps, id: \.self) { n in
                        VStack(spacing: Spacing.baselinePair) {
                            Text("\(n)")
                                .font(n == tapeValue ? .Tokens.bodyMedium : .Tokens.smallLabel)
                                .monospacedDigit()
                                .foregroundStyle(tapeNumeralColor(n))
                            Rectangle()
                                .fill(n == tapeValue ? ColorTokens.text1 : ColorTokens.dividerStrong)
                                .frame(width: n == tapeValue ? 1.5 : 0.5,
                                       height: n == tapeValue ? 12 : 8)
                        }
                        .frame(width: tapePitch)
                    }
                }
                .offset(x: offset)
                .animation(
                    dragValue == nil ? Motion.resolved(Motion.state, reduceMotion: reduceMotion) : nil,
                    value: tapeValue
                )

                // Fixed needle in the tick zone — accent, the live-state mark.
                Rectangle()
                    .fill(ColorTokens.accent)
                    .frame(width: 2, height: 16)
                    .offset(x: center - 1)
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
            .contentShape(Rectangle())
            // Edge fade so the tape reads as a strip passing a window, not a row of chips.
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black, location: 0.12),
                        .init(color: .black, location: 0.88),
                        .init(color: .clear, location: 1)
                    ],
                    startPoint: .leading, endPoint: .trailing
                )
            )
            // Deaf while the keypad is up (round 3): a grazing touch must never fight typing.
            .allowsHitTesting(!isEditingReps && !isEditingWeight)
            .gesture(
                DragGesture(minimumDistance: 8)
                    .onChanged { g in
                        if dragStartX == nil {
                            dragStartX = g.startLocation.x
                            dragStartValue = tapeValue
                            limitHaptic.prepare()
                        }
                        guard let startValue = dragStartValue else { return }
                        // The tape moves WITH the finger: drag left → higher numbers.
                        let dx = g.location.x - (dragStartX ?? g.location.x)
                        let v = min(maxReps, max(minReps, startValue - Int((dx / tapePitch).rounded())))
                        if v != dragValue {
                            let previous = dragValue
                            dragValue = v
                            if (v == minReps || v == maxReps) && v != previous {
                                limitHaptic.impactOccurred()
                                limitHaptic.prepare()
                            }
                        }
                    }
                    .onEnded { _ in
                        if let v = dragValue { commitReps(v) }
                        dragValue = nil
                        dragStartValue = nil
                        dragStartX = nil
                    }
            )
        }
        .frame(height: 48)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "repScrubber.accessibility", defaultValue: "Reps"))
        .accessibilityValue(
            (dragValue ?? reps ?? suggestedReps).map {
                String(format: String(localized: "repScrubber.value.accessibility", defaultValue: "%d reps"), $0)
            } ?? String(localized: "repScrubber.unset.accessibility", defaultValue: "No reps set")
        )
        .accessibilityAdjustableAction { direction in
            let base = reps ?? suggestedReps ?? 8
            switch direction {
            case .increment: commitReps(base + 1)
            case .decrement: commitReps(base - 1)
            @unknown default: break
            }
        }
    }

    private func tapeNumeralColor(_ n: Int) -> Color {
        if n == tapeValue {
            return repsIsGhost ? ColorTokens.text3 : ColorTokens.text1
        }
        return ColorTokens.text3
    }
}
