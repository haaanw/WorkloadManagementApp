import Foundation
import Supabase

/// Namespace for voice-logged workout parsing: invokes the `parse-workout` edge function in
/// `mode: "log"`, and maps its response into `ExerciseEntryDraft`/`SetDraft` values that
/// `ActiveWorkoutSheet` can drop straight into a session.
///
/// Reuses `WorkoutLLMImportService.resolveLocalExercise` (and its category/muscle-group
/// mappers) for exercise identity resolution — never reimplements that matching logic.
/// The mapper is a pure function (no `ModelContext`, no network) so it is unit-testable
/// without SwiftData or Supabase.
enum WorkoutVoiceLogService {

    // MARK: - Response Types

    /// Exact snake_case mirror of the `parse-workout` edge function's `mode: "log"` JSON
    /// contract (see `Supabase/functions/parse-workout/index.ts`, `LoggedWorkout`).
    struct ParsedLoggedWorkoutResponse: Decodable {
        let workout_name: String
        let sport_type: String
        let session_type: String
        let session_rpe: Int?
        let session_duration_minutes: Int?
        let groups: [ParsedGroup]

        struct ParsedGroup: Decodable {
            let group_name: String
            let exercises: [ParsedExercise]
        }

        struct ParsedExercise: Decodable {
            let exercise_name: String
            let exercise_category: String
            let muscle_group: String?
            let sets: [ParsedSet]
        }

        struct ParsedSet: Decodable {
            let reps: Int?
            let weight_kg: Double?
            let duration_seconds: Int?
            let rpe: Double?
            let is_warmup: Bool
        }
    }

    // MARK: - Errors

    enum VoiceLogError: LocalizedError {
        case quotaExceeded
        case offline
        case parseFailed(String)

        var errorDescription: String? {
            switch self {
            case .quotaExceeded:
                return String(localized: "voice.error.quota", defaultValue: "You've hit today's voice logging limit. Log manually for now.")
            case .offline:
                return String(localized: "voice.error.offline", defaultValue: "No internet connection. Check your connection and try again.")
            case .parseFailed(let detail):
                return String(localized: "voice.error.parse", defaultValue: "Could not understand that workout: \(detail)")
            }
        }
    }

    // MARK: - Parsed Draft

    /// A voice-logged session, ready to hand to `ActiveWorkoutSheet`. Every non-empty
    /// parsed set arrives with `SetDraft.isDone == true` — the sheet's zero-done save guard
    /// (`persistSession` filters `sets.filter { $0.isDone }`) means an undone set does not exist.
    struct ParsedSessionDraft {
        var sessionName: String
        var sportType: SportType
        var sessionType: SessionType
        var sessionRPE: Int?
        var durationMinutes: Int?
        var entries: [ExerciseEntryDraft]
        var unresolvedExerciseNames: [String]
        var transcript: String
    }

    // MARK: - Edge Function Call

    /// Sends transcribed workout speech to the `parse-workout` edge function in log mode and
    /// decodes the structured response. Maps transport/HTTP failures to `VoiceLogError`:
    /// HTTP 429 -> `.quotaExceeded`, transport-layer connectivity failures -> `.offline`,
    /// everything else (including HTTP 401/502 and decode failures) -> `.parseFailed`.
    @MainActor
    static func parseLoggedWorkoutText(
        _ text: String,
        client: SupabaseClient
    ) async throws -> ParsedLoggedWorkoutResponse {
        struct LogRequest: Encodable {
            let workout_text: String
            let mode: String
        }

        do {
            let response: ParsedLoggedWorkoutResponse = try await client.functions.invoke(
                "parse-workout",
                options: .init(body: LogRequest(workout_text: text, mode: "log"))
            )
            return response
        } catch let error as VoiceLogError {
            throw error
        } catch let error as FunctionsError {
            throw mapFunctionsError(error)
        } catch let error as URLError {
            if isOffline(error) {
                throw VoiceLogError.offline
            }
            throw VoiceLogError.parseFailed(error.localizedDescription)
        } catch {
            throw VoiceLogError.parseFailed(error.localizedDescription)
        }
    }

    private static func mapFunctionsError(_ error: FunctionsError) -> VoiceLogError {
        switch error {
        case .httpError(let code, let data):
            if code == 429 {
                return .quotaExceeded
            }
            return .parseFailed(serverErrorDetail(from: data) ?? "HTTP \(code)")
        case .relayError:
            return .parseFailed(error.localizedDescription)
        }
    }

    /// Best-effort extraction of the `{"error": "..."}` body the edge function returns on
    /// non-2xx responses, so `.parseFailed` carries a useful detail instead of a bare status code.
    private static func serverErrorDetail(from data: Data) -> String? {
        struct ServerError: Decodable { let error: String }
        return try? JSONDecoder().decode(ServerError.self, from: data).error
    }

    private static func isOffline(_ error: URLError) -> Bool {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed,
             .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed,
             .internationalRoamingOff:
            return true
        default:
            return false
        }
    }

    // MARK: - Response Mapping

    /// Maps the LLM-parsed log response into a `ParsedSessionDraft`. Pure — no `ModelContext`,
    /// no network — so it is fully unit-testable with in-memory fixtures.
    ///
    /// Per exercise: tries `WorkoutLLMImportService.resolveLocalExercise` first. On a hit, the
    /// entry uses the matched candidate's **canonical catalog name** (`ResolvedExercise
    /// .matchedCatalogName`) so history/PR lookups stay continuous, plus the resolved category
    /// and muscle group. On a miss, the entry keeps the spoken name, maps `exercise_category`/
    /// `muscle_group` via the existing mappers, and the spoken name is appended to
    /// `unresolvedExerciseNames` for the caller to surface for manual review.
    static func mapToParsedSessionDraft(
        _ response: ParsedLoggedWorkoutResponse,
        transcript: String,
        catalogExercises: [ExerciseDefinition],
        customExercises: [CustomExercise]
    ) -> ParsedSessionDraft {
        let sportType = SportType(rawValue: response.sport_type) ?? .lifting
        let sessionType = SessionType(rawValue: response.session_type) ?? .strength

        let sessionRPE: Int? = response.session_rpe.flatMap { (1...10).contains($0) ? $0 : nil }
        let durationMinutes: Int? = response.session_duration_minutes.flatMap { $0 >= 0 ? $0 : nil }

        // A voice narration that never names a group ("bench, then squats") should not surface
        // a synthetic single-group label in the UI — only tag entries when the LLM actually
        // segmented the workout into more than one group.
        let hasMultipleGroups = response.groups.count > 1

        let mapped: [MappedExercise] = response.groups.flatMap { group in
            group.exercises.map { exercise in
                mapExercise(
                    exercise,
                    groupName: hasMultipleGroups ? group.group_name : nil,
                    sportType: sportType,
                    catalogExercises: catalogExercises,
                    customExercises: customExercises
                )
            }
        }

        return ParsedSessionDraft(
            sessionName: response.workout_name,
            sportType: sportType,
            sessionType: sessionType,
            sessionRPE: sessionRPE,
            durationMinutes: durationMinutes,
            entries: mapped.map(\.draft),
            unresolvedExerciseNames: mapped.compactMap(\.unresolvedName),
            transcript: transcript
        )
    }

    private struct MappedExercise {
        let draft: ExerciseEntryDraft
        let unresolvedName: String?
    }

    private static func mapExercise(
        _ exercise: ParsedLoggedWorkoutResponse.ParsedExercise,
        groupName: String?,
        sportType: SportType,
        catalogExercises: [ExerciseDefinition],
        customExercises: [CustomExercise]
    ) -> MappedExercise {
        let resolved = WorkoutLLMImportService.resolveLocalExercise(
            name: exercise.exercise_name,
            sportType: sportType,
            catalogExercises: catalogExercises,
            customExercises: customExercises
        )

        let exerciseName: String
        let exerciseCategory: ExerciseCategory
        let muscleGroup: MuscleGroup?
        let unresolvedName: String?

        if let resolved {
            exerciseName = resolved.matchedCatalogName ?? resolved.name
            exerciseCategory = resolved.exerciseCategory
            muscleGroup = resolved.muscleGroup
            unresolvedName = nil
        } else {
            exerciseName = exercise.exercise_name
            exerciseCategory = WorkoutLLMImportService.mapExerciseCategory(exercise.exercise_category) ?? .compound
            muscleGroup = WorkoutLLMImportService.mapMuscleGroup(exercise.muscle_group)
            unresolvedName = exercise.exercise_name
        }

        var draft = ExerciseEntryDraft(
            exerciseName: exerciseName,
            exerciseCategory: exerciseCategory,
            muscleGroup: muscleGroup
        )
        draft.groupName = groupName

        // Every non-empty parsed set is done — it is a logged actual, not a target. An
        // exercise with no sets at all becomes one not-done empty shell so the athlete has
        // somewhere to fill in numbers manually; it is never a fabricated done set.
        draft.sets = exercise.sets.map { set in
            SetDraft(
                reps: set.reps,
                weightKg: set.weight_kg,
                durationSeconds: set.duration_seconds,
                rpe: set.rpe,
                isWarmup: set.is_warmup,
                isDone: true
            )
        }
        if draft.sets.isEmpty {
            draft.sets = [SetDraft(isDone: false)]
        }

        return MappedExercise(draft: draft, unresolvedName: unresolvedName)
    }
}
