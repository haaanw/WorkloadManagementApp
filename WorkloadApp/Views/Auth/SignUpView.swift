import SwiftUI
import SwiftData
import AuthenticationServices

struct SignUpView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale
    @State private var displayName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var selectedSport: SportType = .lifting
    @State private var isLoading = false
    @State private var isSocialLoading = false
    @State private var errorMessage: String?
    @State private var lastAuthError: (any Error)?

    /// Resolve a caught error against the current env locale (Pitfall 7).
    private func resolveErrorMessage(_ error: any Error, locale: Locale) -> String {
        if let authError = error as? AuthService.AuthError {
            // socialSignInFailed wraps an opaque server message — surface verbatim.
            if let serverMessage = authError.serverMessage {
                return serverMessage
            }
            var resource = LocalizedStringResource(authError.localizationKey)
            resource.locale = locale
            return String(localized: resource)
        } else if let socialError = error as? SignUpSocialError {
            var resource = LocalizedStringResource(socialError.localizationKey)
            resource.locale = locale
            return String(localized: resource)
        } else {
            return error.localizedDescription
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("auth.signup.heading")
                        .font(.Tokens.pageTitle)
                        .foregroundStyle(ColorTokens.text1)
                    Text("auth.signup.subhead")
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.sm)
                .padding(.top, Spacing.lg)
                .padding(.bottom, Spacing.lg)

                // Fields — the standard field treatment (control-radius plate, hairline,
                // ink focus feedback), stacked on the page plane instead of full-bleed rows.
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
                }
                .padding(.horizontal, Spacing.sm)

                // Sport picker
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("auth.signup.primarySport")
                        .font(.Tokens.sectionHead)
                        .foregroundStyle(ColorTokens.text1)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 88))], spacing: Spacing.xs) {
                        ForEach(SportType.allCases) { sport in
                            Button {
                                Haptics.select()
                                selectedSport = sport
                            } label: {
                                VStack(spacing: Spacing.xs) {
                                    Image(systemName: sport.systemImage)
                                        .font(.Tokens.sectionHead)
                                        .foregroundStyle(selectedSport == sport ? ColorTokens.text1 : ColorTokens.text2)
                                    Text(sport.displayName)
                                        .font(.Tokens.micro)
                                        .foregroundStyle(selectedSport == sport ? ColorTokens.text1 : ColorTokens.text2)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Spacing.sm)
                                .background(
                                    selectedSport == sport ? ColorTokens.surfaceEl2 : ColorTokens.surfaceEl,
                                    in: RoundedRectangle(cornerRadius: CornerTokens.control)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: CornerTokens.control).stroke(
                                        selectedSport == sport ? ColorTokens.text1 : ColorTokens.divider,
                                        lineWidth: selectedSport == sport ? 1.0 : 0.5
                                    )
                                )
                            }
                            .buttonStyle(.pressable)
                        }
                    }
                }
                .padding(.horizontal, Spacing.sm)
                .padding(.top, Spacing.md)

                if let error = errorMessage {
                    Text(error)
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.zoneDanger)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.top, Spacing.sm)
                }

                // Create account button — primary CTA is the ink-filled pill (v5 CTA Law; never accent).
                PrimaryActionButton(
                    title: "auth.signup.heading",
                    isLoading: isLoading,
                    isDisabled: !isFormValid || isSocialLoading
                ) {
                    Task { await signUp() }
                }
                .padding(.horizontal, Spacing.sm)
                .padding(.top, Spacing.md)

                // Social login buttons
                SocialLoginButtons(
                    mode: .signUp,
                    isLoading: isSocialLoading,
                    onAppleCredential: { credential in
                        Task { await handleAppleSignIn(credential: credential) }
                    },
                    onGoogleTap: {
                        Task { await handleGoogleSignIn() }
                    }
                )
                .padding(.bottom, Spacing.lg)
            }
        }
        .background(ColorTokens.background)
        .navigationTitle("auth.nav.signUp")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: locale) { _, newLocale in
            // Re-resolve any pending auth-error message against the new env locale (Pitfall 7).
            if let pending = lastAuthError, errorMessage != nil {
                errorMessage = resolveErrorMessage(pending, locale: newLocale)
            }
        }
    }

    private var isFormValid: Bool {
        !displayName.isEmpty && !email.isEmpty && password.count >= 8
    }

    private func signUp() async {
        isLoading = true
        errorMessage = nil
        do {
            // 1. Create Supabase auth user
            let userId = try await container.authService.signUp(
                email: email,
                password: password,
                displayName: displayName,
                sportType: selectedSport.rawValue
            )

            // 2. Create Athlete locally
            let athlete = Athlete(
                id: userId,
                displayName: displayName,
                sportType: selectedSport,
                supabaseUserId: userId
            )
            modelContext.insert(athlete)
            try modelContext.save()

            // 3. Push athlete profile to Supabase
            // AthleteRow is defined in SyncService.swift — reuse it here
            await container.syncService.pushAthlete(athlete)

            // 4. Mark as authenticated
            Haptics.success()
            container.setAuthenticated(true)
        } catch {
            lastAuthError = error
            errorMessage = resolveErrorMessage(error, locale: locale)
        }
        isLoading = false
    }

    private func handleAppleSignIn(credential: ASAuthorizationAppleIDCredential) async {
        isSocialLoading = true
        errorMessage = nil
        do {
            try await container.authService.signInWithApple(credential: credential)
            let localAthletes = try? modelContext.fetch(FetchDescriptor<Athlete>())
            if localAthletes?.isEmpty != false {
                guard let userId = await container.authService.currentUserId() else {
                    throw SignUpSocialError.noUserId
                }
                let existingAthlete = await container.syncService.bootstrapAthlete(
                    context: modelContext, userId: userId
                )
                if existingAthlete == nil {
                    // New user — create Athlete profile locally and push to Supabase
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
                    throw SignUpSocialError.noUserId
                }
                let existingAthlete = await container.syncService.bootstrapAthlete(
                    context: modelContext, userId: userId
                )
                if existingAthlete == nil {
                    // New user — create Athlete profile locally and push to Supabase
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

private enum SignUpSocialError: LocalizedError {
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

// MARK: - Reusable input field components

/// The standard auth field: small caption label above a control-radius field plate
/// (`CornerTokens.control`, 0.5pt hairline). Focus feedback mirrors `InstrumentTextField` —
/// the INK hairline thickens to 1pt while editing (Accent Rule — accent never marks focus),
/// settling via `Motion.state`.
struct InputField: View {
    let label: LocalizedStringKey
    /// Verbatim placeholder (String, not LocalizedStringKey — a key would markdown-parse
    /// "you@example.com" into a blue auto-link). Styled quiet (`text3`) via the prompt.
    let placeholder: String
    @Binding var text: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.baselinePair) {
            Text(label)
                .font(.Tokens.smallLabel)
                .foregroundStyle(ColorTokens.text2)
            TextField(label, text: $text, prompt: Text(placeholder).foregroundStyle(ColorTokens.text3))
                .focused($isFocused)
                .font(.Tokens.body)
                .foregroundStyle(ColorTokens.text1)
                .padding(.horizontal, Spacing.sm)
                .frame(minHeight: 44)
                .background(ColorTokens.surfaceEl, in: RoundedRectangle(cornerRadius: CornerTokens.control))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerTokens.control).stroke(
                        isFocused ? ColorTokens.text1 : ColorTokens.divider,
                        lineWidth: isFocused ? 1 : 0.5
                    )
                )
                .animation(Motion.resolved(Motion.state, reduceMotion: reduceMotion), value: isFocused)
        }
    }
}

/// Secure twin of `InputField` — same field treatment, `SecureField` entry.
struct SecureInputField: View {
    let label: LocalizedStringKey
    /// Verbatim placeholder — see `InputField.placeholder`.
    let placeholder: String
    @Binding var text: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.baselinePair) {
            Text(label)
                .font(.Tokens.smallLabel)
                .foregroundStyle(ColorTokens.text2)
            SecureField(label, text: $text, prompt: Text(placeholder).foregroundStyle(ColorTokens.text3))
                .focused($isFocused)
                .font(.Tokens.body)
                .foregroundStyle(ColorTokens.text1)
                .padding(.horizontal, Spacing.sm)
                .frame(minHeight: 44)
                .background(ColorTokens.surfaceEl, in: RoundedRectangle(cornerRadius: CornerTokens.control))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerTokens.control).stroke(
                        isFocused ? ColorTokens.text1 : ColorTokens.divider,
                        lineWidth: isFocused ? 1 : 0.5
                    )
                )
                .animation(Motion.resolved(Motion.state, reduceMotion: reduceMotion), value: isFocused)
        }
    }
}
