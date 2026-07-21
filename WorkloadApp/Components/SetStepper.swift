import SwiftUI

/// Always-visible ± stepper wrapping a tappable numeric field — the fast-entry primitive
/// for set rows (Phase 38, Variant A). One HStack, left → right: a "−" button, a tappable
/// center numeric field (tap = numeric keypad for big jumps), a "+" button.
///
/// Design constraints (DESIGN.md v3): the stepper is a control → `CornerTokens.control`
/// corners on the outer shape (inner segments stay square, clipped by it), no shadows,
/// hairline `divider` borders between segments, Font.Tokens only, 8pt grid. NO `accent`
/// anywhere — steppers/buttons use `text1`/`text2`/`text3`/`divider`.
///
/// Ghost behaviour: when `value == nil` but a carried/target baseline exists, the baseline is
/// rendered ghosted (`text3`) as a not-yet-committed default; the first ± tap or keypad edit
/// commits it to `text1`. The two concrete variants keep the optional `Binding` simple and
/// avoid generic-numeric `Binding<Optional>` friction.

// MARK: - Double variant (weight)

struct SetStepperDouble: View {
    @Binding var value: Double?
    /// Step applied on ± in the *stored* unit (kg). Caller converts for lb-awareness.
    var increment: Double
    /// Placeholder shown when value is nil and no ghost baseline applies.
    var placeholder: String
    /// Carried/target baseline to render ghosted while value is nil. nil → plain placeholder.
    var ghostBaseline: Double? = nil
    /// Lower clamp floor (weight floor 0 — never persist negative load).
    var floor: Double = 0
    /// Decimal places for display formatting.
    var fractionDigits: Int = 1

    @FocusState private var focused: Bool

    private var isGhost: Bool { value == nil && ghostBaseline != nil }

    private func format(_ v: Double) -> String {
        String(format: "%.\(fractionDigits)f", v)
    }

    private func stepDown() {
        // No-op when there is nothing to decrement from: an empty field with no ghost
        // baseline must NOT commit a spurious 0 (which would then persist as a meaningless
        // 0-load set past the empty-set filter). Only step down from a committed value or
        // a carried/target ghost baseline.
        guard let base = value ?? ghostBaseline else { return }
        let next = max(floor, base - increment)
        // v4.1 D13(a): per-step taps are SILENT. Fire the limit haptic only when the
        // press is rejected at the floor (value already clamped, nothing to decrement).
        if next == base {
            Haptics.limit()
        }
        value = next
    }

    private func stepUp() {
        let base = value ?? ghostBaseline ?? floor
        value = max(floor, base + increment)
    }

    var body: some View {
        // v4.2: raised ± keys flanking a debossed readout well (the editable value pocket).
        HStack(spacing: Spacing.xs) {
            StepperButton(symbol: "minus", action: stepDown)

            ZStack {
                // Ghosted carried baseline behind the empty field.
                if isGhost, let g = ghostBaseline {
                    Text(format(g))
                        .font(.Tokens.body)
                        .foregroundStyle(ColorTokens.text3)
                        .monospacedDigit()
                        .allowsHitTesting(false)
                }
                TextField(isGhost ? "" : placeholder, value: $value, format: .number)
                    .keyboardType(.decimalPad)
                    .focused($focused)
                    .multilineTextAlignment(.center)
                    .font(.Tokens.body)
                    .foregroundStyle(ColorTokens.text1)
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
            .debossed(cornerRadius: CornerTokens.control)
            .contentShape(Rectangle())
            .onTapGesture { focused = true }

            StepperButton(symbol: "plus", action: stepUp)
        }
    }
}

// MARK: - Int variant (reps / RPE)

struct SetStepperInt: View {
    @Binding var value: Int?
    var increment: Int
    var placeholder: String
    var ghostBaseline: Int? = nil
    var floor: Int = 0

    @FocusState private var focused: Bool

    private var isGhost: Bool { value == nil && ghostBaseline != nil }

    private func stepDown() {
        // No-op when there is nothing to decrement from (see SetStepperDouble.stepDown):
        // an empty field with no ghost baseline must NOT commit a spurious 0.
        guard let base = value ?? ghostBaseline else { return }
        let next = max(floor, base - increment)
        // v4.1 D13(a): per-step taps are SILENT. Fire the limit haptic only when the
        // press is rejected at the floor (value already clamped, nothing to decrement).
        if next == base {
            Haptics.limit()
        }
        value = next
    }

    private func stepUp() {
        let base = value ?? ghostBaseline ?? floor
        value = max(floor, base + increment)
    }

    var body: some View {
        // v4.2: raised ± keys flanking a debossed readout well (the editable value pocket).
        HStack(spacing: Spacing.xs) {
            StepperButton(symbol: "minus", action: stepDown)

            ZStack {
                if isGhost, let g = ghostBaseline {
                    Text("\(g)")
                        .font(.Tokens.body)
                        .foregroundStyle(ColorTokens.text3)
                        .monospacedDigit()
                        .allowsHitTesting(false)
                }
                TextField(isGhost ? "" : placeholder, value: $value, format: .number)
                    .keyboardType(.numberPad)
                    .focused($focused)
                    .multilineTextAlignment(.center)
                    .font(.Tokens.body)
                    .foregroundStyle(ColorTokens.text1)
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
            .debossed(cornerRadius: CornerTokens.control)
            .contentShape(Rectangle())
            .onTapGesture { focused = true }

            StepperButton(symbol: "plus", action: stepUp)
        }
    }
}

// MARK: - Shared ± button

/// A single ± segment: SF Symbol sized via Font.Tokens (not .system()), text1 foreground, on a
/// milled RAISED key (v4.2 Relief Law). No accent, no shadow.
private struct StepperButton: View {
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.Tokens.label)
                .foregroundStyle(ColorTokens.text1)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
                .raised(cornerRadius: CornerTokens.control)
        }
        // Small ± keys depress a touch deeper (0.94) to match the demo's stepper feel.
        .buttonStyle(.pressable(scale: 0.94))
    }
}
