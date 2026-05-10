# Feature Landscape: v1.3 LLM Import, Sharing & Polish

**Domain:** Fitness app -- AI workout import, template sharing, typography rebrand, tech debt
**Researched:** 2026-05-10
**Focus:** NEW features only (existing template, HealthKit import, coach, subscription systems already built)

## Table Stakes

Features users expect once they see these capabilities advertised. Missing = broken or frustrating.

### LLM Workout Import

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Text input parsing (paste workout text) | Lowest friction entry point; copy from notes/messages/Reddit | Medium | Simplest LLM call -- text-only, no OCR needed. Must handle freeform formats: "3x10 bench 135lbs", "Bench Press: 3 sets of 10 @ 60kg", coach shorthand |
| PDF file import | Coaches distribute programs as PDFs constantly | High | Requires PDF text extraction before LLM. Use iOS `PDFKit` for text-based PDFs. Image-based PDFs need OCR pipeline |
| Image/screenshot import | Users screenshot workouts from Instagram, coaching apps, spreadsheets | High | Requires sending image to vision-capable LLM (GPT-4o, Claude). Base64 encode and send with structured output schema |
| Review-before-save screen | Users must verify parsed data before it becomes a template | Low | Non-negotiable. LLM output is probabilistic -- user MUST confirm exercise names, sets, reps, weights before commit |
| Exercise name normalization | "Barbell Bench" vs "Bench Press" vs "BB Bench" must map correctly | Medium | LLM should output canonical exercise names matching app's exercise library. Fuzzy match against existing exercises + custom exercises |
| Unit detection (kg vs lbs) | Workout sources mix units freely | Low | LLM prompt should extract units; app converts to user's preferred unit. Default to user's existing preference if ambiguous |
| Error state for unparseable input | Garbled text, unrelated content, empty images | Low | Show clear "couldn't parse" message with option to retry or enter manually. Never silently fail |

### Template Sharing

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Share via system share sheet | iOS standard -- users expect share button producing a link | Low | Use `UIActivityViewController` with a shareable URL. Industry standard (Hevy, Strong both do this) |
| Import shared template by tapping link | Receiver taps link, template appears in their library | Medium | Requires Universal Links or custom URL scheme + backend endpoint to store/retrieve shared template data |
| Template preview before import | See what you're getting before adding to library | Low | Show template name, exercise count, group structure. Same pattern as review-before-save in LLM import |
| Shared templates exclude personal weight data | Privacy -- don't leak the sharer's actual weights | Low | Share structure only (exercises, sets, reps, RPE targets). Hevy explicitly does this. Weights are personal |

### Font Migration (Alpino)

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| All text renders in new font consistently | Mixed fonts = broken design. Must be 100% or 0% | Low | Existing `Font.Tokens` abstraction makes this a ~2-file change (FontTokens.swift + Info.plist). Swap "DMSans-Regular/Medium" to "Alpino-Regular/Medium" |
| Font weights match existing hierarchy | Regular + Medium weights must exist in Alpino | Low | Alpino has Thin/Light/Regular/Medium/Bold/Black. Regular + Medium map 1:1 from DM Sans |

### Tech Debt Fixes

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| SyncService pull errors surfaced, not swallowed | Silent `try?` means data can silently fail to sync | Medium | 40+ `try?` calls in SyncService.swift. Each pull function silently drops errors. Need `do/catch` with logging and optional retry. Prioritize pull-side (data loss risk) over push-side (retried on next sync) |
| 0pt border radius enforced everywhere | Design system violation -- 23 occurrences of `RoundedRectangle` across 6 files | Low | Find-and-replace `RoundedRectangle` with `Rectangle` in overlay/stroke modifiers. Mechanical change |

## Differentiators

Features that set the product apart. Not expected, but valuable.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Multi-format LLM import (text + image + PDF in one flow) | Most apps support CSV import only (Hevy, Strong). AI-powered import from ANY format is rare | High | Hevy has HevyGPT but it generates plans, not imports existing ones. Strong only shares via proprietary links. Importing from coach PDFs/screenshots is an unmet need |
| Automatic exercise matching to existing library | Parsed exercises auto-link to user's exercise history for PR tracking continuity | Medium | Match LLM-extracted exercise names against user's ExerciseEntry history + CustomExercise list. Fallback to creating new exercise |
| Coach-to-athlete template sharing | Coach shares template, athlete receives it directly in app with coach attribution | Medium | Extends existing CoachAthleteRelationship. Coach's template becomes athlete-owned copy on import. Differentiated from generic link sharing |
| Batch import (multi-week program) | Import entire training program at once, not one workout at a time | High | LLM parses multi-day structure from PDF. Creates multiple templates with day labels. Defer to v1.4 -- single template import first |
| Shareable template link works without app installed | Web preview page for shared templates with App Store download link | Medium | Requires a web endpoint (Supabase Edge Function or static page) that renders template preview + deep link into app |

## Anti-Features

Features to explicitly NOT build in v1.3.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| On-device LLM processing | No viable on-device model handles structured extraction from images reliably on iPhone. Apple Intelligence APIs do not expose structured extraction. Model size (2-7B minimum for quality) exceeds practical mobile deployment | Use server-side API (OpenAI GPT-4o-mini for text, GPT-4o for images). Cost per parse: ~$0.01-0.05. Acceptable for Pro-gated feature |
| AI chatbot for workout design | LLM cost per conversation is high, liability for training advice, out of scope for v1.3 | Keep import-only. User brings the workout, LLM structures it. No generative workout creation (Hevy already has HevyGPT for this) |
| Template marketplace / public library | Content curation burden, moderation, discoverability UX -- all premature | Stick to direct sharing (link/code). Social discovery is a v2+ feature |
| Background LLM processing | Complexity of background task management + API timeout risk | Process synchronously with loading indicator. Typical parse completes in 2-5 seconds |
| CSV import/export of templates | Engineering effort for niche use case. LLM import subsumes most CSV scenarios | LLM text import handles pasted CSV data naturally. Dedicated CSV parser is redundant |
| Real-time collaborative template editing | Massive sync complexity for minimal value | Templates are personal copies. Share -> import creates independent copy |
| Social feed of shared templates | Community features are a different product direction | Direct sharing only. No public browsing, no likes/comments |

## Feature Dependencies

```
Font Migration (Alpino)
  No dependencies. Can ship independently.

SyncService Hardening
  No dependencies. Can ship independently.

Rounded Border Fix
  No dependencies. Can ship independently.

LLM Workout Import
  Depends on: WorkoutTemplate model (EXISTS)
  Depends on: ExerciseGroup/TemplateExercise/TemplateSet models (EXIST)
  Depends on: TemplateRepository.save() (EXISTS)
  New: LLM API integration (OpenAI Swift client or raw URLSession)
  New: Import parsing engine (text -> structured template)
  New: Image/PDF preprocessing pipeline
  New: Review/confirm UI sheet
  New: Import entry point UI (button in template management view)

Template Sharing
  Depends on: WorkoutTemplate model (EXISTS)
  Depends on: TemplateRepository.save() + duplicate() (EXIST)
  Depends on: Supabase backend (EXISTS)
  New: Supabase table for shared template payloads (or serialized JSON in URL)
  New: Share link generation (Universal Links preferred)
  New: Deep link handler in AppRouter
  New: Template import/preview sheet
  Optional: Web preview page (Supabase Edge Function)

LLM Import --X--> Template Sharing (independent, no cross-dependency)
```

## MVP Recommendation

**Priority order based on value/complexity ratio:**

1. **Font migration (Alpino)** -- Immediate visual rebrand, ~2 hours of work. Existing `Font.Tokens` abstraction means changing 2 filenames in one file. Register new fonts in Info.plist. Delete old font files.

2. **Rounded border fix** -- 23 occurrences across 6 files. Mechanical find-and-replace. Ship with font migration as a single "design polish" phase.

3. **SyncService `try?` hardening** -- Silent data loss is a serious bug. Convert pull-side `try?` to `do/catch` with structured error logging. Does not change behavior for users (data still syncs), but surfaces failures for debugging.

4. **Template sharing** -- Lower complexity than LLM import, high user value for coach-athlete workflows. Builds on existing template + Supabase infrastructure. Ship before LLM import.

5. **LLM workout import** -- Highest complexity, highest differentiation. Requires new API dependency (OpenAI), new parsing logic, new UI flow. Gate behind Pro subscription to offset API costs.

**Defer to v1.4:**
- Batch multi-week program import (too complex for v1.3)
- Web preview page for shared links (nice-to-have, not launch-critical)
- Template folders/organization (premature per REQUIREMENTS.md)

## Detailed Feature Specifications

### LLM Workout Import -- UX Flow

**Entry point:** Button in template management view ("Import Workout") + option in "+" menu

**Step 1: Input selection**
- Three tabs/segments: "Text" | "Photo" | "File"
- Text: Multi-line text field with paste support + placeholder showing example format
- Photo: Camera or photo library picker (PHPickerViewController)
- File: Document picker (UIDocumentPickerViewController) for PDF/DOCX

**Step 2: Processing**
- Send to OpenAI API with structured output schema matching WorkoutTemplate structure
- Show loading indicator ("Analyzing workout...")
- Timeout after 30 seconds with retry option

**Step 3: Review & Confirm**
- Display parsed template: name, sport type, groups, exercises, sets/reps/weight
- Editable fields -- user can fix any LLM errors before saving
- "Save as Template" button creates WorkoutTemplate via TemplateRepository
- Exercise names highlighted if they match existing exercises (continuity signal)

**Edge cases:**
- Multiple workouts in one document: parse first only, show "We found multiple workouts. Import one at a time." (v1.3 limitation)
- No exercises detected: "Couldn't find workout data. Try pasting the workout text directly."
- Mixed units in same document: normalize to user's preference, flag any ambiguous conversions
- Non-English input: GPT-4o handles multilingual well. No special handling needed.
- Very long documents (10+ pages): truncate to first 5 pages with warning

**API choice:** OpenAI GPT-4o-mini for text-only (fast, cheap at ~$0.15/1M input tokens). GPT-4o for images (vision capability, ~$2.50/1M input tokens). A single workout parse: ~500-2000 tokens input, ~200-500 tokens output = $0.001-0.01 per parse for text, $0.01-0.05 for images.

**Subscription gating:** Pro feature. Free users see the button but hit upgrade sheet on tap. API costs justify Pro-only access.

### Template Sharing -- UX Flow

**Sharing (sender):**
1. Template management view: tap "..." menu on template, select "Share"
2. App serializes template structure to JSON (exercises, groups, sets -- NO personal weights)
3. Upload JSON payload to Supabase `shared_templates` table, get back a UUID
4. Generate Universal Link: `https://app.farosapp.com/template/{uuid}` (or custom URL scheme fallback)
5. Present system share sheet with the link

**Receiving (recipient):**
1. Tap link -> app opens (Universal Link) or App Store (deferred deep link)
2. App fetches shared template JSON from Supabase by UUID
3. Show preview sheet: template name, exercise list, group structure
4. "Add to My Templates" creates athlete-owned copy via TemplateRepository.duplicate()
5. Template appears in recipient's library with "(Shared)" suffix

**Data format (shared payload):**
```json
{
  "templateName": "Push Day A",
  "sportType": "lifting",
  "sessionType": "strength",
  "notes": "Heavy compound focus",
  "groups": [
    {
      "groupName": "Group A",
      "orderIndex": 0,
      "exercises": [
        {
          "exerciseName": "Bench Press",
          "exerciseCategory": "compound",
          "muscleGroup": "chest",
          "orderIndex": 0,
          "sets": [
            { "setIndex": 0, "targetReps": 5, "targetRPE": 8.0, "isWarmup": false }
          ]
        }
      ]
    }
  ]
}
```

**Expiration:** Shared links expire after 90 days (configurable). Prevents unbounded storage growth.

**Privacy:** No user identification in shared payload. Template is anonymous once shared. Coach templates shared via coach-athlete relationship retain attribution.

**Coach-specific flow:** Coach can share directly to linked athlete (skips link, pushes template to athlete's library via existing sync). Uses existing CoachAthleteRelationship infrastructure.

### Font Migration -- Execution Plan

**Alpino font family (from FontShare):**
- License: Free for commercial use (ITF/FontShare license)
- Weights needed: Alpino-Regular + Alpino-Medium (matching current DM Sans usage)
- Available weights: Thin, Light, Regular, Medium, Bold, Black

**Changes required:**
1. Download Alpino-Regular.otf and Alpino-Medium.otf from FontShare
2. Add to Xcode project Resources/ folder (replace DMSans files)
3. Update Info.plist: swap DMSans filenames for Alpino filenames in UIAppFonts array
4. Update FontTokens.swift: change all `"DMSans-Regular"` to `"Alpino-Regular"` and `"DMSans-Medium"` to `"Alpino-Medium"`
5. Update DESIGN.md to reference Alpino instead of DM Sans
6. Run app, visually verify all screens (font metrics differ -- check for text truncation or layout shifts)
7. Delete old DMSans font files from project

**Risk:** Alpino has a "small x-height optimised for magazine design" (per ITF description). This means body text at the same point size may appear slightly smaller than DM Sans. May need to bump body/label sizes by 1pt. Test on device before finalizing.

### SyncService Hardening -- Scope

**Problem:** 40+ `try?` calls in SyncService.swift silently swallow errors. Pull-side failures (fetching from Supabase) mean user data never arrives locally. Push-side failures (uploading to Supabase) mean local changes never sync.

**Fix approach:**
- Pull-side `try?` on Supabase queries: convert to `do/catch`, log error with context (entity type, athlete ID)
- Pull-side `try?` on context.fetch: keep `try?` (local fetch, if this fails something is catastrophically wrong)
- Pull-side `try?` on context.save: convert to `do/catch` with error log
- Push-side `try?`: lower priority, already retried on next sync cycle. Log but don't block.

**Deliverable:** Structured logging for sync failures. No user-facing changes. Future: surface sync status indicator on profile screen.

## Sources

- [Hevy routine sharing](https://www.hevyapp.com/features/share-folders-routines/) -- link-based sharing, exercises shared without weights
- [HevyGPT](https://www.hevyapp.com/features/hevy-gpt/) -- ChatGPT integration for plan generation (not import)
- [Strong template sharing](https://help.strongapp.io/article/109-share-workout-or-template) -- share sheet with URL, requires app installed
- [OpenAI Structured Outputs](https://developers.openai.com/api/docs/guides/structured-outputs) -- JSON schema enforcement for reliable parsing
- [OpenAI Vision API](https://developers.openai.com/api/docs/guides/images-vision) -- image input for workout screenshot parsing
- [Alpino font (Befonts)](https://befonts.com/alpino-font-family.html) -- 6 weights, free commercial use, ITF design
- [Apple custom fonts guide](https://developer.apple.com/documentation/uikit/adding-a-custom-font-to-your-app) -- Info.plist registration, Font.custom() usage
- [Apple Universal Links](https://developer.apple.com/documentation/xcode/allowing-apps-and-websites-to-link-to-your-content/) -- deep linking for template sharing
- [SwiftOpenAI package](https://github.com/jamesrochabrun/SwiftOpenAI) -- Swift client for OpenAI API
