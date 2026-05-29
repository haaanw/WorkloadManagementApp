# 21-03 Summary — Behavior/genericity/compliance tests + docs hygiene

**Status:** Complete · Build GREEN

## What shipped
- `WorkloadAppTests/RadialPickerInteractionTests.swift` (new): commit (in-sector -> correct option) + cancel (dead-zone -> nil, beyond-cancel -> nil) for BOTH SportType (7) and SessionType (5); each-placement-resolves-to-own-case round-trips; genericity witnesses (`RadialPicker<SportType>`/`<SessionType>` type-check, radialIcon==systemImage, case counts); a source-compliance test reading RadialPicker.swift (via `#filePath`) asserting no `RoundedRectangle`/`.shadow(`/`ColorTokens.accent`/`.system(`. Auto-included via WorkloadAppTests `fileSystemSynchronizedGroups` (no pbxproj edit needed). `RadialRingGeometry` was already `internal` — no access-level change required.
- `.planning/ROADMAP.md`: Phase 21 criterion 8 "Alpino font" -> "General Sans font"; Phase 21 Plans list fixed from erroneous 17-xx entries to the real 21-01/02/03 descriptions.
- `DESIGN.md`: annotated the 2026-05-10 Alpino decisions-log row "(superseded 2026-05-11 -> General Sans)".

## Verification
- ROADMAP Phase 21 block: no "Alpino font", contains "General Sans font" + the three 21-0x plan entries.
- DESIGN.md: "superseded 2026-05-11" annotation present; Typography section already General Sans.
- RadialPicker.swift source: grep-clean of all four forbidden tokens.
- `xcodebuild build` -> `** BUILD SUCCEEDED **`. Test target compiles (no compile errors).
- `xcodebuild test` crashes the test HOST on launch (pre-existing font `assertionFailure` blocker, confirmed Phase 22 — NOT a regression, WorkloadApp.swift NOT modified). Commit/cancel + genericity logic validated via standalone Swift snippet for both real enum case orderings: ALL PASS (0 failures).

## Deviations
- Source-compliance check implemented as an in-test file read (via `#filePath`) AND independently grep-verified, per the plan's "prefer grep" guidance — both are clean.
- ROADMAP lines 94-96 / 144-146 still show 17-xx entries; those belong to OTHER phase/milestone blocks (Phase 17), not the Phase 21 block (188-190), so they are out of scope and left untouched.
