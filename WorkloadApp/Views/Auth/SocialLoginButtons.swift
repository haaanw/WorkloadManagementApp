import SwiftUI
import AuthenticationServices

/// Shared Apple + Google sign-in buttons used on LoginView and SignUpView.
struct SocialLoginButtons: View {
    @Environment(\.colorScheme) private var colorScheme

    enum Mode { case signIn, signUp }
    let mode: Mode
    let isLoading: Bool
    let onAppleCredential: (ASAuthorizationAppleIDCredential) -> Void
    let onGoogleTap: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // OR divider
            HStack(spacing: 16) {
                Rectangle()
                    .fill(ColorTokens.divider)
                    .frame(height: 0.5)
                Text("OR")
                    .font(.Tokens.body)
                    .foregroundStyle(ColorTokens.text3)
                Rectangle()
                    .fill(ColorTokens.divider)
                    .frame(height: 0.5)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 24)

            // Apple Sign-In button (must be first per Apple HIG)
            VStack(spacing: 8) {
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
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(height: 48)
                .clipShape(Rectangle()) // 0pt corners per DESIGN.md

                // Google Sign-In button
                Button {
                    onGoogleTap()
                } label: {
                    HStack(spacing: 8) {
                        if isLoading {
                            ProgressView()
                        } else {
                            Text("G")
                                .font(.Tokens.body)
                                .foregroundStyle(ColorTokens.text1)
                                .frame(width: 24, height: 24)
                            Text(mode == .signIn
                                ? "Sign in with Google"
                                : "Sign up with Google")
                                .font(.Tokens.body)
                                .foregroundStyle(ColorTokens.text1)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(ColorTokens.surface)
                    .overlay(
                        Rectangle().stroke(ColorTokens.divider, lineWidth: 0.5)
                    )
                }
                .disabled(isLoading)
            }
            .padding(.horizontal, 16)
        }
    }
}
