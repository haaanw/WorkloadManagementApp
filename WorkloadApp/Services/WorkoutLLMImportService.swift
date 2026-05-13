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
                return "Could not read the PDF file. It may be corrupted or password-protected."
            case .invalidImage:
                return "Could not process the image. Please try a different photo."
            case .noTextFound:
                return "No readable text found in the file. Try a clearer image or a different format."
            case .parseFailed(let detail):
                return "Failed to parse workout: \(detail)"
            case .notAuthenticated:
                return "You must be signed in to import workouts."
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
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
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

                continuation.resume(returning: text)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
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
                    TargetSetDraft(
                        targetReps: set.target_reps,
                        targetWeightKg: set.target_weight_kg,
                        targetDurationSeconds: set.target_duration_seconds,
                        targetRIR: nil,
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
}
