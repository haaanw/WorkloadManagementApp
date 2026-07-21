# Design System — Tuwa

**v5 "Pavilion" — Warm Stone, 2026-07-21.** Created by /design-consultation 2026-03-21 · light-only v2 2026-06-17 · v3 "Ink & Grain" 2026-07-14 · v4 "Instrument" 2026-07-20–21 · **v5 return-to-basis locked by user decision 2026-07-21**: the v1 International Style foundation is the product's aesthetic ground truth; v2–v4.2 are treated as guidance layers, and only their ratified carry-overs survive (motion fabric, accent-as-live-state, soft corner scale, relief system). Font picked via 7-face shootout (`.design-explorations/v5-font-preview.html`).

## Product Context

- **What this is:** An iOS app for athlete workload management — synthesizing HRV, sleep, training load, and recovery into a single daily readiness score with plain-English explanations.
- **Who it's for:** Serious amateur self-coached athletes (beachhead: competitive basketball players who also strength-train) who want to understand their body, not just collect data.
- **Space / industry:** Sports performance, training load management, recovery science. Competing with Whoop, Garmin Connect, Apple Fitness+, TrainingPeaks, Strava.
- **Project type:** iOS native app (SwiftUI + SwiftData + HealthKit). No third-party UI frameworks.

## Aesthetic Direction

- **Direction:** International Style Minimalism, recovered from v1 — the visual language of a precision instrument rendered in warm stone, not cold aluminum. Mies van der Rohe's principle: structure IS the aesthetic; every element earns its place or it does not exist. The v4.2 machined relief survives, but the material it carves is warm — travertine and limestone, not anodized metal.
- **Design references:** Barcelona Pavilion (Mies, 1929 — one precious material, used once, completely), Seagram Building, Braun (Rams' control discipline), Apple Health (restrained data presentation).
- **Decoration level:** None. No textures, no shadows, no ornament. Hierarchy is achieved through proportion, spacing, type weight, and physical relief (raised/debossed surfaces).
- **Mood:** Quiet confidence. Not aggressive or energetic (cf. Whoop's red, Strava's orange) — calm, authoritative, precise. A high-end chronograph in a warm room, not a scoreboard.

**Retired with v4:** the black instrument panel, the red index, the mono dial voice, the aluminum palette, near-square geometry, micro-caps screen titles. The instrument *grammar* (tick scales, readout wells, detents) survives; the instrument *costume* does not.

## Typography — the One-Voice Type Law (v5)

The app speaks in exactly **one type voice**: **Instrument Sans** (SIL OFL; static Regular 400 + Medium 500 only). All hierarchy through size and the single weight step — no bold, no italic, no semantic styles, no second face.

- **Numerals:** every data numeral applies `.monospacedDigit()` at the call site (v1 law restored). Instrument Sans carries tabular figures; the mono face is gone.
- **RETIRED (v4 → v5):** the IBM Plex Mono dial voice — tokens (`dial*` retuned to Instrument Sans), font files, and registrations deleted. `IBMPlexMono` is a banned string app-wide (fence-inverted, same mechanism as the `SourceSerif4` ban, which also stays).
- **Case discipline:** sentence case everywhere. Screen titles return to the v1 editorial style — 28pt Regular, sentence case, with the date/context line in micro-caps above. Micro-caps (+0.08em tracking, caps) exist ONLY at micro-label size. The v4 wide-tracked micro-caps titlebar is retired.
- **CJK:** the Noto Sans SC cascade (PostScript names, `cascadeList`) is retained on all tokens.

### Type Scale

| Role          | Size | Weight | Token                  | Notes                                        |
|---------------|------|--------|------------------------|----------------------------------------------|
| Hero score    | 64pt | 400    | `heroScore`            | Tabular, line-height 1, **`accent` color** — the one colored text element in the app |
| Display value | 32pt | 400    | `displayAction`        | Verdict copy / standing values (`dialValue` aliases here at 30→32) |
| Page title    | 28pt | 400    | `pageTitle`            | Sentence case (v1 restored; was 32/micro-caps) |
| Section head  | 17pt | 500    | `sectionHead`          | v1 scale restored (was 19)                    |
| Body          | 17pt | 400    | `body`                 | Line-height 1.55                              |
| Label         | 15pt | 400    | `label`                |                                              |
| Small label   | 13pt | 400    | `smallLabel`           |                                              |
| Micro / cap   | 11pt | 400    | `micro`                | +0.08em tracking, caps (v1 restored; was 12)  |
| Tab label     | 11pt | 500    | `tabLabel`             | Title case (v4.1 readability finding, kept)   |
| Key label     | 11pt | 500    | `keyLabel`             | Decision-key cells; sentence case in v5       |

Former `dial*` tokens survive as deprecated aliases onto this ramp (hero/display/small) so the sweep can migrate call sites file by file; they are deleted at the end of the v5 application pass.

### Font Loading (iOS)

Bundle `InstrumentSans-Regular.ttf` + `InstrumentSans-Medium.ttf` (static faces — the variable font is NOT used; the GeneralSans variable-font PS-name trap of 2026-07-17 is why) and `NotoSansSC-{Regular,Medium}.otf`. Register via `Info.plist` → `UIAppFonts`. Reference ONLY via `FontTokens.swift`; PostScript names live only there and must be runtime-verified via the DEBUG family dump before the pivot is declared rendered (past failure mode: font never rendered, fell back silently).

Source: https://fonts.google.com/specimen/Instrument+Sans (SIL OFL 1.1 — bundle the license at `WorkloadApp/Resources/Fonts/InstrumentSans-LICENSE.txt`). General Sans and IBM Plex Mono files/registrations are removed.

## Color

### Light Mode — v5 Warm Stone (light-only)

Tuwa is intentionally light-only; the app forces light appearance. The v5 material model: **one warm stone material** in ascending planes of light (the relief system needs raised = brighter), warm ink, and a single **travertine accent** — v1's palette pulled slightly cooler per user decision ("1, but slightly less warm").

| Token              | Hex       | Usage                                                       |
|--------------------|-----------|-------------------------------------------------------------|
| `--bg`             | `#F0EFEC` | Stone base plane (page/scroll canvas)                       |
| `--surface`        | `#F4F3F0` | Inline strip / control plane                                |
| `--surface-el`     | `#F8F7F4` | Card plane (canonical card fill)                            |
| `--surface-el-2`   | `#FCFBF9` | Brightest plane — raised tops, active/selected surfaces     |
| `--divider`        | `#D6D3CD` | Hairline rules                                              |
| `--divider-strong` | `#CCC9C2` | Strong hairline — key-row containers, priority boundaries   |
| `--text-1`         | `#1B1A17` | Warm ink (≈15:1 on base)                                    |
| `--text-2`         | `#57544E` | Secondary (≈6.5:1)                                          |
| `--text-3`         | `#8B877F` | Tertiary / micro-caps (≥3:1 on card)                        |
| `--disabled`       | `#A19D95` | Disabled-only glyphs — never information-carrying           |
| `--accent`         | `#6F6759` | **Travertine.** Hero score + live-state only (Accent Rule)  |
| `--well-top`       | `#E7E5E0` | Debossed well gradient, top                                 |
| `--well-bottom`    | `#EDEBE6` | Debossed well gradient, bottom                              |
| `--zone-optimal`   | `#3F5A46` | Desaturated green (contrast-verified 2026-07-20, retained)  |
| `--zone-caution`   | `#6E5624` | Desaturated amber (retained)                                |
| `--zone-danger`    | `#7E362E` | Desaturated red (retained)                                  |
| `--zone-low`       | `#46525E` | Desaturated slate (retained)                                |

Implementation: hardcoded light-only hex literals in `ColorTokens.swift`, no asset catalogs, no dark-mode branches. Charts retune to warm inks (ATL dark warm ink, CTL light warm ink, volume/sleep mid warm inks) keeping ONE muted supporting hue (`#4E7A74` desaturated teal) for the positive series (TSB/HRV). **Panel tokens (`panel`, `panelInk*`, `panelHairline`, gradients) and `index` are retired** — kept only as deprecated aliases during the sweep, deleted with it.

### Accent Rule (v5 — the travertine law)

`--accent` (`#6F6759`) is v1's "green marble slab in the Barcelona Pavilion" plus the v2 live-state carry-over. It may appear ONLY as:

1. **The hero readiness score** — the single colored text element in the app.
2. **Live-state semantics (v2 carry-over):** progress fills, active/selected marks (the active-tab tick, selection dots), the live-recording dot, scale needles.

Never decorative, never body/label text, never an icon tint at rest, never a CTA fill. The v4 red index is retired; every former index mark (needle, tab tick, recording dot) is now drawn in accent. Zone meaning is still carried by text label + zone color — never by the accent.

### Corner Law (v5 — soft precision, v3 scale restored)

Every radius comes from `CornerTokens` — never a hand-typed literal:

| Token                  | Value   | Applies to                                      |
|------------------------|---------|-------------------------------------------------|
| `CornerTokens.card`    | 12pt    | Cards, plates, grouped surfaces, sheets         |
| `CornerTokens.control` | 8pt     | Inputs, cells, steppers, wells, small plates    |
| `CornerTokens.pill`    | capsule | Chips, badges, and the primary CTA              |

`CornerTokens.panel` is deleted with the panel. Hairline borders stay (0.5pt); still NO shadows — elevation is plane + hairline + relief.

### The Relief Law (v4.2 carry-over, re-materialized in stone)

Every machined surface is either RAISED or DEBOSSED; flat is reserved for the base plane and text. The two chokepoint modifiers in CardStyle.swift — never hand-rolled:

- **`.raised(cornerRadius:)`** — milled plate: `surfaceEl2→surfaceEl` vertical gradient, 1px `reliefHighlight` top line, `dividerStrong` hairline. Cards, option cells, keys, toggle knobs.
- **`.debossed(cornerRadius:)`** — pocket: `wellTop→wellBottom` gradient, 1.5px `reliefShade` inner top edge, 1px `reliefHighlightSoft` bottom closing line, `dividerStrong` hairline. Readout wells, focused fields, option channels, toggle tracks.
- Default radii are the v5 corner scale (card 12 / control 8). No `.shadow()` anywhere — relief is strokes + gradients only.

**Readout wells** carry over: every displayed value sits in a fixed-width debossed well — tabular value + micro-caps unit; digits change, the stone never resizes.

**Press inverts relief** carries over: keys press in ~85ms (raised→pocket) and release on a ~300ms non-bouncy spring. The machined form system (InstrumentForm.swift — press-well rows, inline option bays, machined toggle, focus wells) carries over with v5 geometry (8pt wells/cells) and stone tokens; stock iOS `Menu` remains BANNED for settings/pickers.

### Hero Law (v5 — replaces the v4 Panel Law)

The hero surface is a **raised light card**, not a black panel:

- One hero card per screen, maximum, carrying the screen's one hero reading (Home readiness, Load ACWR) as `heroScore` in **accent** — v1's original signature.
- Everything else reads in ink on the same stone. A dark surface anywhere is a design error; `panelStyle(` is banned by fence after the sweep.

### TickScale (retained instrument grammar, re-inked)

`TickScale` survives as the measured-value display grammar: two-weight tick marks in warm grays (minor/major derived from `text3`/`text2`), numerals in `text3` at the micro size, optional ink zone band, optional ghost mark — and the **needle is now 1.5px accent**. Detent haptics stay Home-hero-only. Needles never travel back through zero (v4.1 law kept).

### CTA & Key Row Law (v5)

- **Primary CTA:** ink-filled pill — `text1` fill, `surfaceEl` text, `Capsule()` geometry, `.raised` relief. One per screen at most. Never accent-filled.
- **Decision rows keep the butted equal-weight grammar** inside a raised 12pt container with interior 0.5pt hairlines: the **nocebo guard** — "act" and "keep plan" carry equal visual weight, the UI never pressures the athlete toward the modified option. Key labels: `keyLabel` 11pt Medium, sentence case (micro-caps tracking retired).

### Zone Color Rule (retained)

Zone colors are desaturated — never vivid alarms. Zone state is communicated primarily through text labels ("Optimal" / "Caution" / "High Risk"); color is supplementary (label + optional colored border/strip, never color alone). All four zone tokens hold ≥4.5:1 on the stone surfaces.

### Contrast floors

Primary text ≥13:1, secondary ≥4.5:1, micro-caps ≥3:1 on their surface. The 64pt accent hero holds ≥4.5:1 on the card plane (large-text floor is 3:1; verified at implementation). Pure `#FFFFFF`/`#000000` never used. `--disabled` is exempt only because it never carries information.

### Tab bar — Console architecture, stone dress (v5)

InkTabBar architecture and a11y IDs unchanged. Text-only title-case labels (11pt Medium, modest tracking) on a flat opaque bar (`tabBarSurface` `#ECEBE7`, 0.5pt `dividerStrong` top hairline). Selection = the three-part presence grammar: ink color step `text3→text1`, the faint sliding well (`text1` @5%, 8pt plate, `Motion.state`), and the 1.5pt **accent** tick above the active label sliding on `Motion.tickSpring` — still the ONE sanctioned overshoot in the app. Per-item press-down scale 0.94. No icons, no pill highlights.

## Spacing

- **Base unit:** 8pt. Structural spacing must be multiples of 8pt; 4pt only as the sanctioned `baselinePair` micro-gap (micro-label → value).
- Density: comfortable — v1's generous internal padding and deliberate vertical rhythm return; instrument-tight packing is retired with the panel.

| Token | Value | Usage                                          |
|-------|-------|------------------------------------------------|
| xs    | 8pt   | Icon-label gaps, tight inline spacing          |
| sm    | 16pt  | Card internal padding (horizontal), small gaps |
| md    | 24pt  | Card internal padding (vertical), standard gaps|
| lg    | 32pt  | Section gaps                                   |
| xl    | 48pt  | Major section breaks                           |
| 2xl   | 64pt  | Page-level breathing room                      |

Separator grammar retained: section break = 32pt gap + 17pt Medium header; row separator = 0.5pt hairline inset 16pt.

## Layout

- Grid-disciplined, single scrollable canvas per tab; 16pt horizontal margins.
- Screen top (v1 restored): context line in micro-caps (date) above a 28pt sentence-case page title. `ScreenHeader` restyles; architecture stays.
- Home (top → bottom): header → hero readiness card (micro-label · 64pt accent score · zone label · TickScale) → metric rows on a card → verdict card (display value in ink · reason · equal-weight key row) → tab bar.
- Progressive disclosure (v1): surface = score + top reasons + recommendation; detail on tap; deep trends one more tap. The dashboard is a reading, not a data dump.

## Motion (v4.2 spring law — carried whole)

Motion is the one v2→v4.2 lineage that carries into v5 unchanged in substance: calm mechanics, no bounce, no flourish.

- **Non-bouncy springs** (interruptible, velocity-preserving) via the `Motion` token enum (CardStyle.swift) — the single chokepoint. Never a bare `withAnimation`, never a hand-typed curve/duration at a call site. `reduceMotion` honored via `Motion.resolved(_:reduceMotion:)`.
- **No ease-in, ever.** No content passes through full invisibility during a transition (dip-crossfade banned); tab content hands off layered.
- **Durations:** presses ~100ms in / ≤400ms settle; transitions ≤300ms; frequent actions near-instant. Stagger 30–80ms where used (not inside sheets).
- **Count-up:** hero score count-up ≤400ms — v1's "one intentional moment of delight," now in accent.
- **Haptics:** commit-only + limit/toggle detents (D13a) + Home hero count-up detents. Never decorative.
- `Motion.tickSpring` remains the sole sanctioned overshoot (tab tick only).

## The Five-Primitive Interaction Law (carried from v4.1)

Every touchable class has exactly one defined response; carriers live in `CardStyle.swift`, call sites reference styles/tokens only:

1. **Key** (commits an action) — press-inversion relief (v4.2), release on the non-bouncy spring.
2. **Row** (navigates) — background well (`text1` @6%), no scale, `Motion.rowWell`.
3. **Detent control** (discrete values) — mechanical snap, subtle ~100ms digit-roll, fixed-width readout wells (value cells never resize with digit count), reduced haptics (limits + toggle flips only).
4. **Needle** (displays a measured value) — sweeps on real moments only; travels current→new directly, never back through zero; sweep-from-zero only on genuine first appearance.
5. **Surface** (sheets/expansions) — one-unit origin-aware entrance, 200–250ms, no content stagger.

## Implementation Rules for SwiftUI

1. **Corners from `CornerTokens` only** (card 12 / control 8 / pill). Hand-typed radius literals are fence failures.
2. **No `.shadow()` anywhere.** Elevation = plane + hairline + relief.
3. **One type voice:** everything through `Font.Tokens.*` (Instrument Sans Regular/Medium). No `.system()`, no semantic styles. `IBMPlexMono` and `SourceSerif4` are banned strings app-wide. All data numerals apply `.monospacedDigit()`.
4. **Accent Rule:** `ColorTokens.accent` only as the hero score text and live-state marks (progress fills, active/selected marks, tab tick, recording dot, needles). Never decorative, never CTA fill, never labels.
5. **Hero Law:** at most one hero card per screen; hero reading in accent on a raised light card. No dark surfaces; `panelStyle(` is banned post-sweep.
6. **Zone state = text label first**, color supplementary; never color alone.
7. **Light-only** via `ColorTokens` semantic tokens; never hex literals in views; no dark-mode branches.
8. **Relief through `.raised` / `.debossed` only**; displayed values sit in fixed-width readout wells.
9. **CTAs:** one ink-filled pill max per screen; decision rows are equal-weight butted cells (nocebo guard).
10. **Spacing on the 8pt grid** (4pt `baselinePair` only).
11. **Motion through `Motion` tokens only**, per the spring law; interaction through the Five Primitives.

## Retired concepts (do not reintroduce)

| Concept                                   | Status                                                        |
|-------------------------------------------|---------------------------------------------------------------|
| Source Serif 4 display voice (v3)         | DELETED; name banned by fence                                 |
| Halftone signature (v3)                   | DELETED                                                       |
| IBM Plex Mono dial voice (v4)             | DELETED (tokens, files, registrations); name banned by fence  |
| Black instrument panel + Panel Law (v4)   | RETIRED — hero = raised light card, accent score              |
| Red index `#D04234` (v4)                  | RETIRED — index marks are drawn in accent                     |
| Aluminum cool-gray palette (v4)           | REPLACED by warm stone                                        |
| Near-square 5/4pt corners (v4)            | REPLACED by 12/8/pill                                         |
| Micro-caps wide-tracked screen titles (v4)| RETIRED — v1 editorial titles (28pt sentence case)            |
| Micro-caps key labels (v4)                | RETIRED — sentence case keys                                  |
| Dark-mode palette (v1)                    | Not carried — light-only stands (v2/v3 decision)              |
| Accent-as-CTA-fill (v3)                   | Still retired — CTAs are ink-filled                           |
| Stock iOS `Menu` for settings/pickers     | Still banned (v4.2)                                           |

Retained lineage: light-only, no shadows, 8pt grid, text-label-first zones, nocebo guard, hairline elevation, InkTabBar/ScreenHeader architecture, Motion/Haptics chokepoints, relief system, readout wells, TickScale grammar, Five-Primitive interaction fabric, fence-test enforcement, Noto Sans SC cascade.

## Decisions Log

| Date       | Decision                                         | Rationale                                                                           |
|------------|--------------------------------------------------|-------------------------------------------------------------------------------------|
| 2026-03-21 | International Style Minimalism aesthetic         | Differentiates from Whoop/Strava's aggressive energy coding                          |
| 2026-03-21 | Zone colors desaturated to near-gray             | States communicated through labels, color supplementary — calm > alarm               |
| 2026-06-17 | Tuwa v2 — light ladder, live-state accent, Motion/Haptics chokepoints | Foundation grammar retained through v5                          |
| 2026-06-27 | Light-only direction confirmed                   | Light appearance is the only supported material expression                           |
| 2026-07-14 | Tuwa v3 "Ink & Grain"                            | Superseded: on-device dogfood failed on aesthetics                                   |
| 2026-07-20 | Tuwa v4 "Instrument" (Aluminum Panel) + v4.1 polish | Superseded as costume; its machinery (relief, five primitives, spring motion, Console tab bar, TickScale) survives as v5 carry-overs |
| 2026-07-21 | v4.2 "Machined" — Relief Law, readout wells, press-inversion, spring refit | Carried into v5 whole, re-materialized in stone                 |
| 2026-07-21 | **Tuwa v5 "Pavilion" (Warm Stone) — return to v1 basis** | User decision (D19): v4 not a must-satisfied aesthetic; v1 International Style foundation restored and iterated with ratified carry-overs ONLY — motion fabric, accent-as-live-state, CornerTokens 12/8/pill, relief system. Light-only kept; palette = v1 warmth pulled slightly cooler (warm stone, travertine accent `#6F6759`). All bundled faces judged "too formal, a little dull"; **Instrument Sans** picked from a 7-face shootout as the single voice (One-Voice Type Law; Plex Mono dial voice retired). Panel/red-index/micro-caps-titles retired. |
