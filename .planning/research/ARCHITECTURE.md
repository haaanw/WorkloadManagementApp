# Architecture Patterns

**Domain:** LLM Import, Template Sharing & Typography Polish for iOS Fitness App
**Researched:** 2026-05-10

## Recommended Architecture

Three features integrate into the existing layer stack at different points. None require changes to the core data model (WorkoutTemplate hierarchy is reused as-is). The SyncService gains one new entity (shared template codes). The font migration touches every view but no logic.

### Integration Map

```
Feature               Layer Touched         New Components                Modified Components
─────────────────────────────────────────────────────────────────────────────────────────────
LLM Import            Service + View        LLMImportService             TextTemplateImportSheet (replace)
                                            LLMImportSheet               TemplateRepository (minor)
                                            Supabase Edge Function

Template Sharing      Service + View + DB   TemplateSharingService       SyncService (add push/pull)
                                            ShareTemplateSheet           TemplateListView (add share button)
                                            ImportSharedTemplateSheet    Supabase schema (new table)

Font Migration        Utilities + Views     Alpino-*.otf files           FontTokens.swift (swap names)
                                                                         Info.plist (UIAppFonts)
                                                                         DESIGN.md (update spec)

Sync Hardening        Service               (none)                       SyncService (fix try?)

Border Fix            Views                 (none)                       TemplateEditorSheet + others
```

### Component Boundaries

| Component | Responsibility | Communicates With |
|-----------|---------------|-------------------|
| **LLMImportService** | Coordinates OCR + LLM call, returns parsed templates | Supabase Edge Function (via HTTP), Vision framework, TemplateRepository |
| **LLM Edge Function** | Proxies LLM API call server-side (keeps API key off device) | OpenAI API (structured output), Supabase auth (validates JWT) |
| **TemplateSharingService** | Generates share codes, resolves codes to templates, handles deep links | Supabase (shared_templates table), TemplateRepository |
| **ShareTemplateSheet** | UI for generating/copying share link or code | TemplateSharingService |
| **ImportSharedTemplateSheet** | UI for pasting code or handling deep link, previewing template | TemplateSharingService, TemplateRepository |
| **LLMImportSheet** | Multi-step UI: pick source (text/photo/PDF) -> OCR -> LLM parse -> preview -> save | LLMImportService |

## Data Flow

### LLM Import Flow

```
User picks source (text paste / camera / photo library / PDF)
    |
    v
[On-device OCR] -- Vision VNRecognizeTextRequest (images/PDF only, skip for text paste)
    |
    v
Raw text string
    |
    v
[LLMImportService] -- POST to Supabase Edge Function
    |                   - Sends: raw text + system prompt with schema
    |                   - Auth: Supabase JWT in Authorization header
    |
    v
[Edge Function] -- Calls OpenAI gpt-4o-mini with structured output (JSON mode)
    |               - Returns: JSON array of parsed templates
    |               - Schema: [{name, sportType, sessionType, groups: [{name, exercises:
    |                 [{name, category, sets: [{reps, weight, rpe, rir, warmup}]}]}]}]
    |
    v
[LLMImportService] -- Decodes JSON to [ParsedTemplate] structs
    |                   (reuse existing GroupDTO/ExerciseDTO/SetDTO from SyncService)
    |
    v
[LLMImportSheet] -- Shows preview (reuse template preview pattern from TemplatePreviewSheet)
    |               - User can edit names, remove exercises, adjust before saving
    |
    v
[TemplateRepository.save()] -- Creates WorkoutTemplate + groups + exercises + sets
    |
    v
[SyncService.pushWorkoutTemplates()] -- Syncs to Supabase (existing flow)
```

**Key design decisions:**

1. **Server-side LLM call via Supabase Edge Function** -- API key never on device, cost controlled server-side, rate limiting possible. The app already has a Supabase client with auth; invoking an Edge Function is a single `client.functions.invoke()` call.

2. **OpenAI gpt-4o-mini over Claude/on-device** -- gpt-4o-mini has mature structured output (JSON mode with schema enforcement), low cost (~$0.15/1M input tokens), fast. On-device Apple Foundation Models require iOS 26+ (out of scope for iOS 17+ target). Claude works but OpenAI's JSON schema enforcement is more reliable for structured extraction.

3. **Vision framework for OCR, not LLM vision** -- Sending images to LLM APIs is expensive ($0.003-0.01 per image). A multi-page PDF program could cost $0.05-0.20 per import. VNRecognizeTextRequest is free, on-device, and accurate for typed text. Extract text locally, then send text-only to LLM.

4. **Reuse existing GroupDTO decode path** -- SyncService already has `decodeGroups(from:)` that converts JSON to `[ExerciseGroup]`. The Edge Function returns the same shape, so the import service reuses this decoder.

### Template Sharing Flow

```
Sharer taps "Share" on a template
    |
    v
[TemplateSharingService.createShareCode()]
    |-- Serializes template to JSON (reuse SyncService.encodeGroups)
    |-- Generates 8-char alphanumeric code
    |-- Upserts to Supabase `shared_templates` table:
    |     { code, template_json, sharer_id, sport_type, session_type,
    |       template_name, expires_at (30 days), created_at }
    |
    v
[ShareTemplateSheet]
    |-- Shows share code + "Copy Link" button
    |-- Link format: https://tutrice.app/t/{code}  (universal link)
    |-- Also supports: tutrice://import/{code}  (URL scheme fallback)
    |
    v
--- Recipient side ---
    |
    v
[Universal link / URL scheme / manual code entry]
    |-- onOpenURL handler in AppRouter routes to ImportSharedTemplateSheet
    |-- Or: user taps "Import by code" in TemplateListView
    |
    v
[TemplateSharingService.resolveCode(code)]
    |-- Queries Supabase: SELECT * FROM shared_templates WHERE code = $1 AND expires_at > now()
    |-- Decodes template_json back to preview model
    |
    v
[ImportSharedTemplateSheet]
    |-- Shows template preview (exercise list, set counts)
    |-- "Import" button creates local WorkoutTemplate via TemplateRepository
    |-- Sets isAthleteOwned = true, athleteId = current user
    |-- New UUID (not the sharer's ID) to avoid sync conflicts
```

**Key design decisions:**

1. **Short codes over deep link only** -- Coaches share codes verbally in gyms. A code like `PUSH4X8` is easier to share than a URL. Support both.

2. **Server-stored JSON, not template ID reference** -- The recipient gets a snapshot of the template at share time. If the sharer edits their template later, shared copies are unaffected. This avoids complex permission/ownership chains.

3. **30-day expiry** -- Prevents unbounded table growth. Shared templates are meant for one-time import, not permanent hosting.

4. **No new SwiftData model** -- Shared templates live only in Supabase. The imported result is a regular WorkoutTemplate. No local `SharedTemplate` model needed.

5. **Universal links require AASA file** -- The `apple-app-site-association` file must be hosted at `tutrice.app/.well-known/apple-app-site-association`. This is a one-time setup on the existing GitHub Pages site or Supabase hosting.

### Font Migration Flow

```
[Replace font files]
    DMSans-Regular.ttf -> Alpino-Regular.otf
    DMSans-Medium.ttf  -> Alpino-Medium.otf
    |
    v
[Update Info.plist UIAppFonts]
    Remove: DMSans-Regular.ttf, DMSans-Medium.ttf
    Add:    Alpino-Regular.otf, Alpino-Medium.otf
    |
    v
[Update FontTokens.swift]
    Change all Font.custom("DMSans-Regular", ...) -> Font.custom("Alpino-Regular", ...)
    Change all Font.custom("DMSans-Medium", ...)  -> Font.custom("Alpino-Medium", ...)
    |
    v
[Update WorkloadApp.swift font assertions]
    Existing DEBUG assertions validate font loading -- update font names
    |
    v
[Grep + fix any hardcoded font references]
    TextTemplateImportSheet line 42 has hardcoded "DMSans-Regular" outside FontTokens
    Potentially other views -- full grep required
    |
    v
[Update DESIGN.md]
    Replace "DM Sans" references with "Alpino"
```

**Key design decisions:**

1. **Centralized via FontTokens.swift** -- The existing `Font.Tokens` enum means the migration is a 2-line change in FontTokens plus Info.plist. The only risk is hardcoded font strings outside this enum (found one in TextTemplateImportSheet).

2. **Alpino weight mapping** -- Alpino from FontShare ships as: Thin, Light, Regular, Medium, SemiBold, Bold, Heavy, Black. Map DM Sans Regular -> Alpino Regular, DM Sans Medium -> Alpino Medium. Direct match available.

3. **Size adjustments may be needed** -- Alpino has a smaller x-height than DM Sans. Visual QA pass required after swap. Font sizes in FontTokens may need +1-2pt bumps for equivalent readability.

## Patterns to Follow

### Pattern 1: Edge Function as LLM Proxy

**What:** Supabase Edge Function wraps the OpenAI API call. The iOS app sends raw text; the function adds the system prompt, calls the API, and returns structured JSON.

**When:** Any time an LLM API call is needed from the client. Never embed API keys in the app binary.

**Example (Edge Function -- Deno/TypeScript):**

```typescript
// supabase/functions/parse-workout/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

serve(async (req) => {
  // Validate Supabase JWT
  const authHeader = req.headers.get("Authorization")
  if (!authHeader) return new Response("Unauthorized", { status: 401 })

  const { rawText } = await req.json()

  const response = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${Deno.env.get("OPENAI_API_KEY")}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: "gpt-4o-mini",
      response_format: { type: "json_object" },
      messages: [
        { role: "system", content: WORKOUT_PARSE_PROMPT },
        { role: "user", content: rawText }
      ],
    }),
  })

  const data = await response.json()
  return new Response(
    JSON.stringify(data.choices[0].message.content),
    { headers: { "Content-Type": "application/json" } }
  )
})
```

**Example (iOS client call):**

```swift
// LLMImportService.swift
@MainActor
struct LLMImportService {
    static func parseWorkout(
        rawText: String,
        client: SupabaseClient
    ) async throws -> [ParsedTemplateDTO] {
        let payload = ["rawText": rawText]
        let response = try await client.functions.invoke(
            "parse-workout",
            options: .init(body: payload)
        )
        let json = try JSONDecoder().decode(
            LLMParseResponse.self, from: response.data
        )
        return json.templates
    }
}
```

### Pattern 2: Stateless Service with Static Methods (existing pattern)

**What:** LLMImportService and TemplateSharingService follow the existing engine/service pattern -- pure structs with static methods, no instance state.

**When:** All new service logic. Consistent with WorkloadCalculator, PRDetector, WorkoutImportService.

```swift
@MainActor
struct TemplateSharingService {
    static func createShareCode(
        template: WorkoutTemplate,
        client: SupabaseClient
    ) async throws -> String { ... }

    static func resolveCode(
        _ code: String,
        client: SupabaseClient
    ) async throws -> SharedTemplatePreview { ... }
}
```

### Pattern 3: Preview-then-Save for Imports

**What:** Both LLM import and template sharing show a preview before persisting. User can modify names, remove exercises, then confirm.

**When:** Any time external data enters the template system.

**Why:** Prevents garbage data from LLM hallucination or mismatched sport types. The existing TextTemplateImportSheet already follows this pattern (parse -> preview -> save). LLMImportSheet should mirror the same UX flow.

## Anti-Patterns to Avoid

### Anti-Pattern 1: Embedding LLM API Keys in App Binary

**What:** Shipping OpenAI/Claude API keys inside the iOS app, even in a gitignored config file.
**Why bad:** Binary can be decompiled. Keys extracted within hours of App Store release. Unlimited spend exposure.
**Instead:** Route all LLM calls through Supabase Edge Function. API key lives in Supabase secrets (server-side only).

### Anti-Pattern 2: Sending Images Directly to LLM Vision API

**What:** Using gpt-4o vision or Claude vision to OCR workout photos.
**Why bad:** $0.003-0.01 per image. A multi-page PDF program could cost $0.05-0.20 per import. With thousands of users, this adds up fast. Also slower than on-device OCR.
**Instead:** Use Vision framework (VNRecognizeTextRequest) on-device for OCR. Send extracted text to LLM for structured parsing only.

### Anti-Pattern 3: Creating New SwiftData Models for Shared Templates

**What:** Adding a `SharedTemplate` @Model class that mirrors WorkoutTemplate.
**Why bad:** Duplicates the entire template hierarchy. Sync complexity doubles. SwiftData migration required.
**Instead:** Shared templates are JSON blobs in a Supabase-only table. On import, they become regular WorkoutTemplate instances. No new local model.

### Anti-Pattern 4: Font Migration via Find-and-Replace in Views

**What:** Grepping all `.swift` files and replacing font strings inline.
**Why bad:** Views should never contain font name strings. FontTokens.swift exists precisely to centralize this.
**Instead:** Change FontTokens.swift (2 lines). Grep for any hardcoded font strings that bypassed FontTokens and fix those to use `Font.Tokens.*` instead.

## New Supabase Schema

### shared_templates table

```sql
CREATE TABLE shared_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code TEXT UNIQUE NOT NULL,
    template_name TEXT NOT NULL,
    sport_type TEXT NOT NULL DEFAULT 'lifting',
    session_type TEXT NOT NULL DEFAULT 'strength',
    template_json JSONB NOT NULL,
    sharer_id UUID NOT NULL REFERENCES athletes(id),
    expires_at TIMESTAMPTZ NOT NULL DEFAULT (now() + interval '30 days'),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- RLS: anyone authenticated can read (to import), only owner can insert
ALTER TABLE shared_templates ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read shared templates"
    ON shared_templates FOR SELECT
    TO authenticated
    USING (expires_at > now());

CREATE POLICY "Users can share their own templates"
    ON shared_templates FOR INSERT
    TO authenticated
    WITH CHECK (sharer_id = auth.uid()::uuid);

-- Index for code lookups
CREATE INDEX idx_shared_templates_code ON shared_templates(code) WHERE expires_at > now();

-- Cleanup: periodic deletion of expired codes (pg_cron)
SELECT cron.schedule('cleanup-expired-shares', '0 3 * * *',
    $$DELETE FROM shared_templates WHERE expires_at < now()$$);
```

## New Files Summary

| File | Type | Layer | Purpose |
|------|------|-------|---------|
| `Services/LLMImportService.swift` | `@MainActor struct` | Service | OCR + Edge Function call + JSON decode |
| `Views/WorkoutLog/LLMImportSheet.swift` | `View` | View | Multi-step import UI (source picker, OCR progress, preview, save) |
| `Services/TemplateSharingService.swift` | `@MainActor struct` | Service | Share code generation + resolution via Supabase |
| `Views/ShareTemplateSheet.swift` | `View` | View | Display share code/link with copy button |
| `Views/ImportSharedTemplateSheet.swift` | `View` | View | Code entry + template preview + import |
| `supabase/functions/parse-workout/index.ts` | Edge Function | Backend | OpenAI proxy for workout text parsing |
| `migrations/shared_templates.sql` | SQL | Backend | New table for shared template codes |
| `Resources/Alpino-Regular.otf` | Font file | Resource | Replace DMSans-Regular.ttf |
| `Resources/Alpino-Medium.otf` | Font file | Resource | Replace DMSans-Medium.ttf |

## Modified Files Summary

| File | Change |
|------|--------|
| `Utilities/FontTokens.swift` | Swap `DMSans-*` to `Alpino-*` in all Font.custom calls |
| `Info.plist` | Update UIAppFonts array with new font filenames |
| `WorkloadApp.swift` | Update font assertion names |
| `Views/WorkoutLog/TextTemplateImportSheet.swift` | Fix hardcoded `DMSans-Regular` on line 42 to use `Font.Tokens.body`; may be superseded by LLMImportSheet |
| `Views/TemplateListView.swift` | Add "Share" button to template actions |
| `App/AppRouter.swift` | Add `onOpenURL` handler for `tutrice://import/{code}` and universal link routing |
| `Services/SyncService.swift` | Fix all pull methods: replace bare `try?` with `do/catch` + `logFailure()` (11 occurrences in pull methods) |
| `Views/TemplateEditorSheet.swift` | Replace `.roundedBorder` with `Rectangle().stroke()` overlay |
| `DESIGN.md` | Update font spec from DM Sans to Alpino |

## Scalability Considerations

| Concern | At 100 users | At 10K users | At 1M users |
|---------|--------------|--------------|-------------|
| LLM API cost | ~$1/mo (gpt-4o-mini) | ~$50/mo | Gate behind Pro; batch limits; ~$2K/mo |
| shared_templates growth | Negligible | ~10K rows, auto-expire | pg_cron cleanup job; index on code + expires_at |
| Edge Function cold starts | Unnoticeable | ~200ms p99 | Supabase Pro plan for warm instances |
| OCR processing time | Instant | Instant (on-device) | Instant (on-device) |
| Font file size | +110KB (two weights) | Same | Same |

## Build Order Recommendation

Based on dependency analysis:

1. **Font migration + border fix** (no dependencies, purely cosmetic, quick win)
2. **SyncService hardening** (no dependencies, fixes existing tech debt, de-risks sync for sharing feature)
3. **Template sharing** (depends on hardened sync for confidence; new Supabase table + Edge Function deployment pipeline established)
4. **LLM import** (depends on Edge Function infrastructure from sharing phase; heaviest feature, most testing needed)

**Rationale:** Font and sync fixes are independent leaf changes. Template sharing establishes the Supabase Edge Function deployment pipeline that LLM import reuses. LLM import is the riskiest feature (LLM output quality, cost management, multi-format OCR) and benefits from all other infrastructure being stable.

## Sources

- [Supabase Edge Functions docs](https://supabase.com/docs/guides/functions) -- Edge Function patterns, secrets management
- [Apple VNRecognizeTextRequest](https://developer.apple.com/documentation/vision/vnrecognizetextrequest) -- On-device OCR API
- [Fontshare Alpino](https://www.fontshare.com/?q=Alpino) -- Font availability and weight options
- [OpenAI Structured Outputs](https://platform.openai.com/docs/guides/structured-outputs) -- JSON mode for reliable parsing
- [Universal Links on iOS](https://www.avanderlee.com/swiftui/universal-links-ios/) -- Deep link implementation
- [Apple: Allowing apps and websites to link to your content](https://developer.apple.com/documentation/xcode/allowing-apps-and-websites-to-link-to-your-content/) -- AASA file setup
- Existing codebase: `SyncService.swift`, `TextTemplateImportSheet.swift`, `WorkoutTemplate.swift`, `FontTokens.swift`, `AppContainer.swift`
