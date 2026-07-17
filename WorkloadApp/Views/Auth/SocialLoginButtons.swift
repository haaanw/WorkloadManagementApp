import SwiftUI
import AuthenticationServices

/// Shared Apple + Google sign-in buttons used on LoginView and SignUpView.
struct SocialLoginButtons: View {
    enum Mode { case signIn, signUp }
    let mode: Mode
    let isLoading: Bool
    let onAppleCredential: (ASAuthorizationAppleIDCredential) -> Void
    let onGoogleTap: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // OR divider
            HStack(spacing: Spacing.sm) {
                Rectangle()
                    .fill(ColorTokens.divider)
                    .frame(height: 0.5)
                Text("auth.divider.or")
                    .font(.Tokens.body)
                    .foregroundStyle(ColorTokens.text3)
                Rectangle()
                    .fill(ColorTokens.divider)
                    .frame(height: 0.5)
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.md)

            // Apple Sign-In button (must be first per Apple HIG)
            VStack(spacing: Spacing.xs) {
                SignInWithAppleButton(
                    mode == .signIn ? .signIn : .signUp
                ) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    switch result {
                    case .success(let authorization):
                        guard let credential = authorization.credential
                            as? ASAuthorizationAppleIDCredential else { return }
                        onAppleCredential(credential)
                    case .failure:
                        // Apple cancellation -- no error shown (user-initiated)
                        break
                    }
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 48)
                .clipShape(Capsule()) // pill CTA per DESIGN.md v3 Corner Law (CornerTokens.pill)

                // Google Sign-In button — secondary CTA: outlined pill
                Button {
                    onGoogleTap()
                } label: {
                    HStack(spacing: Spacing.xs) {
                        if isLoading {
                            ProgressView()
                        } else {
                            Text("auth.google.icon")
                                .font(.Tokens.body)
                                .foregroundStyle(ColorTokens.text1)
                                .frame(width: 24, height: 24)
                            Text(mode == .signIn
                                ? LocalizedStringKey("auth.google.signIn")
                                : LocalizedStringKey("auth.google.signUp"))
                                .font(.Tokens.body)
                                .foregroundStyle(ColorTokens.text1)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(ColorTokens.surface, in: Capsule())
                    .overlay(
                        Capsule().stroke(ColorTokens.divider, lineWidth: 0.5)
                    )
                }
                .buttonStyle(.pressable)
                .disabled(isLoading)
            }
            .padding(.horizontal, Spacing.sm)
        }
    }
}
