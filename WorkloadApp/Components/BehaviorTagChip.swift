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
            // v3 Corner Law: tag chips are pills. Selection stays accent (live-state semantic).
            Text(label)
                .font(.Tokens.label)
                .foregroundStyle(isSelected ? ColorTokens.accent : ColorTokens.text2)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs)
                .background(isSelected ? ColorTokens.accentSubtle : ColorTokens.background, in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? ColorTokens.accent : ColorTokens.divider, lineWidth: 0.5)
                )
        }
        .buttonStyle(.pressable)
    }
}
