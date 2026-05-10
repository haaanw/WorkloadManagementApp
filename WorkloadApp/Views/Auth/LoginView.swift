import SwiftUI
import SwiftData
import AuthenticationServices

struct LoginView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.modelContext) private var modelContext
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isSocialLoading = false
    @State private var showSignUp = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Branding
                    VStack(alignment: .leading, spacing: 8) {
                        Text("WORKLOAD")
                            .font(.Tokens.pageTitle)
                            .foregroundStyle(ColorTokens.text1)
                        Text("Train smarter. Recover better.")
                            .font(.Tokens.label)
                            .foregroundStyle(ColorTokens.text2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 64)
                    .padding(.bottom, 48)

                    Rectangle()
                        .fill(ColorTokens.divider)
                        .frame(height: 0.5)

                    // Email field
                    VStack(alignment: .leading, spacing: 0) {
                        Text("EMAIL")
                            .font(.Tokens.micro)
                            .tracking(1.2)
                            .foregroundStyle(ColorTokens.text3)
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                            .padding(.bottom, 8)

                        TextField("you@example.com", text: $email)
                            .font(.Tokens.body)
                            .foregroundStyle(ColorTokens.text1)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
                    }
                    .background(ColorTokens.surface)

                    Rectangle()
                        .fill(ColorTokens.divider)
                        .frame(height: 0.5)

                    // Password field
                    VStack(alignment: .leading, spacing: 0) {
                        Text("PASSWORD")
                            .font(.Tokens.micro)
                            .tracking(1.2)
                            .foregroundStyle(ColorTokens.text3)
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                            .padding(.bottom, 8)

                        SecureField("••••••••", text: $password)
                            .font(.Tokens.body)
                            .foregroundStyle(ColorTokens.text1)
                            .textContentType(.password)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
                    }
                    .background(ColorTokens.surface)

                    Rectangle()
                        .fill(ColorTokens.divider)
                        .frame(height: 0.5)

                    if let error = errorMessage {
                        Text(error)
                            .font(.Tokens.label)
                            .foregroundStyle(ColorTokens.zoneDanger)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)

                        Rectangle()
                            .fill(ColorTokens.divider)
                            .frame(height: 0.5)
                    }

                    // Sign in button
                    Button {
                        Task { await signIn() }
                    } label: {
                        Group {
                            if isLoading {
                                ProgressView()
                            } else {
                                Text("Sign In")
                                    .font(.Tokens.body)
                                    .foregroundStyle(email.isEmpty || password.isEmpty ? ColorTokens.text3 : ColorTokens.text1)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(ColorTokens.surface)
                    }
                    .disabled(email.isEmpty || password.isEmpty || isLoading || isSocialLoading)

                    Rectangle()
                        .fill(ColorTokens.divider)
                        .frame(height: 0.5)

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

                    Rectangle()
                        .fill(ColorTokens.divider)
                        .frame(height: 0.5)

                    // Sign up link
                    Button {
                        showSignUp = true
                    } label: {
                        Text("Create an account")
                            .font(.Tokens.label)
                            .foregroundStyle(ColorTokens.text2)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }

                    Rectangle()
                        .fill(ColorTokens.divider)
                        .frame(height: 0.5)
                }
            }
            .background(ColorTokens.background)
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $showSignUp) {
                SignUpView()
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
            container.setAuthenticated(true)
        } catch {
            errorMessage = error.localizedDescription
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
            container.setAuthenticated(true)
        } catch {
            errorMessage = error.localizedDescription
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
            container.setAuthenticated(true)
        } catch {
            errorMessage = error.localizedDescription
            isSocialLoading = false
        }
    }
}

private enum AuthBootstrapError: LocalizedError {
    case noUserId
    case athleteNotFound
    var errorDescription: String? {
        switch self {
        case .noUserId: return "Could not retrieve your account. Please try again."
        case .athleteNotFound: return "Account profile not found. Please contact support."
        }
    }
}
