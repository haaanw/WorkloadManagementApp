# Design System — WorkloadApp

Created by /design-consultation · 2026-03-21

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
- **Micro / caps:** General Sans Regular, 12pt, `--text-3`, letter-spacing +0.08em, all-caps
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
| Micro / cap   | 12pt | 400    | --text-3    | +0.08em tracking, caps |

### Font Loading (iOS)

Bundle `GeneralSans-Variable.ttf` (variable font) in the Xcode project. Register via `Info.plist` → `UIAppFonts`. Reference in SwiftUI via `FontTokens.swift`: `.font(.Tokens.body)`. The variable font's weight axis selects Regular (400) and Medium (500).

Source: https://www.fontshare.com/fonts/general-sans (ITF FFL license)

## Color

### Dark Mode (Primary)

| Token            | Hex       | Usage                                              |
|------------------|-----------|----------------------------------------------------|
| `--bg`           | `#0B0B0A` | App background — warm near-black                  |
| `--surface`      | `#161615` | Inline strips — lifted from background (revised 2026-05-30, was #131312) |
| `--surface-el`   | `#1F1F1D` | Card plane — standard fill for grouped/elevated cards (revised 2026-05-30, was #1A1A19) |
| `--divider`      | `#232321` | Hairline rules — the only separator tool used     |
| `--text-1`       | `#C2BEB7` | Primary text — warm off-white, not pure white     |
| `--text-2`       | `#7C7972` | Secondary text — adjusted to ≥4.5:1 contrast     |
| `--text-3`       | `#3A3835` | Tertiary / micro labels                           |
| `--accent`       | `#A8A090` | Travertine — used in ONE place: the readiness score number |
| `--zone-optimal` | `#607869` | Barely-green — ACWR optimal zone                 |
| `--zone-caution` | `#7E7252` | Barely-amber — ACWR caution zone                 |
| `--zone-danger`  | `#7E5C5C` | Barely-red — ACWR high-risk zone                 |
| `--zone-low`     | `#5A6470` | Barely-slate — undertraining zone                |

### Light Mode

| Token            | Hex       | Usage                                              |
|------------------|-----------|----------------------------------------------------|
| `--bg`           | `#F4F1ED` | Warm off-white — travertine-coded                 |
| `--surface`      | `#EDEAE6` | Slightly darker off-white                         |
| `--surface-el`   | `#E4E0DB` | Elevated surfaces                                 |
| `--divider`      | `#CFCBC5` | Hairline rules                                    |
| `--text-1`       | `#1C1915` | Near-black ink — warm, not pure black             |
| `--text-2`       | `#696560` | Secondary — adjusted to ≥4.5:1 on light bg       |
| `--text-3`       | `#AFABA5` | Tertiary                                          |
| `--accent`       | `#7A6E5C` | Darker travertine for light mode — same warmth, more contrast |
| `--zone-optimal` | `#3E5C49` | Darker muted green for light mode contrast        |
| `--zone-caution` | `#6B5828` | Darker muted amber                                |
| `--zone-danger`  | `#6E3A3A` | Darker muted red                                  |
| `--zone-low`     | `#3A4A5C` | Darker muted slate                                |

### SwiftUI Color Tokens

Define in `ColorTokens.swift` (already exists in the project — replace with these values):

```swift
extension ColorTokens {
    // Backgrounds
    static let background    = Color("Background")     // #0B0B0A / #F4F1ED
    static let surface       = Color("Surface")        // #131312 / #EDEAE6
    static let surfaceEl     = Color("SurfaceEl")      // #1A1A19 / #E4E0DB
    static let divider       = Color("Divider")        // #232321 / #CFCBC5

    // Text
    static let text1         = Color("Text1")          // #C2BEB7 / #1C1915
    static let text2         = Color("Text2")          // #7C7972 / #696560
    static let text3         = Color("Text3")          // #3A3835 / #AFABA5

    // Accent — one place only
    static let accent        = Color("Accent")         // #A8A090 / #7A6E5C

    // Zones
    static let zoneOptimal   = Color("ZoneOptimal")    // #607869 / #3E5C49
    static let zoneCaution   = Color("ZoneCaution")    // #7E7252 / #6B5828
    static let zoneDanger    = Color("ZoneDanger")     // #7E5C5C / #6E3A3A
    static let zoneLow       = Color("ZoneLow")        // #5A6470 / #3A4A5C
}
```

Add corresponding entries to `Assets.xcassets` with "Any" (light) and "Dark" appearance slots.

### Elevation Ladder (revised 2026-05-30)

Three background planes, used deliberately to create depth without shadows or rounding:

| Plane         | Token        | Dark      | Light     | Usage                                                            |
|---------------|--------------|-----------|-----------|------------------------------------------------------------------|
| Page          | `background` | `#0B0B0A` | `#F4F1ED` | The scroll canvas behind everything                              |
| Card          | `surfaceEl`  | `#1F1F1D` | `#E4E0DB` | **Default fill for any grouped/elevated card** (hero, summary, banners, prompts) |
| Inline strip  | `surface`    | `#161615` | `#EDEAE6` | Flat inline regions that sit *on* the page (metrics strip, flat row lists) |

**Revision rationale:** Dark `surface` (`#131312`) sat only ~3% luminance above `background` (`#0B0B0A`) — cards and page were visually identical, which is the root of the "everything blends together, can't tell where to click" feedback. We (a) raise dark `surface` to `#161615` and `surfaceEl` to `#1F1F1D` to open a perceptible gap, and (b) formalize `surfaceEl` as the standard *card* fill so any grouped, tappable container reads as a distinct plane lifted off the page. Light mode values are unchanged (already legible). Elevation is still communicated by plane + a 0.5pt `divider` border only — never by shadow or rounding.

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

### Accent Color Rule

**The accent (`#A8A090` / travertine) appears in exactly one place: the hero readiness score number.** Nowhere else — not buttons, not highlights, not icons. This is a design constraint enforced by the system. The accent is the "green marble slab" in the Barcelona Pavilion — it appears once, it is complete, it is enough.

### Zone Color Rule

Zone colors are desaturated to near-gray intentionally. They are not vivid alarms. Zone state is communicated primarily through text labels ("Optimal" / "Caution" / "High Risk") — the color is supplementary. This is the correct approach for accessibility: color is additive, not the sole information channel.

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

## Motion

- **Approach:** Minimal-functional. Transitions exist to orient the user, not to delight.
- **No spring physics.** No bounce. No playful ease curves.
- **Easing:** `easeOut` for entrances, `easeIn` for exits, `linear` for state changes.
- **Duration:**
  - State change (zone color, score number): 150ms linear
  - Screen transition: 250ms easeOut
  - Score count-up on first load: 400ms easeOut (numbers count up from 0 — the one intentional moment of delight)
- **Score count-up is the only animation with personality.** Everything else is functional.

## Implementation Rules for SwiftUI

1. **Never use `RoundedRectangle` with cornerRadius > 0.** Use `Rectangle()` everywhere. If a card container is needed, use `Rectangle().fill(Color.surface)` with a `.border(Color.divider, width: 0.5)` overlay.
2. **No `.shadow()` modifiers anywhere.** Remove existing shadow calls.
3. **All numeric Text views use `.monospacedDigit()`** to prevent layout shifts.
4. **Accent color appears only on the hero readiness score.** If a view other than the readiness number requests the accent color, it's a design error.
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
