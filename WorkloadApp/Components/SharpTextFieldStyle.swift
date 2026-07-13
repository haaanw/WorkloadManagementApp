import SwiftUI

/// Design-system text field style (v3 "Ink & Grain": `CornerTokens.control` corners).
/// Replaces .roundedBorder across all text inputs.
///
/// Tuwa v2: a focused field is the *active* element, so its hairline lifts from
/// `divider` to `accent` (the one sanctioned accent use here) and thickens 0.5→1pt.
/// The transition routes through `Motion.state`.
struct SharpTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        SharpField(configuration: configuration)
    }

    private struct SharpField<Label: View>: View {
        let configuration: TextField<Label>
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @FocusState private var isFocused: Bool

        var body: some View {
            configuration
                .focused($isFocused)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.sm)
                .font(.Tokens.body)
                .foregroundStyle(ColorTokens.text1)
                .background(ColorTokens.surface, in: RoundedRectangle(cornerRadius: CornerTokens.control))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerTokens.control)
                        .stroke(
                            isFocused ? ColorTokens.accent : ColorTokens.divider,
                            lineWidth: isFocused ? 1 : 0.5
                        )
                )
                .animation(Motion.resolved(Motion.state, reduceMotion: reduceMotion), value: isFocused)
        }
    }
}
