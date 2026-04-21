import SwiftUI

/// Toggle chip for daily behavior tagging in wellness check-in.
struct BehaviorTagChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.Tokens.label)
                .foregroundStyle(isSelected ? ColorTokens.text1 : ColorTokens.text2)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? ColorTokens.surface : ColorTokens.background)
                .overlay(
                    Rectangle()
                        .stroke(isSelected ? ColorTokens.text2 : ColorTokens.divider, lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
    }
}
