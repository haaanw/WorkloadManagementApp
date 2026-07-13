# Stage 0 Brief — DESIGN.md v3 "Tuwa Editorial / Ink & Grain"

Lane contract for the Stage 0 worker. Orchestrator verifies + commits. Read `.planning/orchestration/2026-07-14-v16-ui-polish.md` (esp. decision D2) first.

## Mission
Rewrite the design system's LAW layer to the Ink & Grain treatment, and make the enforcement layer (tokens + design-fence tests + docs) match. NO screen-level restyling — that's Stages 1–3.

## The Ink & Grain spec (LOCKED, user decision 2026-07-14)
Reference render: `.planning/design-reference/tuwa-c3-vs-d1.html` (middle column, "Ink & Grain").
1. **Serif display voice**: Source Serif 4 Variable, weight 400, tracking ≈ -0.03em, line-height ≈ 0.95. Used ONLY for: hero readiness score + verdict headline. App-authored strings only — NEVER user content (session names, exercise names, notes). Everything else stays General Sans (Regular/Medium).
2. **Corners**: 0pt-everywhere rule RETIRED. New CornerTokens: `card = 12`, `control = 8` (inputs/segmented), `pill = .infinity` (CTAs/chips). Hairline borders stay; still NO shadows.
3. **Halftone signature**: accent-colored dot grid (r ≈ 1.2pt on 8pt spacing, opacity ≈ 0.45, 135° fade mask). Rule: **hero plane only** — one surface per screen max, never decorative elsewhere. Must be fenced.
4. **Accent rule v3**: accent appears ONLY as (a) hero readiness number, (b) verdict CTA fill (pill), (c) halftone signature, (d) existing live-state semantics from UI v2. Never decorative.
5. Unchanged: entire palette (light-only — ColorTokens forces light), 8pt spacing grid, hairlines-not-shadows, zone-communication-by-label rule.

## Work items
1. **Bundle Source Serif 4 Variable** (`SourceSerif4-Variable.ttf`, from Google Fonts / github.com/adobe-fonts/source-serif — OFL licensed): add to `WorkloadApp/Resources/Fonts/`, register in project.pbxproj (PBXFileReference + Resources phase) AND the Info.plist fonts array (check how GeneralSans-Variable is registered in `workload management/workload-management-Info.plist` — mirror it).
2. **FontTokens** (`WorkloadApp/Utilities/FontTokens.swift` or wherever Font.Tokens lives): add `displayScore` + `displayVerdict` serif styles (size TBD by Stage 1 — expose sizes as parameters/constants; hero score target ≈ 76–88pt, verdict ≈ 24–26pt). Follow the existing cascaded() CJK pattern for fallback safety — but note serif roles render app-authored EN/zh strings only; zh verdict strings fall back to Noto Sans SC (acceptable; do NOT bundle a serif CJK font).
3. **CornerTokens**: new `WorkloadApp/Utilities/CornerTokens.swift` (register in pbxproj) with the scale above + doc comments carrying the law.
4. **HalftoneField component**: `WorkloadApp/Components/HalftoneField.swift` — SwiftUI Canvas/pattern view implementing the dot field + fade mask, parameterized (size, opacity), defaulting to spec values.
5. **DESIGN.md v3 rewrite**: update the rules sections — corner law, type law (two-voice system), accent law v3, halftone law, light-only affirmation. Keep palette + spacing + elevation sections. Bump version header, date it, cite the decision.
6. **CLAUDE.md**: update the Design System block (0pt rule, General-Sans-only rule, dark-mode line are all now stale) to summarize v3 and point at DESIGN.md.
7. **Design-fence tests** (find them in WorkloadAppTests — grep "fence" / "design"): flip assertions — RoundedRectangle/cornerRadius now LEGAL per CornerTokens; serif font legal in the two display roles; halftone only via HalftoneField. Add fences where cheap: no `.shadow(`, no hardcoded hex in Views, spacing multiples of 4 minimum.

## Hard constraints
- NO git commands. Orchestrator commits.
- Localizable.xcstrings additive only. New source files registered in pbxproj.
- Do NOT restyle screens; only law + token + fence + the one new component.
- AppShell.swift / AppShellUIKitPrimitives.swift: DO NOT touch (retired but must compile).
- Build gate (must pass, report honestly): `xcodebuild -project "workload management/workload management.xcodeproj" -scheme "workload management" -destination "id=8E872500-703D-4292-9758-38ADFCCFB126" -derivedDataPath ~/.tonus-dd build` — do NOT run `test` (orchestrator runs the suite; avoids concurrent-xcodebuild contention).

## Deliverable
Report: files touched + why; the exact new law text added to DESIGN.md; fence tests changed (old vs new assertion); font licensing note; build result verbatim.
