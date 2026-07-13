# Design System — Tuwa

Created by /design-consultation · 2026-03-21 · Color temperature + contrast revision 2026-06-15 · Tuwa v2 (light-only, bolder palette + accent-as-live-state + more motion life) 2026-06-17 · **Tuwa v3 "Ink & Grain" (two-voice serif display type + corner token scale + halftone signature + accent rule v3) 2026-07-14** — treatment locked by user decision 2026-07-14 (`.planning/orchestration/2026-07-14-v16-ui-polish.md` D2; reference render `.planning/design-reference/tuwa-c3-vs-d1.html`, middle column)

## Product Context

- **What this is:** An iOS app for athlete workload management — synthesizing HRV, sleep, training load, and recovery into a single daily readiness score with plain-English explanations.
- **Who it's for:** Serious amateur athletes (competitive runners, CrossFitters, club-level team sport athletes) who want to understand their body, not just collect data. Scales to professional teams and coaches.
- **Space / industry:** Sports performance, training load management, recovery science. Competing with Whoop, Garmin Connect, Apple Fitness+, TrainingPeaks, Strava.
- **Project type:** iOS native app (SwiftUI + SwiftData + HealthKit). No third-party UI frameworks.

## Aesthetic Direction

- **Direction:** Tuwa Editorial ("Ink & Grain") — the precision instrument acquires an editorial voice. The instrument discipline stays (structure is the aesthetic; every element earns its place), but the two decision moments — the readiness score and the verdict — now speak in a serif display voice, surfaces carry a quiet corner radius, and the hero plane bears one signature texture.
- **Decoration level:** Near-none. No gradients, no shadows, no ornamental elements — with exactly ONE sanctioned texture: the halftone signature on the hero plane (see Halftone Law). Hierarchy is achieved through proportion, spacing, type voice, and plane contrast.
- **Mood:** Quiet confidence. Tuwa is not aggressive or energetic (cf. Whoop's red, Strava's orange). It is calm, authoritative, and precise — like a high-end chronograph, not a scoreboard.
- **Design references:** Barcelona Pavilion (Mies van der Rohe, 1929), Seagram Building (Mies, 1958), Braun product design (Dieter Rams), Apple Health app (restrained data presentation).

## Typography — the Two-Voice Type Law (v3, 2026-07-14)

The app speaks in exactly two type voices:

1. **Instrument voice — General Sans** (rationalist neo-grotesque, Regular 400 + Medium 500 only). Everything: titles, sections, body, labels, metrics, controls, chrome. Hierarchy through size and the single weight step. No bold, no italic.
2. **Display voice — Source Serif 4** (variable, weight 400 only). Used for EXACTLY TWO roles and nothing else:
   - the **hero readiness score** (`Font.Tokens.displayScore`), and
   - the **verdict headline** (`Font.Tokens.displayVerdict`).

**Display-voice hard rules:**
- **App-authored strings only.** The serif never renders user content — session names, exercise names, notes, or anything typed by the athlete. (This also sidesteps CJK mixing: no serif CJK font is bundled; zh display strings cascade to Noto Sans SC, which is acceptable and intentional.)
- Weight 400 only. No serif at any other size, role, or surface — a serif section header or serif body copy is a design error the fence tests reject.
- Hero score: tracking ≈ **-0.03em**, line-height ≈ **0.95**, tabular numerals, accent color.
- Verdict headline: tracking ≈ **-0.01em**, line-height ≈ **1.1**, `--text-1`.

- **Tabular numerals:** Apply `.monospacedDigit()` (SwiftUI) to all numeric metric displays.
- **Micro / caps:** General Sans Regular, 12pt, `--text-3`, letter-spacing +0.10em, all-caps.

### Type Scale

| Role          | Size    | Face           | Weight | Color Token | Notes                                   |
|---------------|---------|----------------|--------|-------------|------------------------------------------|
| Hero score    | ≈76–88pt (token: 84) | Source Serif 4 | 400 | --accent | Tabular, -0.03em, line-height 0.95; Stage 1 tunes final pt on device |
| Verdict head  | ≈24–26pt (token: 25) | Source Serif 4 | 400 | --text-1 | -0.01em, line-height 1.1                 |
| Page title    | 32pt    | General Sans   | 400    | --text-1    |                                          |
| Section head  | 19pt    | General Sans   | 500    | --text-1    |                                          |
| Body          | 17pt    | General Sans   | 400    | --text-1    | Line-height 1.6                          |
| Label         | 15pt    | General Sans   | 400    | --text-2    |                                          |
| Small label   | 13pt    | General Sans   | 400    | --text-2    |                                          |
| Micro / cap   | 12pt    | General Sans   | 400    | --text-3    | +0.10em tracking, caps                   |

### Font Loading (iOS)

Bundle `GeneralSans-Variable.ttf` and `SourceSerif4-Variable.ttf` (variable fonts) in the Xcode project. Register via `Info.plist` → `UIAppFonts`. Reference in SwiftUI via `FontTokens.swift` only: `.font(.Tokens.body)`, `.font(.Tokens.displayScore)`. The single chokepoint for the serif's PostScript name (`SourceSerif4Roman-Regular`) is `FontTokens.serifDisplay(size:)` — no other file may name the serif.

Sources: https://www.fontshare.com/fonts/general-sans (ITF FFL license) · Source Serif 4 from Google Fonts / github.com/adobe-fonts/source-serif (SIL OFL 1.1 — license bundled at `WorkloadApp/Resources/Fonts/SourceSerif4-LICENSE.txt`)

## Color

### Light Mode — Tuwa v2 (revised 2026-06-27)

Tuwa is intentionally light-only. The app forces light appearance at the scene and UIKit-controller layers; this is a product choice, not a fallback. The ladder is inverted vs v1: the **page is the darker plane, cards are lighter**, so cards lift off the page. All chrome stays cool (blue ≥ red) and avoids warm cream fitness branding.

| Token            | Hex       | Usage                                              |
|------------------|-----------|----------------------------------------------------|
| `--bg`           | `#ECEEF1` | Cool gallery-grey page (not cream, not white)     |
| `--surface`      | `#F0F2F5` | Cool off-white — inline strip plane               |
| `--surface-el`   | `#F8FAFC` | Card plane — near-white, lifts off the page        |
| `--surface-el-2` | `#FCFDFE` | Emphasis plane — brightest card (hero / active)    |
| `--divider`      | `#C0C5CB` | Hairline rules — cool neutral, crisp cut          |
| `--divider-strong`| `#A4ABB2`| Stronger hairline for emphasis cards               |
| `--text-1`       | `#14171A` | Cool near-black ink — off pure black              |
| `--text-2`       | `#565D63` | Secondary — cool mid-grey, ≥4.5:1 on cards       |
| `--text-3`       | `#767D84` | Tertiary — cool grey, ≥3:1 on cards              |
| `--accent`       | `#2E6B86` | Cool stone-blue — "live / actionable" semantic, cooled + brighter |
| `--zone-optimal` | `#35513F` | Deep muted sage for light mode contrast           |
| `--zone-caution` | `#57532A` | Muted khaki                                       |
| `--zone-danger`  | `#6B3A3A` | Muted oxblood                                     |
| `--zone-low`     | `#384A5C` | Muted cool slate                                  |

### SwiftUI Color Tokens

**Implementation note (corrected 2026-06-27):** the tokens are NOT named color sets in `Assets.xcassets` (the catalog holds only `AccentColor` / `AppIcon` / `LaunchBackground`). They are hardcoded light-only hex literals in `ColorTokens.swift`. Retune the palette by editing those literals — there is no catalog to touch. Values:

```swift
enum ColorTokens {
    // Backgrounds — 4-plane elevation ladder
    static let background    = .light(0xECEEF1)
    static let surface       = .light(0xF0F2F5)
    static let surfaceEl      = .light(0xF8FAFC)
    static let surfaceEl2     = .light(0xFCFDFE)  // emphasis plane
    static let divider        = .light(0xC0C5CB)
    static let dividerStrong  = .light(0xA4ABB2)

    // Text
    static let text1          = .light(0x14171A)
    static let text2          = .light(0x565D63)
    static let text3          = .light(0x767D84)

    // Accent — the "live / actionable" semantic (see Accent Color Rule)
    static let accent         = .light(0x2E6B86)
    static let accentSubtle   = accent.opacity(0.16)  // active-cell / progress fills

    // Zones (label-led, supplementary) + cool-only chart series
    static let zoneOptimal    = .light(0x35513F)
    static let zoneCaution    = .light(0x57532A)
    static let zoneDanger     = .light(0x6B3A3A)
    static let zoneLow        = .light(0x384A5C)
}
```

### Elevation Ladder (revised 2026-06-27 — Tuwa v2 light-only, now 4 planes)

Four background planes, used deliberately to create depth without shadows:

| Plane          | Token        | Light     | Usage                                                            |
|----------------|--------------|-----------|------------------------------------------------------------------|
| Page           | `background` | `#ECEEF1` | The scroll canvas behind everything                              |
| Inline strip   | `surface`    | `#F0F2F5` | Flat inline regions that sit *on* the page (metrics strip, flat row lists) |
| Card           | `surfaceEl`  | `#F8FAFC` | **Default fill for any grouped/elevated card** (`cardStyle`)     |
| Emphasis       | `surfaceEl2` | `#FCFDFE` | **The most important / active surface** — hero, selected card (`emphasisCardStyle`, + `dividerStrong` border + 2pt accent top rule) |

**Revision rationale:** v2 commits to the light ladder because the app is used in bright gyms, tracks, and between-session contexts where speed of reading matters more than ambient immersion. Cards lift through plane contrast and a full 0.5pt outer border. Elevation is still plane + hairline only — never shadow (corners are a shape decision per the Corner Law, not an elevation cue).

### Separator Grammar (revised 2026-05-30)

Two — and only two — separator tools, used for two different jobs:

1. **Section break** — between top-level sections (e.g. Athlete Info → Preferences → Notifications). Communicated by a **32pt vertical gap** (`lg`) and a 19pt Medium `sectionHead` header introducing the next section. A full-width 0.5pt `divider` may optionally cap the break. Section breaks must never be a bare 8pt spacer — that was the drift that flattened the hierarchy.
2. **Row separator** — between sibling rows *inside* one section. A single 0.5pt `divider` hairline, inset 16pt from the leading edge to read as subordinate to the section break.

This gives the eye a clear two-level rhythm: heavy break (gap + header) vs light hairline (row). Section headers are 19pt Medium `--text-1` (the `sectionHead` token) — **not** 12pt micro-caps `--text-3`. Micro-caps `--text-3` labels are reserved for inline metric captions (HRV / RHR / SLEEP), never for section headers.

### Card Pattern

The single reusable card container (`cardStyle` modifier, `Components/CardStyle.swift`):

- Fill: `surfaceEl` (the card plane).
- Border: 0.5pt `divider` stroke on the card shape — never a shadow.
- Padding: 16pt horizontal (`sm`), 24pt vertical (`md`).
- Corners: `CornerTokens.card` (12pt), per the Corner Law below.

`SectionHeader` (19pt Medium `sectionHead`) and `SectionContainer` (applies the 32pt top break) are the companion primitives. All grouped UI on Dashboard and Profile is built from these — no hand-rolled background+overlay per screen.

### Accent Color Rule v3 (2026-07-14 — Ink & Grain)

**The accent is a single cool stone-blue (`#2E6B86`) — still ONE hue — used as the "live / actionable / you-are-here" semantic, in a defined, restrained set:**

1. The **hero readiness score** number (the primary instance — serif, per the Two-Voice Type Law).
2. The **verdict CTA fill** — the primary CTA is now a **filled accent pill** (`CornerTokens.pill`, accent fill, light text). This supersedes v2's outline-only CTA rule for the verdict CTA; secondary CTAs stay outlined.
3. The **halftone signature** — the accent dot field on the hero plane (see Halftone Law).
4. The existing **live-state semantics from v2**: progress / strike-zone / verdict-bar fills; active / selected states (selected cell, active segment, current tab, focused field) via `accent` or `accentSubtle`; the 2pt accent top rule on the emphasis card.

Nowhere else — never on ordinary icons, body labels, or decoration. It must read as considered and intentional, never sprayed. Zone meaning (optimal/caution/danger) is still carried by text label + zone color — **never** by the accent.

### Corner Law (v3, 2026-07-14 — the 0pt rule is RETIRED)

Every radius comes from `CornerTokens` (`Utilities/CornerTokens.swift`) — never a hand-typed literal:

| Token                 | Value    | Applies to                                                        |
|-----------------------|----------|-------------------------------------------------------------------|
| `CornerTokens.card`   | 12pt     | Cards, plates, grouped surfaces (hero, metrics strip, session rows, sheets) |
| `CornerTokens.control`| 8pt      | Controls: inputs, segmented cells, steppers, pickers, small interactive plates |
| `CornerTokens.pill`   | capsule  | Primary CTAs and chips (prefer `Capsule()`)                       |

What corners do NOT relax:
- **Hairline borders stay** — 0.5pt `divider` / `dividerStrong` strokes on the rounded shape.
- **Still NO shadows** — elevation remains plane contrast + hairline, never blur.

### Halftone Law (v3, 2026-07-14 — the one signature texture)

The halftone field is the single sanctioned texture in the app: an **accent-colored dot grid** (dot radius ≈ 1.2pt on the 8pt grid, opacity ≈ 0.45) fading out along a **135° mask** (top-leading ink → bottom-trailing clear at ≈72%). Implemented once, in `Components/HalftoneField.swift` — never hand-rolled.

- **Hero plane only.** At most ONE halftone surface per screen — the hero readiness card. Never decorative elsewhere: not on metrics, rows, sheets, banners, empty states, or backgrounds.
- Reference geometry: ≈130×130pt anchored to the hero card's top-trailing corner, clipped by the card.
- Always non-interactive (`allowsHitTesting(false)`) and hidden from accessibility.
- This rule is fenced by the design-fence tests.

### App Icon Color Rule

The App Store / launcher icon uses the same light-only Tuwa palette instead of the old cream multicolor direction. The icon field is `--bg` (`#ECEEF1`), grid lines are `--divider`, and the figure is remapped into `--accent`, `--text-1`, `--divider-strong`, and the muted zone tokens. The original icon artwork is preserved as `AppIcon-1024-original.png`; the active submitted asset is `AppIcon-1024.png`.

### Zone Color Rule

Zone colors are desaturated to near-gray intentionally. They are not vivid alarms. Zone state is communicated primarily through text labels ("Optimal" / "Caution" / "High Risk") — the color is supplementary. This is the correct approach for accessibility: color is additive, not the sole information channel.

### Color Temperature & Contrast (revised 2026-06-15)

The neutral ramp is **cool true-neutral** — every chrome token has blue channel ≥ red (no warm/taupe/cream bias ever). Contrast floors are enforced: primary text ≥13:1, secondary ≥4.5:1, micro-caps `--text-3` ≥3:1, dividers a visible ≥1.5:1 luminance step. Pure `#FFFFFF` and `#000000` are never used (Philo never uses pure black); text sits just off the extremes. Olive/oxblood/slate appear ONLY as muted, label-paired zone strips — never in the chrome, never as the second accent.

## Spacing

- **Base unit:** 8pt
- **Density:** Comfortable — generous internal padding, deliberate vertical rhythm
- **Structural spacing values must be multiples of 8pt.** No 10pt, no 12pt, no 6pt structural gaps.
- **Typographic micro-gap:** `baselinePair` is a sanctioned 4pt gap only between a micro/caption label and the value it labels. Use nowhere else.

| Token | Value | Usage                                      |
|-------|-------|--------------------------------------------|
| xs    | 8pt   | Icon-label gaps, tight inline spacing      |
| sm    | 16pt  | Card internal padding (horizontal), small gaps |
| md    | 24pt  | Card internal padding (vertical), standard gaps |
| lg    | 32pt  | Section gaps                               |
| xl    | 48pt  | Major section breaks                       |
| 2xl   | 64pt  | Page-level top/bottom breathing room       |

## Layout

- **Approach:** Grid-disciplined. Single scrollable canvas per tab. No nested scroll views except charts.
- **Border radius:** From `CornerTokens` only — card 12pt / control 8pt / pill (see Corner Law). The 0pt-everywhere rule was retired 2026-07-14.
- **Shadows:** None. Surface elevation is indicated by hairline border rules (`--divider`, 0.5pt) only.
- **Grid:** 16pt horizontal margins. 2-column grid for secondary metric cells. 1-column for rows.
- **Tab bar:** 4 tabs — Dashboard, Workout, Recovery, Profile.

### Dashboard Layout (Top → Bottom)

1. **Navigation bar** — date (micro-caps) + page title (28pt). 16pt horizontal padding.
2. **Hero readiness card** — full width. Contains: section label (micro-caps), score (56pt accent), hairline divider, reasoning text (13pt secondary), recommendation (13pt primary). 24pt vertical padding.
3. **Metrics strip** — 3-column grid (HRV / RHR / Sleep). 16pt padding. Hairline vertical dividers.
4. **Training Load section** — ACWR value, zone badge, simple bar (1pt height), ATL/CTL stats.
5. **Recent sessions** — flat rows with session name, metadata, and load value. No card backgrounds.
6. **Tab bar** — bottom, 4 items.

### Progressive Disclosure

- Surface layer: readiness score + top 2 reasoning factors + recommendation.
- Detail layer (tap hero card): full factor breakdown with per-factor contribution bars.
- Deep layer (tap individual factor): 28-day trend chart for that metric.
- Never surface deep data without user intention. The dashboard is a reading, not a data dump.

## Motion (revised 2026-06-17 — "more life", Tuwa v2)

- **Approach:** Considered and tactile. Motion orients *and* makes the instrument feel alive and responsive — every interaction acknowledges itself. Still disciplined: no cartoon bounce, no decorative animation.
- **Gentle springs are now permitted** for state-settle and entrances (low overshoot — alive, not bouncy). Screen/exit transitions stay on easing curves. This relaxes v1's "no spring physics" rule.
- **One motion language, one chokepoint** — the `Motion` token enum (in `CardStyle.swift`). NEVER a bare `withAnimation { }` (it silently uses SwiftUI's default spring) and NEVER a hand-typed duration literal.

| Token             | Curve                                  | Use                                             |
|-------------------|----------------------------------------|-------------------------------------------------|
| `Motion.state`    | `spring(response 0.30, damping 0.86)`  | Toggle / selection / press release — quick settle |
| `Motion.entrance` | `spring(response 0.42, damping 0.82)`  | Card / row / banner / sheet / list-insert entrances |
| `Motion.screen`   | `easeOut 0.28s`                        | Screen / nav-level transitions                  |
| `Motion.exit`     | `easeIn 0.20s`                         | Removals / dismissals                           |
| `Motion.scoreCountUp` | `easeOut 0.40s`                    | Hero readiness count-up (0 → score, `.numericText`) — the signature moment |

- **Press feedback:** every tappable surface uses `.buttonStyle(.pressable)` (scale 0.97 + fade, springs back via `Motion.state`). No more dead, instant taps.
- **Haptics** (commit-only, via the `Haptics` enum): `tap()` on the per-set done toggle, `success()` on workout save / PR, `warning()` on spike/caution, `select()` on picker/segmented changes. Never decorative.
- **Hero score count-up** is the built signature moment (it was specified in v1 but never implemented — v2 builds it). `reduceMotion` is honored everywhere via `Motion.resolved(_:reduceMotion:)`.

## Implementation Rules for SwiftUI

1. **Corner radii come from `CornerTokens` only** (card 12 / control 8 / pill — see Corner Law). Any file using `RoundedRectangle(cornerRadius:)` or `.cornerRadius(` must reference `CornerTokens`; a hand-typed radius literal is a design error the fence tests reject. `Capsule()` is the canonical pill shape.
2. **No `.shadow()` modifiers anywhere.** Remove existing shadow calls. Elevation = plane + hairline.
3. **All numeric Text views use `.monospacedDigit()`** to prevent layout shifts.
4. **Accent color = Accent Rule v3**: hero score, verdict CTA fill (pill), halftone signature, plus the v2 live-state semantics (progress/strike-zone fills, active/selected state, emphasis-card top rule). Never on ordinary icons, labels, or decoration — that's a design error.
5. **Zone state is always communicated through a text label + optional colored border.** Never rely on color alone.
6. **All spacing uses the design token scale.** No magic numbers. 16pt padding, 24pt padding, 8pt gaps — always multiples of 8 (4pt only as the sanctioned `baselinePair` micro-gap).
7. **Light-only appearance.** All color references use semantic tokens from `ColorTokens`. Never use literal hex values in view code. The app intentionally forces light appearance; do not add dark-mode-specific branches.
8. **Typography uses `Font.Tokens.*` only** — General Sans instrument voice everywhere, Source Serif 4 display voice via `Font.Tokens.displayScore` / `.displayVerdict` for exactly the hero score + verdict headline (see Two-Voice Type Law). Do not use `.system()` or `.headline` / `.body` semantic styles, and never name the serif outside `FontTokens.swift`.
9. **Halftone texture only via `HalftoneField`** — hero plane only, at most one per screen (see Halftone Law).

## Decisions Log

| Date       | Decision                                         | Rationale                                                                           |
|------------|--------------------------------------------------|-------------------------------------------------------------------------------------|
| 2026-03-21 | International Style Minimalism aesthetic         | Differentiates from Whoop/Strava's aggressive energy coding; aligns with "timeless" product vision |
| 2026-03-21 | Near-monochromatic palette with single accent    | Mies van der Rohe principle: one precious material, used with total commitment      |
| 2026-03-21 | Regular + Medium only, no other weights           | Hierarchy through size alone — "less is more" applied to typography                 |
| 2026-03-21 | 0pt border radius everywhere                     | Square corners reinforce the structural, instrument-like aesthetic. **Retired 2026-07-14 (v3 Corner Law).** |
| 2026-03-21 | Zone colors desaturated to near-gray             | States communicated through labels, color is supplementary — calm > alarm           |
| 2026-03-21 | Accent appears on readiness score only           | The one precious material in the design — used once, completely                     |
| 2026-03-21 | Early dark-first direction explored              | Superseded by the 2026-06-27 light-only decision.                                   |
| 2026-05-10 | Migrated from DM Sans to Alpino (superseded 2026-05-11 -> General Sans) | Geometric sans with sharper terminals -- aligns with International Style direction  |
| 2026-05-11 | Migrated from Alpino to General Sans             | Rationalist neo-grotesque — better lining figures for data-heavy UI, superior small-size readability |
| 2026-05-30 | Formalized `surfaceEl` as card plane             | Established the plane + hairline grammar that now carries the light-only material system. |
| 2026-05-30 | Two-tier separator grammar + `cardStyle`/`SectionHeader`/`SectionContainer` primitives | Section breaks (32pt gap + 19pt Medium header) vs row hairlines (inset 0.5pt). Restores hierarchy lost when section headers drifted to 12pt micro-caps and section gaps to 8pt spacers. |
| 2026-06-15 | Recooled palette to cool true-neutral + raised contrast (Philo austere direction) | Old ramp was uniformly warm (travertine accent, #C2BEB7 haze text); flagged too-warm + low-contrast. Neutralized all chrome (blue≥red), lifted text1 to #E8EAEC/13.9:1, retired travertine accent for cool putty #A6C2D0/#3C5A66, made dividers a visible cut, fixed unreadable text-3 micro-caps (1.4→3.5:1). Structure unchanged. |
| 2026-06-17 | **Tuwa v2** — bolder departure + more motion life | Audit found the 2026-06-15 recool never fully landed: light chrome still warm (red>blue), warm zone ramp flooded live UI, grouped regions lacked outer borders, and the interaction layer was unfinished. v2: cooler+brighter accent, inverted light ladder, 4th `surfaceEl2` emphasis plane + `dividerStrong`, full outer borders, cool-only chart series, live/actionable accent semantics, `Motion` tokens, `PressableButtonStyle`, `Haptics`, and hero count-up. |
| 2026-06-27 | Light-only direction confirmed                   | Dark mode was deliberately abandoned. Tuwa now treats light appearance as the only supported material expression and optimizes contrast, accent semantics, and screenshot polish there. |
| 2026-07-14 | **Tuwa v3 "Ink & Grain"** — two-voice type, corner scale, halftone signature, accent v3 | User-locked treatment pick for the v1.6 polish milestone (orchestration doc D2; reference render `tuwa-c3-vs-d1.html`, middle column). Source Serif 4 display voice for the two decision moments (hero score + verdict headline, app-authored strings only); 0pt corner rule retired for `CornerTokens` (card 12 / control 8 / pill); one sanctioned texture (accent halftone, hero plane only); verdict CTA becomes a filled accent pill. Palette, light-only, 8pt grid, hairlines-not-shadows, and zone-by-label all unchanged. |
