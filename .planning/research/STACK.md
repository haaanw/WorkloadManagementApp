# Technology Stack

**Project:** Tonus v1.3 -- LLM Import, Sharing & Polish
**Researched:** 2026-05-10

## Recommended Stack

### LLM-Powered Workout Import

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| Supabase Edge Functions (Deno) | Current | Server-side LLM proxy | Already have Supabase; Edge Functions keep the OpenAI API key server-side (never in the iOS binary). The existing supabase-swift 2.42.0 SDK has `client.functions.invoke()` built in -- zero new iOS dependencies. |
| OpenAI API (gpt-4o-mini) | 2024-07-18+ | Structured text extraction from workout descriptions | Best cost/quality ratio for structured output: $0.15/1M input, $0.60/1M output. Handles text, images, and PDFs. Structured Outputs (JSON Schema mode) guarantees valid JSON matching our template schema. |
| Apple Vision (VNRecognizeTextRequest) | iOS 17+ | On-device OCR for images/screenshots | Already bundled with iOS. Extract text from workout screenshots on-device before sending to LLM. Avoids sending raw images to OpenAI for simple text-based workout plans (cheaper, faster, more private). |
| Apple PDFKit (PDFDocument) | iOS 17+ | On-device PDF text extraction | Already bundled with iOS. Extract text from PDF workout plans on-device. `PDFDocument.page(at:).string` gives plain text without any third-party dependency. |
| SwiftUI `.fileImporter()` | iOS 17+ | Native file picker for PDF/image/text import | Built-in SwiftUI modifier. Presents iOS Files app picker. Supports `UTType.pdf`, `.image`, `.plainText`. No third-party picker needed. |
| UniformTypeIdentifiers | iOS 17+ | File type identification | Apple framework for `UTType.pdf`, `.image`, `.plainText` declarations in fileImporter. |

### Template Sharing

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| Supabase PostgreSQL | Existing | Shared template storage + share codes | Use a `shared_templates` table with a short unique code (6-char alphanumeric). RLS policy: anyone can SELECT by share_code, only owner can INSERT/UPDATE. No new dependencies. |
| Custom URL Scheme | Existing | Deep link for template import | App already has a URL scheme (`com.farosapp.ios://`). Add path `import-template/{code}` to handle share links. No server changes needed for URL routing. |
| Supabase RPC | Existing | Atomic share code generation + template cloning | PostgreSQL function generates unique share code and inserts the flattened template JSON. Called via `client.rpc()` in existing SDK. |

### Font Migration

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| Alpino (FontShare/ITF) | 1.0 | Replace DM Sans as app typeface | Humanist sans with small x-height -- editorial, distinctive, fits the app's clean aesthetic. Available under ITF Free Font License (commercial use allowed, including app embedding). Direct 1:1 weight mapping: Alpino-Regular replaces DMSans-Regular, Alpino-Medium replaces DMSans-Medium. |

### Sync Hardening

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| Swift `do/catch` | N/A | Replace `try?` with proper error handling | No new technology. Refactor existing SyncService pull methods to use `do { } catch { }` with structured logging instead of silently swallowing errors via `try?`. |

## What NOT to Add

| Rejected Option | Why Not |
|-----------------|---------|
| MacPaw/OpenAI Swift SDK | Adds unnecessary dependency. The LLM call goes through Supabase Edge Functions (Deno/TypeScript), not directly from the iOS app. The iOS app only calls `client.functions.invoke()` which is already in supabase-swift. |
| SwiftOpenAI (jamesrochabrun) | Same reason -- no direct OpenAI calls from iOS. All LLM interaction proxied through Edge Functions to protect API keys. |
| Firebase Dynamic Links / Branch.io | Overkill for template sharing. A simple share code + custom URL scheme handles the use case. Universal Links require AASA file hosting and domain verification -- unnecessary complexity for v1.3. |
| CloudKit sharing | Wrong tool. Templates sync via Supabase, not iCloud. Adding CloudKit would create a second sync pathway. |
| Third-party OCR (Google ML Kit, Tesseract) | Apple Vision VNRecognizeTextRequest is excellent on iOS 17+, supports 18 languages, and is free with no SDK bloat. |
| Third-party PDF library (PSPDFKit, etc.) | PDFKit is bundled with iOS and `PDFDocument.page(at:).string` extracts text. No need for a paid/heavy PDF SDK. |
| GPT-4o (full) | GPT-4o-mini is sufficient for workout text parsing. 10x cheaper than GPT-4o for a task that doesn't need frontier reasoning. Structured Outputs work identically on both models. |
| GPT-4.1 / GPT-4.1-mini | Newer models but gpt-4o-mini is battle-tested for structured output and image understanding. Can upgrade later if quality is insufficient -- the Edge Function makes model swaps trivial. |

## Architecture Decision: Edge Function Proxy Pattern

The critical architecture decision for LLM import is: **never call OpenAI directly from the iOS app**.

**Why:**
1. **API key security** -- OpenAI keys in iOS binaries can be extracted. Edge Functions hold the key server-side via `Deno.env.get("OPENAI_API_KEY")`.
2. **Rate limiting** -- Edge Function can enforce per-user rate limits before forwarding to OpenAI.
3. **Model flexibility** -- Swap gpt-4o-mini for a newer/cheaper model without an app update.
4. **Cost control** -- Edge Function can check user subscription status (Pro-only feature) before making the LLM call.
5. **Response transformation** -- Edge Function validates and normalizes LLM output before returning to iOS.

**Data flow:**
```
iOS: Extract text (PDFKit/Vision) or capture raw text input
  -> client.functions.invoke("parse-workout", body: { text: "...", format: "text|ocr" })
  -> Edge Function: Validate auth, check Pro subscription
  -> Edge Function: Call OpenAI with structured output schema
  -> Edge Function: Validate response, return normalized template JSON
  -> iOS: Deserialize into WorkoutTemplate + ExerciseGroup + TemplateExercise + TemplateSet
  -> iOS: Insert into SwiftData, user reviews and confirms
```

**For images that need OCR:**
```
iOS: User selects image via fileImporter or camera
  -> iOS: VNRecognizeTextRequest extracts text on-device
  -> iOS: Send extracted text to Edge Function (same flow as above)
```

**For images where OCR fails or produces poor results:**
```
iOS: Convert image to base64
  -> client.functions.invoke("parse-workout", body: { image_base64: "...", format: "image" })
  -> Edge Function: Forward base64 to OpenAI vision endpoint
  -> Edge Function: Return structured template JSON
```

## Template Sharing Architecture

**Share flow:**
```
iOS: User taps "Share Template" on a WorkoutTemplate
  -> iOS: Serialize template tree to JSON (template + groups + exercises + sets)
  -> iOS: client.rpc("share_template", params: { template_json: {...} })
  -> Supabase: Insert into shared_templates table, generate 6-char code
  -> iOS: Display share code + generate share URL (farosapp://import-template/ABC123)
  -> iOS: Present UIActivityViewController with URL
```

**Import flow:**
```
Recipient: Taps link or enters code manually
  -> iOS: Deep link handler or manual code entry
  -> iOS: client.from("shared_templates").select().eq("share_code", code).single()
  -> iOS: Deserialize JSON into local WorkoutTemplate (new UUID, owned by current user)
  -> iOS: User reviews template before saving
```

## Font Migration Plan

**Scope:** The migration is mechanical -- Alpino has the exact same weight variants needed:
- `DMSans-Regular` -> `Alpino-Regular` (body text, scores, labels)
- `DMSans-Medium` -> `Alpino-Medium` (section headers, emphasis)

**Files affected:**
1. `WorkloadApp/Resources/` -- Replace .ttf files (remove DMSans-*.ttf, add Alpino-Regular.otf + Alpino-Medium.otf)
2. `Info.plist` -- Update `UIAppFonts` array entries
3. `WorkloadApp/Utilities/FontTokens.swift` -- Change all `Font.custom("DMSans-Regular"` to `Font.custom("Alpino-Regular"` and `"DMSans-Medium"` to `"Alpino-Medium"`
4. `WorkloadApp/App/WorkloadApp.swift` -- Update font assertion names in DEBUG checks
5. `DESIGN.md` -- Update font reference

**Risk:** Alpino's small x-height means text may appear slightly smaller at the same point size as DM Sans. Visual QA pass needed after migration to verify readability, especially at 12pt (micro) and 15pt (label) sizes. May need 1-2pt size bumps.

## Supabase Edge Function Dependencies (Server-Side)

The Edge Function for LLM parsing runs Deno (TypeScript). These are NOT iOS dependencies:

```typescript
// supabase/functions/parse-workout/index.ts
import "jsr:@supabase/functions-js/edge-runtime.d.ts"
// OpenAI called via fetch() -- no SDK needed in Deno
// Structured output via JSON schema in the API request body
```

No npm packages needed in the Edge Function. OpenAI's API is called via native `fetch()` with the appropriate headers and JSON body. This keeps the function lean and avoids dependency management in Deno.

## Supabase Schema Additions

```sql
-- Template sharing
CREATE TABLE shared_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  share_code TEXT UNIQUE NOT NULL DEFAULT encode(gen_random_bytes(4), 'hex'),
  owner_id UUID NOT NULL REFERENCES auth.users(id),
  template_json JSONB NOT NULL,
  template_name TEXT NOT NULL,
  sport_type TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  expires_at TIMESTAMPTZ DEFAULT (now() + interval '90 days'),
  download_count INT DEFAULT 0
);

-- RLS: anyone can read by share_code, only owner can insert
ALTER TABLE shared_templates ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can read shared templates"
  ON shared_templates FOR SELECT USING (true);
CREATE POLICY "Owners can insert shared templates"
  ON shared_templates FOR INSERT WITH CHECK (auth.uid() = owner_id);
CREATE POLICY "Owners can delete shared templates"
  ON shared_templates FOR DELETE USING (auth.uid() = owner_id);
```

## Installation

### iOS (no new SPM packages)

```bash
# No new Swift packages required.
# All LLM functionality proxied through existing Supabase Edge Functions.
# All file import uses built-in Apple frameworks (PDFKit, Vision, UniformTypeIdentifiers).
```

### Font files (manual download)

```bash
# Download Alpino from FontShare (https://www.fontshare.com/fonts/alpino)
# Extract Alpino-Regular.otf and Alpino-Medium.otf
# Add to WorkloadApp/Resources/ in Xcode
# Register in Info.plist UIAppFonts array
```

### Supabase Edge Function (deploy once)

```bash
supabase functions new parse-workout
# Edit supabase/functions/parse-workout/index.ts
supabase secrets set OPENAI_API_KEY=sk-...
supabase functions deploy parse-workout
```

## Cost Analysis

| Operation | Model | Est. Tokens | Cost per Import |
|-----------|-------|-------------|-----------------|
| Text workout parsing | gpt-4o-mini | ~500 in, ~300 out | ~$0.00026 |
| Image workout (vision) | gpt-4o-mini | ~1500 in, ~300 out | ~$0.00041 |
| PDF workout (text extracted) | gpt-4o-mini | ~800 in, ~400 out | ~$0.00036 |

At 1,000 imports/month: ~$0.30/month. Negligible cost. Pro-gate the feature to limit to paying users.

## Alternatives Considered

| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| LLM provider | OpenAI gpt-4o-mini via Edge Function | Anthropic Claude, Google Gemini | OpenAI has the best structured output guarantees (JSON Schema mode). Gemini is cheaper but structured output is less reliable. Claude is more expensive for this use case. |
| LLM call location | Supabase Edge Function (server-side) | Direct from iOS app | API key exposure risk, no rate limiting, can't swap models without app update. |
| OCR | Apple Vision (on-device) | Google ML Kit, Tesseract | Vision is free, on-device, private, and excellent quality on iOS 17+. No dependency to manage. |
| PDF parsing | Apple PDFKit (on-device) | PSPDFKit, third-party PDF SDK | PDFKit handles text extraction. We don't need annotation, editing, or rendering -- just text. |
| Template sharing transport | Share codes + deep links | Universal Links, Firebase Dynamic Links | Share codes are simpler, work without server-side AASA hosting, and degrade gracefully (user can type code manually). |
| Font | Alpino (FontShare) | Keep DM Sans, Inter, SF Pro | DM Sans is generic; Alpino gives the app a distinctive editorial character. Inter is overused. SF Pro lacks personality. |

## Confidence Assessment

| Decision | Confidence | Reason |
|----------|------------|--------|
| Edge Function proxy pattern | HIGH | Standard architecture for mobile + LLM. Supabase Edge Functions are documented and SDK support is built in (verified in supabase-swift docs). |
| gpt-4o-mini for parsing | HIGH | Structured Outputs verified in OpenAI docs. Cost is well-documented. Model handles workout text reliably. |
| Apple Vision for OCR | HIGH | VNRecognizeTextRequest is first-party, well-documented, iOS 17+ compatible. |
| PDFKit for PDF text | HIGH | PDFDocument.page(at:).string is documented Apple API. No edge cases for text-based PDFs. |
| Alpino font availability | MEDIUM | Confirmed 6 weights including Regular and Medium via befonts.com. ITF Free Font License allows commercial use per FontShare FAQ. Could not verify exact OTF file names due to FontShare requiring JavaScript -- verify after download. |
| Template sharing via share codes | HIGH | Simple PostgreSQL + RLS pattern. No new dependencies. Share code generation is trivial. |
| No new iOS dependencies needed | HIGH | All features achievable with existing Supabase SDK + Apple frameworks. Verified Edge Functions invoke, PDFKit, Vision are all available. |

## Sources

- [Supabase Edge Functions Swift invocation](https://supabase.com/docs/reference/swift/functions-invoke)
- [Supabase Edge Functions overview](https://supabase.com/docs/guides/functions)
- [OpenAI API pricing](https://openai.com/api/pricing/)
- [VNRecognizeTextRequest docs](https://developer.apple.com/documentation/vision/vnrecognizetextrequest)
- [PDFKit docs](https://developer.apple.com/documentation/pdfkit)
- [SwiftUI fileImporter](https://developer.apple.com/documentation/swiftui/view/fileimporter(ispresented:allowedcontenttypes:allowsmultipleselection:oncompletion:))
- [FontShare Alpino](https://www.fontshare.com/fonts/alpino)
- [FontShare ITF Free Font License](https://www.fontshare.com/licenses/itf-ffl)
- [supabase-swift GitHub](https://github.com/supabase/supabase-swift)
