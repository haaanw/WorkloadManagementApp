import SwiftUI
import SwiftData
import AuthenticationServices

/// OnboardingV2 screen 10 — "Keep this. Make an account." Placed before the paywall so
/// the purchase attaches to a real App User ID and refused-payment emails are captured
/// (spec §3). Three FIRST-CLASS doors (amendment 3): Sign in with Apple, Sign in with
/// Google, and email — the social doors lead, full-width, premium by spacing and relief,
/// never by new color. The account sequence mirrors `SignUpView` exactly, EXCEPT it
/// never sets `isAuthenticated` — the flow, not the auth flag, decides when `.main`
/// renders (BUILD-PLAN §3).
struct AccountScreen: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Quiz Q2 seeds the athlete's sport so no extra screen asks for it (C7 in reverse:
    /// the one quiz answer with a physiological home lands there at creation time).
    let splitChoiceID: String?
    /// Account exists (created or signed into) — advance to the paywall.
    let onCreated: () -> Void

    @State private var displayName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var isSocialLoading = false
    @State private var errorMessage: String?
    @State private var showEmailForm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("onboardingV2.account.title")
                    .font(.Tokens.pageTitle)
                    .foregroundStyle(ColorTokens.text1)
                    .fixedSize(horizontal: false, vertical: true)
                Text("onboardingV2.account.subtitle")
                    .font(.Tokens.body)
                    .foregroundStyle(ColorTokens.text2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, Spacing.xs)

                // The three doors — social first, first-class (amendment 3).
                VStack(spacing: Spacing.sm) {
                    SignInWithAppleButton(.signUp) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        if case .success(let auth) = result,
                           let credential = auth.credential as? ASAuthorizationAppleIDCredential {
                            Task { await handleApple(credential: credential) }
                        }
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: CornerTokens.control))
                    .disabled(isLoading || isSocialLoading)
                    .accessibilityIdentifier("onboardingV2.account.apple")

                    Button {
                        Task { await handleGoogle() }
                    } label: {
                        HStack(spacing: Spacing.xs) {
                            // The shipped Google mark treatment (SocialLoginButtons):
                            // a localized glyph string, no image asset, no icon font.
                            Text("auth.google.icon")
                                .font(.Tokens.body)
                                .foregroundStyle(ColorTokens.text1)
                                .frame(width: 24, height: 24)
                            Text("onboardingV2.account.google")
                                .font(.Tokens.bodyMedium)
                                .foregroundStyle(ColorTokens.text1)
                        }
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(ColorTokens.surfaceEl2, in: RoundedRectangle(cornerRadius: CornerTokens.control))
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerTokens.control)
                                .stroke(ColorTokens.dividerStrong, lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.pressable)
                    .disabled(isLoading || isSocialLoading)
                    .accessibilityIdentifier("onboardingV2.account.googleButton")

                    Button {
                        withAnimation(Motion.resolved(Motion.state, reduceMotion: reduceMotion)) {
                            showEmailForm.toggle()
                        }
                    } label: {
                        Text("onboardingV2.account.emailDoor")
                            .font(.Tokens.bodyMedium)
                            .foregroundStyle(ColorTokens.text1)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(ColorTokens.surfaceEl2, in: RoundedRectangle(cornerRadius: CornerTokens.control))
                            .overlay(
                                RoundedRectangle(cornerRadius: CornerTokens.control)
                                    .stroke(ColorTokens.dividerStrong, lineWidth: 0.5)
                            )
                    }
                    .buttonStyle(.pressable)
                    .disabled(isLoading || isSocialLoading)
                    .accessibilityIdentifier("onboardingV2.account.emailDoorButton")
                }
                .padding(.top, Spacing.lg)

                if showEmailForm {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        InputField(label: "auth.field.name", placeholder: String(localized: "auth.field.namePlaceholder"), text: $displayName)
                            .textContentType(.name)
                        InputField(label: "auth.field.email", placeholder: "you@example.com", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                        SecureInputField(label: "auth.field.password", placeholder: String(localized: "auth.field.passwordPlaceholder"), text: $password)
                            .textContentType(.newPassword)

                        PrimaryActionButton(
                            title: "auth.signup.heading",
                            isLoading: isLoading,
                            isDisabled: !isEmailFormValid || isSocialLoading
                        ) {
                            Task { await signUpWithEmail() }
                        }
                        .padding(.top, Spacing.xs)
                    }
                    .padding(.top, Spacing.md)
                    .transition(.opacity)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.zoneDanger)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, Spacing.sm)
                }
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.lg)
        }
    }

    private var isEmailFormValid: Bool {
        !displayName.isEmpty && !email.isEmpty && password.count >= 8
    }

    /// Q2 → sport, so the athlete's primary sport carries the beachhead split.
    private var sportFromQuiz: SportType {
        switch splitChoiceID {
        case "basketballLifting", "sportLifting": .teamSport
        case "strength": .lifting
        default: .custom
        }
    }

    // MARK: - Doors (SignUpView's sequence, minus setAuthenticated)

    private func signUpWithEmail() async {
        isLoading = true
        errorMessage = nil
        do {
            let userId = try await container.authService.signUp(
                email: email,
                password: password,
                displayName: displayName,
                sportType: sportFromQuiz.rawValue
            )
            let athlete = Athlete(
                id: userId,
                displayName: displayName,
                sportType: sportFromQuiz,
                supabaseUserId: userId
            )
            modelContext.insert(athlete)
            try modelContext.save()
            await container.syncService.pushAthlete(athlete)
            Haptics.success()
            onCreated()
        } catch {
            errorMessage = resolveErrorMessage(error)
        }
        isLoading = false
    }

    private func handleApple(credential: ASAuthorizationAppleIDCredential) async {
        isSocialLoading = true
        errorMessage = nil
        do {
            try await container.authService.signInWithApple(credential: credential)
            try await ensureAthleteAfterSocial(fallbackName: [
                credential.fullName?.givenName, credential.fullName?.familyName
            ].compactMap { $0 }.joined(separator: " "))
            isSocialLoading = false
            Haptics.success()
            onCreated()
        } catch {
            errorMessage = resolveErrorMessage(error)
            isSocialLoading = false
        }
    }

    private func handleGoogle() async {
        isSocialLoading = true
        errorMessage = nil
        do {
            try await container.authService.signInWithGoogle()
            try await ensureAthleteAfterSocial(fallbackName: "")
            isSocialLoading = false
            Haptics.success()
            onCreated()
        } catch {
            errorMessage = resolveErrorMessage(error)
            isSocialLoading = false
        }
    }

    /// The SignUpView social sequence: bootstrap when an account already owns an athlete
    /// row; create-and-push when it is genuinely new; H7 transport failures never
    /// fabricate a profile. A returning subscriber lands on the paywall next, where
    /// Restore resolves their entitlement (App Review 3.1.1).
    private func ensureAthleteAfterSocial(fallbackName: String) async throws {
        let localAthletes = try? modelContext.fetch(FetchDescriptor<Athlete>())
        if localAthletes?.isEmpty != false {
            guard let userId = await container.authService.currentUserId() else {
                throw AccountScreenError.noUserId
            }
            switch await container.syncService.bootstrapAthlete(context: modelContext, userId: userId) {
            case .created:
                break
            case .notFound:
                let athlete = Athlete(
                    id: userId,
                    displayName: fallbackName.isEmpty ? "Athlete" : fallbackName,
                    sportType: sportFromQuiz,
                    supabaseUserId: userId
                )
                modelContext.insert(athlete)
                try modelContext.save()
                await container.syncService.pushAthlete(athlete)
            case .failed(let error):
                throw error
            }
        }
        await container.syncService.pullAll(context: modelContext)
    }

    private func resolveErrorMessage(_ error: any Error) -> String {
        if let authError = error as? AuthService.AuthError {
            if let serverMessage = authError.serverMessage { return serverMessage }
            var resource = LocalizedStringResource(authError.localizationKey)
            resource.locale = locale
            return String(localized: resource)
        }
        return error.localizedDescription
    }
}

private enum AccountScreenError: LocalizedError {
    case noUserId

    var errorDescription: String? {
        String(localized: "auth.error.noUserId", defaultValue: "Could not retrieve your account. Please try again.")
    }
}
