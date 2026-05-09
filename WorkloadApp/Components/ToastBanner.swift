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
                .font(.custom("DMSans-Regular", size: 13))
                .foregroundStyle(ColorTokens.text1)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(ColorTokens.surface)
        .overlay(
            Rectangle()
                .stroke(isError ? ColorTokens.zoneDanger : ColorTokens.divider, lineWidth: 0.5)
        )
        .contentShape(Rectangle())
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .onAppear {
            let delay: Double = isError ? 3.0 : 2.0
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.easeIn(duration: 0.15)) {
                    isPresented = false
                }
            }
        }
    }
}
