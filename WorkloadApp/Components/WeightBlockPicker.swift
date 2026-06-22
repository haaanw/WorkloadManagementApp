import SwiftUI

/// Identifies which inline keypad field in a single `.weightReps` set row currently
/// holds focus. Lets the weight keypad advance to the reps keypad without dismiss /
/// re-summon (proposal §5.5 in-flow focus advance). Hashable + per-row `id` so the same
/// enum can disambiguate multiple rows sharing one `@FocusState`.
enum SetFocusField: Hashable {
    case weight(UUID)
    case reps(UUID)
}

/// Three-tile weight picker for the weight/reps set row (proposal §3).
///
/// Layout: a live value readout above a horizontal cluster of three equal 48×48pt
/// `Rectangle` tiles `[ lighter | CENTER | heavier ]`, plus a distinct trailing
/// "type" affordance that opens the decimal keypad for big jumps.
///
/// LOCKED DECISIONS (Tuwa v2 — accent now marks live / active state):
/// - Selected-center cue = ACCENT: the center tile fills `accentSubtle` with a 1pt inset
///   `accent` edge and an `accent` Medium / larger / `.monospacedDigit()` numeral; the side
///   tiles fill `surface` with `text2` Regular / smaller numerals. The center is the active
///   selection, so it carries the accent (the sanctioned active-cell treatment).
/// - Commit-on-tap: tapping the center commits the centered weight; tapping a side tile
///   commits-and-recenters around it. The per-set `isDone` toggle (Phase A) is the real
///   persistence gate, so accidental taps are harmless until the set is marked done.
///
/// Values are computed in the user's DISPLAY unit (kg / lb), snapped to the house
/// increment (2.5 kg / 5 lb), and converted back to kg on commit via `WeightFormatter`.
struct WeightBlockPicker: View {
    /// Bound stored weight in KG (nil = unset / first-ever).
    @Binding var weightKg: Double?
    var unit: WeightUnit = .kg
    /// Suggested center in KG when `weightKg` is nil (from `SetSuggestion`). May be nil.
    var suggestedCenterKg: Double? = nil
    /// Called when the user commits a weight by tapping a tile (a real user weight commit).
    var onCommit: () -> Void = {}

    // MARK: In-flow keypad focus chain (proposal §5.5)
    /// Shared focus across the row's weight + reps inline keypads. Tapping the "type"
    /// affordance focuses `.weight(rowId)`; on commit we advance to `.reps(rowId)` so
    /// weight → reps flows without dismissing/re-summoning the keyboard.
    var focus: FocusState<SetFocusField?>.Binding? = nil
    /// Stable id of the owning set row (disambiguates focus across rows).
    var rowId: UUID = UUID()
    /// Advance target after a weight keypad commit (the reps field of the same row).
    var advanceTo: SetFocusField? = nil

    /// Inline keypad text buffer; committed on submit / focus loss.
    @State private var keypadText = ""
    /// Alert fallback when no focus chain is wired (e.g. previews / standalone use).
    @State private var showKeypad = false

    // MARK: Increment / values (display unit)

    /// House increment in the display unit: 2.5 kg or 5 lb.
    private var increment: Double {
        switch unit {
        case .kg: return 2.5
        case .lbs: return 5
        }
    }

    /// The current center in DISPLAY units, snapped. nil when there is nothing to show
    /// (no committed weight AND no suggestion) → cold-start placeholder.
    private var centerDisplay: Double? {
        let kg = weightKg ?? suggestedCenterKg
        guard let kg else { return nil }
        return WeightFormatter.snapToIncrement(WeightFormatter.displayValue(kg, unit: unit), to: increment)
    }

    private var lighterDisplay: Double? {
        guard let c = centerDisplay else { return nil }
        return max(0, c - increment)
    }

    private var heavierDisplay: Double? {
        guard let c = centerDisplay else { return nil }
        return c + increment
    }

    /// Cold start: nothing committed and no suggestion to center on.
    private var isUnset: Bool { centerDisplay == nil }

    private var unitLabel: String {
        switch unit {
        case .kg: return String(localized: "unit.kg", defaultValue: "kg")
        case .lbs: return String(localized: "unit.lb", defaultValue: "lb")
        }
    }

    // MARK: Format

    private func numeralString(_ value: Double) -> String {
        // Whole increments render without a trailing ".0"; halves keep one digit.
        if value == value.rounded() {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }

    /// VoiceOver-friendly full-words value, e.g. "sixty kilograms".
    private func accessibilityValueString(_ display: Double?) -> String {
        guard let display else {
            return String(localized: "weightPicker.unset.accessibility", defaultValue: "No weight set")
        }
        let n = numeralString(display)
        switch unit {
        case .kg:
            return String(format: String(localized: "weightPicker.value.kg.accessibility", defaultValue: "%@ kilograms"), n)
        case .lbs:
            return String(format: String(localized: "weightPicker.value.lb.accessibility", defaultValue: "%@ pounds"), n)
        }
    }

    // MARK: Commit

    private func commit(_ display: Double) {
        let snapped = WeightFormatter.snapToIncrement(display, to: increment)
        weightKg = WeightFormatter.toKg(max(0, snapped), from: unit)
        Haptics.select()
        onCommit()
    }

    // MARK: Body

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Live readout above the cluster (display-over-control).
            HStack(spacing: Spacing.baselinePair) {
                Text(centerDisplay.map(numeralString) ?? "—")
                    .font(.Tokens.bodyMedium)
                    .monospacedDigit()
                    .foregroundStyle(isUnset ? ColorTokens.text2 : ColorTokens.text1)
                Text(unitLabel)
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text2)
            }

            HStack(spacing: Spacing.xs) {
                // Lighter
                tile(
                    value: lighterDisplay,
                    isCenter: false,
                    action: { if let v = lighterDisplay { commit(v) } }
                )
                // Center
                tile(
                    value: centerDisplay,
                    isCenter: true,
                    action: { if let v = centerDisplay { commit(v) } }
                )
                // Heavier
                tile(
                    value: heavierDisplay,
                    isCenter: false,
                    action: { if let v = heavierDisplay { commit(v) } }
                )

                // Keypad escape — distinct affordance OUTSIDE the three tiles. Tapping it
                // focuses the inline keypad field (no .alert round-trip), enabling the
                // weight → reps focus chain (§5.5).
                keypadAffordance
            }
        }
        .accessibilityElement(children: .contain)
        .alert(String(localized: "weightPicker.type.title", defaultValue: "Enter weight"), isPresented: $showKeypad) {
            TextField(unitLabel, text: $keypadText)
                .keyboardType(.decimalPad)
            Button(String(localized: "action.cancel", defaultValue: "Cancel"), role: .cancel) {}
            Button(String(localized: "action.done", defaultValue: "Done")) {
                if let typed = Double(keypadText.replacingOccurrences(of: ",", with: ".")) {
                    commit(typed)
                }
            }
        }
    }

    /// Trailing "type" affordance + the inline focusable keypad field it reveals.
    /// When focused, the field overlays the numeral so weight → reps advances inline.
    @ViewBuilder private var keypadAffordance: some View {
        if let focus {
            ZStack {
                // The inline keypad field. Stays mounted (so focus can be programmatically
                // advanced into it) but reads as a sharp, borderless caret target.
                TextField(unitLabel, text: $keypadText)
                    .keyboardType(.decimalPad)
                    .focused(focus, equals: .weight(rowId))
                    .multilineTextAlignment(.center)
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text1)
                    .monospacedDigit()
                    .frame(width: 44, height: 44)
                    .background(ColorTokens.surface)
                    .overlay(Rectangle().stroke(ColorTokens.divider, lineWidth: 0.5))
                    .submitLabel(.next)
                    .onChange(of: focus.wrappedValue) { _, newValue in
                        if newValue == .weight(rowId) {
                            // Entering: seed buffer from current center.
                            keypadText = centerDisplay.map(numeralString) ?? ""
                        }
                    }
                    .onSubmit { commitKeypadAndAdvance() }
                Image(systemName: "keyboard")
                    .font(.Tokens.label)
                    .foregroundStyle(isUnset ? ColorTokens.text1 : ColorTokens.text2)
                    .allowsHitTesting(false)
                    .opacity(focus.wrappedValue == .weight(rowId) ? 0 : 1)
            }
            .accessibilityLabel(String(localized: "weightPicker.type.accessibility", defaultValue: "Type weight"))
        } else {
            Button {
                keypadText = centerDisplay.map(numeralString) ?? ""
                showKeypad = true
            } label: {
                Image(systemName: "keyboard")
                    .font(.Tokens.label)
                    .foregroundStyle(isUnset ? ColorTokens.text1 : ColorTokens.text2)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.pressable)
            .accessibilityLabel(String(localized: "weightPicker.type.accessibility", defaultValue: "Type weight"))
        }
    }

    /// Commit the typed weight, then advance focus to reps (§5.5).
    private func commitKeypadAndAdvance() {
        if let typed = Double(keypadText.replacingOccurrences(of: ",", with: ".")) {
            commit(typed)
        }
        focus?.wrappedValue = advanceTo
    }

    @ViewBuilder
    private func tile(value: Double?, isCenter: Bool, action: @escaping () -> Void) -> some View {
        let enabled = value != nil
        Button(action: action) {
            ZStack {
                Rectangle()
                    .fill(isCenter ? ColorTokens.accentSubtle : ColorTokens.surface)
                    .frame(width: 48, height: 48)
                    .overlay(Rectangle().stroke(ColorTokens.divider, lineWidth: 0.5))
                if isCenter {
                    // v2: the active/center cell carries the accent (accent = live state) — a
                    // 1pt inset accent edge marks it as the current selection.
                    Rectangle()
                        .stroke(ColorTokens.accent, lineWidth: 1)
                        .padding(2)
                        .frame(width: 48, height: 48)
                }
                Text(value.map(numeralString) ?? "—")
                    .font(isCenter ? .Tokens.bodyMedium : .Tokens.smallLabel)
                    .monospacedDigit()
                    .foregroundStyle(tileForeground(isCenter: isCenter, enabled: enabled))
            }
            .frame(width: 48, height: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .disabled(!enabled)
        .animation(Motion.state, value: weightKg)
        .accessibilityLabel(isCenter
            ? String(localized: "weightPicker.center.accessibility", defaultValue: "Current weight")
            : String(localized: "weightPicker.adjust.accessibility", defaultValue: "Adjust weight"))
        .accessibilityValue(accessibilityValueString(value))
    }

    private func tileForeground(isCenter: Bool, enabled: Bool) -> Color {
        if !enabled { return ColorTokens.text3 }
        return isCenter ? ColorTokens.accent : ColorTokens.text2
    }
}
