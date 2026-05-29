# 21-01 Summary — RadialPicker component + RadialSelectable + enum conformances

**Status:** Complete · Build GREEN

## What shipped
- `WorkloadApp/Components/RadialPicker.swift` (new):
  - `protocol RadialSelectable: CaseIterable, Hashable, Identifiable { displayName; radialIcon }`
  - `struct RadialRingGeometry` — pure, SwiftUI-free ring math: `angle(forIndex:)` (-90° top, clockwise, even spacing for any N>=2), `point(forIndex:radius:)`, `highlightIndex(for:)` (dead-zone inner 64pt + cancel outer `diameter*0.75`, nearest-sector resolution). `internal` access so both test files reach it via `@testable`.
  - `struct RadialPicker<Option: RadialSelectable>(selection:title:diameter:)` — collapsed 0pt-corner tile, long-press(0.3s)+drag gesture, medium-impact on open, selection-feedback on each highlight change, medium-impact on commit, easeOut(250ms) open / easeIn(250ms) close (zeroed under Reduce Motion), 8pt grid (diameter 240, deadZone 64, icon 24, padding 16). Accessibility fallback: under VoiceOver OR Reduce Motion the long-press is replaced by a standard `Menu`; ring options are accessibility elements.
- `WorkloadApp/Models/Enums.swift`: added `SessionType.systemImage` (strength=dumbbell.fill, skill=figure.cooldown, cardio=heart.fill, match=flag.checkered, recovery=bed.double.fill) + `SportType`/`SessionType: RadialSelectable` (radialIcon bridges systemImage). Purely additive — no case/rawValue/Codable change.
- `WorkloadAppTests/RadialPickerGeometryTests.swift` (new): angular layout (N=5,7), point quadrants, dead-zone/cancel classification, per-index round-trip resolution.
- `project.pbxproj`: registered RadialPicker.swift (fileRef + buildFile + Components group + app Sources phase). Test file auto-included via WorkloadAppTests `fileSystemSynchronizedGroups`.

## Design compliance
- grep clean: no `RoundedRectangle`, `.shadow(`, `ColorTokens.accent`, `.system(` in RadialPicker.swift.
- No `import HealthKit`/`SwiftData`/`Supabase` — no data-layer coupling.
- Only the functional ring is circular (D-10); all rectangular sub-elements use `Rectangle()` + hairline `divider` border. Selected/highlighted = text1 + text1 border; unselected = text2.

## Verification
- `xcodebuild build` → `** BUILD SUCCEEDED **`.
- Unit tests: `xcodebuild test` crashes the test HOST on launch (pre-existing `assertionFailure` font-registration blocker in App/WorkloadApp.swift, confirmed in Phase 22 — NOT a regression, NOT touched). Geometry logic validated via standalone Swift snippet: ALL PASS (0 failures) covering every assertion in RadialPickerGeometryTests.

## Deviations
- Chip icon sizing uses `Font.Tokens.sectionHead` (not `.system(size:)`) to keep the source `.system(`-free for the Plan 03 compliance grep; 24pt footprint enforced via `.frame`.
