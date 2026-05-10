# Project Research Summary

**Project:** Tonus v1.3 — LLM Import, Sharing & Polish
**Domain:** iOS fitness app — AI feature addition, typography rebrand, infrastructure hardening
**Researched:** 2026-05-10
**Confidence:** HIGH

## Executive Summary

Tonus v1.3 adds four capabilities to an already-shipped app: LLM-powered workout import, template sharing between athletes and coaches, a typography rebrand from DM Sans to Alpino, and SyncService error handling hardening. Research consistently shows this release is an infrastructure and polish cycle as much as a feature cycle — the LLM import is genuinely differentiated (no competitor imports from arbitrary PDFs and photos), but it carries the highest risk and should ship last, after the simpler high-value items are complete. The recommended build order is: design polish first (font and border fix), then sync hardening, then template sharing, then LLM import. Each phase unlocks or de-risks the next.

The critical architectural decision for LLM import is the Edge Function proxy pattern: all LLM calls route through Supabase Edge Functions, and the OpenAI API key lives in Supabase secrets — never in the iOS binary. This is not optional; iOS binaries can be decompiled and keys extracted within hours of App Store release. The proxy also enables rate limiting, Pro subscription validation, and model swaps without app updates. Importantly, zero new iOS dependencies are required: LLM calls go through the existing `client.functions.invoke()` in supabase-swift, OCR uses Apple Vision, and PDF extraction uses Apple PDFKit — all bundled with iOS 17+.

The main risk cluster is LLM output quality. LLMs hallucinate exercise names, invent impossible rep schemes, and misinterpret coach shorthand. The mitigation is mandatory human review before any LLM-generated template is saved — never auto-save. Combine this with a constrained JSON Schema output, sanity bounds on weights and reps, and fuzzy matching against the existing exercise catalog. A secondary risk is the Alpino font migration: Alpino has a smaller x-height than DM Sans, and text may require 1-2pt size bumps. The existing UIFont DEBUG assertion in `WorkloadApp.swift` provides a safety net if font names are wrong.

## Key Findings

### Recommended Stack

No new iOS dependencies are needed. All LLM functionality routes through the existing Supabase Swift SDK. OCR uses Apple Vision (VNRecognizeTextRequest), PDF text extraction uses Apple PDFKit, and file picking uses SwiftUI's `.fileImporter()`. The Supabase Edge Function (Deno/TypeScript) requires no npm packages — the OpenAI API is called via native `fetch()`. For template sharing, a new `shared_templates` Supabase table with RLS policies covers all backend needs.

For the font migration, Alpino is available from FontShare under the ITF Free Font License, which permits commercial use and app embedding. It provides exact weight parity: Alpino-Regular maps to DM Sans Regular, Alpino-Medium maps to DM Sans Medium. The migration affects `FontTokens.swift` (2 string replacements), `Info.plist` (UIAppFonts array), `WorkloadApp.swift` (DEBUG font assertion), and any hardcoded font strings outside FontTokens (one confirmed in `TextTemplateImportSheet` line 42).

**Core technologies:**
- **gpt-4o-mini via Supabase Edge Function:** LLM structured text extraction — best cost/quality ratio at $0.15/1M input tokens; JSON Schema mode guarantees valid output; API key never on device; ~$0.30/month at 1,000 imports
- **Apple Vision (VNRecognizeTextRequest):** On-device OCR for images and scanned PDFs — free, private, iOS 17+ compatible; eliminates per-image LLM vision costs ($0.003–0.01/image)
- **Apple PDFKit:** On-device PDF text extraction — `PDFDocument.page(at:).string` for digital PDFs; Vision OCR fallback for scanned/image-based PDFs only
- **Supabase `shared_templates` table + RLS:** Template snapshot storage with opaque 8-char share codes; 30-day expiry; no new iOS dependency; uses existing client
- **Alpino-Regular.otf + Alpino-Medium.otf:** Typography replacement — commercial license confirmed; direct 1:1 weight mapping from DM Sans

**Rejected options (confirmed by research):**
- OpenAI/SwiftOpenAI SDK on iOS: API key exposure risk; use Edge Function proxy instead
- Universal Links as sole sharing mechanism: requires AASA file setup on `tutrice.app` domain; share codes are the reliable fallback that works in all conditions
- Apple Foundation Models: iOS 26+ only; app targets iOS 17+, making this a non-starter for v1.3
- GPT-4o full model for text parsing: 10x more expensive than gpt-4o-mini with no quality improvement for structured extraction from workout text
- Third-party OCR (Google ML Kit, Tesseract): Apple Vision handles printed text excellently on iOS 17+ at zero cost

### Expected Features

**Must have (table stakes):**
- Text paste workout import — lowest-friction LLM entry point; handles freeform formats (3x10 bench 135lbs, coach shorthand, AMRAP/EMOM notation)
- PDF file import — coaches distribute programs as PDFs; PDFKit then LLM pipeline
- Image/screenshot import — users capture workouts from Instagram, whiteboards, coach apps; Vision OCR then LLM
- Review-before-save screen — LLM output is probabilistic; non-negotiable human verification before any template is committed
- Exercise name normalization — canonical matching against existing catalog (CustomExercise + built-in exercises)
- Unit detection (kg vs lbs) — default to user's preference when ambiguous; flag explicit conversions
- Clear error state for unparseable input — "couldn't parse" message with retry or manual entry fallback
- Share template via system share sheet — `UIActivityViewController` with share code + URL
- Import shared template by tapping link or entering code manually — both mechanisms required
- Template preview before import — show name, exercise count, group structure before committing
- Shared templates exclude personal weight data — structure-only export (exercises, target sets/reps/RPE); no actual logged weights
- All text renders in Alpino consistently — mixed fonts = broken design; must be 100% or 0%
- SyncService pull errors surfaced, not swallowed — 40+ silent `try?` calls are a data integrity risk

**Should have (competitive differentiators):**
- Multi-format LLM import in a single flow (text + image + PDF) — no competitor does this from arbitrary sources
- Automatic exercise matching to existing PR history — continuity for strength tracking
- Coach-to-athlete template push via existing CoachAthleteRelationship — more direct than generic link sharing
- Shareable link with web fallback page (App Store CTA when app not installed) — acquisition driver

**Defer to v1.4:**
- Batch multi-week program import — too complex for v1.3; single template first
- Template folders/organization — premature
- Social feed or public template marketplace — different product direction
- On-device LLM via Core ML or Apple Foundation Models — quality insufficient for structured extraction at available model sizes on iOS 17+

### Architecture Approach

Three features slot into the existing layer stack without requiring any SwiftData model changes. LLM import adds `LLMImportService` (a stateless `@MainActor struct` following the existing engine pattern) plus a Supabase Edge Function. Template sharing adds `TemplateSharingService` plus two views and a new Supabase table. Font migration and border fixes are purely in `FontTokens.swift`, `Info.plist`, and view files — zero logic changes. Sync hardening modifies `SyncService.swift` only, upgrading bare `try?` calls to `do/catch` with per-entity sync tracking.

The existing `decodeGroups(from:)` in SyncService is directly reusable for LLM response decoding. The existing `deepCopyGroups()` on `WorkoutTemplate` is the correct import path for shared templates (new UUIDs, owner set to current user). The preview-then-save pattern already exists in `TextTemplateImportSheet` — mirror it in `LLMImportSheet`.

**Conflict resolution:** STACK.md proposes 90-day share link expiry and 6-char share code. ARCHITECTURE.md proposes 30-day expiry and 8-char code. Resolution: use **30-day expiry** (limits unbounded table growth) and **8-char alphanumeric code** (lower collision probability). Both values can be tuned post-launch without schema changes.

**Major components:**

1. **`LLMImportService`** (`@MainActor struct`, Service layer) — Coordinates on-device OCR, invokes `parse-workout` Edge Function, decodes response to `[ParsedTemplateDTO]`, hands off to TemplateRepository
2. **`parse-workout` Edge Function** (Deno/TypeScript, Supabase) — Validates Supabase JWT, verifies Pro subscription, calls OpenAI with JSON Schema mode, returns normalized template JSON
3. **`TemplateSharingService`** (`@MainActor struct`, Service layer) — Generates share codes, snapshots template JSON to `shared_templates` table, resolves codes on import
4. **`LLMImportSheet`** (View) — Multi-step UI: source picker (text/photo/PDF) → OCR progress → LLM parse → editable preview → save
5. **`ShareTemplateSheet` + `ImportSharedTemplateSheet`** (Views) — Share code display/copy and code entry/preview/import
6. **`shared_templates` table** (Supabase) — Stores template JSON snapshots with RLS (authenticated read by code, owner-only insert/delete), 30-day expiry, pg_cron cleanup job

### Critical Pitfalls

1. **Foundation Models is iOS 26+, app targets iOS 17** — Use cloud LLM API (gpt-4o-mini) as the sole path for v1.3. Design `LLMImportService` against a protocol so a Foundation Models implementation can be added later without rewriting the UI.

2. **LLM hallucination creates garbage templates** — Mitigate with: constrained JSON Schema (enums for exerciseCategory and muscleGroup matching existing app enums exactly), sanity bounds (reject weight > 500kg, reps > 100, sets > 20, RPE > 10), fuzzy exercise name matching against the exercise catalog, and mandatory editable preview before save. Never auto-save LLM output.

3. **LLM API key exposure in iOS binary** — All LLM calls must route through the Supabase Edge Function. The iOS app never holds an OpenAI key. Gate LLM import behind Pro subscription to add a financial barrier to abuse and make API costs sustainable.

4. **`try?` hardening that masks the real sync architecture problem** — Simply adding `catch { log(error) }` is insufficient. `pullAll()` currently marks `lastSyncedAt` as complete even when individual entity pulls fail. Fix requires per-entity sync timestamps and a `SyncResult` return value. Do not update any entity's `lastSyncedAt` if its pull threw an error.

5. **Cascade delete removes shared template data** — Sharing must snapshot the template JSON at share time (not reference the live template). Import must create a fully independent `WorkoutTemplate` (new UUID, current user as owner) via `deepCopyGroups()`. No foreign key to the original template.

6. **Font PostScript name mismatch causes silent system font fallback** — Verify Alpino's PostScript name with Font Book on macOS before writing any `Font.custom()` calls. Update the UIFont DEBUG assertion in `WorkloadApp.swift` for Alpino. Test on a physical device (simulator is case-insensitive; device is not).

7. **`.textFieldStyle(.roundedBorder)` missed in rounded corner fix** — Grepping for `RoundedRectangle` and `cornerRadius` will miss the ~25 instances of `.roundedBorder` across 6 files. Create a custom `TextFieldStyle` conformance with `Rectangle` background and replace all instances. Grep for `.roundedBorder` specifically.

## Implications for Roadmap

Based on combined research, suggested phase structure:

### Phase 1: Design Polish (Font Migration + Border Fix)
**Rationale:** Zero dependencies on other phases. Purely mechanical changes. Establishes the correct design baseline before any new UI is built — mistakes here are cheap; mistakes in font handling cascade into every new view added later.
**Delivers:** App-wide Alpino typography, zero rounded corners in all views and text fields, updated DESIGN.md spec
**Addresses:** Alpino font migration (table stakes), rounded border fix (tech debt), `.roundedBorder` TextFieldStyle cleanup
**Avoids:** Pitfall 5 (font layout breakage from x-height difference), Pitfall 10 (`.roundedBorder` missed in search), Pitfall 11 (PostScript name mismatch causing silent system font fallback)
**Note:** Font swap and border fix ship together as one atomic commit. Visual QA pass on every screen is mandatory before closing this phase.

### Phase 2: Sync Hardening
**Rationale:** Template sharing (Phase 3) adds new sync surface area. Building sharing on a foundation with 40+ silent error swallows creates debugging nightmares. Fixing sync first makes template sharing testable and trustworthy. This is also the lowest-risk change — no user-visible behavior changes, only surfacing errors that were previously hidden.
**Delivers:** Per-entity sync timestamps, `SyncResult` return type from `pullAll()`, structured error logging in all pull methods, `lastSyncedAt` only updated for entities that actually synced
**Addresses:** SyncService hardening (table stakes)
**Avoids:** Pitfall 4 (partial sync treated as complete sync), Pitfall 13 (import race condition compounded by silent sync failures)
**Note:** Verify via console logging and a debug sync-status view. No App Store submission needed to validate.

### Phase 3: Template Sharing
**Rationale:** Lower complexity than LLM import, high value for coach-athlete workflows. Builds on existing template infrastructure and hardened sync from Phase 2. Establishes the Supabase deployment pipeline and any universal link infrastructure that LLM import can reuse. Lower-risk way to exercise the new backend infrastructure before adding LLM complexity.
**Delivers:** `shared_templates` Supabase table and RLS policies, migration SQL, `TemplateSharingService`, `ShareTemplateSheet`, `ImportSharedTemplateSheet`, `onOpenURL` handler in AppRouter, 8-char share codes with 30-day expiry
**Addresses:** Template sharing (all table stakes), template preview before import, privacy-safe export (structure only, no personal weights)
**Avoids:** Pitfall 3 (private data leakage in share payload), Pitfall 7 (deep links failing without app installed), Pitfall 8 (cascade delete on shared template data), Pitfall 13 (sync race on immediate post-import push)
**Note:** Implement share codes before universal links. Universal links require AASA file on `tutrice.app` — one-time setup, must be verified before App Store submission if desired.

### Phase 4: LLM Workout Import
**Rationale:** Highest complexity and highest differentiation. Requires Edge Function infrastructure (established in Phase 3), stable sync (Phase 2), and correct design baseline (Phase 1). Riskiest feature — LLM quality, cost management, and multi-format OCR all need testing time. Shipping last ensures all other infrastructure is stable and any delays do not block the rest of the release.
**Delivers:** `parse-workout` Supabase Edge Function (Deno), `LLMImportService`, `LLMImportSheet` (text/photo/PDF tabs), Vision OCR + PDFKit pipeline, exercise fuzzy matching, editable review-before-save UI, Pro subscription gate, per-user rate limiting in Edge Function
**Addresses:** Text import, PDF import, image/screenshot import, review-before-save, exercise normalization, unit detection, error states (all table stakes)
**Avoids:** Pitfall 1 (Foundation Models iOS version requirement), Pitfall 2 (LLM hallucination), Pitfall 6 (OCR pipeline missing for images/PDFs), Pitfall 9 (API key in binary), Pitfall 12 (cost scaling without rate limits)
**Note:** Build the review UI and Edge Function proxy first. Then add OCR pipeline (Vision + PDFKit). LLM parsing is the final piece. Pro gate must ship with the feature — do not launch unrestricted.

### Phase Ordering Rationale

- **Design before features:** Every new view built after Phase 1 automatically uses the correct font and border style. Retrofitting after would require revisiting every new screen.
- **Sync before sharing:** Template sharing involves new sync paths (push immediately after import, new entity type). Hardened per-entity sync makes this reliable and debuggable.
- **Sharing before LLM:** Template sharing establishes the Supabase Edge Function deployment pipeline and exercises the template serialization/deserialization code that LLM import reuses. Lower risk to validate backend infrastructure without LLM complexity first.
- **LLM import last:** It has the most unknowns (LLM output quality, OCR accuracy on real-world content, cost management). All other infrastructure should be stable before adding this surface area.

### Research Flags

**Needs deeper research during planning:**
- **Phase 3 (Template Sharing):** Universal Links / AASA file setup on `tutrice.app` domain needs verification — confirm the domain can serve AASA with `Content-Type: application/json` and no redirects. Use Apple's AASA validator tool. Share codes are the safe fallback if universal links prove complex.
- **Phase 4 (LLM Import):** OCR accuracy on real-world gym content (handwritten whiteboards, low-contrast PDFs) needs empirical testing before committing to scope. Vision handles printed text well but handwriting is unreliable — scope the v1.3 feature as "printed text and digital PDFs only" and set user expectations accordingly.
- **Phase 4 (LLM Import):** Rate limiting implementation in the Edge Function needs design — per-user counters, storage mechanism (Supabase table with daily reset vs KV), and specific limits per Pro vs free tier need specification before building.
- **Phase 4 (LLM Import):** Structured output schema (JSON Schema for OpenAI) needs iterative prompt testing with real workout PDFs and screenshots before the schema is finalized. This cannot be designed in the abstract.

**Standard patterns (can skip research-phase):**
- **Phase 1 (Design Polish):** Font swap and `Rectangle()` replacement are fully mechanical. Patterns are well-established. No research needed.
- **Phase 2 (Sync Hardening):** Internal Swift refactor of existing code. Do/catch patterns and per-entity timestamp tracking are standard. No research needed.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All technologies verified: Supabase Edge Functions in existing SDK, Apple Vision and PDFKit are first-party iOS 17+ frameworks, gpt-4o-mini pricing and JSON Schema mode confirmed in OpenAI docs. No new iOS SPM packages required. |
| Features | HIGH | Competitive analysis (Hevy, Strong) confirms table stakes. Feature scope is well-bounded by existing REQUIREMENTS.md. Deferred items are clearly justified. |
| Architecture | HIGH | Edge Function proxy is the standard mobile-LLM pattern. Template sharing via share codes and JSON snapshots is simple database work. Integration into existing layer stack requires no model changes. |
| Pitfalls | HIGH | Critical pitfalls are grounded in direct codebase analysis (40+ `try?` instances in SyncService, ~25 `.roundedBorder` instances across 6 files, hardcoded font string in TextTemplateImportSheet line 42 all confirmed). LLM pitfalls are well-documented from external sources and practitioner experience. |

**Overall confidence:** HIGH

### Gaps to Address

- **Alpino PostScript name:** Cannot be confirmed without downloading the font files. Must verify with Font Book before writing `Font.custom()` strings. The UIFont DEBUG assertion in `WorkloadApp.swift` will catch wrong names at launch in DEBUG builds.
- **AASA file hosting for universal links:** `tutrice.app` domain must be configured to serve the apple-app-site-association file correctly. Verify before committing to universal links as the primary share mechanism. Share codes are the always-works fallback.
- **OCR accuracy on handwritten content:** Research indicates Vision handles printed text well but handwriting is unreliable. Scope Phase 4 with an explicit "printed/typed text only" caveat in the UI for v1.3. Do not promise handwriting support.
- **Share code collision probability:** 8-char alphanumeric codes provide ~2.8 trillion combinations, making collision negligible. The Supabase `UNIQUE` constraint provides enforcement. No action needed.
- **Share link expiry duration:** 30-day expiry is the recommendation. This is a product decision and can be adjusted post-launch via an Edge Function config change without schema migration.

## Sources

### Primary (HIGH confidence)
- [Supabase Edge Functions Swift invocation](https://supabase.com/docs/reference/swift/functions-invoke) — `client.functions.invoke()` usage pattern
- [Supabase Edge Functions overview](https://supabase.com/docs/guides/functions) — Edge Function secrets management, Deno runtime
- [Apple VNRecognizeTextRequest](https://developer.apple.com/documentation/vision/vnrecognizetextrequest) — on-device OCR API, iOS 17+ compatibility
- [Apple PDFKit](https://developer.apple.com/documentation/pdfkit) — `PDFDocument.page(at:).string` text extraction
- [SwiftUI fileImporter](https://developer.apple.com/documentation/swiftui/view/fileimporter(ispresented:allowedcontenttypes:allowsmultipleselection:oncompletion:)) — native file picker
- [OpenAI API pricing](https://openai.com/api/pricing/) — gpt-4o-mini cost verification
- [OpenAI Structured Outputs](https://platform.openai.com/docs/guides/structured-outputs) — JSON Schema mode reliability
- [Apple Foundation Models](https://developer.apple.com/documentation/FoundationModels) — iOS 26+ minimum confirmed
- [FontShare ITF Free Font License](https://www.fontshare.com/licenses/itf-ffl) — commercial use and app embedding confirmed
- [Apple custom fonts guide](https://developer.apple.com/documentation/uikit/adding-a-custom-font-to-your-app) — Info.plist UIAppFonts registration pattern
- Codebase analysis: SyncService.swift (40+ `try?`), FontTokens.swift, WorkoutTemplate.swift, TextTemplateImportSheet.swift line 42, TemplateEditorSheet.swift — direct code review (HIGH confidence)

### Secondary (MEDIUM confidence)
- [FontShare Alpino](https://www.fontshare.com/fonts/alpino) — weight availability (JavaScript required to browse; verified via befonts.com mirror)
- [Universal Links on iOS](https://www.avanderlee.com/swiftui/universal-links-ios/) — AASA file setup and in-app deep link routing
- [Apple: Allowing apps and websites to link to your content](https://developer.apple.com/documentation/xcode/allowing-apps-and-websites-to-link-to-your-content/) — universal links official guide
- [Foundation Models capabilities](https://www.natashatherobot.com/p/apple-foundation-models) — 4K context window, no image input confirmed
- [SwiftUI custom font pitfalls](https://blog.eidinger.info/what-can-go-wrong-when-using-custom-fonts-in-swiftui) — PostScript name mismatch, simulator vs device behavior
- [Hevy routine sharing](https://www.hevyapp.com/features/share-folders-routines/) — exercises shared without personal weights; validates privacy model
- [Strong template sharing](https://help.strongapp.io/article/109-share-workout-or-template) — requires app installed; validates need for share code fallback

### Tertiary (LOW confidence)
- [LLM Fitness App Lessons](https://dev.to/justinschroeder/building-bodcoach-llm-lessons-learned-the-hard-way-59kf) — practitioner experience with LLM hallucination in fitness context (single source, but findings align with general LLM behavior)

---
*Research completed: 2026-05-10*
*Ready for roadmap: yes*
