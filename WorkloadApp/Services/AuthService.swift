import Foundation
import Supabase
import AuthenticationServices

/// Wraps Supabase authentication.
@MainActor
@Observable
final class AuthService {

    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    /// Returns the current authenticated user's UUID, or nil if not signed in.
    func currentUserId() async -> UUID? {
        try? await client.auth.session.user.id
    }

    func signUp(email: String, password: String, displayName: String, sportType: String) async throws -> UUID {
        let response = try await client.auth.signUp(
            email: email,
            password: password,
            data: [
                "display_name": .string(displayName),
                "sport_type": .string(sportType)
            ]
        )
        return response.user.id
    }

    func signIn(email: String, password: String) async throws {
        try await client.auth.signIn(email: email, password: password)
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }

    /// Deletes the authenticated user's account via a Supabase RPC function.
    /// The RPC function `delete_own_account` runs with security definer privileges
    /// to remove the user from auth.users after cleaning up public data.
    func deleteAccount() async throws {
        try await client.rpc("delete_own_account").execute()
    }

    /// Returns true if a valid session exists (checks Keychain — does not make a network request).
    func hasSession() async -> Bool {
        (try? await client.auth.session) != nil
    }

    // MARK: - Social Auth

    /// Sign in with Apple using the credential from ASAuthorizationController.
    func signInWithApple(credential: ASAuthorizationAppleIDCredential) async throws {
        guard let tokenData = credential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8) else {
            throw AuthError.noIdentityToken
        }

        _ = try await client.auth.signInWithIdToken(
            credentials: .init(provider: .apple, idToken: idToken)
        )

        // Capture display name on first sign-in (Apple only sends it once)
        if let fullName = credential.fullName {
            let parts = [fullName.givenName, fullName.familyName].compactMap { $0 }
            let name = parts.joined(separator: " ")
            if !name.isEmpty {
                try? await client.auth.update(
                    user: UserAttributes(data: ["display_name": .string(name)])
                )
            }
        }
    }

    /// Sign in with Google via Supabase OAuth (opens ASWebAuthenticationSession).
    func signInWithGoogle() async throws {
        _ = try await client.auth.signInWithOAuth(
            provider: .google,
            redirectTo: URL(string: "com.tonus.app://login-callback")
        ) { (session: ASWebAuthenticationSession) in
            session.prefersEphemeralWebBrowserSession = false
        }
    }

    enum AuthError: LocalizedError {
        case noUserReturned
        case noIdentityToken
        case socialSignInFailed(String)
        var errorDescription: String? {
            switch self {
            case .noUserReturned: return "Sign up succeeded but no user was returned. Please try again."
            case .noIdentityToken: return "Apple sign in failed. Could not retrieve identity token."
            case .socialSignInFailed(let message): return message
            }
        }
    }
}
