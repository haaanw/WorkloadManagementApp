# 21-02 Summary — RadialPicker integration into both sheets

**Status:** Complete · Build GREEN

## What shipped
- `WorkloadApp/Views/WorkoutLog/ActiveWorkoutSheet.swift`: replaced the two `.pickerStyle(.segmented)` Pickers with `RadialPicker(selection: $sportType, title: "Sport Type")` and `RadialPicker(selection: $sessionType, title: "Session Type")`. The `.onChange(of: sportType)` that resets `sessionType = defaultSessionType(for:)` is retained, attached to the sport RadialPicker — sport→session reset behavior preserved.
- `WorkloadApp/Views/Coach/TemplateEditorSheet.swift` (the IN-BUILD Coach copy): replaced the two segmented Pickers with `RadialPicker(selection: $sportType, title: "Sport")` and `RadialPicker(selection: $sessionType, title: "Type")`. Straight swap (no onChange existed).

## Untouched (per plan)
- Save paths, prefill (loadTemplate/loadPrescription), ExercisePickerView wiring, bindings, VStack(spacing:16)/16pt padding/surface background — unchanged.
- `WorkloadApp/Views/TemplateEditorSheet.swift` (stale duplicate, not in build target) — NOT modified (git-diff guard passed: `stale-dup-untouched-OK`).

## Verification
- Each edited file contains exactly 2 `RadialPicker` instances bound to `$sportType`/`$sessionType`.
- No `.pickerStyle(.segmented)` remains in either file.
- Stale duplicate untouched in git diff.
- `xcodebuild build` → `** BUILD SUCCEEDED **`.

## Deviations
- None.
