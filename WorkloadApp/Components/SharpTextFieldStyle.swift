import SwiftUI

/// 0pt-corner text field style matching the design system.
/// Replaces .roundedBorder across all text inputs.
struct SharpTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .font(.Tokens.body)
            .foregroundStyle(ColorTokens.text1)
            .background(ColorTokens.surface)
            .overlay(
                Rectangle()
                    .stroke(ColorTokens.divider, lineWidth: 0.5)
            )
    }
}
