import SwiftUI
import SwiftData
import AuthenticationServices

struct LoginView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var lastAuthError: (any Error)?
    @State private var isSocialLoading = false
    @State private var showSignUp = false

    /// Resolve a caught error against the current env locale (Pitfall 7).
    /// Typed branches use the catalog key; non-typed errors fall back to .localizedDescription.
    private func resolveErrorMessage(_ error: any Error, locale: Locale) -> String {
        if let authError = error as? AuthService.AuthError {
            // socialSignInFailed wraps an opaque server message — surface verbatim.
            if let serverMessage = authError.serverMessage {
                return serverMessage
            }
            var resource = LocalizedStringResource(authError.localizationKey)
            resource.locale = locale
            return String(localized: resource)
        } else if let bootstrap = error as? AuthBootstrapError {
            var resource = LocalizedStringResource(bootstrap.localizationKey)
            resource.locale = locale
            return String(localized: resource)
        } else {
            return error.localizedDescription
        }
    }

    private var signInEnabled: Bool {
        !email.isEmpty && !password.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Branding
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("auth.brand.wordmark")
                            .font(.Tokens.pageTitle)
                            .foregroundStyle(ColorTokens.text1)
                        Text("auth.brand.tagline")
                            .font(.Tokens.label)
                            .foregroundStyle(ColorTokens.text2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.top, Spacing.xl)
                    .padding(.bottom, Spacing.xl)

                    // Fields — the standard field treatment (control-radius plate, hairline,
                    // ink focus feedback), stacked on the page plane instead of full-bleed rows.
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        InputField(label: "auth.field.email", placeholder: "you@example.com", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)

                        SecureInputField(label: "auth.field.password", placeholder: "••••••••", text: $password)
                            .textContentType(.password)
                    }
                    .padding(.horizontal, Spacing.sm)

                    if let error = errorMessage {
                        Text(error)
                            .font(.Tokens.label)
                            .foregroundStyle(ColorTokens.zoneDanger)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.top, Spacing.sm)
                    }

                    // Sign in button — primary CTA is the ink-filled pill (v5 CTA Law; never accent).
                    PrimaryActionButton(
                        title: "auth.action.signIn",
                        isLoading: isLoading,
                        isDisabled: !signInEnabled || isSocialLoading
                    ) {
                        Task { await signIn() }
                    }
                    .padding(.horizontal, Spacing.sm)
                    .padding(.top, Spacing.md)

                    // Social login buttons
                    SocialLoginButtons(
                        mode: .signIn,
                        isLoading: isSocialLoading,
                        onAppleCredential: { credential in
                            Task { await handleAppleSignIn(credential: credential) }
                        },
                        onGoogleTap: {
                            Task { await handleGoogleSignIn() }
                        }
                    )

                    // Sign up link
                    Button {
                        showSignUp = true
                    } label: {
                        Text("auth.action.createAccountLink")
                            .font(.Tokens.label)
                            .foregroundStyle(ColorTokens.text2)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.pressable)
                    .padding(.top, Spacing.sm)
                    .padding(.bottom, Spacing.lg)
                }
            }
            .background(ColorTokens.background)
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $showSignUp) {
                SignUpView()
            }
            .onChange(of: locale) { _, newLocale in
                // Re-resolve any pending auth-error message against the new env locale
                // so the live-switch flow refreshes mid-flight (RESEARCH Pitfall 7).
                if let pending = lastAuthError, errorMessage != nil {
                    errorMessage = resolveErrorMessage(pending, locale: newLocale)
                }
            }
        }
    }

    private func signIn() async {
        isLoading = true
        errorMessage = nil
        do {
            // 1. Authenticate
            try await container.authService.signIn(email: email, password: password)

            // 2. Bootstrap local Athlete if not present (fresh install / new device)
            let localAthletes = try? modelContext.fetch(FetchDescriptor<Athlete>())
            if localAthletes?.isEmpty != false {
                guard let userId = await container.authService.currentUserId() else {
                    throw AuthBootstrapError.noUserId
                }
                let athlete = await container.syncService.bootstrapAthlete(
                    context: modelContext,
                    userId: userId
                )
                if athlete == nil {
                    throw AuthBootstrapError.athleteNotFound
                }
            }

            // 3. Populate local store from Supabase (requires local Athlete to be present)
            await container.syncService.pullAll(context: modelContext)

            // 4. Mark as authenticated (after sync — no race condition)
            isLoading = false
            Haptics.success()
            container.setAuthenticated(true)
        } catch {
            lastAuthError = error
            errorMessage = resolveErrorMessage(error, locale: locale)
            isLoading = false
        }
    }

    private func handleAppleSignIn(credential: ASAuthorizationAppleIDCredential) async {
        isSocialLoading = true
        errorMessage = nil
        do {
            try await container.authService.signInWithApple(credential: credential)
            let localAthletes = try? modelContext.fetch(FetchDescriptor<Athlete>())
            if localAthletes?.isEmpty != false {
                guard let userId = await container.authService.currentUserId() else {
                    throw AuthBootstrapError.noUserId
                }
                let existingAthlete = await container.syncService.bootstrapAthlete(
                    context: modelContext, userId: userId
                )
                if existingAthlete == nil {
                    // New user via Apple — create Athlete profile
                    let name = [credential.fullName?.givenName, credential.fullName?.familyName]
                        .compactMap { $0 }
                        .joined(separator: " ")
                    let athlete = Athlete(
                        id: userId,
                        displayName: name.isEmpty ? "Athlete" : name,
                        sportType: .custom,
                        supabaseUserId: userId
                    )
                    modelContext.insert(athlete)
                    try modelContext.save()
                    await container.syncService.pushAthlete(athlete)
                }
            }
            await container.syncService.pullAll(context: modelContext)
            isSocialLoading = false
            Haptics.success()
            container.setAuthenticated(true)
        } catch {
            lastAuthError = error
            errorMessage = resolveErrorMessage(error, locale: locale)
            isSocialLoading = false
        }
    }

    private func handleGoogleSignIn() async {
        isSocialLoading = true
        errorMessage = nil
        do {
            try await container.authService.signInWithGoogle()
            let localAthletes = try? modelContext.fetch(FetchDescriptor<Athlete>())
            if localAthletes?.isEmpty != false {
                guard let userId = await container.authService.currentUserId() else {
                    throw AuthBootstrapError.noUserId
                }
                let existingAthlete = await container.syncService.bootstrapAthlete(
                    context: modelContext, userId: userId
                )
                if existingAthlete == nil {
                    // New user via Google — create Athlete profile
                    let athlete = Athlete(
                        id: userId,
                        displayName: "Athlete",
                        sportType: .custom,
                        supabaseUserId: userId
                    )
                    modelContext.insert(athlete)
                    try modelContext.save()
                    await container.syncService.pushAthlete(athlete)
                }
            }
            await container.syncService.pullAll(context: modelContext)
            isSocialLoading = false
            Haptics.success()
            container.setAuthenticated(true)
        } catch {
            lastAuthError = error
            errorMessage = resolveErrorMessage(error, locale: locale)
            isSocialLoading = false
        }
    }
}

private enum AuthBootstrapError: LocalizedError {
    case noUserId
    case athleteNotFound

    var localizationKey: String.LocalizationValue {
        switch self {
        case .noUserId: return "auth.error.noUserId"
        case .athleteNotFound: return "auth.error.athleteNotFound"
        }
    }

    var defaultValue: String {
        switch self {
        case .noUserId: return "Could not retrieve your account. Please try again."
        case .athleteNotFound: return "Account profile not found. Please contact support."
        }
    }

    var errorDescription: String? { defaultValue }
}
