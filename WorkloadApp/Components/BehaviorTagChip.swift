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
            // v4: tag chips keep capsule geometry (chips only); selection is INK — text1 label,
            // surfaceEl2 wash, ink hairline (Index Rule: red never marks selection).
            Text(label)
                .font(.Tokens.label)
                .foregroundStyle(isSelected ? ColorTokens.text1 : ColorTokens.text2)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs)
                .background(isSelected ? ColorTokens.surfaceEl2 : ColorTokens.background, in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? ColorTokens.text1 : ColorTokens.divider, lineWidth: 0.5)
                )
        }
        .buttonStyle(.pressable)
    }
}
