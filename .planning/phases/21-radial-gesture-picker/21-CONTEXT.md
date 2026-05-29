# Phase 21: Radial Gesture Picker - Context

**Gathered:** 2026-05-29
**Status:** Ready for planning

<domain>
## Phase Boundary

Build a reusable, generic SwiftUI `RadialPicker` component — an iPod-wheel-inspired circular menu — and use it to replace the two `.pickerStyle(.segmented)` selectors (sport type + session type) in **ActiveWorkoutSheet** and **TemplateEditorSheet**. A long press on the picker's collapsed label opens a circular overlay with the enum's cases arranged evenly around a ring; the user drags a finger to highlight the option under their finger (with haptic feedback on each new highlight); releasing on an option selects it and animates the ring dismissed; releasing outside the ring cancels with no change. The component is driven entirely by a `CaseIterable` enum that supplies an SF Symbol icon + a display label per case, plus a `Binding` to the selected case.

**UI + reusable-component only.** No model, repository, pipeline, engine, sync, or schema changes. The two integration sites bind to their existing `@State var sportType`/`sessionType` — the radial picker is a drop-in replacement for the segmented `Picker`, not a data-flow change.

This phase is purely additive to the view layer: one new component file (`Components/RadialPicker.swift`), one new protocol, an SF-Symbol addition to `SessionType`, and edits to two sheet views. It does not touch the stale duplicate `Views/TemplateEditorSheet.swift` (see Key Decisions / D-09).

</domain>

<decisions>
## Implementation Decisions

### Generic API surface
- **D-01:** `RadialPicker` is generic over a single type parameter constrained to a new protocol `RadialSelectable` (name chosen to avoid colliding with `Identifiable`/`CaseIterable`). The protocol requires: `CaseIterable`, `Hashable`, `Identifiable`, `var displayName: String`, `var radialIcon: String` (SF Symbol name). `SportType` already supplies `displayName` + `systemImage`; conformance maps `radialIcon => systemImage`. `SessionType` has `displayName` but **no** `systemImage` today, so Plan 01 adds a `systemImage`/`radialIcon` to `SessionType` (D-04).
- **D-02:** Public initializer shape:
  `RadialPicker<Option: RadialSelectable>(selection: Binding<Option>, title: LocalizedStringKey, diameter: CGFloat = 240)` where `Option.AllCases` drives the ring. The collapsed (resting) state renders the currently-selected option's icon + `displayName` inside a 0pt-corner `Rectangle` tile matching the segmented-control visual weight it replaces; the long-press recognizer lives on that tile.
- **D-03:** The component is self-contained: it owns the overlay presentation, the drag-hit-testing math, the haptics, the animation, and the accessibility fallback. Call sites only provide a binding + title. No call-site state for "is the ring open".

### Enum option metadata
- **D-04:** Add `var systemImage: String` to `SessionType` in `Models/Enums.swift` (currently it has only `displayName`). Suggested mapping: strength `dumbbell.fill`, skill `figure.cooldown`, cardio `heart.fill`, match `flag.checkered`, recovery `bed.double.fill`. Final symbols are Claude's discretion (must be valid SF Symbols available on iOS 17). This is additive — no rawValue or case changes, so SwiftData persistence and Supabase sync are untouched.
- **D-05:** Ring is laid out by even angular division: `angle(i) = -90° + i * (360° / count)` (first option at top, clockwise). For the project's enums this is 5–7 options (SportType has 7 cases, SessionType has 5), within the ROADMAP's stated 6–8 budget. The component must handle any count >= 2 without hard-coding 6–8.

### Interaction & haptics
- **D-06:** Gesture chain = `LongPressGesture(minimumDuration: 0.3)` to open, sequenced/simultaneous with a `DragGesture(minimumDistance: 0)` for finger tracking. On open: one `UIImpactFeedbackGenerator(style: .medium).impactOccurred()`. While dragging: the option whose angular sector + min-radius the finger is over becomes "highlighted"; each time the highlighted option *changes*, fire a lighter `UIImpactFeedbackGenerator(style: .light)` (or `UISelectionFeedbackGenerator().selectionChanged()`). Generators are created once and `.prepare()`d on open to minimize latency. Selection-commit (release on an option) fires one `.medium` impact.
- **D-07:** Hit-testing: compute the finger's vector from ring center. If its magnitude is **below an inner dead-zone radius** (e.g. `diameter * 0.25`) OR **beyond an outer cancel radius** (e.g. `diameter * 0.75`), no option is highlighted (release here = cancel). Otherwise the angle selects the nearest sector. Release-on-highlight commits; release-with-no-highlight cancels (no change to the binding). This satisfies success criteria 3, 4, 5.
- **D-08:** Animation per DESIGN.md motion rules: overlay open/close uses `.easeOut`/`.easeIn` at 250ms (screen-transition tier). **No spring, no bounce.** Highlight state change is a 150ms linear border/opacity change. The ring scales/​fades in from the collapsed tile; on commit it animates closed (criterion 4).

### Geometry vs the 0pt-corner rule
- **D-10:** DESIGN.md's "0pt corners / `Rectangle()` never `RoundedRectangle`" rule bans **rounded rectangles** — softened box corners that read as decoration. It does **not** ban genuinely circular/arc geometry. A radial picker is intrinsically circular: the ring guide, the angular sectors, and the per-option hit zones are circle math, which is an allowed primitive (`Circle`, `Path` arcs, `.rotationEffect`). The rule's intent — no softened corners, structure-as-aesthetic — is preserved because every **rectangular** element in the component (the collapsed tile, each option's icon+label chip, the dimming scrim) uses `Rectangle()` with 0pt corners and hairline `ColorTokens.divider` borders. The circle is the functional shape of the control, not ornamental rounding. This distinction is stated explicitly so a design-review pass does not flag the arcs as a violation.

### Visual system compliance
- **D-11:** Colors via `ColorTokens` only. The collapsed tile and option chips use `surface`/`surfaceEl` fills with `divider` hairline borders; selected/highlighted state is communicated by a `text1` (vs `text2`) label weight + a `text1` hairline border, **never** the accent color (accent is reserved for the hero readiness score, DESIGN.md §Accent Color Rule). Text uses `Font.Tokens.*`; icons use the same `text1`/`text2` foreground treatment. Dimming scrim uses `background.opacity(...)` (a token, not a hardcoded black).
- **D-12:** All sizing is on the 8pt grid: default ring diameter 240pt, dead-zone radius 64pt, option chip padding 16pt, icon size 24pt. No magic non-8 multiples.
- **D-13:** Localization: option labels come from `displayName` (already `String(localized:)`-backed). Any caps/tracking treatment must follow the project's English-only convention (see `ZoneBadge`: `.tracking`/`.textCase(.uppercase)` only when locale languageCode == "en"). Do not force uppercase on zh-Hans.

### Accessibility (non-gesture fallback)
- **D-14:** The picker must not be gesture-only. When VoiceOver is running (`UIAccessibility.isVoiceOverRunning` / `@Environment(\.accessibilityVoiceOverEnabled)`) **or** Reduce Motion is on (`@Environment(\.accessibilityReduceMotion)`), the long-press radial overlay is bypassed: a tap on the collapsed tile presents the options as a standard accessible list/menu (e.g. a `Menu` or a simple vertically-stacked `Rectangle`-tiled sheet of buttons, each labeled with `displayName`). The radial overlay itself also exposes each option as an `accessibilityElement` with `displayName` so explore-by-touch works. Reduce Motion additionally collapses the open/close animation to an instantaneous (0ms) state change. This satisfies the project's accessibility posture (QA-03 in REQUIREMENTS) without making the gesture the only path.

### Claude's Discretion (for planner/executor)
- Exact protocol name (`RadialSelectable`) and whether `radialIcon` is a stored alias or a default-implemented computed property bridging `systemImage`.
- Whether the open/track gesture is `SequenceGesture` vs `simultaneousGesture` — pick whichever reliably opens-then-tracks in one continuous touch on iOS 17.
- Whether the fallback uses SwiftUI `Menu` vs a custom 0pt-corner button list — either is acceptable if accessible and design-compliant.
- The exact SF Symbols for `SessionType` (must be valid on iOS 17).
- Whether to factor the ring geometry into a small private `RadialRingLayout` helper struct vs inline `GeometryReader` math.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements & Roadmap
- `.planning/ROADMAP.md` → "### Phase 21: Radial Gesture Picker" — goal + 8 success criteria + UX-01. (Note: UX-01 is not yet enumerated in REQUIREMENTS.md; the ROADMAP is the binding source for the WHAT.)

### Design System (HARD constraints)
- `DESIGN.md` — full. Enforce: 0pt corners (`Rectangle()`, never `RoundedRectangle`) for rectangular elements; circles/arcs allowed (D-10); no `.shadow()`; `Font.Tokens.*` only; 8pt grid; `ColorTokens` only; accent ONLY on hero readiness score (so NOT in this component); motion = easeOut/easeIn, no spring.

### Existing code to modify / read
- `WorkloadApp/Views/WorkoutLog/ActiveWorkoutSheet.swift` lines 51–66 — the two `.pickerStyle(.segmented)` `Picker`s (sport @ 51, session @ 61) plus the `.onChange(of: sportType)` (line 57) that resets `sessionType` via `defaultSessionType(for:)` (line 331). The radial picker must preserve this onChange behavior.
- `WorkloadApp/Views/Coach/TemplateEditorSheet.swift` lines 36–48 — the two segmented `Picker`s (sport @ 36, session @ 43). **This is the in-build TemplateEditorSheet** (referenced from the `Coach` group in `workload management.xcodeproj/project.pbxproj`).
- `WorkloadApp/Models/Enums.swift` — `SportType` (lines 5–39: has `displayName` + `systemImage`), `SessionType` (lines 280–298: has `displayName`, NO `systemImage` — add per D-04).
- `WorkloadApp/Components/MetricTile.swift` / `ZoneBadge` — canonical pattern for a 0pt-corner tile: `Rectangle().stroke(ColorTokens.divider, lineWidth: 0.5)` overlay, `Font.Tokens.*`, 16pt padding, English-only tracking/caps. Mirror this idiom.
- `WorkloadApp/Components/TimeRangeSegmentedControl.swift` — the existing custom segmented control (0pt, hairline border, selected = `bodyMedium`/`text1`, unselected = `body`/`text2`). The radial picker's collapsed tile and option chips should match this selected/unselected treatment.
- `WorkloadApp/Utilities/FontTokens.swift` — `Font.Tokens.*` scale (body, bodyMedium, label, smallLabel, micro, etc.).
- `WorkloadApp/Utilities/ColorTokens.swift` — semantic color tokens.

### Build / project file
- `workload management/workload management.xcodeproj/project.pbxproj` — the new `Components/RadialPicker.swift` file MUST be registered (PBXFileReference + PBXBuildFile + Sources phase + the `Components` PBXGroup). Per CLAUDE.md: after adding Swift files, verify the .pbxproj includes them. Existing component registrations (MetricTile, TimeRangeSegmentedControl) are the template.

### Test scheme
- Xcode project: `workload management/workload management.xcodeproj`; scheme: `workload management`; sim: `iPhone 17 Pro Max` (iOS 17+). Component logic that is pure (ring geometry / hit-testing math) should be unit-testable in `WorkloadAppTests`.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `ZoneBadge` / `MetricTile` (`Components/`) — exact 0pt-corner tile idiom (Rectangle + hairline divider border, `Font.Tokens`, 16pt padding, locale-aware tracking). Reuse this for the collapsed tile + option chips.
- `TimeRangeSegmentedControl` — the selected/unselected typographic + color treatment to mirror (`bodyMedium`/`text1` selected, `body`/`text2` unselected).
- `SportType.systemImage` + `displayName` — already supply everything `RadialSelectable` needs for sport; the protocol conformance is trivial.

### Established Patterns
- Components are plain `struct View` files in `WorkloadApp/Components/`, registered individually in the .pbxproj `Components` group.
- No existing haptic usage anywhere in the app (grep for `UIImpactFeedbackGenerator`/`.sensoryFeedback` returns nothing) — this phase introduces the first haptics. Use UIKit feedback generators (`import UIKit`), created once and `.prepare()`d (no global state, no service).
- Locale-aware caps/tracking: `ColorScheme`/locale handled inline via `@Environment(\.locale)` and a languageCode check (see `ZoneBadge`).
- Motion durations/easings are codified in DESIGN.md §Motion (150ms linear state, 250ms easeOut transitions, no spring).

### Integration Points
- ActiveWorkoutSheet: replace the two `Picker { ... }.pickerStyle(.segmented)` blocks (lines 51–66) with two `RadialPicker(selection:title:)` instances; re-attach the `.onChange(of: sportType)` that calls `defaultSessionType(for:)` to the sport picker's binding so changing sport still resets session type. Spacing stays in the existing `VStack(spacing: 16)`.
- TemplateEditorSheet (Coach): replace the two segmented `Picker`s (lines 36–48) likewise; this sheet has no `defaultSessionType` onChange, so it's a straight swap.
- Both sites already hold `@State private var sportType: SportType` and `@State private var sessionType: SessionType` — bindings pass straight through.

### Constraints carried in
- New source file → MUST update `.pbxproj` (CLAUDE.md iOS rule). Incremental build check after the component + after each integration (CLAUDE.md "every 3–5 files").
- Raw HealthKit / Supabase: untouched (no data flow change).
- `Views/TemplateEditorSheet.swift` is a STALE duplicate not in the build target (only the Coach copy is referenced in the .pbxproj). Do NOT edit the duplicate (D-09).

</code_context>

<specifics>
## Specific Ideas

- iPod click-wheel mental model: options live on a ring; the finger "scrubs" around it; the option under the finger is highlighted; lifting off commits. Center and far-outside are "no selection" zones (cancel).
- Worked interaction trace to validate against (maps to success criteria):
  1. Long-press sport tile (held 0.3s) → ring fades in (250ms easeOut), `.medium` haptic. (criterion 2)
  2. Drag finger toward "Running" sector → "Running" highlights (text1 + hairline border), `.light` haptic on the highlight change. (criterion 3)
  3. Lift finger on "Running" → binding becomes `.running`, ring animates closed, `.medium` haptic. (criterion 4)
  4. Re-open, drag to center (dead zone) and lift → no change, ring closes. (criterion 5)
- The same component instance works for both `SportType` (7 cases) and `SessionType` (5 cases) purely via the generic parameter — proving criterion 1 + 7.

</specifics>

<deferred>
## Deferred Ideas

- Per-enum custom ring ordering / favoriting of options (ROADMAP says "customizable" — interpreted as per-enum icon+label, satisfied by `RadialSelectable`; user-reorderable rings are out of scope).
- Replacing OTHER segmented pickers in the app (e.g. unit pickers, ExercisePickerView category) with the radial picker — out of scope; this phase targets only sport + session type in the two named sheets.
- Removing/cleaning up the stale `Views/TemplateEditorSheet.swift` duplicate — out of scope (separate hygiene task).

</deferred>

## Assumptions (full-auto)

1. **UX-01 = the ROADMAP Phase 21 goal + 8 success criteria.** REQUIREMENTS.md does not yet list a v1.5 / UX-01 entry (it ends at v1.3). The ROADMAP's Phase 21 block is treated as the binding requirement. (Flag: REQUIREMENTS.md should later be backfilled with UX-01 for traceability — not done in this phase.)
2. **The in-build TemplateEditorSheet is `WorkloadApp/Views/Coach/TemplateEditorSheet.swift`** (referenced in the .pbxproj Coach group). `WorkloadApp/Views/TemplateEditorSheet.swift` is a stale duplicate and will NOT be edited.
3. **"Alpino font" in success criterion 8 is stale.** The actual app font is **General Sans** via `Font.Tokens.*` (DESIGN.md decision 2026-05-11 superseded the 2026-05-10 Alpino decision; all code references `GeneralSans-*`). The phase will use `Font.Tokens.*` (General Sans, with the Noto Sans SC CJK cascade from Phase 23). No Alpino work is performed. (See font-discrepancy note below.)
4. Adding `systemImage` to `SessionType` is acceptable and non-breaking (additive enum metadata; no rawValue/case change → no sync/persistence impact).
5. Default ring diameter 240pt is a reasonable thumb-reachable size on iPhone; integration sites accept the default (no custom sizing needed).
6. Introducing UIKit haptics (first in the app) via on-demand `UIImpactFeedbackGenerator` is acceptable; no haptics service/abstraction is required for this scope.

## Font Discrepancy Finding (Alpino vs current)

ROADMAP success criterion 8 and `DESIGN.md`'s decisions log (2026-05-10) reference **Alpino**. However, the **next** decisions-log entry (2026-05-11) records a migration **from Alpino to General Sans**, and **all shipping code uses General Sans**: `App/WorkloadApp.swift` registers `GeneralSans-Regular`/`GeneralSans-Medium`; `Utilities/FontTokens.swift` builds every `Font.Tokens.*` from `GeneralSans-*` (with a Noto Sans SC cascade added in Phase 23); `PDFReportEngine.swift` uses `GeneralSans-*`. There is no Alpino font in the codebase. Memory confirms Alpino was a v1.3 backlog item that was reverted. **Resolution: the picker is planned against General Sans via `Font.Tokens.*` (the real current font). The ROADMAP/DESIGN "Alpino" reference is obsolete and should be corrected to "General Sans" in a docs-hygiene pass.**

---

*Phase: 21-radial-gesture-picker*
*Context gathered: 2026-05-29*
