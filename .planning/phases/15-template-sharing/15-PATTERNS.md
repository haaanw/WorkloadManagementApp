# Phase 15: Template Sharing - Pattern Map

**Mapped:** 2026-05-13
**Files analyzed:** 9 new/modified files
**Analogs found:** 9 / 9

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `WorkloadApp/Services/TemplateSharingService.swift` | service | request-response | `WorkloadApp/Services/InviteService.swift` | exact |
| `WorkloadApp/Views/WorkoutLog/ShareCodeSheet.swift` | component | request-response | `WorkloadApp/Views/WorkoutLog/TemplatePreviewSheet.swift` | role-match |
| `WorkloadApp/Views/WorkoutLog/ShareImportSheet.swift` | component | request-response | `WorkloadApp/Views/WorkoutLog/TextTemplateImportSheet.swift` | exact |
| `WorkloadApp/Views/WorkoutLog/ShareImportPreviewSheet.swift` | component | request-response | `WorkloadApp/Views/WorkoutLog/TemplatePreviewSheet.swift` | exact |
| `WorkloadApp/App/AppRouter.swift` (modify) | route | event-driven | self (existing deep link handling) | exact |
| `WorkloadApp/Views/WorkoutLog/WorkoutLogView.swift` (modify) | component | request-response | self (existing toolbar menu) | exact |
| `WorkloadApp/Views/WorkoutLog/TemplateCarouselSection.swift` (modify) | component | event-driven | self (existing context menu) | exact |
| `workload management/workload management/workload management.entitlements` (modify) | config | -- | self | exact |
| `migrations/shared_templates.sql` | migration | CRUD | existing Supabase migration pattern | role-match |

## Pattern Assignments

### `WorkloadApp/Services/TemplateSharingService.swift` (service, request-response)

**Analog:** `WorkloadApp/Services/InviteService.swift`

**Structure pattern** (lines 1-6) -- enum namespace with static methods, no instance state:
```swift
import Foundation
import Supabase

/// Namespace for invite flow operations: code generation, email invite, deep link parsing, relationship confirmation.
/// All Supabase calls happen on the @MainActor; no instance state.
enum InviteService {
```

**Code generation pattern** (lines 10-14) -- extend from 6 to 8 chars:
```swift
    static func makeLocalCode() -> String {
        let chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<6).map { _ in chars.randomElement()! })
    }
```

**Supabase insert pattern** (lines 36-59) -- inline Encodable struct, async throws, returns code:
```swift
    @MainActor
    static func generateInviteCode(
        for athleteId: UUID,
        client: SupabaseClient
    ) async throws -> String {
        let code = makeLocalCode()
        let expires = Date.now.addingTimeInterval(48 * 60 * 60)

        struct InvitationInsert: Encodable {
            let inviterId: UUID
            let inviterRole: String
            let code: String
            let expiresAt: Date
        }

        try await client
            .from("invitations")
            .insert(InvitationInsert(
                inviterId: athleteId,
                inviterRole: "athlete",
                code: code,
                expiresAt: expires
            ))
            .execute()

        return code
    }
```

**Supabase lookup pattern** (lines 67-106) -- inline Decodable struct, select + eq + single:
```swift
    @MainActor
    static func resolveCode(
        _ code: String,
        client: SupabaseClient
    ) async throws -> ResolvedInvitation {
        struct InvitationRow: Decodable {
            let id: UUID
            let inviterId: UUID
            let inviterRole: String
        }

        let row: InvitationRow = try await client
            .from("invitations")
            .select("id, inviter_id, inviter_role")
            .eq("code", value: code)
            .single()
            .execute()
            .value
        // ... map to domain type
    }
```

**Deep link parsing pattern** (lines 21-28):
```swift
    static func handleDeepLink(_ url: URL) -> String? {
        guard url.scheme == "workload",
              url.host == "invite" else { return nil }
        return URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == "code" })?
            .value
    }
```

---

### `WorkloadApp/Views/WorkoutLog/ShareCodeSheet.swift` (component, request-response)

**Analog:** `WorkloadApp/Views/WorkoutLog/TemplatePreviewSheet.swift`

**Sheet structure pattern** (lines 1-11) -- NavigationStack + ScrollView + dismiss + toolbar:
```swift
import SwiftUI
import SwiftData

struct TemplatePreviewSheet: View {
    let template: WorkoutTemplate
    var onEdit: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
```

**Toolbar pattern** (lines 77-93) -- cancellation + confirmation actions:
```swift
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text2)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Edit Template") {
                        onEdit()
                        dismiss()
                    }
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text1)
                }
            }
        }
        .presentationDetents([.medium, .large])
```

---

### `WorkloadApp/Views/WorkoutLog/ShareImportSheet.swift` (component, request-response)

**Analog:** `WorkloadApp/Views/WorkoutLog/TextTemplateImportSheet.swift`

**Import sheet structure** (lines 1-30) -- environment injection, state management, NavigationStack:
```swift
import SwiftUI
import SwiftData

struct TextTemplateImportSheet: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var athletes: [Athlete]

    @State private var inputText = ""
    @State private var parsedTemplates: [ParsedTemplate] = []
    @State private var parseError: String?
    @State private var isSaving = false

    private var athlete: Athlete? { athletes.first }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
```

**Text input + action button pattern** (lines 35-56):
```swift
                VStack(alignment: .leading, spacing: 8) {
                    Text("Paste your workout program below...")
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text2)

                    TextEditor(text: $inputText)
                        .font(.Tokens.label)
                        .frame(minHeight: 200)
                        .overlay(Rectangle().stroke(ColorTokens.divider, lineWidth: 0.5))

                    Button {
                        parseInput()
                    } label: {
                        Text("Parse")
                            .font(.Tokens.body)
                            .foregroundStyle(ColorTokens.text1)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .overlay(Rectangle().stroke(ColorTokens.divider, lineWidth: 0.5))
                    }
                    .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(16)
```

---

### `WorkloadApp/Views/WorkoutLog/ShareImportPreviewSheet.swift` (component, request-response)

**Analog:** `WorkloadApp/Views/WorkoutLog/TemplatePreviewSheet.swift`

**Template preview layout** (lines 12-71) -- header, sport/session subtitle, weekday row, group list, set summary, notes:
```swift
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(template.templateName)
                        .font(.Tokens.sectionHead)
                        .foregroundStyle(ColorTokens.text1)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 4)

                    Text("\(template.sportType.displayName) - \(template.sessionType.displayName)")
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text2)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)

                    weekdayRow(scheduledDays: template.scheduledDays)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)

                    Rectangle().fill(ColorTokens.divider).frame(height: 0.5)

                    ForEach(template.sortedGroups, id: \.id) { group in
                        Text(group.groupName.uppercased())
                            .font(.Tokens.micro)
                            .tracking(1.2)
                            .foregroundStyle(ColorTokens.text3)
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                            .padding(.bottom, 4)

                        ForEach(group.sortedExercises, id: \.id) { exercise in
                            HStack {
                                Text(exercise.exerciseName)
                                    .font(.Tokens.body)
                                    .foregroundStyle(ColorTokens.text1)
                                Spacer()
                                Text(setSummary(exercise))
                                    .font(.Tokens.label)
                                    .foregroundStyle(ColorTokens.text2)
                                    .monospacedDigit()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .background(ColorTokens.background)
```

**Weekday row helper** (lines 98-110):
```swift
    private func weekdayRow(scheduledDays: [Int]) -> some View {
        let days = ["M", "T", "W", "T", "F", "S", "S"]
        return HStack(spacing: 8) {
            ForEach(Array(days.enumerated()), id: \.offset) { index, initial in
                let isoDay = index + 1
                Text(initial)
                    .font(.Tokens.label)
                    .foregroundStyle(scheduledDays.contains(isoDay)
                        ? ColorTokens.text1
                        : ColorTokens.text3)
            }
        }
    }
```

**Set summary helper** (lines 114-124):
```swift
    private func setSummary(_ exercise: TemplateExercise) -> String {
        let sets = exercise.sortedSets.filter { !$0.isWarmup }
        guard !sets.isEmpty else { return "\(exercise.sets.count) sets" }
        if let reps = sets.first?.targetReps, let weight = sets.first?.targetWeightKg {
            return "\(sets.count) x \(reps) @ \(Int(weight))kg"
        } else if let reps = sets.first?.targetReps {
            return "\(sets.count) x \(reps)"
        }
        return "\(sets.count) sets"
    }
```

---

### `WorkloadApp/App/AppRouter.swift` (modify -- add universal link route)

**Analog:** self, lines 31-43

**Existing deep link handling pattern** -- add template share route alongside invite route:
```swift
        .onOpenURL { url in
            // Google Sign-In callback
            if GIDSignIn.sharedInstance.handle(url) { return }

            if let code = InviteService.handleDeepLink(url) {
                pendingInviteCode = PendingInvite(code: code)
                return
            }
            // Supabase OAuth callback fallback
            Task {
                try? await container.supabase.auth.session(from: url)
            }
        }
        .sheet(item: $pendingInviteCode) { pending in
            InviteConfirmationSheet(code: pending.code, mode: .athleteAccepting)
                .environment(container)
        }
```

**New state var pattern** (line 14) -- matches `PendingInvite` identifiable wrapper:
```swift
struct PendingInvite: Identifiable {
    let id = UUID()
    let code: String
}
// Add analogous:
// struct PendingShareCode: Identifiable { let id = UUID(); let code: String }
```

---

### `WorkloadApp/Views/WorkoutLog/WorkoutLogView.swift` (modify -- add Import button to toolbar)

**Analog:** self, lines 175-205

**Existing toolbar menu pattern** -- add "Import Shared Template" alongside existing menu items:
```swift
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 16) {
                        Menu {
                            Button {
                                showMyPrograms = true
                            } label: {
                                Label("My Programs", systemImage: "doc.text.fill")
                            }
                            Button {
                                if container.subscriptionService.isPro {
                                    showTextImport = true
                                } else {
                                    showUpgrade = true
                                }
                            } label: {
                                Label("Import Program (Text)", systemImage: "doc.plaintext")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .foregroundStyle(ColorTokens.text2)
                        }
```

---

### `WorkloadApp/Views/WorkoutLog/TemplateCarouselSection.swift` (modify -- add Share to context menu)

**Analog:** self, lines 305-331

**Existing context menu pattern** -- add "Share Template" button:
```swift
            .contextMenu {
                if let onPreviewTemplate {
                    Button { onPreviewTemplate(template) } label: {
                        Label("Preview", systemImage: "eye")
                    }
                }
                Button { onEditTemplate(template) } label: {
                    Label("Edit Template", systemImage: "pencil")
                }
                Button { duplicateTemplate(template) } label: {
                    Label("Duplicate Template", systemImage: "doc.on.doc")
                }
                // ... more items ...
                Divider()
                Button(role: .destructive) { ... } label: {
                    Label("Delete Template", systemImage: "trash")
                }
            }
```

---

### `workload management/workload management/workload management.entitlements` (modify -- add Associated Domains)

**Analog:** self (current file)

**Current entitlements** (full file):
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.healthkit</key>
    <true/>
    <key>com.apple.developer.healthkit.access</key>
    <array/>
    <key>com.apple.developer.applesignin</key>
    <array>
        <string>Default</string>
    </array>
</dict>
</plist>
```

Add `com.apple.developer.associated-domains` key with `applinks:tuwa.app` value.

---

## Shared Patterns

### Template JSON Serialization
**Source:** `WorkloadApp/Services/SyncService.swift` lines 1318-1354
**Apply to:** `TemplateSharingService.swift` (share creation and import)
```swift
    static func encodeGroups(_ groups: [ExerciseGroup]) -> String? {
        let dtos = groups.sorted(by: { $0.orderIndex < $1.orderIndex }).map { GroupDTO(from: $0) }
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(dtos) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func decodeGroups(from json: String) -> [ExerciseGroup] {
        let decoder = JSONDecoder()
        guard let data = json.data(using: .utf8),
              let dtos = try? decoder.decode([GroupDTO].self, from: data) else { return [] }
        return dtos.enumerated().map { index, dto in
            let group = ExerciseGroup(groupName: dto.groupName, orderIndex: index)
            group.exercises = dto.exercises.enumerated().map { eIdx, exDTO in
                let exercise = TemplateExercise(
                    exerciseName: exDTO.exerciseName,
                    exerciseCategory: ExerciseCategory(rawValue: exDTO.exerciseCategory) ?? .compound,
                    muscleGroup: exDTO.muscleGroup.flatMap { MuscleGroup(rawValue: $0) },
                    orderIndex: eIdx
                )
                exercise.sets = exDTO.sets.enumerated().map { sIdx, setDTO in
                    TemplateSet(
                        setIndex: sIdx,
                        targetReps: setDTO.targetReps,
                        targetWeightKg: setDTO.targetWeightKg,
                        targetDurationSeconds: setDTO.targetDurationSeconds,
                        targetDistanceMeters: setDTO.targetDistanceMeters,
                        targetRPE: setDTO.targetRPE,
                        targetRIR: setDTO.targetRIR,
                        isWarmup: setDTO.isWarmup
                    )
                }
                return exercise
            }
            return group
        }
    }
```

### Deep Copy with Weight Stripping
**Source:** `WorkloadApp/Models/WorkoutTemplate.swift` lines 56-87
**Apply to:** `TemplateSharingService.swift` (import logic)
```swift
    func deepCopyGroups() -> [ExerciseGroup] {
        sortedGroups.map { group in
            let newGroup = ExerciseGroup(
                groupName: group.groupName,
                orderIndex: group.orderIndex
            )
            newGroup.exercises = group.sortedExercises.map { exercise in
                let newExercise = TemplateExercise(
                    exerciseName: exercise.exerciseName,
                    exerciseCategory: exercise.exerciseCategory,
                    muscleGroup: exercise.muscleGroup,
                    orderIndex: exercise.orderIndex
                )
                newExercise.sets = exercise.sortedSets.map { set in
                    TemplateSet(
                        setIndex: set.setIndex,
                        targetReps: set.targetReps,
                        targetWeightKg: set.targetWeightKg,  // <-- strip this to nil on import
                        targetDurationSeconds: set.targetDurationSeconds,
                        targetDistanceMeters: set.targetDistanceMeters,
                        targetRPE: set.targetRPE,
                        targetRIR: set.targetRIR,
                        isWarmup: set.isWarmup
                    )
                }
                return newExercise
            }
            return newGroup
        }
    }
```

### Codable Row Pattern (Supabase insert/select)
**Source:** `WorkloadApp/Services/SyncService.swift` lines 1371-1406
**Apply to:** `TemplateSharingService.swift` (SharedTemplateInsert, SharedTemplateResponse structs)
```swift
struct WorkoutTemplateRow: Codable {
    let id: UUID
    let coachId: UUID
    let templateName: String
    let sportType: String
    let sessionType: String
    let notes: String?
    let groupsJson: String?
    let createdAt: Date
    let updatedAt: Date
    let isAthleteOwned: Bool
    let athleteId: UUID?
    let isFavorite: Bool
    let isArchived: Bool
    let lastUsedAt: Date?
    let usageCount: Int
    let scheduledDays: [Int]?

    init(from model: WorkoutTemplate) {
        // ... map model fields to Codable properties
        self.groupsJson = SyncService.encodeGroups(model.groups)
    }
}
```

### Design System Tokens
**Source:** DESIGN.md (referenced in all view files)
**Apply to:** All three new sheet files
- Font: `Font.Tokens.body`, `.Tokens.label`, `.Tokens.sectionHead`, `.Tokens.micro`
- Colors: `ColorTokens.text1`, `.text2`, `.text3`, `.background`, `.divider`
- Borders: `Rectangle().stroke(ColorTokens.divider, lineWidth: 0.5)` -- never RoundedRectangle
- Spacing: multiples of 8pt only (8, 16, 24, 32, 48)
- No shadows, no rounded corners

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `tuwa.app/.well-known/apple-app-site-association` | config | -- | Static JSON file hosted externally; no iOS codebase analog. Use RESEARCH.md AASA example. |
| `tuwa.app/index.html` | component | -- | External landing page; no iOS codebase analog. Use RESEARCH.md landing page example. |

## Metadata

**Analog search scope:** `WorkloadApp/Services/`, `WorkloadApp/Views/WorkoutLog/`, `WorkloadApp/App/`, `WorkloadApp/Models/`, `workload management/`
**Files scanned:** 12 analog candidates read
**Pattern extraction date:** 2026-05-13
