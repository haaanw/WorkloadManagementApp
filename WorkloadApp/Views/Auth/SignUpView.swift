import SwiftUI
import SwiftData

struct SignUpView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.modelContext) private var modelContext
    @State private var displayName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var selectedSport: SportType = .lifting
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Create Account")
                        .font(.Tokens.pageTitle)
                        .foregroundStyle(ColorTokens.text1)
                    Text("Set up your athlete profile.")
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 32)
                .padding(.bottom, 32)

                Rectangle()
                    .fill(ColorTokens.divider)
                    .frame(height: 0.5)

                // Name field
                InputField(label: "NAME", placeholder: "Your name", text: $displayName)
                    .textContentType(.name)

                Rectangle()
                    .fill(ColorTokens.divider)
                    .frame(height: 0.5)

                // Email field
                InputField(label: "EMAIL", placeholder: "you@example.com", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                Rectangle()
                    .fill(ColorTokens.divider)
                    .frame(height: 0.5)

                // Password field
                SecureInputField(label: "PASSWORD", placeholder: "Min. 8 characters", text: $password)
                    .textContentType(.newPassword)

                Rectangle()
                    .fill(ColorTokens.divider)
                    .frame(height: 0.5)

                // Sport picker
                VStack(alignment: .leading, spacing: 16) {
                    Text("PRIMARY SPORT")
                        .font(.Tokens.micro)
                        .tracking(1.2)
                        .foregroundStyle(ColorTokens.text3)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 88))], spacing: 8) {
                        ForEach(SportType.allCases) { sport in
                            Button {
                                selectedSport = sport
                            } label: {
                                VStack(spacing: 8) {
                                    Image(systemName: sport.systemImage)
                                        .font(.system(size: 20))
                                        .foregroundStyle(selectedSport == sport ? ColorTokens.text1 : ColorTokens.text2)
                                    Text(sport.displayName)
                                        .font(.Tokens.micro)
                                        .tracking(0.5)
                                        .foregroundStyle(selectedSport == sport ? ColorTokens.text1 : ColorTokens.text2)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(selectedSport == sport ? ColorTokens.surface : ColorTokens.background)
                                .overlay(
                                    Rectangle().stroke(
                                        selectedSport == sport ? ColorTokens.text3 : ColorTokens.divider,
                                        lineWidth: selectedSport == sport ? 1.0 : 0.5
                                    )
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .background(ColorTokens.background)

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

                // Create account button
                Button {
                    Task { await signUp() }
                } label: {
                    Group {
                        if isLoading {
                            ProgressView()
                        } else {
                            Text("Create Account")
                                .font(.Tokens.body)
                                .foregroundStyle(isFormValid ? ColorTokens.text1 : ColorTokens.text3)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(ColorTokens.surface)
                }
                .disabled(!isFormValid || isLoading)

                Rectangle()
                    .fill(ColorTokens.divider)
                    .frame(height: 0.5)
            }
        }
        .background(ColorTokens.background)
        .navigationTitle("Sign Up")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var isFormValid: Bool {
        !displayName.isEmpty && !email.isEmpty && !password.isEmpty
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
            container.setAuthenticated(true)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Reusable input field components

struct InputField: View {
    let label: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .font(.Tokens.micro)
                .tracking(1.2)
                .foregroundStyle(ColorTokens.text3)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)
            TextField(placeholder, text: $text)
                .font(.Tokens.body)
                .foregroundStyle(ColorTokens.text1)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
        }
        .background(ColorTokens.surface)
    }
}

struct SecureInputField: View {
    let label: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .font(.Tokens.micro)
                .tracking(1.2)
                .foregroundStyle(ColorTokens.text3)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)
            SecureField(placeholder, text: $text)
                .font(.Tokens.body)
                .foregroundStyle(ColorTokens.text1)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
        }
        .background(ColorTokens.surface)
    }
}
