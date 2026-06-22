# Design System — WorkloadApp

Created by /design-consultation · 2026-03-21 · Color temperature + contrast revision 2026-06-15 · **Tuwa v2 (bolder palette + accent-as-live-state + more motion life) 2026-06-17**

## Product Context

- **What this is:** An iOS app for athlete workload management — synthesizing HRV, sleep, training load, and recovery into a single daily readiness score with plain-English explanations.
- **Who it's for:** Serious amateur athletes (competitive runners, CrossFitters, club-level team sport athletes) who want to understand their body, not just collect data. Scales to professional teams and coaches.
- **Space / industry:** Sports performance, training load management, recovery science. Competing with Whoop, Garmin Connect, Apple Fitness+, TrainingPeaks, Strava.
- **Project type:** iOS native app (SwiftUI + SwiftData + HealthKit). No third-party UI frameworks.

## Aesthetic Direction

- **Direction:** International Style Minimalism — the visual language of a precision scientific instrument. Mies van der Rohe's principle: "Less is more." Structure is the aesthetic. Every element earns its place or it does not exist.
- **Decoration level:** None. No gradients, no shadows, no rounded corners, no ornamental elements. Hierarchy is achieved through proportion, spacing, and type weight alone.
- **Mood:** Quiet confidence. WorkloadApp is not aggressive or energetic (cf. Whoop's red, Strava's orange). It is calm, authoritative, and precise — like a high-end chronograph, not a scoreboard.
- **Design references:** Barcelona Pavilion (Mies van der Rohe, 1929), Seagram Building (Mies, 1958), Braun product design (Dieter Rams), Apple Health app (restrained data presentation).

## Typography

All hierarchy is achieved through size and one weight variation. No bold, no italic, no expressive typefaces.

- **Typeface:** General Sans — rationalist neo-grotesque, neutral, precise. Clean lining figures, excellent small-size readability. Bundle as variable `.ttf` from FontShare (ITF FFL license).
- **Weights used:** Regular (400) and Medium (500) only. No other weights. No italic.
- **Hero score:** General Sans Regular, 64pt, tabular numerals. Color: Accent only. This is the single colored text element in the UI.
- **Page title:** General Sans Regular, 32pt, `--text-1`
- **Section header:** General Sans Medium, 19pt, `--text-1`
- **Body / metric labels:** General Sans Regular, 17pt, `--text-1` or `--text-2`
- **Secondary info (label):** General Sans Regular, 15pt, `--text-2`
- **Small label:** General Sans Regular, 13pt, `--text-2`
- **Micro / caps:** General Sans Regular, 12pt, `--text-3`, letter-spacing +0.10em, all-caps
- **Tabular numerals:** Apply `.monospacedDigit()` (SwiftUI) to all numeric metric displays.

### Type Scale

| Role          | Size | Weight | Color Token | Notes                  |
|---------------|------|--------|-------------|------------------------|
| Hero score    | 64pt | 400    | --accent    | Tabular, line-height 1 |
| Page title    | 32pt | 400    | --text-1    |                        |
| Section head  | 19pt | 500    | --text-1    |                        |
| Body          | 17pt | 400    | --text-1    | Line-height 1.6        |
| Label         | 15pt | 400    | --text-2    |                        |
| Small label   | 13pt | 400    | --text-2    |                        |
| Micro / cap   | 12pt | 400    | --text-3    | +0.10em tracking, caps |

### Font Loading (iOS)

Bundle `GeneralSans-Variable.ttf` (variable font) in the Xcode project. Register via `Info.plist` → `UIAppFonts`. Reference in SwiftUI via `FontTokens.swift`: `.font(.Tokens.body)`. The variable font's weight axis selects Regular (400) and Medium (500).

Source: https://www.fontshare.com/fonts/general-sans (ITF FFL license)

## Color

### Dark Mode (Primary) — Tuwa v2 (revised 2026-06-17)

| Token            | Hex       | Usage                                              |
|------------------|-----------|----------------------------------------------------|
| `--bg`           | `#090B0D` | App background — graphite near-black, cool cast (blue ≥ red) |
| `--surface`      | `#15191D` | Inline strips — cool neutral, perceptibly lifted from background |
| `--surface-el`   | `#1F262C` | Card plane — standard cool-neutral fill for grouped/elevated cards |
| `--surface-el-2` | `#28323A` | **Emphasis plane** — the most important / active surface (hero, selected card). The 4th step. |
| `--divider`      | `#3D464D` | Hairline rules — lifted to a genuinely visible cool cut |
| `--divider-strong`| `#525E66`| Stronger hairline for emphasis cards / high-priority cuts (≥2.5:1 over fill) |
| `--text-1`       | `#ECEEF0` | Primary text — crisp cool off-white, off pure white |
| `--text-2`       | `#A2AAB0` | Secondary text — cool mid-grey, ≥4.5:1 on cards   |
| `--text-3`       | `#747C82` | Tertiary / micro labels — cool grey, ≥3:1 on cards |
| `--accent`       | `#7FB3CC` | Cool stone-blue — the "live / actionable" semantic (see Accent Color Rule); brighter/bolder than v1 |
| `--zone-optimal` | `#6E8A78` | Muted cool sage — ACWR optimal zone              |
| `--zone-caution` | `#86825E` | Cooled khaki — ACWR caution zone (label-led, never a fill) |
| `--zone-danger`  | `#9A6F6F` | Muted oxblood — ACWR high-risk zone              |
| `--zone-low`     | `#6C7886` | Muted cool slate — undertraining zone            |

### Light Mode — Tuwa v2 (revised 2026-06-17)

Ladder is inverted vs v1: the **page is the darker plane, cards are lighter**, so cards lift off the page (v1 had bg lightest, which flattened separation). All cool (blue ≥ red).

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

**Implementation note (corrected 2026-06-17):** the tokens are NOT named color sets in `Assets.xcassets` (the catalog holds only `AccentColor` / `AppIcon` / `LaunchBackground`). They are hardcoded adaptive hex literals in `ColorTokens.swift` via a `UIColor.adaptive(dark:light:)` helper. Retune the palette by editing those literals — there is no catalog to touch. Values (dark / light):

```swift
enum ColorTokens {
    // Backgrounds — 4-plane elevation ladder
    static let background    = .adaptive(dark: 0x090B0D, light: 0xECEEF1)
    static let surface       = .adaptive(dark: 0x15191D, light: 0xF0F2F5)
    static let surfaceEl      = .adaptive(dark: 0x1F262C, light: 0xF8FAFC)
    static let surfaceEl2     = .adaptive(dark: 0x28323A, light: 0xFCFDFE)  // emphasis plane
    static let divider        = .adaptive(dark: 0x3D464D, light: 0xC0C5CB)
    static let dividerStrong  = .adaptive(dark: 0x525E66, light: 0xA4ABB2)

    // Text
    static let text1          = .adaptive(dark: 0xECEEF0, light: 0x14171A)
    static let text2          = .adaptive(dark: 0xA2AAB0, light: 0x565D63)
    static let text3          = .adaptive(dark: 0x747C82, light: 0x767D84)

    // Accent — the "live / actionable" semantic (see Accent Color Rule)
    static let accent         = .adaptive(dark: 0x7FB3CC, light: 0x2E6B86)
    static let accentSubtle   = accent.opacity(0.16)  // active-cell / progress fills

    // Zones (label-led, supplementary) + cool-only chart series
    static let zoneOptimal    = .adaptive(dark: 0x6E8A78, light: 0x35513F)
    static let zoneCaution    = .adaptive(dark: 0x86825E, light: 0x57532A)
    static let zoneDanger     = .adaptive(dark: 0x9A6F6F, light: 0x6B3A3A)
    static let zoneLow        = .adaptive(dark: 0x6C7886, light: 0x384A5C)
}
```

### Elevation Ladder (revised 2026-06-17 — Tuwa v2, now 4 planes)

Four background planes, used deliberately to create depth without shadows or rounding:

| Plane          | Token        | Dark      | Light     | Usage                                                            |
|----------------|--------------|-----------|-----------|------------------------------------------------------------------|
| Page           | `background` | `#090B0D` | `#ECEEF1` | The scroll canvas behind everything                              |
| Inline strip   | `surface`    | `#15191D` | `#F0F2F5` | Flat inline regions that sit *on* the page (metrics strip, flat row lists) |
| Card           | `surfaceEl`  | `#1F262C` | `#F8FAFC` | **Default fill for any grouped/elevated card** (`cardStyle`)     |
| Emphasis       | `surfaceEl2` | `#28323A` | `#FCFDFE` | **The most important / active surface** — hero, selected card (`emphasisCardStyle`, + `dividerStrong` border + 2pt accent top rule) |

**Revision rationale:** The 2026-05-30 "widening" failed — the encoded dark ladder still sat at `surfaceEl:surface = 1.082:1` (ΔL* ~3.9, below the perceptible-contrast floor), so cards were indistinguishable from the page and the hairline border carried 100% of the separation. v2 (a) genuinely widens the dark steps to a perceptible ΔL* (~8–10), (b) lifts `divider` so the hairline actually reads, (c) adds a 4th **emphasis** plane (`surfaceEl2`) for the single most important surface on a screen, and (d) inverts the light ladder so cards (lighter) lift off the page (darker). Every grouped region must carry a **full** 0.5pt outer border — partial/absent borders were a major blend source. Elevation is still plane + hairline only — never shadow or rounding.

### Separator Grammar (revised 2026-05-30)

Two — and only two — separator tools, used for two different jobs:

1. **Section break** — between top-level sections (e.g. Athlete Info → Preferences → Notifications). Communicated by a **32pt vertical gap** (`lg`) and a 19pt Medium `sectionHead` header introducing the next section. A full-width 0.5pt `divider` may optionally cap the break. Section breaks must never be a bare 8pt spacer — that was the drift that flattened the hierarchy.
2. **Row separator** — between sibling rows *inside* one section. A single 0.5pt `divider` hairline, inset 16pt from the leading edge to read as subordinate to the section break.

This gives the eye a clear two-level rhythm: heavy break (gap + header) vs light hairline (row). Section headers are 19pt Medium `--text-1` (the `sectionHead` token) — **not** 12pt micro-caps `--text-3`. Micro-caps `--text-3` labels are reserved for inline metric captions (HRV / RHR / SLEEP), never for section headers.

### Card Pattern

The single reusable card container (`cardStyle` modifier, `Components/CardStyle.swift`):

- Fill: `surfaceEl` (the card plane).
- Border: `Rectangle().stroke(divider, width: 0.5)` — never `RoundedRectangle`, never a shadow.
- Padding: 16pt horizontal (`sm`), 24pt vertical (`md`).
- Corners: 0pt (square), always.

`SectionHeader` (19pt Medium `sectionHead`) and `SectionContainer` (applies the 32pt top break) are the companion primitives. All grouped UI on Dashboard and Profile is built from these — no hand-rolled background+overlay per screen.

### Accent Color Rule (relaxed to a semantic 2026-06-17 — Tuwa v2)

**The accent is a single cool stone-blue (`#7FB3CC` dark / `#2E6B86` light) — still ONE hue — now used as the "live / actionable / you-are-here" semantic, in a defined, restrained set:**

1. The hero readiness score number (as before — the primary instance).
2. Progress / strike-zone / verdict-bar **fills** (the actionable number made visual).
3. The **active / selected** state: selected set cell, active segmented-control segment, current tab, focused text field — via `accent` (border/text) or `accentSubtle` (fill behind content).
4. The **primary CTA** — as an accent **outline** (never a filled accent button).
5. The 2pt accent **top rule** on the emphasis card (`emphasisCardStyle`).

Nowhere else — never on ordinary icons, body labels, or decoration. It must read as considered and intentional, never sprayed. This relaxes v1's "hero number only" rule: the accent now earns its place by always meaning *this is live / this is what you act on*. Zone meaning (optimal/caution/danger) is still carried by text label + zone color — **never** by the accent.

### Zone Color Rule

Zone colors are desaturated to near-gray intentionally. They are not vivid alarms. Zone state is communicated primarily through text labels ("Optimal" / "Caution" / "High Risk") — the color is supplementary. This is the correct approach for accessibility: color is additive, not the sole information channel.

### Color Temperature & Contrast (revised 2026-06-15)

The neutral ramp is **cool true-neutral** — every chrome token has blue channel ≥ red (no warm/taupe/cream bias ever). Contrast floors are enforced: primary text ≥13:1, secondary ≥4.5:1, micro-caps `--text-3` ≥3:1, dividers a visible ≥1.5:1 luminance step. Pure `#FFFFFF` and `#000000` are never used (Philo never uses pure black); text sits just off the extremes. Olive/oxblood/slate appear ONLY as muted, label-paired zone strips — never in the chrome, never as the second accent.

## Spacing

- **Base unit:** 8pt
- **Density:** Comfortable — generous internal padding, deliberate vertical rhythm
- **All spacing values must be multiples of 8pt.** No 10pt, no 12pt, no 6pt gaps.

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
- **Border radius:** 0pt everywhere. Absolutely square corners. No softness.
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

1. **Never use `RoundedRectangle` with cornerRadius > 0.** Use `Rectangle()` everywhere. If a card container is needed, use `Rectangle().fill(Color.surface)` with a `.border(Color.divider, width: 0.5)` overlay.
2. **No `.shadow()` modifiers anywhere.** Remove existing shadow calls.
3. **All numeric Text views use `.monospacedDigit()`** to prevent layout shifts.
4. **Accent color = the "live / actionable" semantic** (see Accent Color Rule): hero score, progress/strike-zone fills, active/selected state, primary-CTA outline, emphasis-card top rule. Never on ordinary icons, labels, or decoration — that's a design error.
5. **Zone state is always communicated through a text label + optional colored border.** Never rely on color alone.
6. **All spacing uses the design token scale.** No magic numbers. 16pt padding, 24pt padding, 8pt gaps — always multiples of 8.
7. **Support both color schemes.** All color references use semantic tokens from `ColorTokens`. Never use literal hex values in view code. Use `@Environment(\.colorScheme)` only for conditional logic that can't be expressed in the token system.
8. **Typography uses `Font.Tokens.*`** for all text (backed by General Sans Variable). Do not use `.system()` or `.headline` / `.body` semantic styles — these override the design system.

## Decisions Log

| Date       | Decision                                         | Rationale                                                                           |
|------------|--------------------------------------------------|-------------------------------------------------------------------------------------|
| 2026-03-21 | International Style Minimalism aesthetic         | Differentiates from Whoop/Strava's aggressive energy coding; aligns with "timeless" product vision |
| 2026-03-21 | Near-monochromatic palette with single accent    | Mies van der Rohe principle: one precious material, used with total commitment      |
| 2026-03-21 | Regular + Medium only, no other weights           | Hierarchy through size alone — "less is more" applied to typography                 |
| 2026-03-21 | 0pt border radius everywhere                     | Square corners reinforce the structural, instrument-like aesthetic                  |
| 2026-03-21 | Zone colors desaturated to near-gray             | States communicated through labels, color is supplementary — calm > alarm           |
| 2026-03-21 | Accent appears on readiness score only           | The one precious material in the design — used once, completely                     |
| 2026-03-21 | Secondary text adjusted to #7C7972 (dark mode)   | Meets WCAG AA 4.5:1 contrast — aesthetic preserved, accessibility not compromised   |
| 2026-03-21 | Dark-first, light mode supported via token system| iOS convention + outdoor readability; same design system, two material expressions  |
| 2026-05-10 | Migrated from DM Sans to Alpino (superseded 2026-05-11 -> General Sans) | Geometric sans with sharper terminals -- aligns with International Style direction  |
| 2026-05-11 | Migrated from Alpino to General Sans             | Rationalist neo-grotesque — better lining figures for data-heavy UI, superior small-size readability |
| 2026-05-30 | Widened dark elevation ladder; formalized `surfaceEl` as card plane | Original `surface` (#131312) was ~3% above `background` — cards blended into the page ("can't tell where to click"). Raised `surface`→#161615, `surfaceEl`→#1F1F1D; cards now use `surfaceEl`. Light mode unchanged. |
| 2026-05-30 | Two-tier separator grammar + `cardStyle`/`SectionHeader`/`SectionContainer` primitives | Section breaks (32pt gap + 19pt Medium header) vs row hairlines (inset 0.5pt). Restores hierarchy lost when section headers drifted to 12pt micro-caps and section gaps to 8pt spacers. |
| 2026-06-15 | Recooled palette to cool true-neutral + raised contrast (Philo austere direction) | Old ramp was uniformly warm (travertine accent, #C2BEB7 haze text); flagged too-warm + low-contrast. Neutralized all chrome (blue≥red), lifted text1 to #E8EAEC/13.9:1, retired travertine accent for cool putty #A6C2D0/#3C5A66, made dividers a visible cut, fixed unreadable text-3 micro-caps (1.4→3.5:1). Structure unchanged. |
| 2026-06-17 | **Tuwa v2** — bolder departure + more motion life | Audit found the 2026-06-15 recool never fully landed: light chrome still warm (red>blue), warm zone ramp flooded live UI (chartATL alias, error toasts, toggle tint), the dark elevation ladder was imperceptible (ΔL* ~3.9), grouped regions lacked outer borders, AND the whole interaction layer was unfinished (no MotionTokens, zero ButtonStyle/press feedback, haptics only in scrubbers, the v1-mandated hero count-up never built). v2: cooler+brighter accent (#7FB3CC/#2E6B86), neutralized + inverted light ladder, widened dark ladder to a perceptible gap, added 4th `surfaceEl2` emphasis plane + `dividerStrong`, full outer borders on all grouped regions, cool-only chart series. Relaxed two v1 rules with user approval: accent → "live/actionable" semantic (small defined set, not hero-only); motion → gentle springs permitted, added `Motion` tokens + `PressableButtonStyle` + `Haptics` + built the hero count-up. |
