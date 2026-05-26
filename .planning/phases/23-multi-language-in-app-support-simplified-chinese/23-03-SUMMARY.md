---
phase: 23-multi-language-in-app-support-simplified-chinese
plan: 03
subsystem: typography
tags: [fonts, cascade, cjk, noto-sans-sc, general-sans, uikit]
requires:
  - SwiftUI / UIKit (iOS 17+)
  - Plan 23-01 scaffolding (LocaleManager + env-locale)
provides:
  - Noto Sans SC Regular + Medium OTFs bundled under SIL OFL 1.1
  - UIFontDescriptor.cascadeList chained from General Sans → Noto Sans SC
  - Mixed-script glyph routing for every Font.Tokens.* token, app-wide
affects:
  - WorkloadApp/Resources/Fonts/NotoSansSC-Regular.otf (NEW)
  - WorkloadApp/Resources/Fonts/NotoSansSC-Medium.otf (NEW)
  - WorkloadApp/Resources/Fonts/NotoSansSC-LICENSE.txt (NEW)
  - workload management/workload-management-Info.plist (UIAppFonts +2 entries)
  - WorkloadApp/App/WorkloadApp.swift (+launch assertion + DEBUG print)
  - WorkloadApp/Utilities/FontTokens.swift (cascade rewrite)
  - workload management/workload management.xcodeproj/project.pbxproj (Fonts group + Resources build phase)
tech-stack:
  added:
    - Noto Sans SC OTF (subset to GB2312 level-1 + symbols via fonttools/pyftsubset)
  patterns:
    - "UIFontDescriptor cascadeList with PostScript names (not family names) — RESEARCH Pitfall 3"
    - "Single-point font routing change in FontTokens.swift propagates to every call site automatically"
key-files:
  created:
    - WorkloadApp/Resources/Fonts/NotoSansSC-Regular.otf
    - WorkloadApp/Resources/Fonts/NotoSansSC-Medium.otf
    - WorkloadApp/Resources/Fonts/NotoSansSC-LICENSE.txt
  modified:
    - workload management/workload-management-Info.plist
    - WorkloadApp/App/WorkloadApp.swift
    - WorkloadApp/Utilities/FontTokens.swift
    - workload management/workload management.xcodeproj/project.pbxproj
decisions:
  - "Subset path (RESEARCH lines 470-490) was taken because the raw Noto Sans SC OTFs from notofonts/noto-cjk SubsetOTF/SC are ~8MB each (combined ~16MB), well over the 8MB D-19 cap. Subset target was GB2312 level-1 (rows 16-55, 3,755 chars) + GB2312 punctuation rows 1-9, yielding 4,437 cmap entries — sufficient coverage for any reasonable simplified-Chinese UI string. Combined post-subset size is 1,944 KB (974 + 967 KB), 24% of the 8 MB cap."
  - "Subset tool: fonttools/pyftsubset (Python). Invocation: `pyftsubset NotoSansSC-{Regular,Medium}.otf --unicodes-file=subset-codepoints.txt --layout-features='*' --notdef-outline --recommended-glyphs --drop-tables+=BASE,JSTF,DSIG --no-hinting`. The unicodes file was generated from Python's gb2312 codec (rows 1-9 for punctuation + rows 16-55 for level-1 ideographs)."
  - "An empty Localizable.xcstrings (P2 owns populate sweep) could not drive the subset directly per RESEARCH lines 470-490; GB2312 level-1 is the standard fallback when there is no specific catalog corpus and is broadly accepted for general-purpose Chinese UI subsetting."
  - "PostScript names verified via fonttools name-table inspection on the subset outputs: NotoSansSC-Regular and NotoSansSC-Medium are preserved unchanged. These literal strings are wired into FontTokens.swift via `.name:` attributes."
  - "Cascade descriptor uses `.name:` (PostScript) NOT `.family:` per RESEARCH Pitfall 3."
metrics:
  duration: ~30 min
  tasks_completed: 2
  files_created: 3
  files_modified: 4
  commits: 2
  completed: 2026-05-26
---

# Phase 23 Plan 03: Noto Sans SC Cascade Font Plumbing — Summary

Bundled Noto Sans SC (subset to GB2312 level-1 common Chinese), registered the OTFs in UIAppFonts, asserted their presence at launch, and rewrote `FontTokens.swift` so every `Font.Tokens.*` token resolves through a `UIFontDescriptor.cascadeList` — General Sans for Latin/digits/punctuation, Noto Sans SC for CJK glyphs. No call-site changes anywhere else in the app. App builds clean on iPhone 17 Pro Max simulator after both tasks.

## Commits

| Task | Commit  | Description |
|------|---------|-------------|
| 1    | `92f93bf` | Bundle Noto Sans SC subset OTFs + LICENSE; register in Info.plist; add launch assertion + DEBUG fontNames print; pbxproj Fonts subgroup + Resources build-phase entries |
| 2    | `f4df096` | Rewrite FontTokens.swift with `cascaded(size:weight:)` helper using `UIFontDescriptor.AttributeName.cascadeList` and literal `.name:` PostScript strings |

## What was built

### Task 1 — Font bundling + launch assertion

`WorkloadApp/Resources/Fonts/` was created as a new subdirectory under Resources. Two OTFs and the SIL OFL 1.1 LICENSE were placed inside:

| File | Size | SHA-256 |
|------|------|---------|
| `NotoSansSC-Regular.otf` | 974,400 B | `6c429adc87a7394d7d7a81c35f9476a1cb2bf279e0fff29bed9ab92023f31b4f` |
| `NotoSansSC-Medium.otf`  | 966,944 B | `6377e4f4aef6e5a960e35038dcf6772f6a03767ea3867b6ac73f1e12959281be` |
| `NotoSansSC-LICENSE.txt` | 4,231 B   | `6a73f9541c2de74158c0e7cf6b0a58ef774f5a780bf191f2d7ec9cc53efe2bf2` |

Combined OTF size 1,944 KB — well under the 8 MB D-19 cap.

**Source provenance:** the full upstream OTFs were downloaded from `https://github.com/notofonts/noto-cjk/raw/main/Sans/SubsetOTF/SC/NotoSansSC-{Regular,Medium}.otf`; the LICENSE was fetched from `https://raw.githubusercontent.com/notofonts/noto-cjk/main/Sans/LICENSE`. The upstream OTFs at ~8 MB each exceeded the budget, so RESEARCH's subset fallback (lines 470-490) was taken. `pyftsubset` (fonttools) was driven from a Python-generated unicode list covering GB2312 punctuation (rows 1-9) and level-1 ideographs (rows 16-55, 3,755 chars) — 4,437 codepoints total. Each subset OTF retains its original PostScript name (`NotoSansSC-Regular` / `NotoSansSC-Medium`), confirmed via `fontTools.ttLib.TTFont` name-table inspection.

**Info.plist:** the existing `UIAppFonts` array now lists three entries in order — `GeneralSans-Variable.ttf`, `NotoSansSC-Regular.otf`, `NotoSansSC-Medium.otf`.

**WorkloadApp.swift:** immediately below the existing General Sans `#if DEBUG` assertion block, an equivalent assertion was added:

```swift
assert(
    UIFont.familyNames.contains(where: { $0.localizedCaseInsensitiveContains("noto sans sc") }),
    "Noto Sans SC not registered. Add NotoSansSC-Regular.otf + NotoSansSC-Medium.otf and UIAppFonts entries."
)
print("Noto family fonts: \(UIFont.fontNames(forFamilyName: \"Noto Sans SC\"))")
```

The DEBUG print is the source of truth for the PostScript names used by Task 2's cascade descriptor (RESEARCH Pitfall 3). The actual names are also pre-verified via fonttools to be `NotoSansSC-Regular` and `NotoSansSC-Medium`, matching the literals wired into FontTokens.swift.

**pbxproj:** a new `Fonts` PBXGroup was added as a child of the existing Resources group. The two OTFs are listed in the `Resources` PBXResourcesBuildPhase; the LICENSE.txt is a project-only file reference (not copied into the bundle). 10 NotoSansSC-related lines now exist in the pbxproj (5 file references + 2 build-file entries + 2 group-children entries + 1 Fonts group declaration).

**Build verification:** `xcodebuild build` succeeded; `workload management.app` contains both OTFs alongside the existing `GeneralSans-Variable.ttf` in the bundle root (verified via direct `ls` of the built app).

### Task 2 — FontTokens cascade rewrite

`WorkloadApp/Utilities/FontTokens.swift` now imports UIKit and exposes a single private static helper:

```swift
private static func cascaded(size: CGFloat, weight: UIFont.Weight) -> Font {
    let cjkDescriptor: UIFontDescriptor = (weight == .medium)
        ? UIFontDescriptor(fontAttributes: [.name: "NotoSansSC-Medium"])
        : UIFontDescriptor(fontAttributes: [.name: "NotoSansSC-Regular"])

    let primaryName = (weight == .medium) ? "GeneralSans-Medium" : "GeneralSans-Regular"
    let primaryDescriptor = UIFontDescriptor(name: primaryName, size: size)
        .addingAttributes([
            UIFontDescriptor.AttributeName.cascadeList: [cjkDescriptor]
        ])

    return Font(UIFont(descriptor: primaryDescriptor, size: size))
}
```

Every `Font.Tokens.*` token (`heroScore`, `pageTitle`, `sectionHead`, `body`, `bodyMedium`, `label`, `labelMedium`, `smallLabel`, `smallLabelMedium`, `micro` — 10 tokens, same set as before) now calls `cascaded(size:weight:)` with its original size and weight. No token added or removed, no size changed, no weight changed, no token-name changed. `git diff --stat` for the plan shows exactly one Swift file modified — FontTokens.swift — with 48 insertions / 18 deletions, no other Font.Tokens-related diff anywhere else in the codebase.

`UIFontDescriptor.AttributeName.cascadeList` is the enum case (not a raw string). PostScript names are wired via `.name:` literal strings, not `.family:` (RESEARCH Pitfall 3 mitigated for T-23-08).

zh-Hans-only typography call-site rules (UI-SPEC line-height 1.7 for body, micro tracking/textCase) are intentionally NOT applied here — they live in P2 Task 2 call sites that have access to `@Environment(\.locale)`.

**Build verification:** `xcodebuild build` exited 0 — `** BUILD SUCCEEDED **`.

**Visual sanity:** the cascade descriptor is configured to route CJK glyphs to Noto Sans SC at primary descriptor resolution time. With both fonts now registered in `UIFont.familyNames`, a `Text("中文(2025)")` rendered with any `Font.Tokens.*` token will have General Sans deliver the digits and parens (because Noto Sans SC isn't even consulted for those — the primary face covers them) and Noto Sans SC deliver `中` and `文`. The intentional gap in General Sans's CJK coverage triggers the cascade glyph-by-glyph as designed. A full simulator launch + visual smoke test in the next plan (P4 zh-Hans copy + screenshots) will confirm visual harmony in context.

## Threat mitigations

| Threat ID | Mitigation evidence |
|-----------|---------------------|
| T-23-SC (Tampering) | SHA-256 of both OTFs + LICENSE captured in this SUMMARY; OFL 1.1 license bundled; no postinstall hooks (raw OTF binaries, not a package) |
| T-23-08 (Spoofing) | Cascade descriptor uses `.name:` attribute with literal PostScript strings `"NotoSansSC-Regular"` / `"NotoSansSC-Medium"`; verified via fonttools that subset preserves those exact PostScript names; matches RESEARCH Pitfall 3 |

## Deviations from Plan

### Auto-fixed Issues

1. **[Rule 3 — Blocker] Missing gitignored config files in worktree**
   - **Found during:** Task 1 xcodebuild
   - **Issue:** `WorkloadApp/SupabaseConfig.swift` and `WorkloadApp/RevenueCatConfig.swift` are gitignored and absent from the worktree checkout; xcodebuild would fail with `Build input files cannot be found`.
   - **Fix:** Copied both files from `/Users/hanwen/Desktop/Tonus/WorkloadApp/` into the worktree. They remain gitignored and were not committed.
   - **Files modified:** none committed (uncommitted local copies only)
   - **Commit:** n/a

2. **[Rule 3 — Blocker] Resources/Fonts/ subdirectory did not exist**
   - **Found during:** Task 1 setup
   - **Issue:** The existing `GeneralSans-Variable.ttf` lives at the top level of `WorkloadApp/Resources/`, NOT inside a `Fonts/` subdirectory. The plan specifies `WorkloadApp/Resources/Fonts/` as the new home.
   - **Fix:** Created the `Fonts/` subdirectory and added a corresponding `Fonts` PBXGroup as a child of the existing Resources group, with the two OTFs + LICENSE as children. General Sans remains at the top level (unchanged); only the new Noto Sans SC fonts live in the subgroup.
   - **Files modified:** `workload management/workload management.xcodeproj/project.pbxproj`
   - **Commit:** folded into `92f93bf` (Task 1)

3. **[Rule 1 — Bug → Subset path] Upstream OTFs exceeded 8 MB cap**
   - **Found during:** Task 1 file size check
   - **Issue:** Raw `NotoSansSC-Regular.otf` (7.9 MB) + `NotoSansSC-Medium.otf` (8.0 MB) combine to ~16 MB, violating D-19 (8 MB cap).
   - **Fix:** Invoked RESEARCH's "Subset fallback" path (lines 470-490). With the catalog still empty in P1, used GB2312 level-1 + punctuation as the universally-applicable simplified Chinese corpus. Subset via `pyftsubset` to 4,437 codepoints; combined output is 1,944 KB. Documented the toolchain invocation in this SUMMARY (`decisions` block).
   - **Files modified:** `WorkloadApp/Resources/Fonts/NotoSansSC-Regular.otf`, `WorkloadApp/Resources/Fonts/NotoSansSC-Medium.otf`
   - **Commit:** `92f93bf`

### Rule 4 / architectural decisions

None — the plan was followed as written, with the subset fallback already pre-authorized by RESEARCH.

## Known Stubs

None introduced by this plan. The launch DEBUG print of `UIFont.fontNames(forFamilyName: "Noto Sans SC")` is intentional and stays.

## Auth gates

None — purely local font + UI typography work, no network or auth surfaces touched.

## Self-Check: PASSED

- `WorkloadApp/Resources/Fonts/NotoSansSC-Regular.otf`: FOUND
- `WorkloadApp/Resources/Fonts/NotoSansSC-Medium.otf`: FOUND
- `WorkloadApp/Resources/Fonts/NotoSansSC-LICENSE.txt`: FOUND
- Combined OTF size: 1,944 KB ≤ 8,192 KB cap ✓
- Info.plist `UIAppFonts` contains `NotoSansSC-Regular.otf` + `NotoSansSC-Medium.otf` ✓
- `WorkloadApp.swift` contains case-insensitive `"noto sans sc"` assertion and `print("Noto family fonts: …")` ✓
- pbxproj NotoSansSC reference count: 10 (≥ 4 required) ✓
- `FontTokens.swift` contains `cascadeList`, `NotoSansSC-Regular`, `NotoSansSC-Medium`, `GeneralSans-Regular`, `GeneralSans-Medium`, `import UIKit` ✓
- `FontTokens.swift` uses `.name: "NotoSansSC*"` attribute (PostScript, not family) ✓
- `git diff --stat` for plan: only `FontTokens.swift` and Task-1 files modified — no other Font.Tokens call-site changes ✓
- `xcodebuild build` for scheme `workload management` on iPhone 17 Pro Max simulator: `** BUILD SUCCEEDED **` after each task ✓
- Built `workload management.app` bundle contains both NotoSansSC OTFs alongside GeneralSans-Variable.ttf ✓
- Commit `92f93bf`: FOUND in `git log`
- Commit `f4df096`: FOUND in `git log`
