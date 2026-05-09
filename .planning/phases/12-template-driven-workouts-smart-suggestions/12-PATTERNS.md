# Phase 12: Template-Driven Workouts & Smart Suggestions - Pattern Map

**Mapped:** 2026-05-10
**Files analyzed:** 8 (1 new, 7 modified)
**Analogs found:** 8 / 8

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `WorkloadApp/Services/TemplateSuggestionEngine.swift` | engine | transform | `WorkloadApp/Services/AutoregulationEngine.swift` | exact |
| `WorkloadApp/Views/WorkoutLog/TemplatePickerSheet.swift` | component | request-response | `WorkloadApp/Views/WorkoutLog/TemplatePreviewSheet.swift` | exact |
| `WorkloadApp/Views/WorkoutLog/ActiveWorkoutSheet.swift` | component | request-response | self (loadPrescription + prefillFromHistory patterns) | exact |
| `WorkloadApp/Views/WorkoutLog/WorkoutLogView.swift` | component | request-response | self (toolbar + sheet bindings) | exact |
| `WorkloadApp/Views/WorkoutLog/TemplateCarouselSection.swift` | component | request-response | self (onTapGesture + contextMenu) | exact |
| `WorkloadApp/Views/WorkoutLog/TemplatePreviewSheet.swift` | component | request-response | self (minimal change -- trigger moves to contextMenu) | exact |
| `WorkloadApp/Views/Dashboard/DashboardView.swift` | component | request-response | self (WelcomeActionCard insertion point) | exact |
| `WorkloadApp/Models/WorkoutSession.swift` | model | CRUD | self (additive optional field) | exact |

## Pattern Assignments

### `WorkloadApp/Services/TemplateSuggestionEngine.swift` (engine, transform) -- NEW

**Analog:** `WorkloadApp/Services/AutoregulationEngine.swift`

**Imports pattern** (lines 1):
```swift
import Foundation
```

**Struct + nested types pattern** (lines 10-39):
```swift
struct AutoregulationEngine {

    struct DailyInput {
        let recoveryZone: RecoveryZone
        let recoveryScore: Double       // 0-100
        let acwrZone: ACWRZone
        let acwr: Double
        let wellnessScore: Double?       // 0-100
        let daysSinceLastRest: Int
        let fatigueIndex: Double?

        init(
            recoveryZone: RecoveryZone,
            recoveryScore: Double,
            acwrZone: ACWRZone,
            acwr: Double,
            wellnessScore: Double?,
            daysSinceLastRest: Int,
            fatigueIndex: Double? = nil
        ) {
            // ...
        }
    }

    struct TrainingRecommendation {
        let intensityCap: Double
        let volumeModifier: Double
        let sessionType: RecommendedSessionType
        let warnings: [Warning]
        let headline: String
        let detail: String
    }
```

**Static method pattern** -- follow `ProgressionEngine.suggest()` (lines 48-54):
```swift
static func suggest(
    exerciseName: String,
    category: ExerciseCategory,
    context: TrainingContext,
    recentEntries: [ExerciseHistoryRecord]
) -> ExerciseSuggestion {
```

**ISO weekday helper** -- copy from `TemplateCarouselSection` (lines 30-33):
```swift
private var todayISOWeekday: Int {
    let apple = Calendar.current.component(.weekday, from: .now)
    return apple == 1 ? 7 : apple - 1  // Apple 1=Sun -> ISO 7=Sun
}
```

**Key pattern:** Pure struct, static methods only, no SwiftData/SwiftUI imports, no state. Input struct for complex parameters, output struct for results. Uses `RecoveryZone` from `Models/Enums.swift`.

---

### `WorkloadApp/Views/WorkoutLog/TemplatePickerSheet.swift` (component, request-response) -- NEW

**Analog:** `WorkloadApp/Views/WorkoutLog/TemplatePreviewSheet.swift`

**Imports + struct signature** (lines 1-7):
```swift
import SwiftUI
import SwiftData

struct TemplatePreviewSheet: View {
    let template: WorkoutTemplate
    var onEdit: () -> Void
    @Environment(\.dismiss) private var dismiss
```

**Navigation + toolbar pattern** from `TemplatePreviewSheet` + `FinishWorkoutSheet`:
```swift
NavigationStack {
    ScrollView {
        VStack(alignment: .leading, spacing: 0) {
            // content
        }
    }
    .background(ColorTokens.background)
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
```

**Template fetching pattern** -- copy from `TemplateCarouselSection` (lines 22-26):
```swift
private var templates: [WorkoutTemplate] {
    guard let athleteId = athletes.first?.id else { return [] }
    return (try? TemplateRepository(modelContext: modelContext)
        .fetchAthleteTemplates(athleteId: athleteId)) ?? []
}
```

**Empty state pattern** -- copy from `TemplateCarouselSection` (lines 64-91):
```swift
private var emptyState: some View {
    VStack(spacing: 16) {
        Text("No Templates Yet")
            .font(.Tokens.sectionHead)
            .foregroundStyle(ColorTokens.text1)

        Text("Create your first template to speed up workout logging.")
            .font(.Tokens.body)
            .foregroundStyle(ColorTokens.text2)
            .multilineTextAlignment(.center)

        Button {
            onCreateTemplate()
        } label: {
            Text("Create Template")
                .font(.Tokens.label)
                .foregroundStyle(ColorTokens.text1)
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
                .overlay(Rectangle().stroke(ColorTokens.divider, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 24)
    .frame(maxWidth: .infinity)
    .background(ColorTokens.background)
}
```

**Button styling pattern** -- copy from `WelcomeActionCard` (lines 32-41):
```swift
Button(action: onLogWorkout) {
    Text("Log Workout")
        .font(.Tokens.label)
        .foregroundStyle(ColorTokens.text1)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .overlay(
            Rectangle().stroke(ColorTokens.divider, lineWidth: 0.5)
        )
}
```

**Key pattern:** Uses callbacks (`onSelectTemplate`, `onStartBlank`, `onCreateTemplate`) for parent coordination -- same as `TemplateCarouselSection`'s callback approach. Environment injection: `@Environment(AppContainer.self)`, `@Environment(\.modelContext)`, `@Environment(\.dismiss)`, `@Query private var athletes: [Athlete]`.

---

### `WorkloadApp/Views/WorkoutLog/ActiveWorkoutSheet.swift` (component, request-response) -- MODIFY

**Analog:** Self -- `loadPrescription()` pattern (lines 324-354)

**Template-to-draft conversion** -- copy structure from `loadPrescription()`:
```swift
private func loadPrescription() {
    guard let rx = prescription else { return }
    sessionName = rx.templateName
    sportType = rx.sportType
    sessionType = rx.sessionType

    entries = rx.sortedGroups.flatMap { group in
        group.sortedExercises.map { exercise in
            var draft = ExerciseEntryDraft(
                exerciseName: exercise.exerciseName,
                exerciseCategory: exercise.exerciseCategory,
                muscleGroup: exercise.muscleGroup
            )
            draft.groupName = group.groupName
            draft.sets = exercise.sortedSets.map { set in
                SetDraft(
                    reps: set.targetReps,
                    weightKg: set.targetWeightKg,
                    rpe: set.targetRPE,
                    rir: set.targetRIR,
                    isWarmup: set.isWarmup,
                    targetReps: set.targetReps,
                    targetWeightKg: set.targetWeightKg,
                    targetRPE: set.targetRPE
                )
            }
            if draft.sets.isEmpty { draft.sets = [SetDraft()] }
            return draft
        }
    }
}
```

**Ghost targets differ from prescription:** In `loadFromTemplate()`, set `reps`/`weightKg`/`rpe` to nil (user fills), populate only `targetReps`/`targetWeightKg`/`targetRPE` as ghost placeholders. The `SetEntryRow` already renders target* fields as placeholder text (lines 692-705):
```swift
private var weightPlaceholder: String {
    if let t = set.targetWeightKg { return String(format: "%.0f", t) }
    return "kg"
}

private var repsPlaceholder: String {
    if let t = set.targetReps { return "\(t)" }
    return "reps"
}

private var rpePlaceholder: String {
    if let t = set.targetRPE { return String(format: "%.0f", t) }
    return "RPE"
}
```

**ProgressionEngine integration** -- copy from `prefillFromHistory()` (lines 193-229):
```swift
private func prefillFromHistory(_ draft: inout ExerciseEntryDraft) {
    let history = ProgressionEngine.fetchHistory(
        exerciseName: draft.exerciseName,
        modelContext: modelContext
    )
    guard !history.isEmpty else { return }
    let context = buildTrainingContext()
    let suggestion = ProgressionEngine.suggest(
        exerciseName: draft.exerciseName,
        category: draft.exerciseCategory,
        context: context,
        recentEntries: history
    )
    // ...
    draft.suggestionRationale = suggestion.rationale
    draft.progressionType = suggestion.progressionType
}
```

**Init pattern** -- current init (line 30-32):
```swift
init(prescription: PrescribedWorkout? = nil) {
    self.prescription = prescription
}
```
Extend with optional `template: WorkoutTemplate? = nil` parameter.

**Save + template update** -- copy from `saveSession()` (lines 358-440), add template tracking after `modelContext.save()`:
```swift
// After existing modelContext.save() at line 406:
if let source = sourceTemplate {
    source.lastUsedAt = .now
    source.usageCount += 1
    source.updatedAt = .now
    try? modelContext.save()
}
```

**ExerciseEntryDraft extension** -- current fields (lines 556-565). Add `progressionSuggestions: [ProgressionEngine.SetSuggestion]?` for Pro overlay.

---

### `WorkloadApp/Views/WorkoutLog/WorkoutLogView.swift` (component, request-response) -- MODIFY

**"+" button** -- current toolbar (lines 191-197):
```swift
Button {
    showActiveWorkout = true
} label: {
    Image(systemName: "plus")
        .foregroundStyle(ColorTokens.text1)
}
```
Change to open `showTemplatePicker = true` instead.

**Sheet binding pattern** -- copy from existing sheet bindings (lines 200-243):
```swift
.sheet(isPresented: $showActiveWorkout) {
    ActiveWorkoutSheet(prescription: activePrescription)
}
.sheet(item: $selectedTemplateForPreview) { template in
    TemplatePreviewSheet(
        template: template,
        onEdit: {
            selectedTemplateForPreview = nil
            editingTemplate = template
            showTemplateEditor = true
        }
    )
    .environment(container)
}
```
Add new `.sheet(isPresented: $showTemplatePicker)` for TemplatePickerSheet.

**TemplateCarouselSection callbacks** -- current (lines 61-73):
```swift
TemplateCarouselSection(
    onEditTemplate: { template in
        editingTemplate = template
        showTemplateEditor = true
    },
    onPreviewTemplate: { template in
        selectedTemplateForPreview = template
    },
    onCreateTemplate: {
        editingTemplate = nil
        showTemplateEditor = true
    }
)
```
Change `onPreviewTemplate` to `onStartFromTemplate` that sets `selectedTemplate` and opens `showActiveWorkout`.

---

### `WorkloadApp/Views/WorkoutLog/TemplateCarouselSection.swift` (component, request-response) -- MODIFY

**Tap action** -- current `onTapGesture` (lines 266-281):
```swift
.onTapGesture {
    if swipedTemplateId == template.id && swipeOffset < 0 {
        withAnimation(.easeOut(duration: 0.25)) {
            swipeOffset = 0
            swipedTemplateId = nil
        }
        return
    }
    if isCentered {
        onPreviewTemplate(template)  // Change to onStartFromTemplate(template)
    } else {
        withAnimation(.easeOut(duration: 0.25)) {
            centeredId = template.id
        }
    }
}
```

**Context menu** -- add preview option (lines 282-299):
```swift
.contextMenu {
    Button { onEditTemplate(template) } label: {
        Label("Edit Template", systemImage: "pencil")
    }
    // ADD: Preview option here
    Button { duplicateTemplate(template) } label: {
        Label("Duplicate Template", systemImage: "doc.on.doc")
    }
    // ... existing items
}
```

**Suggested label styling** -- follow section header pattern (lines 97-104):
```swift
Text("MY TEMPLATES")
    .font(.Tokens.micro)
    .tracking(1.2)
    .textCase(.uppercase)
    .foregroundStyle(ColorTokens.text3)
```
Use same micro/tracking for "Suggested" and "Recovery-adjusted" labels on cards.

---

### `WorkloadApp/Views/Dashboard/DashboardView.swift` (component, request-response) -- MODIFY

**Card insertion point** -- after HeroReadinessCard, before conditional cards (lines 40-59):
```swift
HeroReadinessCard(viewModel: viewModel)

// INSERT QuickStartSection HERE (D-11)

if showWelcomeCard {
    WelcomeActionCard(...)
}
```

**Horizontal scroll card pattern** -- copy from `WelcomeActionCard` button styling:
```swift
VStack(alignment: .leading, spacing: 0) {
    Text("QUICK START")
        .font(.Tokens.micro)
        .tracking(1.2)
        .foregroundStyle(ColorTokens.text3)
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 8)

    ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 8) {
            // compact cards
        }
        .padding(.horizontal, 16)
    }
    .padding(.bottom, 16)
}
.background(ColorTokens.surface)
```

**Sheet coordination** -- dashboard already has `showActiveWorkout` binding (line 19):
```swift
@State private var showActiveWorkout = false
```

---

### `WorkloadApp/Models/WorkoutSession.swift` (model, CRUD) -- MODIFY

**Additive field pattern** -- follow existing optional fields (lines 8-14):
```swift
var sessionName: String?
var sportType: SportType
var durationSeconds: Int
var sessionRPE: Double?
var notes: String?
var sessionType: SessionType = SessionType.strength
var loggedByCoachId: UUID?          // nil = athlete self-logged
```
Add `var sourceTemplateId: UUID? = nil` as additive optional -- SwiftData handles gracefully with no migration.

---

### `WorkloadApp/Views/WorkoutLog/TemplatePreviewSheet.swift` (component, request-response) -- MODIFY

**Minimal change:** No structural change needed. Preview moves from tap trigger (in TemplateCarouselSection) to context menu trigger. TemplatePreviewSheet code itself stays the same -- it receives a `WorkoutTemplate` and displays it. The only change is where it's invoked from.

---

## Shared Patterns

### Environment Injection
**Source:** All view files
**Apply to:** TemplatePickerSheet, QuickStartSection, FillButtonBar
```swift
@Environment(AppContainer.self) private var container
@Environment(\.modelContext) private var modelContext
@Environment(\.dismiss) private var dismiss
@Query private var athletes: [Athlete]
```

### Pro-Gating
**Source:** `WorkloadApp/Views/WorkoutLog/ActiveWorkoutSheet.swift` lines 129-133
**Apply to:** ProgressionEngine overlay, "Fill suggested" button, TemplateSuggestionEngine suggestions, "Suggested" label
```swift
if container.subscriptionService.isPro {
    prefillFromHistory(&draft)
} else {
    fallbackFromHistoryPublic(&draft)
}
```

### Template Repository Access
**Source:** `WorkloadApp/Views/WorkoutLog/TemplateCarouselSection.swift` lines 22-26
**Apply to:** TemplatePickerSheet, QuickStartSection (dashboard)
```swift
private var templates: [WorkoutTemplate] {
    guard let athleteId = athletes.first?.id else { return [] }
    return (try? TemplateRepository(modelContext: modelContext)
        .fetchAthleteTemplates(athleteId: athleteId)) ?? []
}
```

### Design System
**Source:** `DESIGN.md` + existing components
**Apply to:** All new views
- 0pt border radius: `Rectangle()` not `RoundedRectangle`
- No shadows: use `.overlay(Rectangle().stroke(ColorTokens.divider, lineWidth: 0.5))`
- DM Sans only: `Font.Tokens.body`, `.Tokens.label`, `.Tokens.micro`, `.Tokens.sectionHead`
- 8pt grid: padding values must be 8, 16, 24, 32, 48
- Accent only on hero readiness score

### Section Header
**Source:** `TemplateCarouselSection` lines 97-104, `WelcomeActionCard` line 12-14
**Apply to:** QuickStartSection header, TemplatePickerSheet sections
```swift
Text("SECTION TITLE")
    .font(.Tokens.micro)
    .tracking(1.2)
    .textCase(.uppercase)
    .foregroundStyle(ColorTokens.text3)
    .padding(.horizontal, 16)
    .padding(.top, 16)
    .padding(.bottom, 8)
```

### Divider
**Source:** All views
**Apply to:** All new/modified views
```swift
Rectangle()
    .fill(ColorTokens.divider)
    .frame(height: 0.5)
```

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| (none) | -- | -- | All files have close analogs in the existing codebase |

## Metadata

**Analog search scope:** `WorkloadApp/Services/`, `WorkloadApp/Views/`, `WorkloadApp/Models/`, `WorkloadApp/Repositories/`
**Files scanned:** 14 analog candidates read
**Pattern extraction date:** 2026-05-10
