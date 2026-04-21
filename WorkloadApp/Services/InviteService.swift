import Foundation
import Supabase

/// Namespace for invite flow operations: code generation, email invite, deep link parsing, relationship confirmation.
/// All Supabase calls happen on the @MainActor; no instance state.
enum InviteService {

    // MARK: - Code generation (local, no network)

    /// Generates a cryptographically random 6-character uppercase alphanumeric code.
    static func makeLocalCode() -> String {
        let chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<6).map { _ in chars.randomElement()! })
    }

    // MARK: - Deep link parsing (local, no network)

    /// Extracts the invite code from a deep link URL.
    /// Expected format: workload://invite?code=XXXXXX
    /// Returns nil if the URL is not a valid invite link.
    static func handleDeepLink(_ url: URL) -> String? {
        guard url.scheme == "workload",
              url.host == "invite" else { return nil }
        return URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == "code" })?
            .value
    }

    // MARK: - Code flow: athlete generates invite code

    /// Creates an invitation row in Supabase and returns the 6-char code.
    /// The athlete is the inviter. Expires in 48 hours.
    @MainActor
    static func generateInviteCode(
        for athleteId: UUID,
        client: SupabaseClient
    ) async throws -> String {
        let code = makeLocalCode()
        let expires = Date.now.addingTimeInterval(48 * 60 * 60)

        struct InvitationInsert: Encodable {
            let inviterId: UUID
            let inviterRole: String
            let code: String
            let expiresAt: Date
        }

        try await client
            .from("invitations")
            .insert(InvitationInsert(
                inviterId: athleteId,
                inviterRole: "athlete",
                code: code,
                expiresAt: expires
            ))
            .execute()

        return code
    }

    // MARK: - Code flow: coach resolves code (before confirmation)

    /// Looks up an invitation by code and returns the athlete who created it.
    /// Shown on the confirmation screen — does NOT insert the relationship.
    @MainActor
    static func resolveCode(
        _ code: String,
        client: SupabaseClient
    ) async throws -> ResolvedInvitation {
        struct InvitationRow: Decodable {
            let id: UUID
            let inviterId: UUID
            let inviterRole: String
        }

        let row: InvitationRow = try await client
            .from("invitations")
            .select("id, inviter_id, inviter_role")
            .eq("code", value: code)
            .single()
            .execute()
            .value

        struct AthleteRow: Decodable {
            let id: UUID
            let displayName: String?
            let sportType: String?
        }

        let athlete: AthleteRow = try await client
            .from("athletes")
            .select("id, display_name, sport_type")
            .eq("id", value: row.inviterId)
            .single()
            .execute()
            .value

        return ResolvedInvitation(
            invitationId: row.id,
            code: code,
            otherPartyId: athlete.id,
            otherPartyName: athlete.displayName ?? "Unknown",
            otherPartySport: SportType(rawValue: athlete.sportType ?? "") ?? .custom
        )
    }

    // MARK: - Confirm relationship (after user taps "Confirm")

    /// Inserts the coach_athlete_relationships row.
    /// Also marks the invitation as accepted (if invitationId is provided).
    @MainActor
    static func confirmRelationship(
        coachId: UUID,
        athleteId: UUID,
        invitationId: UUID?,
        redeemerAthleteId: UUID?,
        client: SupabaseClient
    ) async throws -> CoachAthleteRelationship {
        struct RelationshipInsert: Encodable {
            let coachId: UUID
            let athleteId: UUID
            let status: String
        }

        struct RelationshipRow: Decodable {
            let id: UUID
            let coachId: UUID
            let athleteId: UUID
            let status: String
            let createdAt: Date
            let updatedAt: Date
        }

        let row: RelationshipRow = try await client
            .from("coach_athlete_relationships")
            .insert(RelationshipInsert(coachId: coachId, athleteId: athleteId, status: "accepted"))
            .select()
            .single()
            .execute()
            .value

        // Mark invitation accepted (code and email flows)
        if let invitationId, let redeemerAthleteId {
            struct InvitationUpdate: Encodable {
                let status: String
                let redeemedBy: UUID
            }
            try? await client
                .from("invitations")
                .update(InvitationUpdate(status: "accepted", redeemedBy: redeemerAthleteId))
                .eq("id", value: invitationId)
                .execute()
        }

        let rel = CoachAthleteRelationship(
            id: row.id,
            coachId: row.coachId,
            athleteId: row.athleteId,
            status: RelationshipStatus(rawValue: row.status) ?? .accepted
        )
        rel.createdAt = row.createdAt
        rel.updatedAt = row.updatedAt
        return rel
    }

    // MARK: - Email flow: coach sends invite to athlete

    /// Creates an invitation row for email-based invite.
    /// Supabase Edge Function "send-invite-email" sends the deep link.
    @MainActor
    static func sendEmailInvite(
        to email: String,
        from coachId: UUID,
        client: SupabaseClient
    ) async throws {
        let code = makeLocalCode()
        let expires = Date.now.addingTimeInterval(48 * 60 * 60)

        struct InvitationInsert: Encodable {
            let inviterId: UUID
            let inviterRole: String
            let code: String
            let email: String
            let expiresAt: Date
        }

        try await client
            .from("invitations")
            .insert(InvitationInsert(
                inviterId: coachId,
                inviterRole: "coach",
                code: code,
                email: email,
                expiresAt: expires
            ))
            .execute()

        struct EdgePayload: Encodable {
            let email: String
            let code: String
        }
        try await client.functions.invoke(
            "send-invite-email",
            options: .init(body: EdgePayload(email: email, code: code))
        )
    }
}

// MARK: - Value types

struct ResolvedInvitation {
    let invitationId: UUID
    let code: String
    let otherPartyId: UUID
    let otherPartyName: String
    let otherPartySport: SportType
}
