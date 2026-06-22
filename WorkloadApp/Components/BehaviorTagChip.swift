import SwiftUI

/// Toggle chip for daily behavior tagging in wellness check-in.
struct BehaviorTagChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.select()
            action()
        } label: {
            Text(label)
                .font(.Tokens.label)
                .foregroundStyle(isSelected ? ColorTokens.accent : ColorTokens.text2)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? ColorTokens.accentSubtle : ColorTokens.background)
                .overlay(
                    Rectangle()
                        .stroke(isSelected ? ColorTokens.accent : ColorTokens.divider, lineWidth: 0.5)
                )
        }
        .buttonStyle(.pressable)
    }
}
