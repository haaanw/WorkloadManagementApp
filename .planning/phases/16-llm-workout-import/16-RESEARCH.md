# Phase 16: LLM Workout Import - Research

**Researched:** 2026-05-14
**Domain:** iOS on-device text extraction (PDFKit, Vision OCR) + Supabase Edge Function (Deno) + OpenAI structured outputs
**Confidence:** HIGH

## Summary

This phase adds three input paths (text paste, PDF file, camera/photo) that all converge on a single Supabase Edge Function (`parse-workout`) which calls GPT-4o-mini with JSON Schema enforcement to produce structured workout data. The iOS client handles all text extraction locally (PDFKit for PDFs, Vision framework VNRecognizeTextRequest for images) and sends plain text to the edge function. The parsed result maps directly to the existing GroupDraft/ExerciseDraft/TargetSetDraft structures and pre-fills TemplateEditorSheet for user review before saving.

All three technologies are mature and well-documented. PDFKit text extraction is trivial (3-5 lines). Vision OCR is straightforward with VNRecognizeTextRequest (must use the VN-prefixed API since RecognizeTextRequest requires iOS 18, and the app targets iOS 17+). The Supabase Edge Function is a standard Deno.serve handler calling the OpenAI REST API with structured outputs. The existing codebase already has the `client.functions.invoke()` pattern (InviteService) and template creation from external data (TemplateSharingService.importTemplate).

**Primary recommendation:** Build a single `WorkoutImportService` enum (matching InviteService/TemplateSharingService pattern) that handles PDF extraction, OCR, and edge function invocation, plus a `WorkoutImportSheet` with segmented picker for the three input modes.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Single import sheet with segmented picker for text/PDF/photo tabs. One "Import Workout" button in WorkoutLogView toolbar opens a sheet with three input modes.
- **D-02:** Text tab: multiline text field with "Parse" button. PDF tab: document picker (UTType.pdf). Photo tab: camera or photo library picker.
- **D-03:** Single Supabase Edge Function (`parse-workout`) accepts plain text and returns structured JSON. Client handles PDF text extraction (PDFKit) and image OCR (Vision framework) on-device before sending text to the edge function.
- **D-04:** Edge function uses GPT-4o-mini with JSON Schema structured output enforcement per LLM-06. Response schema: exercise name, sets, reps, weight (optional), rest (optional), notes (optional).
- **D-05:** Edge function deployed in `supabase/functions/parse-workout/` with Deno runtime. OpenAI API key stored as Supabase secret, never in iOS binary.
- **D-06:** Reuse existing TemplateEditorSheet with pre-filled data from LLM response. User sees the same familiar editing interface, can modify any field before saving. No separate preview-only view needed.
- **D-07:** LLM response maps to WorkoutTemplate + ExerciseGroup + TemplateExercise + TemplateSet structure. Sport type and session type inferred by LLM if possible, default to .lifting/.strength.
- **D-08:** Inline error banner with retry button on parse failure. Partial results display with missing fields highlighted -- user can always fix manually.
- **D-09:** Loading state: full-sheet overlay with "Analyzing workout..." text and spinner. Parse typically takes 2-5 seconds.

### Claude's Discretion
- Edge function prompt engineering (system prompt for GPT-4o-mini)
- PDF text extraction approach (PDFKit vs other)
- Vision framework OCR configuration
- Timeout and retry logic for edge function calls

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| LLM-01 | User can paste workout text and have it parsed into a template via LLM | Edge function structured outputs + WorkoutImportSheet text tab |
| LLM-02 | User can import a PDF file and have its text extracted and parsed into a template | PDFKit PDFDocument.page(at:).string extraction on-device |
| LLM-03 | User can take a photo or select from library and have OCR + LLM parse it into a template | Vision VNRecognizeTextRequest OCR on-device |
| LLM-04 | User sees parsed template preview with exercises/sets/reps before saving | Pre-fill TemplateEditorSheet with GroupDraft/ExerciseDraft/TargetSetDraft from LLM response |
| LLM-05 | LLM parsing runs via Supabase Edge Function proxy (API key never in iOS binary) | Supabase Edge Function with Deno.env.get('OPENAI_API_KEY') |
| LLM-06 | LLM import uses GPT-4o-mini with structured output (JSON Schema enforcement) | OpenAI response_format: { type: "json_schema", json_schema: { strict: true } } |
</phase_requirements>

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| PDF text extraction | Browser / Client (iOS) | -- | PDFKit is an on-device Apple framework; no network needed |
| Image OCR | Browser / Client (iOS) | -- | Vision framework runs on-device Neural Engine; privacy-preserving |
| LLM workout parsing | API / Backend (Edge Function) | -- | API key must never exist in iOS binary; Edge Function is the proxy |
| Template creation | Browser / Client (iOS) | Database / Storage | TemplateEditorSheet creates local SwiftData objects, then syncs |
| Import UI | Browser / Client (iOS) | -- | Sheet with segmented picker, document/photo pickers |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| PDFKit (Apple) | iOS 17+ built-in | PDF text extraction | Apple's first-party PDF framework; zero dependencies [VERIFIED: Apple developer docs] |
| Vision (Apple) | iOS 17+ built-in | Image OCR text recognition | Apple's first-party computer vision; runs on Neural Engine [VERIFIED: Apple developer docs] |
| OpenAI REST API | v1 (chat/completions) | LLM workout text parsing | Industry standard; structured outputs with JSON Schema enforcement [VERIFIED: OpenAI docs] |
| Supabase Edge Functions | Deno runtime | Serverless proxy for OpenAI calls | Already used in codebase (send-invite-email); keeps API key server-side [VERIFIED: codebase InviteService.swift] |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| UniformTypeIdentifiers (Apple) | iOS 17+ built-in | UTType.pdf for document picker | Required for UIDocumentPickerViewController / .fileImporter |
| PhotosUI (Apple) | iOS 17+ built-in | PhotosPicker for image selection | SwiftUI PhotosPicker for library access |
| UIKit UIImagePickerController | iOS 17+ built-in | Camera capture | Camera access for photo-to-OCR flow |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| PDFKit | Vision OCR on PDF pages | PDFKit gives clean text for digital PDFs; Vision OCR only needed for scanned/image PDFs |
| OpenAI npm package in Deno | Raw fetch() to OpenAI REST API | fetch() is simpler, no dependency, full control over request; npm package adds unnecessary overhead for a single endpoint call |
| GPT-4o-mini | GPT-4.1-mini | GPT-4.1-mini may be newer but GPT-4o-mini is locked per D-04; structured outputs are well-tested on it |

**Installation:** No new Swift packages needed. Edge function has no npm dependencies (uses raw fetch).

## Architecture Patterns

### System Architecture Diagram

```
User Input (text / PDF / photo)
        |
        v
[iOS Client: WorkoutImportSheet]
        |
   +----+----+----+
   |         |         |
   v         v         v
 Text    PDFKit    Vision OCR
 (raw)   extract   VNRecognize
   |      text     TextRequest
   |         |         |
   +----+----+----+
        |
        v (plain text string)
[client.functions.invoke("parse-workout")]
        |
        v (HTTPS POST)
[Supabase Edge Function: parse-workout/index.ts]
        |
        v (OpenAI REST API)
[GPT-4o-mini + JSON Schema enforcement]
        |
        v (structured JSON)
[Edge Function returns JSON response]
        |
        v
[iOS Client: decode ParsedWorkoutResponse]
        |
        v
[Map to GroupDraft/ExerciseDraft/TargetSetDraft]
        |
        v
[TemplateEditorSheet (pre-filled, editable)]
        |
        v (user taps Save)
[WorkoutTemplate + ExerciseGroup + TemplateExercise + TemplateSet]
```

### Recommended Project Structure

```
WorkloadApp/
  Services/
    WorkoutImportService.swift    # PDF extraction, OCR, edge function call
  Views/
    WorkoutLog/
      WorkoutImportSheet.swift    # Import UI with segmented picker

supabase/
  functions/
    parse-workout/
      index.ts                    # Deno edge function
```

### Pattern 1: Supabase Edge Function Call (Existing)
**What:** Call a Supabase Edge Function from iOS using the Swift SDK
**When to use:** Any server-side operation requiring secrets (API keys)
**Example:**
```swift
// Source: InviteService.swift lines 199-206 (verified in codebase)
struct EdgePayload: Encodable {
    let email: String
    let code: String
}
try await client.functions.invoke(
    "send-invite-email",
    options: .init(body: EdgePayload(email: email, code: code))
)
```

### Pattern 2: Service Enum with Static Methods (Existing)
**What:** Stateless service namespace with @MainActor static methods for Supabase operations
**When to use:** All service-level operations in this codebase
**Example:**
```swift
// Source: TemplateSharingService.swift, InviteService.swift (verified in codebase)
enum WorkoutImportService {
    @MainActor
    static func parseWorkout(
        text: String,
        client: SupabaseClient
    ) async throws -> ParsedWorkoutResponse {
        struct ParseRequest: Encodable {
            let workout_text: String
        }
        let response: ParsedWorkoutResponse = try await client.functions.invoke(
            "parse-workout",
            options: .init(body: ParseRequest(workout_text: text))
        )
        return response
    }
}
```

### Pattern 3: Template Pre-fill from External Data (Existing)
**What:** Create GroupDraft/ExerciseDraft/TargetSetDraft arrays from parsed JSON
**When to use:** When opening TemplateEditorSheet with LLM-parsed data
**Example:**
```swift
// Source: TemplateSharingService.importTemplate pattern (verified in codebase)
// TemplateEditorSheet already accepts existingTemplate for pre-fill via loadExisting()
// For LLM import: pass pre-built drafts directly to a new init parameter
```

### Pattern 4: Supabase Edge Function (Deno)
**What:** Deno.serve handler that proxies OpenAI API calls
**When to use:** parse-workout edge function
**Example:**
```typescript
// Source: Supabase docs + OpenAI structured outputs docs
Deno.serve(async (req) => {
  const { workout_text } = await req.json()
  const apiKey = Deno.env.get('OPENAI_API_KEY')

  const response = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: 'gpt-4o-mini',
      messages: [
        { role: 'system', content: SYSTEM_PROMPT },
        { role: 'user', content: workout_text }
      ],
      response_format: {
        type: 'json_schema',
        json_schema: {
          name: 'parsed_workout',
          schema: WORKOUT_SCHEMA,
          strict: true
        }
      }
    })
  })

  const data = await response.json()
  const parsed = JSON.parse(data.choices[0].message.content)
  return new Response(JSON.stringify(parsed), {
    headers: { 'Content-Type': 'application/json' }
  })
})
```

### Pattern 5: PDFKit Text Extraction
**What:** Extract plain text from a PDF document on-device
**When to use:** PDF tab in import sheet
**Example:**
```swift
// Source: Apple PDFKit docs [CITED: developer.apple.com/documentation/pdfkit]
import PDFKit

static func extractText(from url: URL) -> String? {
    guard let document = PDFDocument(url: url) else { return nil }
    var text = ""
    for i in 0..<document.pageCount {
        guard let page = document.page(at: i) else { continue }
        if let pageText = page.string {
            text += pageText + "\n"
        }
    }
    return text.isEmpty ? nil : text
}
```

### Pattern 6: Vision Framework OCR
**What:** Extract text from an image using VNRecognizeTextRequest
**When to use:** Photo tab in import sheet
**Example:**
```swift
// Source: Apple Vision docs [CITED: developer.apple.com/documentation/vision/vnrecognizetextrequest]
// IMPORTANT: Must use VN-prefixed API for iOS 17 compatibility.
// The new RecognizeTextRequest (no VN prefix) requires iOS 18.
import Vision

static func extractText(from image: UIImage) async throws -> String {
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
            let text = observations.compactMap {
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
```

### Anti-Patterns to Avoid
- **Sending raw image data to edge function:** Always extract text on-device first. Sending images means larger payloads, slower calls, and unnecessary data transfer. PDFKit and Vision handle extraction locally with zero network cost.
- **Using OpenAI npm package in Deno:** For a single REST API call, raw fetch() is simpler, has no dependency management, and gives full control. The npm package adds unnecessary complexity.
- **Creating a separate preview view:** D-06 explicitly says reuse TemplateEditorSheet. Do not create a custom preview screen.
- **Using the new Vision API (RecognizeTextRequest without VN prefix):** This requires iOS 18. The app targets iOS 17+. Must use VNRecognizeTextRequest.
- **Hardcoding the OpenAI API key anywhere:** Not in the edge function source, not in the iOS binary. Use Deno.env.get('OPENAI_API_KEY') in the edge function, set via `supabase secrets set`.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| PDF text extraction | Custom PDF parser | PDFKit PDFDocument.page(at:).string | Apple's built-in framework handles all PDF variants; 3 lines of code |
| Image OCR | Custom ML model for text detection | Vision VNRecognizeTextRequest | Apple's Neural Engine-optimized OCR; handles handwriting, multiple languages |
| JSON Schema enforcement | Manual JSON validation / regex parsing | OpenAI structured outputs (strict: true) | Guarantees schema compliance; no post-processing or error recovery needed |
| Document picker | Custom file browser | SwiftUI .fileImporter(isPresented:allowedContentTypes:) | System UI, handles iCloud, Files app, sandboxing automatically |
| Photo picker | Custom gallery browser | SwiftUI PhotosPicker | System UI, handles permissions, iCloud Photos, privacy |

**Key insight:** Every layer of this feature has a battle-tested solution. The only custom code is the edge function prompt engineering and the mapping from LLM JSON to GroupDraft structures.

## Common Pitfalls

### Pitfall 1: PDFKit Returns Empty String for Scanned PDFs
**What goes wrong:** PDFKit extracts text from the PDF text layer. Scanned PDFs (images embedded in PDF) have no text layer, so `page.string` returns empty or nil.
**Why it happens:** Scanned documents are stored as images inside a PDF container.
**How to avoid:** When PDFKit extraction returns empty/whitespace, fall back to rendering each PDF page as an image and running Vision OCR on it. This handles both digital and scanned PDFs.
**Warning signs:** Extracted text is empty or contains only whitespace for a multi-page document.

### Pitfall 2: Vision OCR Ordering
**What goes wrong:** VNRecognizedTextObservation results are not guaranteed to be in reading order. Text may come back in random positional order.
**Why it happens:** Vision detects text regions independently without implied reading order.
**How to avoid:** Sort observations by Y coordinate (top to bottom), then X coordinate (left to right) before joining text. This produces natural reading order for most workout layouts.
**Warning signs:** Parsed workout has exercises in wrong order or set/rep numbers attached to wrong exercises.

### Pitfall 3: Edge Function Timeout
**What goes wrong:** OpenAI API call takes longer than expected, edge function times out.
**Why it happens:** GPT-4o-mini typically responds in 2-5 seconds, but can spike under load.
**How to avoid:** Set a reasonable timeout on the iOS side (30 seconds). Show loading state immediately. On the edge function side, the Supabase default timeout for edge functions is 60 seconds which is sufficient.
**Warning signs:** Intermittent "request timed out" errors from the edge function.

### Pitfall 4: LLM Hallucinating Exercise Details
**What goes wrong:** LLM invents exercises, reps, or weights not present in the source text.
**Why it happens:** LLMs fill in gaps; workout descriptions often omit details.
**How to avoid:** System prompt should instruct the model to only extract what is explicitly stated. Use null/omit for fields not mentioned. The user review step (TemplateEditorSheet) is the safety net.
**Warning signs:** Parsed template has suspiciously complete data for a sparse input text.

### Pitfall 5: Supabase Auth Header Required
**What goes wrong:** Edge function call fails with 401 Unauthorized.
**Why it happens:** Supabase Edge Functions require an Authorization header by default. The Swift SDK automatically includes the user's JWT when calling `client.functions.invoke()`.
**How to avoid:** Ensure the user is authenticated before calling the import function. The app already gates most features behind auth.
**Warning signs:** Import fails for unauthenticated users (should not happen given app flow).

### Pitfall 6: TemplateEditorSheet Pre-fill Requires Init Change
**What goes wrong:** TemplateEditorSheet currently only accepts an existing WorkoutTemplate for editing, not raw draft data.
**Why it happens:** The existing init takes `existingTemplate: WorkoutTemplate?` and loads via `loadExisting()`.
**How to avoid:** Add a new init parameter (e.g., `prefillDrafts: [GroupDraft]?`) or a separate convenience init that accepts the parsed data. The sheet already uses @State GroupDraft arrays internally, so pre-filling is straightforward.
**Warning signs:** Attempting to create a WorkoutTemplate just to pass it to the editor (wasteful; creates orphan model objects).

## Code Examples

### OpenAI Structured Output JSON Schema for Workout Parsing
```typescript
// Source: OpenAI structured outputs docs [CITED: developers.openai.com/api/docs/guides/structured-outputs]
const WORKOUT_SCHEMA = {
  type: "object",
  properties: {
    workout_name: { type: "string" },
    sport_type: {
      type: "string",
      enum: ["lifting", "running", "cycling", "teamSport", "crossfit", "swimming", "custom"]
    },
    session_type: {
      type: "string",
      enum: ["strength", "skill", "cardio", "match", "recovery"]
    },
    groups: {
      type: "array",
      items: {
        type: "object",
        properties: {
          group_name: { type: "string" },
          exercises: {
            type: "array",
            items: {
              type: "object",
              properties: {
                exercise_name: { type: "string" },
                exercise_category: {
                  type: "string",
                  enum: ["compound", "isolation", "cardio", "bodyweight", "plyometric", "drill", "interval"]
                },
                muscle_group: {
                  type: ["string", "null"],
                  enum: ["chest", "back", "legs", "shoulders", "arms", "core", "fullBody", null]
                },
                sets: {
                  type: "array",
                  items: {
                    type: "object",
                    properties: {
                      target_reps: { type: ["integer", "null"] },
                      target_weight_kg: { type: ["number", "null"] },
                      target_duration_seconds: { type: ["integer", "null"] },
                      target_rpe: { type: ["number", "null"] },
                      is_warmup: { type: "boolean" }
                    },
                    required: ["target_reps", "target_weight_kg", "target_duration_seconds", "target_rpe", "is_warmup"],
                    additionalProperties: false
                  }
                }
              },
              required: ["exercise_name", "exercise_category", "muscle_group", "sets"],
              additionalProperties: false
            }
          }
        },
        required: ["group_name", "exercises"],
        additionalProperties: false
      }
    }
  },
  required: ["workout_name", "sport_type", "session_type", "groups"],
  additionalProperties: false
}
```

### Swift Decodable for Edge Function Response
```swift
// Maps to the JSON Schema above
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
```

### Mapping ParsedWorkoutResponse to GroupDraft Arrays
```swift
// Converts LLM response into TemplateEditorSheet draft structures
static func mapToGroupDrafts(_ response: ParsedWorkoutResponse) -> [GroupDraft] {
    response.groups.map { group in
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
                    targetRPE: set.target_rpe,
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
}
```

### PDFKit Fallback to Vision OCR for Scanned PDFs
```swift
import PDFKit
import Vision

static func extractText(from url: URL) async throws -> String {
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

    // If text layer is empty/whitespace, fall back to OCR
    if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
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
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| VNRecognizeTextRequest (completion handler) | RecognizeTextRequest (async/await) | iOS 18 / WWDC24 | Must use old API since app targets iOS 17 |
| deno.land/x/openai import | jsr:@openai/openai or npm:openai | Jan 2025 | For this phase, raw fetch() is preferred over any SDK |
| OpenAI function calling for structured data | response_format json_schema with strict:true | Aug 2024 | Guarantees schema compliance; no parsing failures |

**Deprecated/outdated:**
- `VNRecognizeTextRequest` is technically legacy (replaced by `RecognizeTextRequest` in iOS 18), but is the correct choice for iOS 17+ targets
- `deno.land/x/openai` imports are being superseded by JSR imports, but raw fetch() avoids the dependency entirely

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | GPT-4o-mini structured outputs cost ~$0.15/1M input + $0.60/1M output tokens | Code Examples | Low -- pricing may have changed; a typical workout parse is <1000 tokens total (~$0.001) |
| A2 | Supabase Edge Functions default timeout is 60 seconds | Pitfalls | Low -- if shorter, can configure per-function; 30s client timeout is the real constraint |
| A3 | TemplateEditorSheet GroupDraft/ExerciseDraft/TargetSetDraft structs are stable and won't change before this phase | Architecture | Medium -- if Phase 15 modified these drafts, need to verify |

## Open Questions

1. **Supabase CLI not installed locally**
   - What we know: Neither `supabase` nor `deno` CLI is installed on this machine
   - What's unclear: How will the edge function be deployed?
   - Recommendation: Deploy via Supabase Dashboard (paste code directly) or install Supabase CLI (`brew install supabase/tap/supabase`). Dashboard deployment is viable for a single function.

2. **No existing supabase/functions/ directory**
   - What we know: Only `supabase/migrations/` exists in the project
   - What's unclear: Whether the project has a `supabase/config.toml` or if edge functions have been deployed via dashboard previously
   - Recommendation: Create `supabase/functions/parse-workout/index.ts` in the repo. Deploy via dashboard or CLI. The `send-invite-email` function referenced in InviteService.swift was likely deployed via dashboard.

3. **Weight unit handling in LLM response**
   - What we know: The app uses kg internally (targetWeightKg). Users may input workouts with lbs.
   - What's unclear: Whether the LLM should normalize to kg or pass through the original unit
   - Recommendation: Have the LLM always output kg. Include in the system prompt: "Convert all weights to kilograms. If the weight appears to be in pounds, convert to kg (multiply by 0.453592)."

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Supabase CLI | Edge function deployment | No | -- | Deploy via Supabase Dashboard UI |
| Deno | Local edge function testing | No | -- | Test via deployed function; or install with `curl -fsSL https://deno.land/install.sh \| sh` |
| PDFKit framework | PDF text extraction | Yes | iOS 17+ built-in | -- |
| Vision framework | Image OCR | Yes | iOS 17+ built-in | -- |
| OpenAI API | LLM parsing | Yes (remote) | v1 | -- |
| Supabase project | Edge function hosting | Yes (remote) | -- | -- |

**Missing dependencies with no fallback:**
- None -- all critical dependencies are available (Apple frameworks built-in, Supabase remote)

**Missing dependencies with fallback:**
- Supabase CLI: deploy via Dashboard instead
- Deno: test against deployed function instead of local

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | Yes | Supabase JWT required for edge function calls (automatic via Swift SDK) |
| V3 Session Management | No | -- |
| V4 Access Control | Yes | Edge function validates auth header; only authenticated users can parse |
| V5 Input Validation | Yes | Limit input text length on client and edge function; sanitize before sending to OpenAI |
| V6 Cryptography | No | No custom crypto; HTTPS for all API calls |

### Known Threat Patterns for This Stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Prompt injection via user text | Tampering | System prompt with clear boundaries; structured output schema constrains response shape |
| API key exposure | Information Disclosure | Key stored as Supabase secret, accessed via Deno.env.get(); never in iOS binary or source |
| Excessive API usage / cost attack | Denial of Service | Rate limiting on edge function (Supabase built-in); input text length limit (e.g., 10,000 chars) |
| Malicious PDF/image upload | Tampering | Text extraction is on-device via Apple frameworks; only plain text sent to edge function |

## Project Constraints (from CLAUDE.md)

- **Architecture:** Service must be an enum with static methods (WorkoutImportService) [VERIFIED: codebase pattern]
- **@MainActor:** Required on all static methods that call Supabase [VERIFIED: InviteService, TemplateSharingService]
- **Snake_case Encodable:** Request/response structs use snake_case for JSON keys [VERIFIED: codebase pattern]
- **Design system:** 0pt corners, no shadows, Alpino font, 8pt grid, ColorTokens [VERIFIED: CLAUDE.md]
- **No system fonts:** Use Font.Tokens.* exclusively [VERIFIED: CLAUDE.md]
- **HealthKit raw data policy:** Not applicable to this phase (no HealthKit data involved)
- **Xcode project:** New .swift files must be added to .pbxproj [VERIFIED: CLAUDE.md]

## Sources

### Primary (HIGH confidence)
- [Apple PDFKit docs](https://developer.apple.com/documentation/pdfkit) - PDFDocument, PDFPage.string API
- [Apple Vision VNRecognizeTextRequest](https://developer.apple.com/documentation/vision/vnrecognizetextrequest) - OCR API, recognition levels
- [OpenAI Structured Outputs](https://developers.openai.com/api/docs/guides/structured-outputs) - JSON Schema enforcement, strict mode
- [Supabase Edge Functions docs](https://supabase.com/docs/guides/functions) - Deno.serve pattern, deployment
- [Supabase Edge Functions secrets](https://supabase.com/docs/guides/functions/secrets) - Deno.env.get(), supabase secrets set
- [Supabase Swift SDK functions.invoke](https://supabase.com/docs/reference/swift/functions-invoke) - FunctionInvokeOptions, Decodable response
- Codebase: InviteService.swift, TemplateSharingService.swift, TemplateEditorSheet.swift, WorkoutTemplate.swift, Enums.swift

### Secondary (MEDIUM confidence)
- [WWDC24 Vision Framework enhancements](https://developer.apple.com/videos/play/wwdc2024/10163/) - RecognizeTextRequest (iOS 18 only) vs VNRecognizeTextRequest
- [OpenAI on JSR](https://deno.com/blog/openai-on-jsr) - jsr:@openai/openai import pattern for Deno

### Tertiary (LOW confidence)
- None

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - all Apple frameworks verified, OpenAI structured outputs well-documented, existing codebase patterns confirmed
- Architecture: HIGH - directly mirrors existing InviteService and TemplateSharingService patterns
- Pitfalls: HIGH - scanned PDF fallback and VNRecognizeTextRequest ordering are well-documented issues

**Research date:** 2026-05-14
**Valid until:** 2026-06-14 (30 days - stable technologies)
