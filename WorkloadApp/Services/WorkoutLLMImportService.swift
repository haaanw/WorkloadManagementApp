import Foundation
import Supabase
import PDFKit
import Vision
import UIKit

/// Namespace for LLM-powered workout import: PDF text extraction, image OCR,
/// edge function invocation, and response-to-draft mapping.
/// All Supabase calls happen on @MainActor; extraction methods are off-main-thread safe.
enum WorkoutLLMImportService {

    // MARK: - Response Types

    struct ParsedWorkoutResponse: Decodable {
        let workout_name: String
        let sport_type: String
        let session_type: String
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
            let target_reps: Int?
            let target_weight_kg: Double?
            let target_duration_seconds: Int?
            let target_rpe: Double?
            let is_warmup: Bool
        }
    }

    // MARK: - Errors

    enum ImportError: LocalizedError {
        case invalidPDF
        case invalidImage
        case noTextFound
        case parseFailed(String)
        case notAuthenticated

        var errorDescription: String? {
            switch self {
            case .invalidPDF:
                return String(localized: "error.import.invalidPDF", defaultValue: "Could not read the PDF file. It may be corrupted or password-protected.")
            case .invalidImage:
                return String(localized: "error.import.invalidImage", defaultValue: "Could not process the image. Please try a different photo.")
            case .noTextFound:
                return String(localized: "error.import.noTextFound", defaultValue: "No readable text found in the file. Try a clearer image or a different format.")
            case .parseFailed(let detail):
                return String(localized: "error.import.parseFailed", defaultValue: "Failed to parse workout: \(detail)")
            case .notAuthenticated:
                return String(localized: "error.import.notAuthenticated", defaultValue: "You must be signed in to import workouts.")
            }
        }
    }

    // MARK: - Edge Function Call

    /// Sends workout text to the parse-workout edge function and decodes the structured response.
    @MainActor
    static func parseWorkoutText(
        _ text: String,
        client: SupabaseClient
    ) async throws -> ParsedWorkoutResponse {
        struct ParseRequest: Encodable {
            let workout_text: String
        }

        do {
            let response: ParsedWorkoutResponse = try await client.functions.invoke(
                "parse-workout",
                options: .init(body: ParseRequest(workout_text: text))
            )
            return response
        } catch let error as ImportError {
            throw error
        } catch {
            throw ImportError.parseFailed(error.localizedDescription)
        }
    }

    // MARK: - PDF Text Extraction

    /// Extracts text from a PDF file. Tries the text layer first (digital PDFs),
    /// then falls back to rendering each page as an image and running OCR (scanned PDFs).
    static func extractTextFromPDF(url: URL) async throws -> String {
        guard let document = PDFDocument(url: url) else {
            throw ImportError.invalidPDF
        }

        // Try text layer first (digital PDFs)
        var text = ""
        for i in 0..<document.pageCount {
            if let pageText = document.page(at: i)?.string {
                text += pageText + "\n"
            }
        }

        // If text layer is empty/whitespace, fall back to OCR on rendered pages
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            text = ""
            for i in 0..<document.pageCount {
                guard let page = document.page(at: i) else { continue }
                let bounds = page.bounds(for: .mediaBox)
                let renderer = UIGraphicsImageRenderer(size: bounds.size)
                let image = renderer.image { ctx in
                    UIColor.white.setFill()
                    ctx.fill(bounds)
                    ctx.cgContext.translateBy(x: 0, y: bounds.height)
                    ctx.cgContext.scaleBy(x: 1, y: -1)
                    page.draw(with: .mediaBox, to: ctx.cgContext)
                }
                if let pageText = try? await extractTextFromImage(image) {
                    text += pageText + "\n"
                }
            }
        }

        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ImportError.noTextFound
        }

        return text
    }

    // MARK: - Image OCR

    /// Extracts text from an image using Vision framework VNRecognizeTextRequest.
    /// Results are sorted in reading order (top-to-bottom, left-to-right).
    static func extractTextFromImage(_ image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else {
            throw ImportError.invalidImage
        }

        return try await withCheckedThrowingContinuation { continuation in
            var hasResumed = false
            let request = VNRecognizeTextRequest { request, error in
                guard !hasResumed else { return }
                hasResumed = true

                if let error {
                    print("Image OCR error: \(error)")
                    continuation.resume(throwing: ImportError.invalidImage)
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: "")
                    return
                }

                // Sort by Y descending (VN origin is bottom-left, so higher Y = higher on screen),
                // then by X ascending (left to right) for reading order
                let sorted = observations.sorted { a, b in
                    if abs(a.boundingBox.midY - b.boundingBox.midY) > 0.01 {
                        return a.boundingBox.midY > b.boundingBox.midY
                    }
                    return a.boundingBox.midX < b.boundingBox.midX
                }

                let text = sorted.compactMap {
                    $0.topCandidates(1).first?.string
                }.joined(separator: "\n")

                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    continuation.resume(throwing: ImportError.noTextFound)
                } else {
                    continuation.resume(returning: text)
                }
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                guard !hasResumed else { return }
                hasResumed = true
                print("Image OCR request error: \(error)")
                continuation.resume(throwing: ImportError.invalidImage)
            }
        }
    }

    // MARK: - Response Mapping

    /// Maps the LLM-parsed response to GroupDraft/ExerciseDraft/TargetSetDraft structs
    /// used by TemplateEditorSheet.
    static func mapToGroupDrafts(
        _ response: ParsedWorkoutResponse
    ) -> (name: String, sportType: SportType, sessionType: SessionType, groups: [GroupDraft]) {
        let sportType = SportType(rawValue: response.sport_type) ?? .lifting
        let sessionType = SessionType(rawValue: response.session_type) ?? .strength

        let groups = response.groups.map { group in
            var draft = GroupDraft(groupName: group.group_name)
            draft.exercises = group.exercises.map { exercise in
                var exDraft = ExerciseDraft(
                    exerciseName: exercise.exercise_name,
                    exerciseCategory: ExerciseCategory(rawValue: exercise.exercise_category) ?? .compound,
                    muscleGroup: exercise.muscle_group.flatMap { MuscleGroup(rawValue: $0) }
                )
                exDraft.sets = exercise.sets.map { set in
                    // Convert RPE to RIR (RIR = 10 - RPE) when LLM returns target_rpe
                    let rir: Int? = set.target_rpe.map { Int(10.0 - $0) }
                    return TargetSetDraft(
                        targetReps: set.target_reps,
                        targetWeightKg: set.target_weight_kg,
                        targetDurationSeconds: set.target_duration_seconds,
                        targetRIR: rir,
                        isWarmup: set.is_warmup
                    )
                }
                if exDraft.sets.isEmpty {
                    exDraft.sets = [TargetSetDraft()]
                }
                return exDraft
            }
            return draft
        }

        return (
            name: response.workout_name,
            sportType: sportType,
            sessionType: sessionType,
            groups: groups
        )
    }

    // MARK: - Free-form Exercise Resolution

    enum ExerciseResolveSource: Equatable {
        case localCatalog
        case localCustom
        case llm
        case manual
    }

    struct ResolvedExercise: Equatable {
        let name: String
        let exerciseCategory: ExerciseCategory
        let muscleGroup: MuscleGroup
        let sportType: SportType
        let source: ExerciseResolveSource
        let confidence: Double
        /// The matched candidate's canonical catalog/custom-exercise name, distinct from `name`
        /// (which is always the requested/spoken name). Populated only for `.localCatalog` and
        /// `.localCustom` matches in `resolveLocalExercise`; nil for `.llm`/`.manual` sources,
        /// which have no canonical name to defer to. Callers that need history/PR continuity
        /// across a fuzzy-matched spoken variant (e.g. voice logging) should prefer this over
        /// `name` when it is non-nil.
        let matchedCatalogName: String?

        init(
            name: String,
            exerciseCategory: ExerciseCategory,
            muscleGroup: MuscleGroup,
            sportType: SportType,
            source: ExerciseResolveSource,
            confidence: Double,
            matchedCatalogName: String? = nil
        ) {
            self.name = name
            self.exerciseCategory = exerciseCategory
            self.muscleGroup = muscleGroup
            self.sportType = sportType
            self.source = source
            self.confidence = confidence
            self.matchedCatalogName = matchedCatalogName
        }
    }

    struct LLMExerciseCandidate: Equatable {
        let exerciseName: String
        let exerciseCategoryRaw: String
        let muscleGroupRaw: String?
    }

    enum ExerciseResolveError: LocalizedError, Equatable {
        case emptyName
        case missingMuscleGroup
        case parseReturnedNoExercise

        var errorDescription: String? {
            switch self {
            case .emptyName:
                return String(localized: "exercise.resolve.error.emptyName", defaultValue: "Enter an exercise name.")
            case .missingMuscleGroup:
                return String(localized: "exercise.resolve.error.missingMuscleGroup", defaultValue: "Choose a muscle group before saving.")
            case .parseReturnedNoExercise:
                return String(localized: "exercise.resolve.error.noExercise", defaultValue: "Could not identify an exercise.")
            }
        }
    }

    static func resolveLocalExercise(
        name: String,
        sportType: SportType,
        customExercises: [CustomExercise]
    ) -> ResolvedExercise? {
        let catalog = ExerciseDatabase.exercises(for: sportType)
        return resolveLocalExercise(
            name: name,
            sportType: sportType,
            catalogExercises: catalog,
            customExercises: customExercises
        )
    }

    static func resolveLocalExercise(
        name: String,
        sportType: SportType,
        catalogExercises: [ExerciseDefinition],
        customExercises: [CustomExercise]
    ) -> ResolvedExercise? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let catalogCandidates = catalogExercises.compactMap { exercise -> LocalExerciseCandidate? in
            guard let muscleGroup = exercise.muscleGroup else { return nil }
            return LocalExerciseCandidate(
                name: exercise.name,
                category: exercise.category,
                muscleGroup: muscleGroup,
                source: exercise.isCustom ? .localCustom : .localCatalog
            )
        }

        let customCandidates = customExercises.compactMap { exercise -> LocalExerciseCandidate? in
            guard exercise.sportType == nil || exercise.sportType == sportType else { return nil }
            guard let muscleGroup = exercise.muscleGroup else { return nil }
            return LocalExerciseCandidate(
                name: exercise.name,
                category: exercise.exerciseCategory,
                muscleGroup: muscleGroup,
                source: .localCustom
            )
        }

        guard let match = bestLocalMatch(
            name: trimmed,
            candidates: customCandidates + catalogCandidates
        ) else { return nil }

        return ResolvedExercise(
            name: trimmed,
            exerciseCategory: match.candidate.category,
            muscleGroup: match.candidate.muscleGroup,
            sportType: sportType,
            source: match.candidate.source,
            confidence: match.score,
            matchedCatalogName: match.candidate.name
        )
    }

    @MainActor
    static func parseExerciseText(
        name: String,
        description: String?,
        sportType: SportType,
        client: SupabaseClient
    ) async throws -> ResolvedExercise {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { throw ExerciseResolveError.emptyName }

        let detail = description?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
        let text = [
            "Exercise name: \(trimmedName)",
            detail.map { "Description: \($0)" },
            "Sport: \(sportType.rawValue)",
            "Parse this as one exercise and return exercise_category and muscle_group."
        ]
            .compactMap { $0 }
            .joined(separator: "\n")

        let response = try await parseWorkoutText(text, client: client)
        guard let exercise = response.groups.first?.exercises.first else {
            throw ExerciseResolveError.parseReturnedNoExercise
        }
        return try resolveLLMExercise(
            LLMExerciseCandidate(
                exerciseName: exercise.exercise_name,
                exerciseCategoryRaw: exercise.exercise_category,
                muscleGroupRaw: exercise.muscle_group
            ),
            requestedName: trimmedName,
            sportType: sportType
        )
    }

    static func resolveLLMExercise(
        _ candidate: LLMExerciseCandidate,
        requestedName: String,
        sportType: SportType
    ) throws -> ResolvedExercise {
        let trimmedName = requestedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { throw ExerciseResolveError.emptyName }
        guard let muscleGroup = mapMuscleGroup(candidate.muscleGroupRaw) else {
            throw ExerciseResolveError.missingMuscleGroup
        }

        guard let exerciseCategory = mapExerciseCategory(candidate.exerciseCategoryRaw) else {
            throw ExerciseResolveError.parseReturnedNoExercise
        }

        return ResolvedExercise(
            name: trimmedName,
            exerciseCategory: exerciseCategory,
            muscleGroup: muscleGroup,
            sportType: sportType,
            source: .llm,
            confidence: 0.76
        )
    }

    static func manualResolution(
        name: String,
        exerciseCategory: ExerciseCategory,
        muscleGroup: MuscleGroup?,
        sportType: SportType
    ) throws -> ResolvedExercise {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { throw ExerciseResolveError.emptyName }
        guard let muscleGroup else { throw ExerciseResolveError.missingMuscleGroup }

        return ResolvedExercise(
            name: trimmedName,
            exerciseCategory: exerciseCategory,
            muscleGroup: muscleGroup,
            sportType: sportType,
            source: .manual,
            confidence: 1.0
        )
    }

    static func makeCustomExercise(
        from resolved: ResolvedExercise,
        athlete: Athlete?
    ) -> CustomExercise {
        let exercise = CustomExercise(
            name: resolved.name,
            exerciseCategory: resolved.exerciseCategory,
            muscleGroup: resolved.muscleGroup,
            sportType: resolved.sportType
        )
        exercise.athlete = athlete
        return exercise
    }

    static func mapExerciseCategory(_ rawValue: String) -> ExerciseCategory? {
        let normalized = normalizeIdentifier(rawValue)
        return ExerciseCategory.allCases.first {
            normalizeIdentifier($0.rawValue) == normalized
                || normalizeIdentifier($0.displayName) == normalized
        }
    }

    static func mapMuscleGroup(_ rawValue: String?) -> MuscleGroup? {
        guard let rawValue, !rawValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        let normalized = normalizeIdentifier(rawValue)
        return MuscleGroup.allCases.first {
            normalizeIdentifier($0.rawValue) == normalized
                || normalizeIdentifier($0.displayName) == normalized
        }
    }
}

private struct LocalExerciseCandidate {
    let name: String
    let category: ExerciseCategory
    let muscleGroup: MuscleGroup
    let source: WorkoutLLMImportService.ExerciseResolveSource
}

private extension WorkoutLLMImportService {
    static let localMatchThreshold = 0.84

    static func bestLocalMatch(
        name: String,
        candidates: [LocalExerciseCandidate]
    ) -> (candidate: LocalExerciseCandidate, score: Double)? {
        let normalizedName = normalizeExerciseName(name)
        guard !normalizedName.isEmpty else { return nil }

        let scored = candidates
            .map { candidate in
                (
                    candidate: candidate,
                    score: fuzzyScore(
                        normalizedName,
                        normalizeExerciseName(candidate.name)
                    )
                )
            }
            .max { lhs, rhs in lhs.score < rhs.score }

        guard let scored, scored.score >= localMatchThreshold else { return nil }
        return scored
    }

    static func fuzzyScore(_ lhs: String, _ rhs: String) -> Double {
        guard !lhs.isEmpty, !rhs.isEmpty else { return 0 }
        if lhs == rhs { return 1.0 }

        let lhsTokens = Set(lhs.split(separator: " ").map(String.init))
        let rhsTokens = Set(rhs.split(separator: " ").map(String.init))
        let overlap = lhsTokens.intersection(rhsTokens)
        let tokenScore = Double(overlap.count) / Double(max(lhsTokens.count, rhsTokens.count))
        let distance = levenshtein(lhs, rhs)
        let editScore = 1.0 - (Double(distance) / Double(max(lhs.count, rhs.count)))
        let containsScore = lhs.contains(rhs) || rhs.contains(lhs) ? 0.92 : 0.0

        return max(containsScore, (tokenScore * 0.55) + (editScore * 0.45))
    }

    static func normalizeExerciseName(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .replacingOccurrences(of: #"[^a-z0-9]+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ")
            .joined(separator: " ")
    }

    static func normalizeIdentifier(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .replacingOccurrences(of: #"[^a-z0-9]+"#, with: "", options: .regularExpression)
    }

    static func levenshtein(_ lhs: String, _ rhs: String) -> Int {
        let lhs = Array(lhs)
        let rhs = Array(rhs)
        guard !lhs.isEmpty else { return rhs.count }
        guard !rhs.isEmpty else { return lhs.count }

        var previous = Array(0...rhs.count)
        var current = Array(repeating: 0, count: rhs.count + 1)

        for lhsIndex in 1...lhs.count {
            current[0] = lhsIndex
            for rhsIndex in 1...rhs.count {
                let substitution = previous[rhsIndex - 1] + (lhs[lhsIndex - 1] == rhs[rhsIndex - 1] ? 0 : 1)
                let insertion = current[rhsIndex - 1] + 1
                let deletion = previous[rhsIndex] + 1
                current[rhsIndex] = min(substitution, insertion, deletion)
            }
            swap(&previous, &current)
        }

        return previous[rhs.count]
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
