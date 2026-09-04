import SwiftUI

/// The morning check-in prompt row. Moved here verbatim from `RecoveryView.swift` with the
/// Trends merge (v1.7.3 reorientation slice 3): Home has carried this prompt since slice 1
/// (APP-REORIENTATION R3 — the daily loop opens with the check-in), and the merged Trends
/// tab is a read-only exhibit surface that does not mount it, so Home is the surviving
/// consumer.
struct MorningCheckInPrompt: View {
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: Spacing.baselinePair) {
                    Text("recovery.checkin.title")
                        .font(.Tokens.sectionHead)
                        .foregroundStyle(ColorTokens.text1)
                    Text("recovery.checkin.prompt")
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text2)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text3)
            }
            .cardStyle(verticalPadding: Spacing.sm)
        }
        .buttonStyle(.pressable(scale: 1, opacity: 0.6))
        .foregroundStyle(ColorTokens.text1)
    }
}
