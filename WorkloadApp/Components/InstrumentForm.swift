import SwiftUI

// v4.2 "Machined" form system (owned by workstream WS-B — see
// .planning/orchestration/2026-07-20-v42-handoff.md). The form vocabulary the whole app
// settles into, built on the `.raised` / `.debossed` Relief primitives (CardStyle.swift).
//
// Everything here is strokes + gradients (the no-shadow law holds) and every value/motion goes
// through ColorTokens / Font.Tokens / Spacing / CornerTokens / Motion. Six pieces:
//   • ReadoutWell        — fixed-width debossed value pocket (tabular value + micro-caps unit)
//   • InstrumentFormRow  — 56pt label + trailing content row with a drawn tick-chevron
//   • MachinedOptionCell — a raised option cell with a drilled selection dot
//   • InlineOptionList / InlineMultiOptionList — the stock-`Menu` replacement (a debossed
//     channel of machined option cells expanding inline)
//   • FormField          — a right-aligned text field that grows a debossed focus well
//   • MachinedToggleStyle — a round polished knob riding a debossed channel that turns ink
//   • DestructiveFormRow — the quiet zone-danger row
//
// The form system carries into DESIGN.md v5 "Pavilion" whole, re-materialized in warm stone
// (v5 geometry + stone tokens); stock iOS `Menu` stays BANNED for settings/pickers.

// MARK: - Tick chevron (drawn 1.5px caret — never an SF Symbol)

/// The precision chevron: a 1.5px drawn caret (two butted strokes) that rotates 180° when its
/// row expands. Replaces `chevron.up.chevron.down` on machined select rows — the demo's drawn
/// tick, not a glyph. Rotation is driven by the caller on `Motion.state`.
struct TickChevron: View {
    /// true → caret points up (row open); false → caret points down (row closed).
    var isUp: Bool = false

    private struct Caret: Shape {
        func path(in rect: CGRect) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            return p
        }
    }

    var body: some View {
        Caret()
            .stroke(ColorTokens.text3, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
            .frame(width: 11, height: 6)
            .rotationEffect(.degrees(isUp ? 180 : 0))
            .accessibilityHidden(true)
    }
}

// MARK: - Readout well (fixed-width debossed value pocket — DESIGN.md v4.2 Readout wells)

/// Every displayed value sits in one of these: a debossed pocket holding a tabular reading
/// (`smallLabelMedium` + `.monospacedDigit()`, v5 numeral law) and an optional micro-caps unit.
/// The value area reserves the widest realistic reading (`widthTemplate`) so digits change but
/// the stone never resizes (v4.1 D13(c) carried into the well). Digit swaps roll subtly via
/// `Motion.digitRoll`; pass `rolls: false` to snap.
struct ReadoutWell: View {
    /// The live reading, already formatted ("5–6", "130.0", "Advanced").
    let value: String
    /// Optional micro-caps unit ("KG", "D/WK", "MIN"). nil for text selections.
    var unit: String? = nil
    /// The widest reading this well will show — reserves the fixed width. Defaults to `value`.
    var widthTemplate: String? = nil
    /// Ink for set readings; `text3` for placeholders (both text selections and numerals).
    var color: Color = ColorTokens.text1
    var rolls: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: Spacing.baselinePair) {
            ZStack(alignment: .trailing) {
                Text(widthTemplate ?? value)
                    .foregroundStyle(.clear)
                    .accessibilityHidden(true)
                Text(value)
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .contentTransition(.numericText())
                    .animation(
                        rolls ? Motion.resolved(Motion.digitRoll, reduceMotion: reduceMotion) : nil,
                        value: value
                    )
            }
            .font(.Tokens.smallLabelMedium)
            .monospacedDigit()
            if let unit {
                // v6: a unit is annotation, and the design system's own `ReadoutWell` renders it
                // in the mono face. `text2`, not the annotation default `text3` — this label sits
                // inside a DEBOSSED well, where `text3` measures 2.84:1 and DESIGN.md rule 7
                // therefore forbids it (a pre-existing v5 contrast miss, fixed here).
                //
                // No `.annotationReveal`: a well is a live control whose unit must be legible the
                // instant the row exists, not 340ms after it.
                AnnotationLabel(unit, size: .small, color: ColorTokens.text2)
            }
        }
        .padding(.horizontal, Spacing.sm)
        .frame(minHeight: 32)
        .debossed(cornerRadius: CornerTokens.control)
        .accessibilityElement()
        .accessibilityLabel(Text(unit.map { "\(value) \($0)" } ?? value))
    }
}

// MARK: - Form row (56pt label + trailing content)

/// The machined form row: a 56pt row carrying a label (+ optional subtitle) on the left and
/// arbitrary trailing content (a `ReadoutWell`, a `MachinedToggle`, a `FormField`) on the right.
/// When `action` is non-nil the whole row is a `.rowWell` press surface; `chevron` adds the drawn
/// tick that rotates when `isExpanded`.
struct InstrumentFormRow<Trailing: View>: View {
    let label: LocalizedStringKey
    var subtitle: LocalizedStringKey? = nil
    var showsChevron: Bool = false
    var isExpanded: Bool = false
    var isEnabled: Bool = true
    var action: (() -> Void)? = nil
    @ViewBuilder var trailing: Trailing

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var content: some View {
        HStack(spacing: Spacing.sm) {
            VStack(alignment: .leading, spacing: Spacing.baselinePair) {
                Text(label)
                    .font(.Tokens.body)
                    .foregroundStyle(isEnabled ? ColorTokens.text1 : ColorTokens.text3)
                if let subtitle {
                    Text(subtitle)
                        .font(.Tokens.smallLabel)
                        .foregroundStyle(ColorTokens.text3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: Spacing.sm)
            trailing
            if showsChevron {
                TickChevron(isUp: isExpanded)
                    .animation(Motion.resolved(Motion.state, reduceMotion: reduceMotion), value: isExpanded)
            }
        }
        .padding(.horizontal, Spacing.sm)
        .frame(minHeight: 56)
        .contentShape(Rectangle())
    }

    var body: some View {
        if let action {
            Button {
                Haptics.select()
                action()
            } label: {
                content
            }
            .buttonStyle(.rowWell(cornerRadius: CornerTokens.control))
            .disabled(!isEnabled)
        } else {
            content
        }
    }
}

// MARK: - Machined option cell (flat outlined cell + drilled selection dot)

/// One option cell: a FLAT hairline-outlined cell carrying a label (+ optional subtitle / icon)
/// and a drilled selection dot (an ink-ringed pocket that fills ink when selected). The single
/// choosable unit shared by `InlineOptionList`, `InlineMultiOptionList`, and the onboarding
/// pickers.
///
/// v1.7.1 (HAN's explicit direction, 2026-08-05): the cell dropped its `.raised` plate and the
/// list dropped its debossed channel — the raised-boxes-in-a-dark-well grammar read as heavy
/// "boxes with a darker background". Selection is carried by the outline weight, the dot, and
/// the label's medium face; the plane underneath stays whatever the host surface is.
struct MachinedOptionCell: View {
    let label: String
    var subtitle: String? = nil
    var systemImage: String? = nil
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The drilled dot: a 14pt ring that fills ink when selected (ink, never a vivid alarm).
    private var dot: some View {
        Circle()
            .stroke(isSelected ? ColorTokens.text1 : ColorTokens.dividerStrong, lineWidth: 1.5)
            .frame(width: 14, height: 14)
            .overlay {
                Circle()
                    .fill(ColorTokens.text1)
                    .frame(width: 8, height: 8)
                    .opacity(isSelected ? 1 : 0)
            }
            .animation(Motion.resolved(Motion.state, reduceMotion: reduceMotion), value: isSelected)
            .accessibilityHidden(true)
    }

    var body: some View {
        Button {
            Haptics.select()
            action()
        } label: {
            HStack(spacing: Spacing.sm) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.Tokens.label)
                        .foregroundStyle(isSelected ? ColorTokens.text1 : ColorTokens.text2)
                        .frame(width: 24)
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: Spacing.baselinePair) {
                    Text(label)
                        .font(isSelected ? .Tokens.bodyMedium : .Tokens.body)
                        .foregroundStyle(isSelected ? ColorTokens.text1 : ColorTokens.text2)
                        .multilineTextAlignment(.leading)
                    if let subtitle {
                        Text(subtitle)
                            .font(.Tokens.smallLabel)
                            .foregroundStyle(ColorTokens.text3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: Spacing.sm)
                dot
            }
            .padding(.horizontal, Spacing.sm)
            .frame(minHeight: 48)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .overlay(
                RoundedRectangle(cornerRadius: CornerTokens.control)
                    .stroke(
                        isSelected ? ColorTokens.text1 : ColorTokens.divider,
                        lineWidth: isSelected ? 1 : 0.5
                    )
            )
        }
        .buttonStyle(.pressable(scale: 1, opacity: 0.7))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

/// The bay the option cells sit in: a flat 4pt-gapped column of outlined cells. The debossed
/// channel was dropped in v1.7.1 (HAN: flatter option lists) — the expand/collapse container
/// keeps its name and call sites, only the surface treatment changed.
private struct OptionChannel<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: Spacing.baselinePair) {
            content
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Inline option list (the Menu replacement — single select)

/// A machined select. The collapsed row shows the label + current value in a `ReadoutWell` + the
/// tick chevron; tapping expands a debossed channel of `MachinedOptionCell`s inline. Choosing an
/// option updates the readout and collapses after a beat — reads like a component bay, never a
/// stock iOS `Menu` (banned app-wide for settings/pickers in v4.2).
struct InlineOptionList<T: Hashable>: View {
    let label: LocalizedStringKey
    @Binding var selection: T?
    let options: [T]
    let displayName: (T) -> String
    /// Placeholder shown in the readout when `selection` is nil.
    var placeholder: String = "—"
    /// Optional micro-caps unit shown in the readout (e.g. "MIN", "D/WK").
    var unit: String? = nil
    var subtitleFor: ((T) -> String?)? = nil
    var systemImageFor: ((T) -> String?)? = nil
    var isEnabled: Bool = true
    /// Fired after a selection commits (e.g. to mark the form dirty).
    var onSelect: (() -> Void)? = nil

    @State private var isExpanded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Non-optional convenience: bridges a `Binding<T>` into the optional storage.
    init(
        _ label: LocalizedStringKey,
        selection: Binding<T>,
        options: [T],
        unit: String? = nil,
        subtitleFor: ((T) -> String?)? = nil,
        systemImageFor: ((T) -> String?)? = nil,
        isEnabled: Bool = true,
        onSelect: (() -> Void)? = nil,
        displayName: @escaping (T) -> String
    ) {
        self.label = label
        self._selection = Binding(
            get: { selection.wrappedValue },
            set: { if let value = $0 { selection.wrappedValue = value } }
        )
        self.options = options
        self.displayName = displayName
        self.unit = unit
        self.subtitleFor = subtitleFor
        self.systemImageFor = systemImageFor
        self.isEnabled = isEnabled
        self.onSelect = onSelect
    }

    /// Optional binding + placeholder (cold-start selects that begin unset).
    init(
        _ label: LocalizedStringKey,
        selection: Binding<T?>,
        options: [T],
        placeholder: String,
        unit: String? = nil,
        subtitleFor: ((T) -> String?)? = nil,
        systemImageFor: ((T) -> String?)? = nil,
        isEnabled: Bool = true,
        onSelect: (() -> Void)? = nil,
        displayName: @escaping (T) -> String
    ) {
        self.label = label
        self._selection = selection
        self.options = options
        self.displayName = displayName
        self.placeholder = placeholder
        self.unit = unit
        self.subtitleFor = subtitleFor
        self.systemImageFor = systemImageFor
        self.isEnabled = isEnabled
        self.onSelect = onSelect
    }

    private var currentValue: String {
        selection.map(displayName) ?? placeholder
    }

    /// Reserve the readout width for the widest option so selecting never resizes the well.
    private var widthTemplate: String {
        options.map(displayName).max(by: { $0.count < $1.count }) ?? placeholder
    }

    var body: some View {
        VStack(spacing: 0) {
            InstrumentFormRow(
                label: label,
                showsChevron: true,
                isExpanded: isExpanded,
                isEnabled: isEnabled,
                action: {
                    withAnimation(Motion.resolved(Motion.state, reduceMotion: reduceMotion)) {
                        isExpanded.toggle()
                    }
                }
            ) {
                ReadoutWell(
                    value: currentValue,
                    unit: unit,
                    widthTemplate: widthTemplate,
                    color: selection == nil ? ColorTokens.text3 : ColorTokens.text1
                )
            }

            if isExpanded {
                OptionChannel {
                    ForEach(options, id: \.self) { option in
                        MachinedOptionCell(
                            label: displayName(option),
                            subtitle: subtitleFor?(option),
                            systemImage: systemImageFor?(option),
                            isSelected: selection == option
                        ) {
                            selection = option
                            onSelect?()
                            // Let the dot fill before the bay closes (asyncAfter is not an
                            // animation curve — the Motion fence covers curves/durations only).
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                                withAnimation(Motion.resolved(Motion.state, reduceMotion: reduceMotion)) {
                                    isExpanded = false
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, Spacing.sm)
                .padding(.bottom, Spacing.xs)
                .transition(.opacity)
            }
        }
    }
}

// MARK: - Inline multi-select

/// The multi-select sibling: cells toggle in place, no auto-collapse, and the readout shows a
/// running count. Used for movement-type / body-region multi-pickers that were stock `Menu`s.
struct InlineMultiOptionList<T: Hashable & Identifiable>: View {
    let label: LocalizedStringKey
    @Binding var selection: Set<T>
    let options: [T]
    let displayName: (T) -> String
    /// Builds the readout summary for the current count ("2 selected"). nil count → placeholder.
    let summary: (Int) -> String
    var placeholder: String = "—"
    var systemImageFor: ((T) -> String?)? = nil
    var onToggle: (() -> Void)? = nil

    @State private var isExpanded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            InstrumentFormRow(
                label: label,
                showsChevron: true,
                isExpanded: isExpanded,
                action: {
                    withAnimation(Motion.resolved(Motion.state, reduceMotion: reduceMotion)) {
                        isExpanded.toggle()
                    }
                }
            ) {
                ReadoutWell(
                    value: selection.isEmpty ? placeholder : summary(selection.count),
                    color: selection.isEmpty ? ColorTokens.text3 : ColorTokens.text1,
                    rolls: false
                )
            }

            if isExpanded {
                OptionChannel {
                    ForEach(options) { option in
                        MachinedOptionCell(
                            label: displayName(option),
                            systemImage: systemImageFor?(option),
                            isSelected: selection.contains(option)
                        ) {
                            if selection.contains(option) {
                                selection.remove(option)
                            } else {
                                selection.insert(option)
                            }
                            onToggle?()
                        }
                    }
                }
                .padding(.horizontal, Spacing.sm)
                .padding(.bottom, Spacing.xs)
                .transition(.opacity)
            }
        }
    }
}

// MARK: - Form field (right-aligned text field with a debossed focus well)

/// A machined text field: quiet and borderless at rest, growing a debossed focus well + 1pt ink
/// border while editing (Accent Rule — accent never marks focus). Right-aligned by default to sit
/// as the trailing value of a form row; pass `axis: .vertical` for multi-line notes.
struct FormField: View {
    let placeholder: LocalizedStringKey
    @Binding var text: String
    var axis: Axis = .horizontal
    var alignment: TextAlignment = .trailing
    var lineLimit: ClosedRange<Int>? = nil
    var onEdit: (() -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var isFocused: Bool

    var body: some View {
        field
            .font(.Tokens.body)
            .foregroundStyle(ColorTokens.text1)
            .multilineTextAlignment(alignment)
            .focused($isFocused)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background {
                if isFocused {
                    Color.clear.debossed(cornerRadius: CornerTokens.control)
                }
            }
            .overlay {
                if isFocused {
                    RoundedRectangle(cornerRadius: CornerTokens.control)
                        .stroke(ColorTokens.text1, lineWidth: 1)
                }
            }
            .animation(Motion.resolved(Motion.state, reduceMotion: reduceMotion), value: isFocused)
            .onChange(of: text) { onEdit?() }
    }

    @ViewBuilder
    private var field: some View {
        if axis == .vertical {
            let tf = TextField(placeholder, text: $text, axis: .vertical)
            if let lineLimit {
                tf.lineLimit(lineLimit)
            } else {
                tf
            }
        } else {
            TextField(placeholder, text: $text)
        }
    }
}

// MARK: - Machined toggle (round polished knob in a debossed channel)

/// The v4.2 toggle (tuning pick 3-B): a round polished knob that rides a debossed channel; the
/// channel turns ink when on and an engraved index tick lights in the pocket. One `Haptics.tap()`
/// per flip (v4.1 discrete-commit policy). A `ToggleStyle` so existing `Toggle` sites swap by
/// changing `.toggleStyle(.design)` → `.toggleStyle(.machined)`.
struct MachinedToggleStyle: ToggleStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let trackWidth: CGFloat = 52
    private let trackHeight: CGFloat = 32
    private let knob: CGFloat = 24

    func makeBody(configuration: Configuration) -> some View {
        Button {
            Haptics.tap()
            configuration.isOn.toggle()
        } label: {
            ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                // Debossed channel; fills ink inside the pocket when on.
                RoundedRectangle(cornerRadius: CornerTokens.control)
                    .fill(ColorTokens.text1)
                    .opacity(configuration.isOn ? 1 : 0)
                    .frame(width: trackWidth, height: trackHeight)
                    .debossed(cornerRadius: CornerTokens.control)

                // Engraved tick — lights in the ink-filled channel when on (light-on-ink,
                // the CTA-text tone).
                Rectangle()
                    .fill(ColorTokens.inkInverse)
                    .frame(width: 1.5, height: 10)
                    .padding(.leading, Spacing.xs)
                    .opacity(configuration.isOn ? 0.9 : 0)
                    .accessibilityHidden(true)

                // Round polished knob: a raised disc (a rounded rect whose radius is half its
                // side is a circle, so the relief stays circular without hand-rolling it).
                Color.clear
                    .frame(width: knob, height: knob)
                    .raised(cornerRadius: knob / 2)
                    .padding(.horizontal, Spacing.baselinePair)
            }
            .frame(width: trackWidth, height: trackHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable(scale: 1, opacity: 0.85))
        .animation(Motion.resolved(Motion.state, reduceMotion: reduceMotion), value: configuration.isOn)
        .accessibilityAddTraits(configuration.isOn ? [.isButton, .isSelected] : .isButton)
    }
}

extension ToggleStyle where Self == MachinedToggleStyle {
    /// The v4.2 round machined toggle (knob in a debossed channel). Use everywhere a settings
    /// toggle appears, replacing `.toggleStyle(.design)`.
    static var machined: MachinedToggleStyle { MachinedToggleStyle() }
}

// MARK: - Destructive row (quiet zone-danger text)

/// The quiet destructive form row: zone-danger label on a `.rowWell` press surface — no fill, no
/// alarm color block (DESIGN.md rule: state through the label, restraint over shouting).
struct DestructiveFormRow: View {
    let label: LocalizedStringKey
    var isBusy: Bool = false
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            Text(label)
                .font(.Tokens.body)
                .foregroundStyle(ColorTokens.zoneDanger)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.sm)
                .frame(minHeight: 52)
                .contentShape(Rectangle())
        }
        .buttonStyle(.rowWell(cornerRadius: CornerTokens.control))
        .disabled(isBusy)
    }
}
