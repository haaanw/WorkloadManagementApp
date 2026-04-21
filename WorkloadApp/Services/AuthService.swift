import Foundation
import Supabase

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

    /// Returns true if a valid session exists (checks Keychain — does not make a network request).
    func hasSession() async -> Bool {
        (try? await client.auth.session) != nil
    }

    enum AuthError: LocalizedError {
        case noUserReturned
        var errorDescription: String? {
            switch self {
            case .noUserReturned: return "Sign up succeeded but no user was returned. Please try again."
            }
        }
    }
}
