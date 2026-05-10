# Domain Pitfalls: v1.3 LLM Import, Sharing & Polish

**Domain:** Adding LLM-powered import, template sharing, font migration, and sync hardening to existing iOS fitness app
**Researched:** 2026-05-10
**Confidence:** HIGH (based on codebase analysis + verified external sources)

---

## Critical Pitfalls

Mistakes that cause rewrites, data loss, or App Store rejection.

### Pitfall 1: Foundation Models Requires iOS 26 -- Your App Targets iOS 17

**What goes wrong:** Apple's Foundation Models framework (on-device LLM with `@Generable` structured output) is iOS 26+ only. The app currently deploys to iOS 17+. Using Foundation Models means either raising the deployment target (losing users) or maintaining two code paths.

**Why it happens:** Developers see the Foundation Models WWDC sessions and assume they can use it. The framework does not exist on iOS 17-25.

**Consequences:** Either you ship an LLM feature that only works on iOS 26+ (most users on older iOS get nothing), or you rely on a cloud LLM API for all users and the on-device path becomes a future optimization.

**Prevention:**
- Use a cloud LLM API (OpenAI, Claude, etc.) as the primary path for v1.3. Every user gets the feature regardless of iOS version.
- Design the import engine as a protocol (`WorkoutImportEngine`) with a cloud implementation now. Add a Foundation Models implementation later when iOS 26 adoption is high enough.
- If you want zero cloud dependency, consider shipping a smaller on-device model via Core ML, but this is significantly more work and the model quality for structured extraction will be worse.

**Detection:** Check deployment target in Xcode. If it says iOS 17, Foundation Models is not available.

**Phase:** LLM Import phase must decide cloud vs on-device on day one. This is an architectural decision, not a detail.

### Pitfall 2: LLM Output Hallucination Creates Garbage Templates

**What goes wrong:** The LLM invents exercises that do not exist in your exercise catalog, hallucinates rep/set schemes (e.g., "10x100 deadlifts at 500kg"), or misinterprets rest periods as sets. The imported template looks plausible but contains nonsense data that flows into workload calculations.

**Why it happens:** LLMs are probabilistic text generators. Workout PDFs have wildly inconsistent formats (coach shorthand, abbreviations like "3x8@75%", supersets denoted with "+", "AMRAP", "EMOM"). The LLM guesses when uncertain rather than admitting confusion.

**Consequences:** Bad data enters the WorkoutTemplate model, which then flows into WorkoutPipeline, WorkloadCalculator, and ProgressionEngine. A template with 10x100 deadlifts at 500kg produces absurd TSS values and breaks ACWR calculations. Users lose trust in the app.

**Prevention:**
- **Constrained output schema:** Define a strict JSON schema for the LLM response. Use enums for `exerciseCategory` and `muscleGroup` that match your existing `ExerciseCategory` and `MuscleGroup` enums exactly. Do not let the LLM free-text these fields.
- **Exercise name fuzzy matching:** After LLM extraction, run exercise names through a fuzzy matcher against your existing exercise catalog (CustomExercise + built-in exercises). Surface unmatched names for user confirmation rather than silently creating new exercises.
- **Sanity bounds:** Reject or flag any set with weight > 500kg, reps > 100, sets > 20, or RPE > 10. These are physical impossibilities.
- **Human-in-the-loop review:** Always show the parsed template to the user for confirmation before saving. Never auto-save an LLM-generated template.

**Detection:** Unit test the import engine with 20+ real-world workout PDFs/screenshots in various formats. Track the "user edited after import" rate -- if users always edit, the parsing is bad.

**Phase:** LLM Import phase. Build the review UI before the parsing engine.

### Pitfall 3: Template Sharing Exposes Private Data via Deep Links

**What goes wrong:** The shared template link/code contains or reveals data it should not: the sharer's athlete ID, their actual weights/reps (from `lastUsedAt` / usage history), or internal UUIDs that could be used to enumerate users.

**Why it happens:** Developers serialize the full `WorkoutTemplate` model (including `coachId`, `athleteId`, `usageCount`, `lastUsedAt`, `scheduledDays`) into the share payload. Or they use the template's real UUID in the share URL, which is also the Supabase row ID.

**Consequences:** Privacy violation. If template shares include actual weights, a coach sharing a template reveals their athlete's training data. If UUIDs are predictable or enumerable, an attacker can fetch other users' templates.

**Prevention:**
- Generate a separate `shareCode` (short alphanumeric, 8-12 chars) that maps to the template in Supabase. Never expose the template's `id` (UUID) in the share URL.
- When exporting for sharing, strip all personal fields: `coachId`, `athleteId`, `lastUsedAt`, `usageCount`, `scheduledDays`, and any set-level actual values. Share only the template structure (name, sport type, groups, exercises, target sets/reps/weight).
- Supabase RLS policy on the share table: anyone can read a shared template by its share code, but only the owner can create/delete shares.
- Rate-limit share code lookups to prevent enumeration.

**Detection:** Review the share payload JSON before shipping. Search for any field containing "Id", "athlete", "coach", "usage", or "actual".

**Phase:** Template Sharing phase. Design the share schema before building the UI.

### Pitfall 4: SyncService `try?` Hardening Masks the Real Problem

**What goes wrong:** You replace `try?` with `do { try } catch { log(error) }` and call it done. But the real issue is that a single pull function failure (e.g., `pullWorkoutTemplates` throws) silently corrupts the sync state. The `lastSyncedAt` timestamp still updates even though templates were not pulled, so the next sync skips them.

**Why it happens:** The current `pullAll()` method calls 10+ pull functions sequentially and sets `lastSyncedAt` at the end regardless of individual failures. Replacing `try?` with logged errors does not fix the architectural issue: partial sync completion is treated as full sync completion.

**Consequences:** Data goes missing on one device but not another. Users see stale templates or missing workout sessions. The bug is intermittent and hard to reproduce because it depends on which specific pull function failed.

**Prevention:**
- **Track per-entity sync status:** Instead of one `lastSyncedAt`, track `lastSyncedAt` per entity type (workouts, templates, snapshots, etc.). Only update the timestamp for entities that actually synced successfully.
- **Return a sync result:** Change `pullAll()` to return a `SyncResult` struct listing which entities succeeded and which failed, with error details. The caller (AppRouter / MainTabView) can then decide whether to retry or show a subtle indicator.
- **Do not update `lastSyncedAt` on partial failure:** If any pull function throws, the overall sync should be marked incomplete.
- **Add exponential backoff for failed entities:** If templates fail to pull, retry them sooner than the full 15-minute sync interval.

**Detection:** Add a debug view (or console log) showing per-entity sync timestamps. If any entity's timestamp is significantly older than others, there is a silent failure.

**Phase:** Sync Hardening phase. This is the core of the fix, not just adding `catch` blocks.

---

## Moderate Pitfalls

### Pitfall 5: Font Migration Breaks Layout Without Visible Errors

**What goes wrong:** Alpino has a different x-height, letter spacing, and line height than DM Sans. After swapping the font name in `FontTokens.swift`, text overflows containers, truncates in buttons, or creates awkward spacing. The app looks "off" but nothing crashes.

**Why it happens:** Alpino is described as having a "small x-height optimized for magazine design." DM Sans has a larger x-height typical of UI fonts. Same point size renders differently -- Alpino text will appear smaller and may need size adjustments. Additionally, Alpino has "slightly rounded corners" on strokes which may clash with the 0pt border radius design system if the rounding is visible at body text sizes.

**Prevention:**
- **Do not just swap the font name.** Compare DM Sans and Alpino at every size in the type scale (12, 15, 17, 19, 32, 64pt) side by side. Adjust sizes if needed to maintain visual hierarchy.
- **Test both Regular and Medium weights.** Alpino has both, but the Medium weight may be heavier or lighter than DM Sans Medium. Verify the weight mapping is correct.
- **Check Info.plist font registration.** Remove DM Sans entries, add Alpino entries. The font file names must match exactly (case-sensitive on device, case-insensitive on simulator -- this causes "works on simulator, breaks on device" bugs).
- **Verify font files are in Copy Bundle Resources.** Missing from build phases = silent fallback to system font. The existing `WorkloadApp.swift` has UIFont assertions for DM Sans -- update these for Alpino.
- **Test Dynamic Type interaction.** Custom fonts with fixed sizes do not respond to Dynamic Type by default. This is already the case with DM Sans, but verify Alpino does not introduce new accessibility issues.

**Detection:** The existing UIFont assertion in `WorkloadApp.swift` will crash in DEBUG if the font name is wrong. Keep this assertion and update it for Alpino font names.

**Phase:** Font Migration phase. Do this in a single atomic commit and visually QA every screen.

### Pitfall 6: LLM Import Needs OCR Pipeline for Images/PDFs, Not Just Text

**What goes wrong:** The LLM import feature is built to accept text input only. Users expect to photograph a whiteboard workout or import a PDF from their coach. Text-only import misses the primary use case.

**Why it happens:** Developers build the LLM parsing engine first (text in, template out) and defer image handling. But the hardest part is not the LLM parsing -- it is extracting text from messy real-world images (handwritten whiteboards, low-contrast PDFs, screenshots of Instagram stories).

**Consequences:** The feature launches but users cannot actually use it for their most common scenario (photographing a gym whiteboard or importing a coach's PDF).

**Prevention:**
- **Use Vision framework's VNRecognizeTextRequest** for OCR. It handles printed text well on iOS 17+ with `.accurate` recognition level. Handwritten text support is weaker -- set expectations accordingly.
- **Build the pipeline as: Image/PDF -> Vision OCR -> cleaned text -> LLM parsing -> review UI.** Each step is independently testable.
- **For PDFs:** Use PDFKit to extract text first (much faster and more accurate than OCR for digital PDFs). Fall back to Vision OCR only for scanned/image-based PDFs.
- **Support three input modes:** (1) camera capture, (2) photo library pick, (3) paste/type text. All three funnel into the same LLM parsing engine.

**Detection:** Test with 10 real photos of gym whiteboards, 5 coach PDFs, and 5 screenshots. If OCR accuracy is below 80%, the feature is not ready.

**Phase:** LLM Import phase. Build OCR pipeline before LLM parsing.

### Pitfall 7: Template Share Deep Links Break When App Not Installed

**What goes wrong:** You implement custom URL scheme (`faros://template/ABC123`) for sharing. User receives link, taps it, iOS says "no app can handle this" or silently does nothing. Even with Universal Links, the AASA (Apple App Site Association) file must be configured correctly on your domain.

**Why it happens:** Custom URL schemes do not work when the app is not installed. Universal Links require server-side configuration (AASA file on your domain) that is easy to misconfigure.

**Consequences:** Shared templates only work if the recipient already has the app installed. The sharing feature fails at its primary goal of acquisition/virality.

**Prevention:**
- **Use a simple share code** (e.g., "PUSH-PULL-42") that users can manually enter in-app, alongside any deep link approach. This always works regardless of app installation.
- **If using Universal Links:** Host the AASA file at `https://yourdomain.com/.well-known/apple-app-site-association`. Test with Apple's AASA validator. The file must be served with `Content-Type: application/json` and no redirects.
- **Fallback web page:** If the user does not have the app, the Universal Link should load a web page showing the template and a download CTA. This requires a minimal web page on your domain.
- **Do not use `UIApplication.open()` with your own Universal Links** inside the app -- iOS opens them in Safari instead of routing internally. Use in-app navigation directly.

**Detection:** Test the full flow on a device without the app installed. Test with iMessage, WhatsApp, email, and Notes -- each app handles links differently.

**Phase:** Template Sharing phase. Decide on share mechanism (code vs deep link vs both) before building.

### Pitfall 8: SwiftData Cascade Deletes on Shared Templates

**What goes wrong:** When a user who shared a template deletes it locally, the cascade delete removes ExerciseGroups, TemplateExercises, and TemplateSets. If the sharing mechanism stores references to the original template (rather than copies), recipients lose access.

**Why it happens:** The existing `WorkoutTemplate` model uses `@Relationship(deleteRule: .cascade)` for groups. If sharing works by reference (pointing to the original template row in Supabase), deletion propagates.

**Consequences:** User A shares a template, User B imports it, User A deletes it, User B's imported template disappears on next sync.

**Prevention:**
- **Sharing must create a full deep copy.** When User B imports a shared template, create a completely independent `WorkoutTemplate` with new UUIDs, owned by User B. No foreign key relationship to the original.
- **The `deepCopyGroups()` method already exists** on `WorkoutTemplate` -- use it. But also generate new UUIDs for the copied template itself (not just groups).
- **Supabase sharing table** should store a snapshot of the template data at share time, not a reference to the live template. If the sharer updates their template later, existing shares are unaffected.

**Detection:** Test: User A shares template, User A deletes template, User B tries to import via share code. Should succeed with the snapshot from share time.

**Phase:** Template Sharing phase. Deep copy is the only safe approach.

### Pitfall 9: LLM API Key Exposure in iOS Binary

**What goes wrong:** The OpenAI/Claude API key is hardcoded in the app binary or stored in a plist. Anyone can extract it by decompiling the IPA.

**Why it happens:** Developers treat LLM API keys like Supabase anon keys (which are designed to be public). LLM API keys are secret -- they have direct cost implications (attacker racks up your bill).

**Consequences:** Financial loss from unauthorized API usage. API key revocation disrupts the feature for all users.

**Prevention:**
- **Proxy through Supabase Edge Functions.** The iOS app calls your Supabase function, which calls the LLM API with the key stored server-side. The app never sees the LLM API key.
- **Rate limit per user** at the proxy level. One import per minute, 20 per day. This limits damage from abuse.
- **Gate behind Pro subscription.** Only paying users can use LLM import. This adds a financial barrier to abuse and makes the cost sustainable.
- **Follow the RevenueCatConfig pattern:** if any API key must be in the app, use a gitignored config file. But prefer server-side keys entirely.

**Detection:** Search the IPA/binary for API key patterns (`sk-`, `Bearer`). Use `strings` command on the compiled binary.

**Phase:** LLM Import phase. Set up the proxy before building the import UI.

---

## Minor Pitfalls

### Pitfall 10: `.textFieldStyle(.roundedBorder)` is a System Style, Not Custom

**What goes wrong:** Developers grep for `RoundedRectangle` and `cornerRadius` but miss `.textFieldStyle(.roundedBorder)` which is a built-in SwiftUI style that renders rounded corners. The design system mandates 0pt corners everywhere.

**Why it happens:** `.roundedBorder` is a SwiftUI enum case, not a custom modifier. It is easy to miss in a search for "rounded" because it does not contain "Rectangle" or "cornerRadius".

**Consequences:** Text fields across the app (there are 25+ instances in ActiveWorkoutSheet, TemplateEditorSheet, ExercisePickerView, etc.) retain rounded corners even after the "border fix" phase.

**Prevention:**
- Create a custom `TextFieldStyle` conformance with 0pt corners (using `Rectangle` background) and replace all `.textFieldStyle(.roundedBorder)` instances.
- Search for `.roundedBorder` specifically (already identified: ~25 instances across 6 files).
- Apply the custom style via a ViewModifier or extension so future text fields automatically get the correct style.

**Detection:** Visual QA pass on every screen with text input fields. Grep for `.roundedBorder` -- count should be zero after the fix.

**Phase:** Design Fix phase. Simple find-and-replace but needs the custom style defined first.

### Pitfall 11: Font File Name vs PostScript Name Mismatch

**What goes wrong:** The font file is named `Alpino-Regular.otf` but `Font.custom()` requires the PostScript name (which might be `Alpino-Regular`, `AlpinoRegular`, or `Alpino Regular`). Using the wrong name causes silent fallback to system font.

**Why it happens:** SwiftUI's `Font.custom()` takes the font's PostScript name, not the filename. These often differ. DM Sans files are `DMSans-Regular.ttf` and the PostScript name is `DMSans-Regular` -- they happen to match. Alpino may not.

**Consequences:** App renders in San Francisco (system font) instead of Alpino. Looks completely wrong but does not crash. Easy to miss on simulator if the fallback font looks similar at a glance.

**Prevention:**
- After adding font files to the project, use Font Book (macOS) or run `fc-scan Alpino-Regular.otf | grep postscript` to find the exact PostScript name.
- Update the UIFont assertion in `WorkloadApp.swift` to validate the new font names at launch in DEBUG builds.
- Test on a physical device, not just simulator. Simulator is case-insensitive for font names; device is not.

**Detection:** The existing UIFont assertion will catch this in DEBUG. Make sure it runs before any views render.

**Phase:** Font Migration phase.

### Pitfall 12: LLM Import Cost Scaling Without Rate Limiting

**What goes wrong:** Users import the same PDF repeatedly (because the first result was not perfect and they retry), or they use the import feature to parse large multi-page training programs. Each call costs money.

**Why it happens:** No rate limiting, no caching of results, no awareness of input size. A 10-page PDF sent to GPT-4o costs 10-50x more than a single workout description.

**Consequences:** LLM API costs spiral. If the feature is free-tier, a small number of power users can generate disproportionate costs.

**Prevention:**
- **Cache parsed results** by input hash. If the same image/text is submitted twice, return the cached result.
- **Limit input size:** Max 2 pages for PDF, max 2000 characters for text, max 1 image at a time.
- **Show cost awareness:** "You have 5 imports remaining this week" (for free tier) or unlimited for Pro.
- **Use the cheapest model that works.** GPT-4o-mini or Claude Haiku for structured extraction is usually sufficient and 10-20x cheaper than full models.

**Detection:** Monitor API costs per user in the Supabase Edge Function. Alert if any user exceeds $1/day.

**Phase:** LLM Import phase. Rate limiting must ship with the feature, not after.

### Pitfall 13: Template Sharing Sync Race Condition

**What goes wrong:** User B imports a shared template while User B's device is mid-sync. The imported template is saved locally but then overwritten or duplicated by the next pull cycle because the sync sees it as a "new" remote record.

**Why it happens:** The current sync uses last-write-wins on `updatedAt`. A newly imported template has `updatedAt = now`. If the pull happens immediately after and finds no matching record on Supabase (because push has not happened yet), it does not conflict. But if the push happens first and then a pull follows, the pull may create a duplicate if the deduplication logic does not account for the import source.

**Consequences:** Duplicate templates appear in the user's list. Or worse, the locally-imported template is overwritten with stale data from Supabase.

**Prevention:**
- When importing a shared template, immediately push it to Supabase before the next pull cycle. Use `pushWorkoutTemplates()` after the import save.
- Ensure the template's UUID is generated locally and used as the primary key in both SwiftData and Supabase. The `@Attribute(.unique) var id: UUID` pattern already handles this.
- Add an `importedFromShareCode` field on the template so sync logic can distinguish imported templates from synced ones.

**Detection:** Test rapid import -> sync -> pull cycle. Check for duplicates in the template list.

**Phase:** Template Sharing phase (must coordinate with Sync Hardening phase).

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| LLM Import | iOS 26 Foundation Models not available on iOS 17 | Use cloud LLM API, design for future on-device path |
| LLM Import | Hallucinated exercise names and impossible rep schemes | Constrained schema + fuzzy matching + human review |
| LLM Import | API key exposed in binary | Proxy through Supabase Edge Functions |
| LLM Import | No OCR pipeline for images/PDFs | Vision framework OCR -> text -> LLM pipeline |
| LLM Import | Cost scaling without limits | Rate limit + cache + cheapest model + Pro-gating |
| Template Sharing | Private data in share payload | Strip personal fields, use opaque share codes |
| Template Sharing | Deep links fail without app installed | Share codes that work in-app + fallback web page |
| Template Sharing | Cascade delete removes shared template | Deep copy on import, snapshot at share time |
| Template Sharing | Sync race on import | Push immediately after import, UUID-based dedup |
| Font Migration | Layout breaks from different metrics | Side-by-side comparison at every type scale size |
| Font Migration | PostScript name mismatch | Verify with Font Book, test on physical device |
| Font Migration | Font not in Copy Bundle Resources | Check Build Phases, keep UIFont assertion |
| Sync Hardening | `lastSyncedAt` updated on partial failure | Per-entity sync timestamps |
| Sync Hardening | Logging errors without fixing architecture | Return SyncResult, do not mark complete on failure |
| Design Fix | `.roundedBorder` missed in search | Grep for `.roundedBorder` specifically, create custom TextFieldStyle |

---

## Sources

- [Apple Foundation Models Framework Documentation](https://developer.apple.com/documentation/FoundationModels) -- HIGH confidence
- [Foundation Models Limitations and Capabilities](https://www.natashatherobot.com/p/apple-foundation-models) -- MEDIUM confidence (4K context window, no image input confirmed)
- [Foundation Models Code-Along Q&A](https://antongubarenko.substack.com/p/ios-26-foundation-model-framework-f6d) -- MEDIUM confidence
- [Apple Vision Framework OCR](https://developer.apple.com/documentation/vision/recognizing-text-in-images) -- HIGH confidence
- [SwiftUI Custom Font Pitfalls](https://blog.eidinger.info/what-can-go-wrong-when-using-custom-fonts-in-swiftui) -- MEDIUM confidence
- [Universal Links Implementation](https://www.avanderlee.com/swiftui/universal-links-ios/) -- MEDIUM confidence
- [SwiftData Silent Failures](https://www.mikebuss.com/posts/swiftdata-template) -- MEDIUM confidence
- [Common SwiftData Errors](https://www.hackingwithswift.com/quick-start/swiftdata/common-swiftdata-errors-and-their-solutions) -- HIGH confidence
- [Alpino Font Family](https://freefontdl.com/alpino-font-family/) -- MEDIUM confidence (6 weights: Thin, Light, Regular, Medium, Bold, Black)
- [FontShare License FAQ](https://www.fontshare.com/faq) -- HIGH confidence (free for personal and commercial use)
- [LLM Fitness App Lessons](https://dev.to/justinschroeder/building-bodcoach-llm-lessons-learned-the-hard-way-59kf) -- LOW confidence (single practitioner source)
- Codebase analysis: SyncService.swift (40+ `try?` instances), FontTokens.swift, WorkoutTemplate.swift, 25+ `.roundedBorder` instances -- HIGH confidence (direct code review)
