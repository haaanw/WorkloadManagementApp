# Phase 12: Template-Driven Workouts & Smart Suggestions - Research

**Researched:** 2026-05-10
**Domain:** SwiftUI template-driven workout flow, ghost target UX, day-of-week suggestion engine
**Confidence:** HIGH

## Summary

Phase 12 connects the template system (built in Phase 11) to the active workout flow, enabling one-tap session starts with smart pre-filling. The work divides into four domains: (1) template picker sheet replacing the direct "+" button flow, (2) ghost target display and fill mechanisms in ActiveWorkoutSheet, (3) dashboard quick-start cards, and (4) a new TemplateSuggestionEngine for day-of-week pattern learning.

All building blocks exist. `WorkoutTemplate`, `TemplateRepository`, `ProgressionEngine`, `TemplateCarouselSection`, and `ActiveWorkoutSheet` are fully implemented. The phase is pure integration and new UI -- no model migrations, no backend changes, no new dependencies. The `SetDraft` model already has `targetReps`/`targetWeightKg`/`targetRPE` fields and `isFromHistory` flag, designed for exactly this use case.

**Primary recommendation:** Build bottom-up -- TemplateSuggestionEngine (pure logic, testable) first, then ActiveWorkoutSheet ghost targets + fill buttons, then template picker sheet, then dashboard quick-start cards, then carousel suggestion labels. Each layer depends on the one before it.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** '+' button opens a template picker sheet (not ActiveWorkoutSheet directly). Picker shows carousel of templates + 'Start blank workout' option. Selecting a template opens ActiveWorkoutSheet pre-filled.
- **D-02:** Carousel cards in Workout Log tab are tap-to-start -- tapping a carousel card opens ActiveWorkoutSheet pre-filled from that template. One-tap quick-start replaces Phase 11's tap-to-preview behavior.
- **D-03:** TemplatePreviewSheet moves to long-press context menu (was tap target in Phase 11).
- **D-04:** When user has zero templates, '+' still opens picker sheet with empty state: 'Create your first template' CTA card + 'Start blank workout' button. Picker always shows.
- **D-05:** Template-loaded session shows last-used actual values as gray placeholder text (ghost) in weight/reps/etc. fields. Fields start empty but ghost shows reference value.
- **D-06:** User can accept ghost values via two mechanisms: keyboard enter/submit fills the entire set row, dedicated 'Fill all' button fills ALL rows and ALL fields at once.
- **D-07:** If user doesn't interact with ghost values (no enter, no fill button), fields remain empty -- ghost values are NOT auto-saved.
- **D-08:** ProgressionEngine suggestions appear as small text below the input fields (e.g., 'up-arrow 85kg suggested') alongside the ghost placeholder.
- **D-09:** Pro users get two fill buttons: 'Fill last' (fills last-used values) and 'Fill suggested' (fills ProgressionEngine values). Free users see only 'Fill last'.
- **D-10:** ProgressionEngine requires exercise history to generate suggestions. For exercises with no prior history, no suggestion text shown.
- **D-11:** Quick-start cards appear below HeroReadinessCard, above metrics strip. Horizontal scroll, max 3-4 compact cards.
- **D-12:** Card sources: favorited templates first, then TemplateSuggestionEngine's pick for today (Pro + sufficient data). No duplicates.
- **D-13:** Quick-start section hidden entirely when user has zero templates. Appears after first template is created.
- **D-14:** Tapping a dashboard quick-start card opens ActiveWorkoutSheet pre-filled from that template.
- **D-15:** Suggestion surfaced as highlighted card in Workout Log carousel with 'Suggested' label. Auto-centered in carousel. No separate banner or modal.
- **D-16:** Insufficient data fallback (< 2 weeks or no clear pattern): silent fallback to Phase 11 centering logic.
- **D-17:** Engine uses two signals: day-of-week usage frequency (primary) AND current recovery zone (secondary). Recovery-aware: if user is in red/yellow zone, engine suggests lighter template.
- **D-18:** Recovery conflict resolution: when recovery zone conflicts with usual template, suggest lighter alternative with 'Recovery-adjusted' note. If user has only one template, still suggest it.
- **D-19:** Pro-gated. Free users see carousel centering via scheduledDays/lastUsedAt but no 'Suggested' label or recovery-aware swapping.

### Claude's Discretion
- Template picker sheet layout and visual design (card sizing, spacing)
- 'Fill last' / 'Fill suggested' button placement and styling in ActiveWorkoutSheet
- Ghost placeholder text color/opacity
- How ProgressionEngine suggestion text is styled below fields
- Dashboard quick-start card visual design (compact horizontal cards)
- 'Suggested' and 'Recovery-adjusted' label styling on carousel cards
- How to determine "lighter" template (exercise count, historical TSS, sport type heuristic)
- Animation/transition when pre-filling ActiveWorkoutSheet from template

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| TMPL-03 | User can select a saved template when starting a new session via template picker | TemplatePickerSheet new component; WorkoutLogView '+' button redirect; ActiveWorkoutSheet template init |
| TMPL-04 | Template-loaded session pre-fills exercises with last-used actual values as ghost targets | SetDraft already has target* fields; ProgressionEngine.fetchHistory() provides last-used values; ghost display in SetEntryRow |
| TMPL-06 | Dashboard and workout log tab show favorite/recent templates as quick-start cards | QuickStartSection new component in DashboardView; TemplateCarouselSection tap-to-start modification |
| TMPL-07 | ProgressionEngine overlays recovery-aware suggested targets alongside last-used values (Pro-gated) | ProgressionEngine.suggest() already complete; integration into template-loaded ActiveWorkoutSheet; FillButtonBar with dual buttons |
| TMPL-08 | TemplateSuggestionEngine suggests most likely template based on day-of-week usage patterns (Pro-gated) | New pure struct engine; day-of-week frequency from WorkoutSession dates cross-referenced with template IDs; recovery zone secondary signal |
</phase_requirements>

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Template picker sheet | View (SwiftUI) | -- | Pure UI orchestration; data from TemplateRepository |
| Ghost target display | View (SwiftUI) | -- | Placeholder text rendering in SetEntryRow fields |
| Fill mechanisms (enter/button) | View (SwiftUI) | -- | UI interaction modifying @State draft arrays |
| ProgressionEngine overlay | Engine (pure struct) | View (SwiftUI) | Engine already exists; view integration needed for display |
| Dashboard quick-start cards | View (SwiftUI) | -- | New section in DashboardView VStack |
| TemplateSuggestionEngine | Engine (pure struct) | -- | Pure computation: day-of-week frequency + recovery zone |
| Template usage tracking | View (SwiftUI) | Repository | Update lastUsedAt/usageCount on session save |
| Last-used value lookup | Repository | -- | ProgressionEngine.fetchHistory() fetches from SwiftData |

## Architecture Patterns

### System Architecture Diagram

```
User taps "+" on WorkoutLogView
        |
        v
  TemplatePickerSheet
  (shows template cards + "Start blank")
        |
        v [user selects template]
  ActiveWorkoutSheet(template: WorkoutTemplate)
        |
        v [onAppear: loadFromTemplate()]
   For each TemplateExercise:
        |
        +-- ProgressionEngine.fetchHistory(exerciseName)
        |        -> [ExerciseHistoryRecord] (last-used values for ghost)
        |
        +-- ProgressionEngine.suggest(exerciseName, context, history)  [Pro only]
        |        -> ExerciseSuggestion (progression overlay)
        |
        v
   ExerciseEntryDraft populated with:
     - sets[].targetWeightKg/targetReps/targetRPE = last-used actuals (ghost)
     - suggestionRationale + progressionType (Pro overlay)
     - sets[] fields empty (user fills or uses Fill button)
        |
        v [user finishes workout]
   FinishWorkoutSheet -> saveSession()
        |
        +-- Update source template: lastUsedAt = .now, usageCount += 1
        +-- WorkoutPipeline.processSession() (existing)
```

```
Dashboard Quick-Start Flow:
  DashboardView.onAppear
        |
        v
  TemplateRepository.fetchFavorites(athleteId)
        -> [WorkoutTemplate] (favorites)
        |
  TemplateSuggestionEngine.suggest(templates, sessions, recoveryZone)  [Pro]
        -> WorkoutTemplate? (today's suggestion)
        |
        v
  QuickStartSection (horizontal scroll, max 3-4 cards)
        |
        v [user taps card]
  ActiveWorkoutSheet(template: selectedTemplate)
```

```
TemplateSuggestionEngine Logic:
  Input: all templates, recent sessions (2+ weeks), current recoveryZone
        |
        v
  1. Build day-of-week frequency map:
     For each template, count how many sessions used it on each weekday
        |
        v
  2. Find template with highest frequency for today's weekday
        |
        v
  3. Recovery check:
     If recovery is red/yellow AND a lighter alternative exists
        -> swap to lighter template, mark "Recovery-adjusted"
     Else
        -> return the frequency winner
        |
        v
  Output: SuggestionResult { template, isRecoveryAdjusted, rationale }
```

### Recommended Project Structure

No new directories needed. All files go in existing locations:

```
WorkloadApp/
├── Services/
│   └── TemplateSuggestionEngine.swift     # NEW: pure struct, static methods
├── Views/
│   ├── Dashboard/
│   │   └── DashboardView.swift            # MODIFY: add QuickStartSection
│   └── WorkoutLog/
│       ├── ActiveWorkoutSheet.swift        # MODIFY: template init, ghost targets, fill buttons
│       ├── WorkoutLogView.swift            # MODIFY: '+' button opens picker
│       ├── TemplateCarouselSection.swift   # MODIFY: tap-to-start, suggestion badge
│       ├── TemplatePickerSheet.swift       # NEW: template selection sheet
│       └── TemplatePreviewSheet.swift      # MODIFY: long-press trigger only
```

### Pattern 1: Template-to-Draft Conversion

**What:** Convert a WorkoutTemplate's exercise groups into ExerciseEntryDraft array with ghost targets from last-used history.
**When to use:** When ActiveWorkoutSheet receives a template parameter on appear.

```swift
// [VERIFIED: ActiveWorkoutSheet.swift existing loadPrescription() pattern]
private func loadFromTemplate(_ template: WorkoutTemplate) {
    sessionName = template.templateName
    sportType = template.sportType
    sessionType = template.sessionType
    sourceTemplate = template  // track for lastUsedAt update on save

    entries = template.sortedGroups.flatMap { group in
        group.sortedExercises.map { exercise in
            var draft = ExerciseEntryDraft(
                exerciseName: exercise.exerciseName,
                exerciseCategory: exercise.exerciseCategory,
                muscleGroup: exercise.muscleGroup
            )
            draft.groupName = group.groupName

            // Fetch last-used actuals for ghost targets
            let history = ProgressionEngine.fetchHistory(
                exerciseName: exercise.exerciseName,
                modelContext: modelContext
            )

            if let lastSession = history.first {
                // Ghost targets = last-used actuals
                draft.sets = exercise.sortedSets.enumerated().map { idx, templateSet in
                    let historySet = idx < lastSession.sets.count ? lastSession.sets[idx] : nil
                    return SetDraft(
                        // Fields empty (user fills)
                        // Ghost targets from last-used actuals
                        targetReps: historySet?.reps ?? templateSet.targetReps,
                        targetWeightKg: historySet?.weightKg ?? templateSet.targetWeightKg,
                        targetRPE: historySet?.rpe ?? templateSet.targetRPE,
                        isFromHistory: historySet != nil
                    )
                }
            } else {
                // No history: ghost from template defaults
                draft.sets = exercise.sortedSets.map { set in
                    SetDraft(
                        targetReps: set.targetReps,
                        targetWeightKg: set.targetWeightKg,
                        targetRPE: set.targetRPE
                    )
                }
            }

            // Pro: compute ProgressionEngine suggestions
            if container.subscriptionService.isPro && !history.isEmpty {
                let context = buildTrainingContext()
                let suggestion = ProgressionEngine.suggest(
                    exerciseName: exercise.exerciseName,
                    category: exercise.exerciseCategory,
                    context: context,
                    recentEntries: history
                )
                draft.suggestionRationale = suggestion.rationale
                draft.progressionType = suggestion.progressionType
                draft.progressionSuggestions = suggestion.suggestedSets  // NEW field on draft
            }

            if draft.sets.isEmpty { draft.sets = [SetDraft()] }
            return draft
        }
    }
}
```

### Pattern 2: TemplateSuggestionEngine (Pure Struct)

**What:** Day-of-week frequency analysis with recovery-aware fallback.
**When to use:** On carousel load and dashboard quick-start section.

```swift
// [ASSUMED: new engine following project convention]
struct TemplateSuggestionEngine {

    struct SuggestionResult {
        let template: WorkoutTemplate
        let isRecoveryAdjusted: Bool
        let rationale: String
    }

    /// Suggest the best template for today based on usage patterns and recovery.
    /// Returns nil if insufficient data (< 2 weeks of sessions) or no clear pattern.
    static func suggest(
        templates: [WorkoutTemplate],
        recentSessions: [WorkoutSession],
        currentRecoveryZone: RecoveryZone,
        today: Date = .now
    ) -> SuggestionResult? {
        guard templates.count > 0 else { return nil }

        // Check sufficient data: need 2+ weeks of sessions
        let twoWeeksAgo = Calendar.current.date(byAdding: .weekOfYear, value: -2, to: today)!
        let relevantSessions = recentSessions.filter { $0.sessionDate >= twoWeeksAgo }
        guard relevantSessions.count >= 3 else { return nil }

        let todayWeekday = isoWeekday(from: today)

        // Build frequency map: templateName -> [weekday: count]
        // Match sessions to templates by name
        let frequencyPick = pickByFrequency(
            templates: templates,
            sessions: recentSessions,
            weekday: todayWeekday
        )

        guard let picked = frequencyPick else {
            return nil  // No clear pattern -> silent fallback to Phase 11 centering
        }

        // Recovery check (D-17, D-18)
        if currentRecoveryZone == .red || currentRecoveryZone == .yellow {
            if let lighter = findLighterAlternative(
                current: picked, all: templates, sessions: recentSessions
            ) {
                return SuggestionResult(
                    template: lighter,
                    isRecoveryAdjusted: true,
                    rationale: "Recovery-adjusted: lighter session suggested"
                )
            }
            // Only one template or no lighter alternative: suggest it anyway (D-18)
        }

        return SuggestionResult(
            template: picked,
            isRecoveryAdjusted: false,
            rationale: "Based on your \(weekdayName(todayWeekday)) training pattern"
        )
    }

    /// ISO weekday: 1=Mon...7=Sun
    static func isoWeekday(from date: Date) -> Int {
        let apple = Calendar.current.component(.weekday, from: date)
        return apple == 1 ? 7 : apple - 1
    }
}
```

### Pattern 3: Ghost Target in SetEntryRow

**What:** Show last-used value as gray placeholder text in empty fields.
**When to use:** Template-loaded sessions in ActiveWorkoutSheet.

```swift
// [VERIFIED: SetEntryRow already has targetWeightKg/targetReps/targetRPE placeholder support]
// The existing weightPlaceholder/repsPlaceholder/rpePlaceholder computed properties
// already read from set.targetWeightKg, set.targetReps, set.targetRPE.
// These display as placeholder text in TextField when the value is nil.
// D-05 requires these show as ColorTokens.text3 -- the .textFieldStyle(.roundedBorder)
// provides system placeholder color. May need custom placeholder for exact text3 color.
```

### Anti-Patterns to Avoid

- **Auto-saving ghost values:** D-07 explicitly states ghost values must NOT be auto-saved. Never assign target values to actual fields without user interaction.
- **Fetching history per-render:** ProgressionEngine.fetchHistory() does a SwiftData fetch. Call it once on template load, not on every body recomputation. Store results in @State.
- **Blocking UI with history fetch:** Template loading with 5+ exercises each doing a SwiftData fetch could cause frame drops. Consider batching or using Task for progressive loading.
- **Modifying ProgressionEngine:** The engine is complete and pure. Phase 12 integrates it -- do not modify its logic or API.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Progressive overload logic | Custom weight/rep progression | `ProgressionEngine.suggest()` | Already handles detraining, recovery zones, per-category logic [VERIFIED: ProgressionEngine.swift] |
| Exercise history lookup | Custom SwiftData queries | `ProgressionEngine.fetchHistory()` | Already fetches last 8 sessions with sorted sets [VERIFIED: ProgressionEngine.swift] |
| Template CRUD | New repository methods | `TemplateRepository` | fetchAthleteTemplates, fetchFavorites already implemented [VERIFIED: TemplateRepository.swift] |
| Carousel centering | Custom scroll logic | Existing `TemplateCarouselSection` centering | Uses ScrollView + scrollPosition + scrollTargetBehavior [VERIFIED: TemplateCarouselSection.swift] |
| Recovery context building | Manual recovery fetch | `ActiveWorkoutSheet.buildTrainingContext()` | Already fetches latest RecoverySnapshot + WorkloadSnapshot + runs AutoregulationEngine [VERIFIED: ActiveWorkoutSheet.swift] |
| ISO weekday conversion | Custom weekday math | Copy from `TemplateCarouselSection.todayISOWeekday` | Exact same Apple-to-ISO conversion needed [VERIFIED: TemplateCarouselSection.swift] |

**Key insight:** This phase is 90% integration of existing components. The only genuinely new logic is `TemplateSuggestionEngine` (day-of-week frequency + recovery swap).

## Common Pitfalls

### Pitfall 1: Ghost Values Accidentally Persisted

**What goes wrong:** If `SetDraft.targetWeightKg` is populated and the save code reads from target fields instead of value fields, empty sets get saved with ghost values the user never confirmed.
**Why it happens:** `saveSession()` currently reads `setDraft.reps`, `setDraft.weightKg` etc. (the actual fields). These are nil when user didn't fill them. But a copy-paste error could read `targetReps`/`targetWeightKg` instead.
**How to avoid:** Never modify `saveSession()` to read from target fields. Ghost targets live in `targetReps`/`targetWeightKg` only. Actual values live in `reps`/`weightKg`. The fill buttons explicitly copy target -> actual when invoked.
**Warning signs:** Sets appearing in session history with values the user never entered.

### Pitfall 2: Template Picker Breaking Prescription Flow

**What goes wrong:** WorkoutLogView currently opens `ActiveWorkoutSheet(prescription: activePrescription)` for prescribed workouts. Redirecting "+" to TemplatePickerSheet could break the prescription start flow.
**Why it happens:** The "+" button serves dual purpose: start fresh workout AND start prescribed workout (when a prescription card is tapped).
**How to avoid:** The prescription flow uses `activePrescription` state + `.sheet(isPresented: $showActiveWorkout)`. The "+" button change only affects the toolbar button -- prescription card taps set `activePrescription` and `showActiveWorkout = true`, which should remain unchanged.
**Warning signs:** Prescribed workout cards stop opening ActiveWorkoutSheet.

### Pitfall 3: N+1 History Fetches on Template Load

**What goes wrong:** Loading a template with 8 exercises triggers 8 separate SwiftData fetches (one per exercise via fetchHistory), plus 8 ProgressionEngine.suggest() calls for Pro users.
**Why it happens:** Each exercise needs its own history lookup.
**How to avoid:** This is acceptable for typical template sizes (3-8 exercises). SwiftData fetches are fast for small result sets. If performance becomes an issue, batch the fetches or use a single predicate with exercise names array. Monitor with Instruments.
**Warning signs:** Visible delay (>500ms) when opening ActiveWorkoutSheet from template.

### Pitfall 4: Carousel Tap Action Regression

**What goes wrong:** TemplateCarouselSection.onTapGesture currently opens preview for centered card. Changing to start-session could lose the preview capability.
**Why it happens:** D-02 changes tap to start-session, D-03 moves preview to long-press context menu. Must update both behaviors atomically.
**How to avoid:** Update the `onTapGesture` block to call a new `onStartFromTemplate` callback instead of `onPreviewTemplate`. Add preview to the context menu (which already exists with Edit, Duplicate, etc.). Remove the `.sheet(item: $selectedTemplateForPreview)` binding or repurpose it for long-press.
**Warning signs:** Tapping a carousel card opens preview sheet instead of starting workout.

### Pitfall 5: Fill Button Overwriting User Edits

**What goes wrong:** User manually enters weight for set 1, then taps "Fill last" which overwrites their manual entry.
**Why it happens:** "Fill all" fills ALL rows without checking if user already typed values.
**How to avoid:** Two options: (a) only fill empty fields (skip fields with user input), or (b) fill everything and accept the overwrite (simpler, user chose "fill all"). D-06 says "fills ALL rows and ALL fields" suggesting option (b) is intended. Document this behavior.
**Warning signs:** User complaints about losing manual entries after tapping Fill.

### Pitfall 6: TemplateSuggestionEngine Matching Sessions to Templates

**What goes wrong:** Sessions don't store a direct reference to the template they were started from. Matching must use name/exercise similarity, which is fragile.
**Why it happens:** `WorkoutSession` has no `sourceTemplateId` field. The template-session link is implicit.
**How to avoid:** Add a `sourceTemplateId: UUID?` field to `WorkoutSession` (or track via a separate mechanism). When a template-based session is saved, store the template ID. This enables accurate frequency counting. Alternatively, match by `sessionName == template.templateName` as a heuristic.
**Warning signs:** TemplateSuggestionEngine gives wrong suggestions because sessions can't be matched to templates.

## Code Examples

### Example 1: Template Picker Sheet

```swift
// [ASSUMED: new component following project patterns]
struct TemplatePickerSheet: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var athletes: [Athlete]

    let onSelectTemplate: (WorkoutTemplate) -> Void
    let onStartBlank: () -> Void
    let onCreateTemplate: () -> Void

    private var templates: [WorkoutTemplate] {
        guard let athleteId = athletes.first?.id else { return [] }
        return (try? TemplateRepository(modelContext: modelContext)
            .fetchAthleteTemplates(athleteId: athleteId)) ?? []
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    if templates.isEmpty {
                        // D-04: Empty state
                        emptyState
                    } else {
                        templateGrid
                    }

                    // "Start blank workout" always visible
                    Button {
                        dismiss()
                        onStartBlank()
                    } label: {
                        Text("Start blank workout")
                            .font(.Tokens.body)
                            .foregroundStyle(ColorTokens.text2)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                }
            }
            .background(ColorTokens.surfaceEl)
            .navigationTitle("Templates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text2)
                }
            }
        }
    }
}
```

### Example 2: Fill Button Bar

```swift
// [ASSUMED: new component following project patterns]
struct FillButtonBar: View {
    let isPro: Bool
    let onFillLast: () -> Void
    let onFillSuggested: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Button {
                onFillLast()
            } label: {
                Text("Fill last")
                    .font(.Tokens.bodyMedium)
                    .foregroundStyle(ColorTokens.text1)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .overlay(Rectangle().stroke(ColorTokens.divider, lineWidth: 0.5))
            }
            .buttonStyle(.plain)

            if isPro {
                Button {
                    onFillSuggested()
                } label: {
                    Text("Fill suggested")
                        .font(.Tokens.bodyMedium)
                        .foregroundStyle(ColorTokens.text1)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .overlay(Rectangle().stroke(ColorTokens.divider, lineWidth: 0.5))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ColorTokens.surface)
    }
}
```

### Example 3: Template Usage Update on Session Save

```swift
// [VERIFIED: FinishWorkoutSheet.swift + ActiveWorkoutSheet.saveSession() pattern]
// In ActiveWorkoutSheet.saveSession(), after modelContext.save():
if let source = sourceTemplate {
    source.lastUsedAt = .now
    source.usageCount += 1
    source.updatedAt = .now
    try? modelContext.save()
    if let athleteId = athlete?.id {
        Task {
            await container.syncService.pushWorkoutTemplates(
                context: modelContext, coachId: athleteId
            )
        }
    }
}
```

### Example 4: Session-Template Linkage for Frequency Counting

```swift
// [ASSUMED: recommended approach for accurate frequency counting]
// Option A: Add sourceTemplateId to WorkoutSession (additive field, safe)
// In WorkoutSession model:
var sourceTemplateId: UUID? = nil

// On save in ActiveWorkoutSheet:
session.sourceTemplateId = sourceTemplate?.id

// In TemplateSuggestionEngine:
static func buildFrequencyMap(
    templates: [WorkoutTemplate],
    sessions: [WorkoutSession]
) -> [UUID: [Int: Int]] {  // templateId -> [weekday: count]
    var map: [UUID: [Int: Int]] = [:]
    for session in sessions {
        guard let templateId = session.sourceTemplateId else { continue }
        let weekday = isoWeekday(from: session.sessionDate)
        map[templateId, default: [:]][weekday, default: 0] += 1
    }
    return map
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Direct ActiveWorkoutSheet open from "+" | TemplatePickerSheet intermediary | Phase 12 | Users choose template before starting |
| Carousel tap = preview | Carousel tap = start session | Phase 12 | One fewer tap to start workout |
| Manual exercise entry | Ghost targets + fill buttons | Phase 12 | Near-zero input for repeat workouts |
| No workout suggestions | Day-of-week + recovery-aware suggestions | Phase 12 | App learns user patterns |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | WorkoutSession needs a `sourceTemplateId` field for accurate frequency counting | Code Examples, Pitfall 6 | TemplateSuggestionEngine can't accurately match sessions to templates; falls back to name matching which is fragile |
| A2 | `Font.Tokens.bodyMedium` exists as a 17pt Medium weight token | Code Examples | May need to be defined if not already in FontTokens |
| A3 | `ColorTokens.surfaceEl` exists for elevated surface | UI-SPEC | May need to be added to ColorTokens enum |
| A4 | 3 sessions in 2 weeks is sufficient threshold for "enough data" | Architecture Pattern 2 | Threshold may be too low or too high for meaningful patterns |
| A5 | "Lighter" template determination via historical average session TSS comparison is workable | CONTEXT.md specifics | May need a simpler heuristic if TSS data is sparse |

## Open Questions

1. **sourceTemplateId on WorkoutSession**
   - What we know: Sessions don't currently track which template they originated from. TemplateSuggestionEngine needs this for frequency counting.
   - What's unclear: Whether to add a new field to WorkoutSession (requires SwiftData migration awareness) or use name-matching heuristic.
   - Recommendation: Add `sourceTemplateId: UUID? = nil` to WorkoutSession. It's an additive optional field -- SwiftData handles this gracefully with no migration needed. The accuracy gain is worth it.

2. **"Lighter template" heuristic**
   - What we know: D-17/D-18 say suggest lighter template when recovery is compromised. CONTEXT specifics suggest using historical average session TSS.
   - What's unclear: What if templates don't have enough session history to compute average TSS?
   - Recommendation: Use exercise count as primary proxy (fewer exercises = lighter), with session TSS average as secondary when available. This provides a reasonable fallback.

3. **Fill button interaction with keyboard**
   - What we know: D-06 mentions "keyboard enter/submit" filling a set row. SwiftUI TextField doesn't have a native "enter" callback on number pad keyboards.
   - What's unclear: iOS number pad has no return/enter key. The "submit" action only fires with `.onSubmit` on text keyboards.
   - Recommendation: Implement the "enter to fill row" behavior as a `.onSubmit` modifier on text fields. For number pad fields, the "Fill last" button serves as the primary fill mechanism. Consider adding a small checkmark button per row as an alternative to keyboard enter.

## Project Constraints (from CLAUDE.md)

- **0pt border radius everywhere** -- TemplatePickerSheet, QuickStartCard, FillButtonBar all use `Rectangle()`, never `RoundedRectangle`
- **No shadows** -- use hairline borders (0.5pt `ColorTokens.divider`) instead
- **Accent color only on hero readiness score** -- no accent in Phase 12 anywhere
- **DM Sans Regular + Medium only** -- all text via `Font.Tokens.*`, never `.system()`
- **8pt spacing multiples** -- 8, 16, 24, 32, 48
- **Pure struct engines with static methods** -- TemplateSuggestionEngine follows this pattern
- **@MainActor on repositories and ViewModels** -- template fetches are @MainActor
- **Pro-gating via `container.subscriptionService.isPro`** -- consistent with existing pattern
- **SwiftData additive-only changes** -- new optional fields only, no renames
- **After 3-5 file modifications, run build check** -- xcodebuild verification required

## Sources

### Primary (HIGH confidence)
- `WorkloadApp/Services/ProgressionEngine.swift` -- full API, types, fetchHistory() verified
- `WorkloadApp/Models/WorkoutTemplate.swift` -- model fields including lastUsedAt, usageCount, scheduledDays
- `WorkloadApp/Views/WorkoutLog/ActiveWorkoutSheet.swift` -- existing draft models, prefill patterns, saveSession flow
- `WorkloadApp/Views/WorkoutLog/TemplateCarouselSection.swift` -- centering logic, tap/context menu patterns
- `WorkloadApp/Views/WorkoutLog/WorkoutLogView.swift` -- current "+" button flow, sheet bindings
- `WorkloadApp/Views/Dashboard/DashboardView.swift` -- VStack layout, section ordering
- `WorkloadApp/Repositories/TemplateRepository.swift` -- fetch methods, CRUD operations
- `WorkloadApp/Views/WorkoutLog/FinishWorkoutSheet.swift` -- finish flow, template save pattern
- `WorkloadApp/Services/SubscriptionService.swift` -- isPro gating verified

### Secondary (MEDIUM confidence)
- `12-UI-SPEC.md` -- component inventory, interaction contracts, visual specs
- `12-CONTEXT.md` -- all 19 decisions, canonical references, integration points

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- no new dependencies, all existing Swift/SwiftUI/SwiftData
- Architecture: HIGH -- all integration points verified against existing code
- Pitfalls: HIGH -- identified from reading actual source code and data flow

**Research date:** 2026-05-10
**Valid until:** 2026-06-10 (stable -- no external dependency changes expected)
