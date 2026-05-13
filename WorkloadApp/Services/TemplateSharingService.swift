import Foundation
import Supabase
import SwiftData

/// Namespace for template sharing operations: code generation, share creation, lookup, import.
/// Mirrors InviteService pattern -- all Supabase calls on @MainActor; no instance state.
enum TemplateSharingService {

    // MARK: - Code Generation

    /// Generate 8-char alphanumeric share code (extends InviteService 6-char pattern to 8)
    static func makeShareCode() -> String {
        let chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<8).map { _ in chars.randomElement()! })
    }

    // MARK: - Deep Link Parsing

    /// Parse template share code from universal link or custom URL scheme.
    /// Universal link: https://tuwa.app/t/{code}
    /// Custom scheme: workload://template?code={code}
    static func handleDeepLink(_ url: URL) -> String? {
        // Universal link: tuwa.app/t/{code}
        if url.host == "tuwa.app" || url.host == "www.tuwa.app" {
            let components = url.pathComponents
            if components.count >= 3, components[1] == "t" {
                let code = components[2]
                if code.count == 8 { return code.uppercased() }
            }
        }
        // Custom URL scheme fallback
        if url.scheme == "workload", url.host == "template" {
            return URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?
                .first(where: { $0.name == "code" })?
                .value?
                .uppercased()
        }
        return nil
    }

    // MARK: - Share Creation

    /// Create a shared_templates row in Supabase, returns the 8-char code.
    /// Retries up to 3 times on unique constraint violation (code collision).
    @MainActor
    static func shareTemplate(
        _ template: WorkoutTemplate,
        ownerId: UUID,
        client: SupabaseClient
    ) async throws -> String {
        struct SharedTemplateInsert: Encodable {
            let share_code: String
            let owner_id: UUID
            let template_json: TemplateSharePayload
            let expires_at: Date
        }

        for attempt in 0..<3 {
            let code = makeShareCode()
            let expires = Date.now.addingTimeInterval(30 * 24 * 60 * 60) // 30 days

            let groupsJson = SyncService.encodeGroups(template.groups)

            let payload = SharedTemplateInsert(
                share_code: code,
                owner_id: ownerId,
                template_json: TemplateSharePayload(
                    v: 1,
                    template_name: template.templateName,
                    sport_type: template.sportType.rawValue,
                    session_type: template.sessionType.rawValue,
                    notes: template.notes,
                    scheduled_days: template.scheduledDays,
                    groups_json: groupsJson
                ),
                expires_at: expires
            )

            do {
                try await client.from("shared_templates")
                    .insert(payload)
                    .execute()
                return code
            } catch {
                // On unique violation (code collision), retry
                let errorStr = "\(error)"
                if errorStr.contains("23505") && attempt < 2 {
                    continue
                }
                throw error
            }
        }
        // Should not reach here due to throw in loop, but satisfy compiler
        throw NSError(
            domain: "TemplateSharingService",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Failed to generate unique share code after 3 attempts"]
        )
    }

    // MARK: - Share Lookup

    /// Look up a shared template by its 8-char code.
    @MainActor
    static func lookupShareCode(
        _ code: String,
        client: SupabaseClient
    ) async throws -> SharedTemplateResponse {
        struct SharedTemplateRow: Decodable {
            let id: UUID
            let share_code: String
            let owner_id: UUID
            let template_json: TemplateSharePayload
            let expires_at: Date
            let created_at: Date
        }

        let row: SharedTemplateRow = try await client
            .from("shared_templates")
            .select()
            .eq("share_code", value: code.uppercased())
            .gt("expires_at", value: ISO8601DateFormatter().string(from: Date.now))
            .single()
            .execute()
            .value

        return SharedTemplateResponse(
            id: row.id,
            shareCode: row.share_code,
            ownerId: row.owner_id,
            payload: row.template_json,
            expiresAt: row.expires_at
        )
    }

    // MARK: - Import

    /// Import a shared template: decode JSON, strip weights, create local copy with new UUIDs.
    /// Weights are stripped to prevent leaking the sharer's personal training data.
    @MainActor
    static func importTemplate(
        from response: SharedTemplateResponse,
        forAthlete athlete: Athlete,
        context: ModelContext
    ) -> WorkoutTemplate {
        let payload = response.payload

        // Decode groups from JSON using SyncService (creates fresh objects with new UUIDs)
        var groups: [ExerciseGroup] = []
        if let json = payload.groups_json {
            groups = SyncService.decodeGroups(from: json)
        }

        // Strip targetWeightKg from all sets (no personal weight data from sharer)
        for group in groups {
            for exercise in group.exercises {
                for set in exercise.sets {
                    set.targetWeightKg = nil
                }
            }
        }

        // Create new template with current user as owner
        let template = WorkoutTemplate(
            coachId: athlete.id,
            templateName: payload.template_name,
            sportType: SportType(rawValue: payload.sport_type) ?? .lifting,
            sessionType: SessionType(rawValue: payload.session_type) ?? .strength
        )
        template.notes = payload.notes
        template.scheduledDays = payload.scheduled_days
        template.isAthleteOwned = true
        template.athleteId = athlete.id
        template.groups = groups

        context.insert(template)
        return template
    }
}

// MARK: - Codable Types

/// Versioned payload stored in template_json JSONB column.
struct TemplateSharePayload: Codable {
    let v: Int
    let template_name: String
    let sport_type: String
    let session_type: String
    let notes: String?
    let scheduled_days: [Int]
    let groups_json: String?
}

/// Response type from share code lookup.
struct SharedTemplateResponse: Identifiable {
    let id: UUID
    let shareCode: String
    let ownerId: UUID
    let payload: TemplateSharePayload
    let expiresAt: Date
}
