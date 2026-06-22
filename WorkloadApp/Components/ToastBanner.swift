import SwiftUI

/// Auto-dismissing toast banner for confirmation and error messages.
/// Design system: flat surface card, no shadows, no rounded corners.
struct ToastBanner: View {
    let message: String
    let isError: Bool
    @Binding var isPresented: Bool

    var body: some View {
        HStack(spacing: 8) {
            Text(message)
                .font(.Tokens.smallLabel)
                .foregroundStyle(ColorTokens.text1)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(ColorTokens.surfaceEl2)
        .overlay(
            Rectangle()
                .stroke(isError ? ColorTokens.zoneDanger : ColorTokens.divider, lineWidth: 0.5)
        )
        .contentShape(Rectangle())
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .task {
            let delay: Duration = isError ? .seconds(3) : .seconds(2)
            try? await Task.sleep(for: delay)
            withAnimation(Motion.exit) {
                isPresented = false
            }
        }
    }
}
