import SwiftUI
import AuthenticationServices

/// Shared Apple + Google sign-in buttons used on LoginView and SignUpView.
struct SocialLoginButtons: View {
    enum Mode { case signIn, signUp }
    let mode: Mode
    let isLoading: Bool
    let onAppleCredential: (ASAuthorizationAppleIDCredential) -> Void
    let onGoogleTap: () -> Void

    /// Locale-correct lookup for the annotation below (`String(localized:)` reads the process
    /// locale, not the environment locale the app pins its language with).
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(spacing: 0) {
            // OR divider
            HStack(spacing: Spacing.sm) {
                Rectangle()
                    .fill(ColorTokens.divider)
                    .frame(height: 0.5)
                // v6: the one annotation on this screen. "OR" set between two hairlines is a
                // separator mark, not something the app says — and at `body` (17pt) it read as
                // copy. Everything else here is prose and CTAs, which stay working voice.
                AnnotationLabel(LocalePinnedStrings.localized("auth.divider.or", locale: locale))
                    .annotationReveal()
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
                // Corner Law (v5): control corners from CornerTokens.
                .clipShape(RoundedRectangle(cornerRadius: CornerTokens.control))

                // Google Sign-In button — secondary CTA: hairline-bordered rectangular key
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
                    .background(ColorTokens.surfaceEl, in: RoundedRectangle(cornerRadius: CornerTokens.control))
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerTokens.control)
                            .stroke(ColorTokens.dividerStrong, lineWidth: 0.5)
                    )
                }
                .buttonStyle(.pressable)
                .disabled(isLoading)
            }
            .padding(.horizontal, Spacing.sm)
        }
    }
}
