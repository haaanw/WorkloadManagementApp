# Phase 11: Template Management & Creation - Research

**Researched:** 2026-05-09
**Domain:** SwiftUI CRUD views, horizontal carousel, SwiftData template management
**Confidence:** HIGH

## Summary

Phase 11 builds athlete-facing template management on top of a mature foundation: the `WorkoutTemplate`, `ExerciseGroup`, `TemplateExercise`, and `TemplateSet` models already exist with all required fields (`isAthleteOwned`, `isFavorite`, `isArchived`, `lastUsedAt`, `usageCount`, `scheduledDays`). The `TemplateRepository` already provides fetch, save, duplicate, archive, and delete operations for athlete-owned templates. The `TemplateEditorSheet` is fully functional for creating and editing templates with exercise groups and sets.

The primary engineering work is (1) building a horizontal carousel component using iOS 17+ `ScrollView` + `scrollTargetBehavior(.viewAligned)` with scale/opacity transforms via `GeometryReader`, (2) modifying the `ActiveWorkoutSheet` finish dialog to add a save-as-template toggle with quick-save behavior, (3) extending `TemplateEditorSheet` with scheduled-days and favorite-toggle fields, and (4) adding `.contextMenu` and custom swipe-to-reveal gesture actions on carousel cards.

**Primary recommendation:** Reuse all existing models, repository, and editor components. The new code is purely view-layer: a carousel component, a preview sheet, a modified finish dialog, and two new fields on the editor.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Templates live inside the Workout Log tab -- no new tab, no separate nav destination.
- **D-02:** Display as a centered carousel of template cards. Today's scheduled template is centered and enlarged; adjacent templates shown smaller. Uses `scheduledDays` weekday match.
- **D-03:** Fallback when no template scheduled today: center on most recently used template (`lastUsedAt`). Pattern-based learning deferred to Phase 12.
- **D-04:** Carousel tap action: Claude's discretion (start workout directly or show preview first).
- **D-05:** Save-as-template is a toggle/checkbox in the existing finish workout confirmation dialog. No separate entry point.
- **D-06:** Confirmation/editing step after checking the toggle: Claude's discretion.
- **D-07:** Save-as-template always creates athlete-owned template (`isAthleteOwned=true`).
- **D-08:** Reuse existing `TemplateEditorSheet` for athletes -- same groups/exercises/sets editing.
- **D-09:** Add scheduled days picker to editor: weekday toggle row (M T W T F S S) writing to `scheduledDays: [Int]` (ISO 8601, 1=Mon...7=Sun).
- **D-10:** Add favorite toggle to editor.
- **D-11:** Editor sets `isAthleteOwned=true` and `athleteId` automatically for athlete-created templates.
- **D-12:** Swipe left on carousel card reveals destructive actions (archive, delete).
- **D-13:** Long-press on carousel card shows iOS context menu with all actions: Edit, Duplicate, Favorite/Unfavorite, Archive, Delete.
- **D-14:** Delete requires confirmation. Archive is soft-delete (reversible).

### Claude's Discretion
- Carousel tap action: show preview sheet (chosen in UI-SPEC -- Phase 12 will add "Start Workout")
- Save-as-template confirmation step: quick save with auto-naming (chosen in UI-SPEC)
- Carousel card visual design (sizing, spacing, information density)
- Empty state when user has zero templates
- Whether "New Template" appears as a card in the carousel or as a separate button

### Deferred Ideas (OUT OF SCOPE)
- Pattern-based template suggestion (Phase 12 `TemplateSuggestionEngine`, TMPL-08)
- Template-driven workout launching with pre-filled exercises (Phase 12, TMPL-03, TMPL-04)
- Dashboard quick-start cards (Phase 12, TMPL-06)
- ProgressionEngine overlay on template targets (Phase 12, TMPL-07)
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| TMPL-01 | User can manually create a training template with named exercise groups (A/B/C/D), each containing exercises with target sets/reps/weight | Existing `TemplateEditorSheet` fully supports this. Add athlete-mode init path that sets `isAthleteOwned=true` and `athleteId` automatically. Carousel "New Template" card and empty-state CTA provide entry points. |
| TMPL-02 | User can save a completed workout session as a new template (actuals become targets, exercises in single default group) | Modify `ActiveWorkoutSheet` finish confirmation dialog to add save-as-template toggle. Convert `ExerciseEntryDraft`/`SetDraft` actuals to `WorkoutTemplate`/`ExerciseGroup`/`TemplateExercise`/`TemplateSet` targets. Quick-save with auto-naming per UI-SPEC D-06. |
| TMPL-05 | User can edit, duplicate, archive, favorite/pin, and delete templates from template management view | `TemplateRepository` already has all methods. Carousel provides management surface with context menu (D-13) and swipe actions (D-12). Delete confirmation alert (D-14). Preview sheet "Edit Template" button opens editor. |
</phase_requirements>

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Template carousel display | Browser / Client (SwiftUI Views) | -- | Pure UI rendering of local SwiftData queries |
| Template CRUD operations | Browser / Client (Repositories) | API / Backend (Supabase sync) | SwiftData local-first, then async push to Supabase |
| Save-from-session conversion | Browser / Client (View logic) | -- | Conversion from session drafts to template models is stateless mapping |
| Template editor fields | Browser / Client (SwiftUI Views) | -- | New fields on existing editor, local state only until save |
| Sync after template changes | API / Backend (SyncService) | -- | Existing `pushWorkoutTemplates` handles all template syncs |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUI | iOS 17+ | All views, carousel, context menus, sheets | Apple framework, project standard [VERIFIED: project.pbxproj] |
| SwiftData | iOS 17+ | Template persistence via `@Model` and `@Query` | Apple framework, project standard [VERIFIED: WorkoutTemplate.swift] |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| ScrollTargetBehavior (.viewAligned) | iOS 17+ | Carousel snap-to-center behavior | Carousel implementation [VERIFIED: Apple Developer docs] |
| GeometryReader | iOS 13+ | Card scale/opacity transforms based on scroll position | Adjacent card scaling in carousel [VERIFIED: project uses GeometryReader elsewhere] |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| ScrollView + viewAligned | TabView with page style | TabView hides adjacent items; carousel needs peek at neighbors |
| Custom swipe gesture | SwipeActions modifier | SwipeActions only works on List rows, not freeform cards |
| .contextMenu | Custom long-press sheet | contextMenu is native iOS pattern, free accessibility |

**Installation:** No new dependencies required. All APIs are part of the Apple SDK already in use.

## Architecture Patterns

### System Architecture Diagram

```
WorkoutLogView
    |
    +-- TemplateCarouselSection (new)
    |       |
    |       +-- TemplateCarouselCard (new, per template)
    |       |       +-- .contextMenu  (Edit, Duplicate, Favorite, Archive, Delete)
    |       |       +-- .gesture(DragGesture)  (swipe-to-reveal actions)
    |       |
    |       +-- NewTemplateCard (new, last position)
    |       |       +-- tap -> TemplateEditorSheet (existing, athlete mode)
    |       |
    |       +-- EmptyTemplateState (new, zero templates)
    |
    +-- TemplatePreviewSheet (new)
    |       +-- "Edit Template" -> TemplateEditorSheet (existing)
    |
    +-- [existing session history, import suggestions, prescriptions]

ActiveWorkoutSheet
    |
    +-- FinishWorkoutSheet (replaces .alert)
            +-- RPE display
            +-- Save-as-template toggle + name field
            +-- "Finish Workout" / "Keep Editing" buttons
            +-- on finish: saveSession() + optionally saveAsTemplate()

TemplateEditorSheet (existing, extended)
    +-- [existing: name, sport, type, notes, groups/exercises/sets]
    +-- ScheduledDaysPicker (new)
    +-- Favorite toggle (new)
    +-- save() -> TemplateRepository + SyncService.pushWorkoutTemplates()
```

### Recommended Project Structure
```
WorkloadApp/
├── Views/
│   ├── WorkoutLog/
│   │   ├── WorkoutLogView.swift              # Modified: add carousel section
│   │   ├── ActiveWorkoutSheet.swift          # Modified: replace .alert with FinishWorkoutSheet
│   │   ├── TemplateCarouselSection.swift     # NEW: carousel container + cards
│   │   ├── TemplatePreviewSheet.swift        # NEW: half-sheet preview
│   │   └── FinishWorkoutSheet.swift          # NEW: expanded finish dialog
│   ├── TemplateEditorSheet.swift             # Modified: add schedule + favorite fields
│   └── ...
├── Components/
│   └── ToastBanner.swift                     # NEW: generic auto-dismissing toast
├── Models/                                    # NO CHANGES (all fields exist)
├── Repositories/                              # NO CHANGES (all methods exist)
└── Services/                                  # NO CHANGES
```

### Pattern 1: Carousel with ViewAligned Scroll
**What:** Horizontal scroll with snap-to-center, scale/opacity transforms for adjacent cards
**When to use:** Displaying a browsable collection of cards where one is "active"
**Example:**
```swift
// Source: Apple Developer docs + fatbobman.com/en/posts/mastering-swiftui-scrolling
// [VERIFIED: Apple Developer Documentation]

ScrollView(.horizontal, showsIndicators: false) {
    HStack(spacing: 16) {
        ForEach(templates) { template in
            TemplateCarouselCard(template: template, isCentered: template.id == centeredId)
                .containerRelativeFrame(.horizontal) { size, _ in
                    size - 80  // peek at adjacent cards
                }
                .scrollTransition { content, phase in
                    content
                        .scaleEffect(phase.isIdentity ? 1.0 : 0.85)
                        .opacity(phase.isIdentity ? 1.0 : 0.6)
                }
        }
    }
    .scrollTargetLayout()
}
.scrollTargetBehavior(.viewAligned)
.scrollPosition(id: $centeredId)
```

### Pattern 2: Session-to-Template Conversion
**What:** Map workout session exercise entries to template structure
**When to use:** Save-as-template from finished workout
**Example:**
```swift
// [ASSUMED] — pattern derived from existing ActiveWorkoutSheet.saveSession()

func saveAsTemplate(
    name: String,
    sportType: SportType,
    sessionType: SessionType,
    entries: [ExerciseEntryDraft],
    athleteId: UUID,
    modelContext: ModelContext
) -> WorkoutTemplate {
    let template = WorkoutTemplate(
        coachId: athleteId,  // reuses coachId field for owner
        templateName: name,
        sportType: sportType,
        sessionType: sessionType
    )
    template.isAthleteOwned = true
    template.athleteId = athleteId

    // All exercises in one "Main" group per TMPL-02
    let group = ExerciseGroup(groupName: "Main", orderIndex: 0)
    for (idx, entry) in entries.enumerated() {
        let exercise = TemplateExercise(
            exerciseName: entry.exerciseName,
            exerciseCategory: entry.exerciseCategory,
            muscleGroup: entry.muscleGroup,
            orderIndex: idx
        )
        // Actuals become targets
        for (sIdx, set) in entry.sets.enumerated() {
            let targetSet = TemplateSet(
                setIndex: sIdx,
                targetReps: set.reps,
                targetWeightKg: set.weightKg,
                targetDurationSeconds: set.durationSeconds,
                targetDistanceMeters: set.distanceMeters,
                targetRPE: set.rpe,
                targetRIR: set.rir,
                isWarmup: set.isWarmup
            )
            exercise.sets.append(targetSet)
        }
        group.exercises.append(exercise)
    }
    template.groups.append(group)

    modelContext.insert(template)
    try? modelContext.save()
    return template
}
```

### Pattern 3: Context Menu on Carousel Cards
**What:** Long-press context menu for CRUD actions
**When to use:** Template management actions
**Example:**
```swift
// Source: SwiftUI .contextMenu API [VERIFIED: Apple SwiftUI framework]

TemplateCarouselCard(template: template)
    .contextMenu {
        Button { editTemplate(template) } label: {
            Label("Edit Template", systemImage: "pencil")
        }
        Button { duplicateTemplate(template) } label: {
            Label("Duplicate Template", systemImage: "doc.on.doc")
        }
        Button {
            toggleFavorite(template)
        } label: {
            Label(
                template.isFavorite ? "Unfavorite" : "Favorite",
                systemImage: template.isFavorite ? "star.fill" : "star"
            )
        }
        Button { archiveTemplate(template) } label: {
            Label("Archive Template", systemImage: "archivebox")
        }
        Divider()
        Button(role: .destructive) {
            templateToDelete = template
            showDeleteConfirmation = true
        } label: {
            Label("Delete Template", systemImage: "trash")
        }
    }
```

### Pattern 4: Custom Swipe-to-Reveal Gesture
**What:** Drag gesture on carousel card to reveal action buttons
**When to use:** Destructive actions on non-List views (D-12)
**Example:**
```swift
// [ASSUMED] — custom implementation since .swipeActions is List-only

@State private var swipeOffset: CGFloat = 0

TemplateCarouselCard(template: template)
    .offset(x: swipeOffset)
    .gesture(
        DragGesture()
            .onChanged { value in
                if value.translation.width < 0 {
                    swipeOffset = max(value.translation.width, -144)
                }
            }
            .onEnded { value in
                withAnimation(.easeOut(duration: 0.25)) {
                    if value.translation.width < -72 {
                        swipeOffset = -144  // reveal both buttons
                    } else {
                        swipeOffset = 0  // snap back
                    }
                }
            }
    )
    .background(alignment: .trailing) {
        HStack(spacing: 0) {
            // Archive button (72pt wide)
            // Delete button (72pt wide)
        }
    }
```

### Anti-Patterns to Avoid
- **Custom paging with Timer:** Do not use timer-based auto-scroll for the carousel. Users control scroll position; auto-advance would be disorienting for a workout template picker.
- **Nested ScrollView conflicts:** The carousel is a horizontal ScrollView inside a vertical ScrollView (WorkoutLogView). Use `.scrollTargetLayout()` on the inner HStack and ensure the outer ScrollView does not intercept horizontal gestures. iOS 17+ handles this correctly with `scrollTargetBehavior`.
- **Deleting without confirmation:** D-14 explicitly requires delete confirmation. Archive is immediate (soft-delete, reversible).
- **Using .alert for finish dialog:** The existing `.alert("Finish Workout")` is too limited for toggle + text field + buttons. Replace with a custom `.sheet` (FinishWorkoutSheet).
- **Filtering templates in the view:** Use `TemplateRepository.fetchAthleteTemplates()` which already filters `isAthleteOwned && !isArchived`. Do not re-filter in the view.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Carousel snap behavior | Custom scroll offset tracking with UIScrollView | `scrollTargetBehavior(.viewAligned)` + `scrollTargetLayout()` | iOS 17+ native API handles snap, deceleration, and accessibility |
| Card scale/opacity on scroll | Manual GeometryReader offset calculations | `.scrollTransition` modifier (iOS 17+) | Native modifier automatically computes phase and applies transforms |
| Context menu | Custom long-press gesture + popover | `.contextMenu` modifier | Free VoiceOver support, native animation, consistent with iOS patterns |
| Template CRUD | New repository methods | Existing `TemplateRepository` | All operations already implemented and tested |
| Template model fields | New model properties | Existing `WorkoutTemplate` fields | `isAthleteOwned`, `isFavorite`, `isArchived`, `scheduledDays`, `lastUsedAt`, `usageCount` all exist |
| Supabase sync | New sync methods | Existing `SyncService.pushWorkoutTemplates()` | Already handles all template fields including athlete-owned ones |

**Key insight:** This phase is almost entirely view-layer work. The data layer (models, repository, sync) is already complete from Phase 9. Resist the urge to modify models or repository -- they are ready to use as-is.

## Common Pitfalls

### Pitfall 1: ScrollView + DragGesture Conflict
**What goes wrong:** Custom swipe-to-reveal gesture on carousel cards conflicts with the horizontal ScrollView's own pan gesture, causing either swipe or scroll to fail.
**Why it happens:** Both the DragGesture and ScrollView respond to horizontal swipes. iOS gesture system cannot distinguish intent.
**How to avoid:** Only allow swipe-to-reveal on the centered card (which is already "resting" and won't be scrolled to). Use `.highPriorityGesture` or `.simultaneousGesture` with a minimum distance threshold. Alternatively, limit swipe to work only after a short press delay.
**Warning signs:** Card swipe triggers scroll, or scroll triggers swipe reveal on wrong card.

### Pitfall 2: ISO 8601 Weekday Mismatch
**What goes wrong:** The `scheduledDays` array uses ISO 8601 (1=Mon...7=Sun) but `Calendar.current.component(.weekday, from:)` returns 1=Sun...7=Sat.
**Why it happens:** Apple's Calendar API uses a different weekday numbering than ISO 8601.
**How to avoid:** Convert Apple weekday to ISO: `let isoWeekday = appleWeekday == 1 ? 7 : appleWeekday - 1`. Test with Sunday specifically.
**Warning signs:** Templates scheduled for Sunday show on Monday, or Monday templates show on Sunday.

### Pitfall 3: Replace .alert with .sheet Carefully
**What goes wrong:** Removing the existing `.alert("Finish Workout")` and replacing with a `.sheet` changes the interaction model -- sheets are dismissible by swipe-down, alerts are not.
**Why it happens:** A sheet can be accidentally dismissed mid-save, potentially losing RPE and template name data.
**How to avoid:** Use `.interactiveDismissDisabled(true)` on the finish sheet, or use `.presentationDetents([.medium])` to make it feel dialog-like. Ensure all state is preserved if the user dismisses and re-opens.
**Warning signs:** User swipes down on finish dialog and workout data is lost.

### Pitfall 4: coachId Field for Athlete-Owned Templates
**What goes wrong:** The `WorkoutTemplate` init requires `coachId: UUID`. For athlete-owned templates, this field is set to the athlete's ID (as established in Phase 9 D-01).
**Why it happens:** The model was originally designed for coach-created templates. The `coachId` field is reused for the owner ID.
**How to avoid:** Always pass the athlete's UUID as `coachId` when creating athlete-owned templates. Set `isAthleteOwned = true` and `athleteId = athlete.id`. The sync query `pushWorkoutTemplates(coachId:)` uses `coachId` to fetch all templates for the owner, so this works correctly for both coaches and athletes.
**Warning signs:** Templates not syncing because `coachId` doesn't match the athlete's UUID.

### Pitfall 5: Empty Sets in Session-to-Template Conversion
**What goes wrong:** Some exercise entries in a finished workout may have empty sets (no reps, no weight) if the user added an exercise but didn't fill in data. Converting these to template targets creates useless empty sets.
**Why it happens:** Users sometimes add exercises speculatively during a workout and don't fill them in.
**How to avoid:** Filter out completely empty sets (where all target fields are nil) during conversion. Also consider filtering out exercises with zero valid sets.
**Warning signs:** Templates created from sessions have entries like "Bench Press - 0 sets" or sets with all nil values.

### Pitfall 6: scrollTransition vs GeometryReader
**What goes wrong:** Using both `.scrollTransition` and `GeometryReader` for the same transform causes double-application or conflicting animations.
**Why it happens:** `.scrollTransition` (iOS 17+) is the modern replacement for manual GeometryReader-based scroll transforms.
**How to avoid:** Use `.scrollTransition` exclusively -- it provides a `phase` object with `.isIdentity` (centered), and the transition values needed for scale and opacity. Do not add a separate GeometryReader for the same purpose.
**Warning signs:** Cards flicker, scale incorrectly, or have choppy animation during scroll.

## Code Examples

### ISO Weekday Conversion
```swift
// [VERIFIED: Calendar API docs]

extension Date {
    /// Current day as ISO 8601 weekday (1=Mon...7=Sun)
    var isoWeekday: Int {
        let apple = Calendar.current.component(.weekday, from: self)
        // Apple: 1=Sun, 2=Mon...7=Sat -> ISO: 1=Mon...7=Sun
        return apple == 1 ? 7 : apple - 1
    }
}
```

### Carousel Centering Logic
```swift
// [ASSUMED] — derived from CONTEXT.md D-02, D-03

func initialCenteredTemplateId(from templates: [WorkoutTemplate]) -> UUID? {
    let todayISO = Date.now.isoWeekday

    // 1. Find templates scheduled for today
    let todayTemplates = templates.filter { $0.scheduledDays.contains(todayISO) }

    if !todayTemplates.isEmpty {
        // Pick the one most recently used
        return todayTemplates
            .sorted { ($0.lastUsedAt ?? .distantPast) > ($1.lastUsedAt ?? .distantPast) }
            .first?.id
    }

    // 2. Fallback: most recently used template
    let byLastUsed = templates
        .sorted { ($0.lastUsedAt ?? .distantPast) > ($1.lastUsedAt ?? .distantPast) }

    if let mostRecent = byLastUsed.first, mostRecent.lastUsedAt != nil {
        return mostRecent.id
    }

    // 3. Fallback: first template
    return templates.first?.id
}
```

### Toast Banner Component
```swift
// [ASSUMED] — new component, pattern from SpikeAlertBanner

struct ToastBanner: View {
    let message: String
    let isError: Bool
    @Binding var isPresented: Bool

    var body: some View {
        if isPresented {
            HStack(spacing: 8) {
                Text(message)
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text1)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(ColorTokens.surface)
            .overlay(Rectangle().stroke(ColorTokens.divider, lineWidth: 0.5))
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + (isError ? 3.0 : 2.0)) {
                    withAnimation(.easeIn(duration: 0.15)) {
                        isPresented = false
                    }
                }
            }
        }
    }
}
```

### TemplateEditorSheet Schedule Picker
```swift
// [ASSUMED] — new field per D-09, UI-SPEC layout

private let weekdayLabels = ["M", "T", "W", "T", "F", "S", "S"]
private let weekdayValues = [1, 2, 3, 4, 5, 6, 7]  // ISO 8601

HStack(spacing: 8) {
    ForEach(Array(zip(weekdayValues, weekdayLabels)), id: \.0) { value, label in
        Button {
            if scheduledDays.contains(value) {
                scheduledDays.removeAll { $0 == value }
            } else {
                scheduledDays.append(value)
            }
        } label: {
            Text(label)
                .font(.Tokens.label)
                .foregroundStyle(
                    scheduledDays.contains(value) ? ColorTokens.text1 : ColorTokens.text2
                )
                .frame(width: 40, height: 40)
                .background(
                    scheduledDays.contains(value) ? ColorTokens.surface : ColorTokens.background
                )
                .overlay(
                    Rectangle().stroke(
                        scheduledDays.contains(value) ? ColorTokens.text1 : ColorTokens.divider,
                        lineWidth: 0.5
                    )
                )
        }
        .buttonStyle(.plain)
    }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| UIPageViewController for paging | `scrollTargetBehavior(.viewAligned)` | iOS 17 (June 2023) | No UIKit bridging needed, pure SwiftUI |
| GeometryReader for scroll transforms | `.scrollTransition` modifier | iOS 17 (June 2023) | Cleaner API, automatic phase computation |
| Manual scroll offset tracking | `.scrollPosition(id:)` | iOS 17 (June 2023) | Two-way binding for programmatic scroll |
| TabView(.page) for carousel | ScrollView + scrollTargetLayout | iOS 17 (June 2023) | Supports peek at adjacent items, custom spacing |

**Deprecated/outdated:**
- `TabView(selection:).tabViewStyle(.page)`: Still works but does not support adjacent card peek or custom spacing. Not suitable for this carousel design.
- `UICollectionView` via `UIViewRepresentable`: Unnecessary since iOS 17 ScrollView APIs cover the requirements natively.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `.scrollTransition` modifier works with horizontal ScrollView + HStack for scale/opacity transforms | Architecture Patterns | Would need to fall back to GeometryReader-based calculations; more code but achievable |
| A2 | `containerRelativeFrame` can be used with custom width calculations for carousel card sizing | Architecture Patterns | Would need explicit `.frame(width: 280)` instead; minor adjustment |
| A3 | Custom DragGesture on carousel cards does not conflict with ScrollView horizontal panning when applied only to centered card | Common Pitfalls | Swipe-to-reveal may need alternative approach (e.g., context menu is always available as fallback) |
| A4 | FinishWorkoutSheet as `.sheet` replacement for `.alert` provides enough UI space for toggle + name field | Architecture Patterns | Could use `.fullScreenCover` or inline view instead |

## Open Questions (RESOLVED)

1. **scrollTransition vs GeometryReader for card transforms**
   - RESOLVED: Use `.scrollTransition` exclusively (Plan 11-02 Task 1). It provides `phase.isIdentity` for centered detection and supports custom scale (0.85x) and opacity (0.6) values directly. Simpler and more performant than manual GeometryReader. Fall back to GeometryReader only if runtime testing reveals insufficient control.

2. **Swipe gesture conflict with ScrollView**
   - RESOLVED: Apply DragGesture only to the centered card (Plan 11-02 Task 1, following Pitfall 1 recommendation). Non-centered cards rely on context menu (D-13) for management actions. Swipe is a convenience on the active card, not the sole action path.

## Sources

### Primary (HIGH confidence)
- `WorkloadApp/Models/WorkoutTemplate.swift` -- all model fields verified present
- `WorkloadApp/Repositories/TemplateRepository.swift` -- all CRUD operations verified
- `WorkloadApp/Views/TemplateEditorSheet.swift` -- existing editor structure verified
- `WorkloadApp/Views/WorkoutLog/ActiveWorkoutSheet.swift` -- finish dialog structure verified
- `WorkloadApp/Views/WorkoutLog/WorkoutLogView.swift` -- current view structure verified
- `WorkloadApp/Services/SyncService.swift` -- pushWorkoutTemplates verified at line 687
- `WorkloadApp/Utilities/FontTokens.swift` -- all font tokens verified

### Secondary (MEDIUM confidence)
- [Apple Developer Documentation - ScrollTargetBehavior](https://developer.apple.com/documentation/swiftui/scrolltargetbehavior) -- iOS 17+ API availability confirmed
- [fatbobman.com - Mastering SwiftUI Scrolling](https://fatbobman.com/en/posts/mastering-swiftui-scrolling-implementing-custom-paging/) -- scrollTargetLayout + viewAligned patterns verified

### Tertiary (LOW confidence)
- `.scrollTransition` exact transform control -- verified as existing API, but exact behavior with custom scale values needs runtime confirmation (A1)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- all components are existing Apple frameworks already in use in the project
- Architecture: HIGH -- all models, repository, and sync infrastructure verified present; patterns are straightforward SwiftUI view composition
- Pitfalls: MEDIUM -- carousel gesture conflicts and scrollTransition behavior need runtime verification

**Research date:** 2026-05-09
**Valid until:** 2026-06-09 (30 days -- stable iOS 17 APIs, no fast-moving dependencies)
