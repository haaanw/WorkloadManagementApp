# Design System — Tuwa

**v4 "Instrument" — Aluminum Panel, 2026-07-20** (amended **v4.1 polish round, 2026-07-20** — Console tab bar + the Five-Primitive Interaction Law, decisions D12–D15, demo `.planning/design-reference/tuwa-v4-polish-demos.html`). Created by /design-consultation 2026-03-21 · light-only v2 2026-06-17 · v3 "Ink & Grain" 2026-07-14 · **v4 "Instrument" treatment locked by user decision 2026-07-20** (orchestration `.planning/orchestration/2026-07-20-v4-instrument.md` D9–D11; picked mockup `.planning/design-reference/tuwa-instrument-round2.html`, column D "Aluminum Panel" — its CSS is tone ground truth).

## Product Context

- **What this is:** An iOS app for athlete workload management — synthesizing HRV, sleep, training load, and recovery into a single daily readiness score with plain-English explanations.
- **Who it's for:** Serious amateur self-coached athletes (beachhead: competitive basketball players who also strength-train) who want to understand their body, not just collect data.
- **Space / industry:** Sports performance, training load management, recovery science. Competing with Whoop, Garmin Connect, Apple Fitness+, TrainingPeaks, Strava.
- **Project type:** iOS native app (SwiftUI + SwiftData + HealthKit). No third-party UI frameworks.

## Aesthetic Direction

- **Direction:** Tuwa Instrument ("Aluminum Panel") — the app is a precision measuring instrument, not an app that talks about measurement. References: **Braun** (Rams' control discipline), **Bang & Olufsen** (machined aluminum body, linear scale grammar), **1990s Contax** (black instrument panel with luminous readings). The body is cool aluminum; each screen carries at most ONE near-black instrument panel bearing the hero reading; numerals are the voice.
- **Decoration level:** None. No textures, no shadows, no ornament. The v3 halftone signature is RETIRED. Hierarchy is achieved through material contrast (aluminum vs panel), tick-scale grammar, mono numerals, and spacing.
- **Mood:** Calm mechanical authority. A camera top-plate, not a scoreboard. Tuwa never shouts; the needle just points.

## Typography — the Two-Voice Type Law (v4)

The app speaks in exactly two type voices:

1. **UI voice — General Sans** (Regular 400 + Medium 500 only, via the variable font's `wght` axis). All textual UI: titles, sections, body, labels, controls, chrome. Hierarchy through size and the single weight step. No bold, no italic.
2. **Dial voice — IBM Plex Mono** (static Regular / Medium / SemiBold, OFL). ALL data numerals: scores, weights, metric values, deltas, tick labels, units. Reached ONLY via the `Font.Tokens.dial*` chokepoint. App-authored numerals/units only — never body copy, never user content. Monospace ⇒ tabular digits by construction.

**RETIRED (v3 → v4):** the Source Serif 4 display voice (`serifDisplay`, `displayScore`, `displayVerdict`) is deleted — tokens, chokepoint, and font files. The name `SourceSerif4` is a banned string app-wide (fence-enforced, inverted from the v3 chokepoint fence).

**Case discipline (column D):**
- **Screen titles = micro-caps, wide tracking** — 12.5–13pt Semibold-equivalent (General Sans Medium), letter-spacing 0.28–0.3em, ALL CAPS. NOT large title. (Stage 1″ restyles `ScreenHeader`.)
- **Micro-labels** — 9.5–10pt, tracking ≥0.2em, caps, `--text-3` (`panelInk2` on the panel).
- Content copy (reasons, explanations) stays sentence case in the UI voice.

### Type Scale

| Role            | Size  | Face          | Weight | Token                     | Notes                                    |
|-----------------|-------|---------------|--------|---------------------------|-------------------------------------------|
| Dial hero       | 60pt  | IBM Plex Mono | 500    | `dialHero`                | The ONE hero reading per screen; −0.03em, line-height 0.95; `panelInk` on the panel |
| Dial value      | 30pt  | IBM Plex Mono | 500    | `dialValue`               | Standing dial values (verdict weight etc); −0.02em |
| Dial small      | 13pt  | IBM Plex Mono | 500    | `dialSmall`               | Inline data readings, metric rows, deltas |
| Dial tick       | 9pt   | IBM Plex Mono | 400    | `dialTick`                | Tick-scale numerals only                  |
| Page title      | 32pt  | General Sans  | 400    | `pageTitle`/`screenTitle` | Legacy role — Stage 1″ replaces with micro-caps titlebar |
| Section head    | 19pt  | General Sans  | 500    | `sectionHead`             |                                           |
| Body            | 17pt  | General Sans  | 400    | `body`                    | Line-height 1.55                          |
| Label           | 15pt  | General Sans  | 400    | `label`                   |                                           |
| Small label     | 13pt  | General Sans  | 400    | `smallLabel`              |                                           |
| Micro / cap     | 12pt  | General Sans  | 400    | `micro`                   | Wide tracking, caps                       |

SemiBold Plex Mono is bundled and registered for Stage-2″ use if the hero needs more presence at 60pt; default is Medium.

### Font Loading (iOS)

Bundle `GeneralSans-Variable.ttf`, `IBMPlexMono-{Regular,Medium,SemiBold}.ttf` (static faces), and `NotoSansSC-{Regular,Medium}.otf` in the Xcode project; register via `Info.plist` → `UIAppFonts`. Reference in SwiftUI via `FontTokens.swift` only. The mono's PostScript names (`IBMPlexMono-Regular` / `-Medium` / `-SemiBold`, runtime-verified via the DEBUG family dump 2026-07-20) live ONLY in `FontTokens.swift` — no other file may name the dial font (fence-enforced). CJK cascade to Noto Sans SC is retained on both voices (defensive on dial tokens — their content is numerals/units).

Sources: https://www.fontshare.com/fonts/general-sans (ITF FFL) · IBM Plex Mono from github.com/IBM/plex via the google/fonts mirror (SIL OFL 1.1 — license bundled at `WorkloadApp/Resources/Fonts/IBMPlexMono-LICENSE.txt`).

## Color

### Light Mode — v4 Aluminum Panel (light-only unchanged)

Tuwa is intentionally light-only; the app forces light appearance. The v4 material model: a cool **aluminum body** carrying at most ONE near-black **instrument panel** per screen, with a single red **index** accent for marks.

| Token               | Hex       | Usage                                                        |
|---------------------|-----------|--------------------------------------------------------------|
| `--bg`              | `#E9EAEB` | Aluminum base plane (flat token; a subtle vertical gradient is sanctioned ONLY on the scroll background, Stage 1″) |
| `--surface`         | `#EFF0F1` | Inline strip / control plane                                 |
| `--surface-el`      | `#F5F6F7` | Card plane (the v4 canonical card fill)                      |
| `--surface-el-2`    | `#FAFBFB` | Brightest light plane — active/selected surfaces             |
| `--divider`         | `#D0D2D5` | Hairline rules                                               |
| `--divider-strong`  | `#C6C9CC` | Strong hairline — key-row containers, priority boundaries    |
| `--text-1`          | `#17181A` | Ink (14.8:1 on base)                                         |
| `--text-2`          | `#4A4D51` | Secondary (7.1:1)                                            |
| `--text-3`          | `#85898E` | Tertiary / micro-caps (≥3:1 on card)                         |
| `--disabled`        | `#9A9EA3` | Disabled-only glyphs — never information-carrying            |
| `--panel`           | `#1E2022` | Panel fill (flat token; panel component renders the `#232527 → #1A1C1E` vertical gradient) |
| `--panel-ink`       | `#F0F1F2` | Primary ink on panel (14.3:1)                                |
| `--panel-ink-2`     | `#8B8F94` | Secondary ink on panel (5.0:1)                               |
| `--panel-hairline`  | `#35373A` | Hairlines inside/around the panel                            |
| `--index`           | `#D04234` | The red index — marks only (see Index Rule)                  |
| `--zone-optimal`    | `#3F5A46` | Desaturated instrument green (6.3:1 base / 7.0:1 card)       |
| `--zone-caution`    | `#6E5624` | Desaturated instrument amber (5.8:1 / 6.4:1)                 |
| `--zone-danger`     | `#7E362E` | Desaturated instrument red — distinct from `--index` (7.1:1 / 7.9:1) |
| `--zone-low`        | `#46525E` | Desaturated slate (6.6:1 / 7.4:1)                            |

Implementation: tokens are hardcoded light-only hex literals in `ColorTokens.swift` (no asset-catalog color sets). `accent` is retained as an alias of `index` so v2/v3 live-state call sites compile mid-pivot; Stage 1″/2″ migrates them to the Index Rule / ink grammar.

### Panel Law (the v4 signature)

The near-black panel is the emphasis surface — the two-tone drama of the design:

- **One panel per screen, maximum.** It carries the screen's ONE hero instrument reading: Home readiness, Log verdict header (if hero'd), Load ACWR.
- Fill: the `#232527 → #1A1C1E` vertical gradient (panel component only; the flat `panel` token elsewhere). Border: 0.5pt `panelHairline`. Corners: `CornerTokens.panel` (5pt).
- On-panel ink: `panelInk` primary, `panelInk2` micro-labels/units; tick scales use panel-tuned tick colors; zone band on panel renders in `panelInk`.
- Everything else lives on aluminum cards (`surfaceEl`). A second dark surface on the same screen is a design error.

### Index Rule (v4 accent law)

`--index` (`#D04234`) is the single accent, and it may appear ONLY as an **index mark**:

1. **Scale needles** — the 1.5px red needle on `TickScale` (linear scales, micro-scales).
2. **The active-tab tick** — a 1.5pt red rule ABOVE the active tab label (needle grammar).
3. **A live-recording dot** — the one live-session indicator.

**Never a fill, never text, never an icon tint, never decorative.** The v3 accent-as-CTA-fill rule is RETIRED: CTAs are ink-filled key cells (`--text-1` fill, `panelInk` text), NOT red. Index marks are ≥1.5pt strokes/shapes, so text-contrast floors do not apply to them; `--index` must never carry text. Zone meaning is still carried by text label + zone color — never by the index.

### Corner Law (v4 — near-square)

Every radius comes from `CornerTokens` (`Utilities/CornerTokens.swift`) — never a hand-typed literal:

| Token                  | Value   | Applies to                                            |
|------------------------|---------|-------------------------------------------------------|
| `CornerTokens.card`    | 5pt     | Cards, plates, grouped surfaces, sheets               |
| `CornerTokens.panel`   | 5pt     | The black instrument panel                            |
| `CornerTokens.control` | 4pt     | Inputs, segmented cells, steppers, small plates       |
| `CornerTokens.pill`    | capsule | **DEMOTED: chips/badges only.** Never CTAs.           |

Hairline borders stay (0.5pt); still NO shadows — elevation remains plane + hairline.

### Key Row Law (butted keys — v4 CTA grammar)

Decision/action rows are **butted key rows**: flex cells of equal weight inside ONE container with a 0.5pt `dividerStrong` border, separated by interior 0.5pt hairlines — **no gaps, no pills**.

- **CTA key** = ink-filled cell (`--text-1` fill, `panelInk` text). NOT red — the index never fills.
- Secondary keys = card fill (`surfaceEl`), ink text. Key labels: 10.5pt-class micro-caps, tracking ≈0.18em, Medium.
- Equal visual weight between "act" and "keep plan" keys is the **nocebo guard** — the UI never pressures the athlete toward the modified option. This law is retained from v2/v3 and now has a physical grammar.

### TickScale (the signature component — Stage 1″ builds it)

`TickScale` replaces StrikeZoneBar's visuals (same data semantics + accessibility):

- Two-weight tick marks: minor 1px in the tick color, major 1.5px in the tick-major color.
- Mono tick numerals (`dialTick`, 9pt).
- Optional **zone band**: ink (`--text-1`) on light surfaces, `panelInk` on the panel.
- **1.5px red needle** (`--index`) marking the current value.
- Optional faint **ghost mark** (planned/previous value) at ~0.55 opacity of the numeral ink.
- Tick colors on aluminum: `#4E5154` minor / `#6E7175` major / `#8B8F94` numerals (column D vars; Stage 1″ tokenizes as component-internal constants derived from ColorTokens).

### Tab bar — Console (v4.1 D12)

Text-only **title-case** labels (11pt Medium `keyLabel`, modest ~0.13em tracking, Latin only) on a flat opaque bar (`tabBarSurface`, 0.5pt `dividerStrong` top hairline). The v4.1 readability raise: 9pt all-caps `--disabled` → 11pt title-case, with inactive labels lifted to `--text-3`.

Selected state is a three-part **presence** grammar (not a font-weight change — see below): (1) the ink color step `--text-3` → `--text-1`; (2) a faint sliding **well** behind the active item — `--text-1` @5%, `CornerTokens.control` plate, inset off the bar edges, sliding between tabs on `Motion.state`; (3) the 1.5pt red **index tick** ABOVE the active label (needle grammar, Index Rule), which slides on the springy `Motion.tickSpring` — the one overshoot in the app. Per-item press-down: scale 0.94. No icons, no pill highlights.

**Weight-shift caveat:** D12's mock shows a 500→600 shift on select, but General Sans is Regular/Medium-only and bold is banned — a same-size bump would be fake-bolding. Labels therefore stay Medium at both states and selection is carried by color + well + tick (the sanctioned "color+size, not fake bolding" substitute). A literal within-law weight shift (Regular→Medium) would need an 11pt-Regular tab token in `FontTokens.swift`; deferred. (InkTabBar architecture + a11y IDs unchanged.)

### Zone Color Rule (retained)

Zone colors are desaturated instrument variants — never vivid alarms. Zone state is communicated primarily through text labels ("Optimal" / "Caution" / "High Risk"); color is supplementary (label + optional colored border/strip, never color alone). All four zone tokens hold ≥4.5:1 on both light surfaces (verified 2026-07-20).

### Contrast floors

Primary text ≥13:1, secondary ≥4.5:1, micro-caps ≥3:1 (on their surface), panel ink ≥13:1, panel secondary ≥4.5:1. Pure `#FFFFFF`/`#000000` never used. `--index` and `--disabled` are exempt only because they never carry information-bearing text (index = marks; disabled = disabled).

## Spacing

- **Base unit:** 8pt. Structural spacing must be multiples of 8pt; 4pt only as the sanctioned `baselinePair` micro-gap (micro-label → value).
- Density: instrument-tight inside panels/cards, generous between sections.

| Token | Value | Usage                                      |
|-------|-------|--------------------------------------------|
| xs    | 8pt   | Icon-label gaps, tight inline spacing      |
| sm    | 16pt  | Card internal padding (horizontal), small gaps |
| md    | 24pt  | Card internal padding (vertical), standard gaps |
| lg    | 32pt  | Section gaps                               |
| xl    | 48pt  | Major section breaks                       |
| 2xl   | 64pt  | Page-level breathing room                  |

Separator grammar retained: section break = 32pt gap + 19pt Medium header; row separator = 0.5pt hairline inset 16pt.

## Layout

- Grid-disciplined, single scrollable canvas per tab; 16pt horizontal margins.
- Screen top: micro-caps titlebar (title left, quiet action right) — not large-title chrome.
- Home (top → bottom): titlebar → black readiness panel (micro-label · hero dial reading · zone label · TickScale) → metric rows on a card (label vs `dialSmall` value) → verdict card (`dialValue` + microscale + reason + key row) → tab bar.

## Motion (v4 — Emil Kowalski framework; governs Stage 3″)

Crisp + mechanical. Motion is a detent click, not a flourish.

- **Curve:** strong ease-out `cubic-bezier(0.23, 1, 0.32, 1)` for UI transitions. **No ease-in, ever.**
- **Durations:** press feedback 100–160ms (scale 0.97); UI transitions 150–250ms; **never >300ms**. Frequent actions (tab switches) get near-instant treatment.
- **Stagger:** 30–80ms steps.
- **Springs:** ONLY for gesture-driven/momentum motion, damping ≈1.0 (no overshoot). State changes use the ease-out curve, not springs.
- **Count-up:** the hero reading count-up stays but faster — ≤400ms.
- **Haptics:** commit-only, plus **detent haptics** on scale/needle landings. Never decorative.
- One motion language, one chokepoint: the `Motion` token enum (CardStyle.swift). Never a bare `withAnimation { }`, never a hand-typed duration at a call site. `reduceMotion` honored via `Motion.resolved(_:reduceMotion:)`. (Stage 3″ retunes the token values to this law; the token names and fence stay.)

## The Five-Primitive Interaction Law (v4.1)

Every touchable class in the app gets **exactly one defined response** — the feel vocabulary is a fixed set of five primitives, applied everywhere, never improvised per screen. This is what "interactive in every detail" means concretely. Carriers live in `CardStyle.swift`; call sites reference the styles/tokens, never raw curves. (Ratified by decision D13 with the adjustments below; demo `.planning/design-reference/tuwa-v4-polish-demos.html` §2.)

1. **Key** — anything that *commits an action* (CTAs, key cells, tab items). Touch-down: **scale 0.97** + (for ink-filled keys) **brighten**, settling on `Motion.press` (120ms). Carrier: `.buttonStyle(.key)` (brighten) or `.buttonStyle(.pressable)` (dim, for light surfaces). Release always snappy.
2. **Row** — anything that *navigates* (disclosure/list rows). Touch-down: a **background well** (`--text-1` @6%), **NO scale** (rows are surfaces, not buttons), on `Motion.rowWell` (~110ms). Carrier: `.buttonStyle(.rowWell)`.
3. **Detent control** — anything with *discrete values* (toggles, steppers, segments, pickers). Mechanical snap; value swaps **digit-roll** subtly (~100ms, small travel — `Motion.digitRoll` + `.contentTransition(.numericText())`). **Fixed-width value cells:** a value container **never resizes** when the digit count changes — reserve width for the widest realistic reading (carrier: `DialValueCell`, hidden `widthTemplate`). **Haptics are reduced (D13a):** per-step taps are **silent**; a haptic fires ONLY at **min/max limits** (`Haptics.limit()`) and on **toggle flips** (`Haptics.tap()`), plus the Home hero count-up band detents.
4. **Needle** — anything that *displays a measured value* (`TickScale`). Sweeps only on **real moments** (screen load / explicit re-measure); minor updates settle instantly under `Motion.state`. Value changes animate **current→new directly — never back through zero** (79→42 travels straight down); sweep-from-zero is allowed ONLY on genuine first appearance (the Home count-up). Detent haptics are **opt-in** and restricted to the Home hero (`TickScale(detents: true)`).
5. **Surface** — sheets / expansions. **One-unit entrance** (the surface moves as a whole, origin-aware, interruptible, 200–250ms) — **no content stagger** (D13f; the v4.0 40ms row-stagger inside sheets is retired). Carrier: WS3's `SheetChrome` + `Motion.entrance`.

Motion carriers added in v4.1: `Motion.rowWell`, `Motion.digitRoll`, and `Motion.tickSpring` (the ONE sanctioned overshoot — Console tab tick only). The `tickSpring` overshoot must appear nowhere else.

## Implementation Rules for SwiftUI

1. **Corners from `CornerTokens` only** (card 5 / panel 5 / control 4; pill = chips only). Hand-typed radius literals are fence failures.
2. **No `.shadow()` anywhere.** Elevation = plane + hairline.
3. **All data numerals use the `dial*` tokens** (tabular by construction). Non-dial numeric text keeps `.monospacedDigit()`.
4. **Index Rule:** `ColorTokens.index` only as scale needles, the active-tab tick, and the live-recording dot. Never fill/text/decoration. (`accent` alias exists mid-pivot; do not add NEW `accent` usages.)
5. **Panel Law:** at most one black panel per screen, hero reading only; everything else on aluminum cards.
6. **Zone state = text label first**, color supplementary; never color alone.
7. **Light-only** via `ColorTokens` semantic tokens; never hex literals in views; no dark-mode branches.
8. **Typography via `Font.Tokens.*` only** — General Sans UI voice + IBM Plex Mono dial voice. No `.system()`, no semantic styles, and never name the mono outside `FontTokens.swift`. `SourceSerif4` is a banned string app-wide.
9. **CTAs are butted key cells** (ink fill), never pills, never red.
10. **Spacing on the 8pt grid** (4pt `baselinePair` only).
11. **Motion through `Motion` tokens only**, per the v4 motion law.
12. **Interaction through the Five Primitives** (v4.1): every touchable uses its one defined response — `.key` / `.pressable` (Key), `.rowWell` (Row), detent controls with fixed-width `DialValueCell` value areas + reduced haptics, `TickScale` needles that never return to zero, one-unit sheet surfaces. Value cells that display data numerals never resize with digit count (reserve the widest reading).

## v4.2 "Machined" amendment (2026-07-21 — decisions D16–D18)

**The Relief Law.** Every machined surface is either RAISED or DEBOSSED; flat is reserved for the base plane and text. Implemented as the two chokepoint modifiers in CardStyle.swift — never hand-rolled:
- **`.raised(cornerRadius:)`** — milled plate (tuning pick 1-B): `surfaceEl2→surfaceEl` vertical gradient, 1px `reliefHighlight` top line inside the shape, `dividerStrong` hairline. Cards, option cells, keys, toggle knobs.
- **`.debossed(cornerRadius:)`** — pocket (pick 2-B): `wellTop→wellBottom` gradient, 1.5px `reliefShade` inner top edge, 1px `reliefHighlightSoft` bottom closing line, `dividerStrong` hairline. Readout wells, focused fields, option channels, toggle tracks.
- No `.shadow()` anywhere — relief is strokes + gradients only; the no-shadow law holds.

**Readout wells.** Every displayed value (form values, stepper counts, selections) sits in a fixed-width debossed well: mono value + micro-caps unit; digits change, the metal never resizes.

**Press inverts relief (pick 4-A).** Keys press in ~85ms (raised→pocket: highlight dies, inner shade appears, 0.5px drop, brightness lift) and release on a ~300ms non-bouncy spring. This asymmetry + inversion is the app's press feel; scale-only presses are retired for keys.

**Machined form system** (InstrumentForm.swift): 56pt press-well rows; drawn 1.5px tick-chevrons rotating on the spring; options expand INLINE as butted raised cells with drilled selection dots inside a debossed channel (pick 5-A) — stock iOS `Menu` is BANNED app-wide for settings/pickers; fields grow a debossed focus well + ink border; toggle = round polished knob (pick 3-B) in a debossed channel that turns ink when on, with an engraved index tick; destructive rows are quiet zone-danger text.

**Spring motion law (D16).** Motion tokens move from fixed timing curves to NON-BOUNCY springs (interruptible, velocity-preserving). No content anywhere may pass through full invisibility during a transition (the dip-crossfade is banned); tab content hands off layered (incoming rises ~6px + fades over the outgoing). `tickSpring` remains the sole sanctioned overshoot. Durations stay in the premium-fast band (presses ~100ms in, settles ≤400ms, transitions ≤300ms).

## Retired v3 concepts (do not reintroduce)

| v3 concept                              | v4 status                                                    |
|-----------------------------------------|--------------------------------------------------------------|
| Source Serif 4 display voice            | DELETED (tokens, chokepoint, font files); name banned by fence |
| Halftone signature (`HalftoneField`)    | DELETED (component + fence + call sites)                     |
| Accent-as-fill CTA (blue pill)          | RETIRED — CTAs are ink-filled butted key cells               |
| 12pt card / 8pt control corners         | Retuned to 5 / 4 (near-square)                               |
| Pill CTAs (`Capsule` buttons)           | DEMOTED — capsule geometry for chips/badges only             |
| Cool paper-blue palette + stone-blue accent | REPLACED by aluminum/panel palette + red index           |
| Serif hero + accent-colored score       | Hero reading = `dialHero` mono in `panelInk` on the panel    |

Retained from v2/v3: light-only, no shadows, 8pt grid, text-label-first zones, nocebo guard (equal-weight decision keys), hairline elevation grammar, InkTabBar/ScreenHeader architecture, Motion/Haptics chokepoints, fence-test enforcement.

## Decisions Log

| Date       | Decision                                         | Rationale                                                                           |
|------------|--------------------------------------------------|-------------------------------------------------------------------------------------|
| 2026-03-21 | International Style Minimalism aesthetic         | Differentiates from Whoop/Strava's aggressive energy coding                          |
| 2026-03-21 | Zone colors desaturated to near-gray             | States communicated through labels, color supplementary — calm > alarm               |
| 2026-05-11 | General Sans as the UI voice                     | Rationalist neo-grotesque — lining figures, small-size readability                   |
| 2026-06-17 | Tuwa v2 — light ladder, live-state accent, Motion/Haptics chokepoints | Foundation grammar that v4 retains structurally                 |
| 2026-06-27 | Light-only direction confirmed                   | Light appearance is the only supported material expression                           |
| 2026-07-14 | Tuwa v3 "Ink & Grain" — serif display, 12pt corners, halftone, accent pill CTA | Superseded by v4: on-device dogfood failed on aesthetics ("feels like a default app") |
| 2026-07-20 | **Tuwa v4 "Instrument" (Aluminum Panel)** — Braun/B&O/Contax pivot | User decisions D9–D11: v1.6 dogfood failed on aesthetics; treatment picked via 2 mockup rounds (column D). Full pivot: serif + halftone + paper-blue palette retired; IBM Plex Mono dial voice, black panel hero, red index marks, near-square geometry, butted keys, TickScale grammar, Emil Kowalski motion law. Structural v1.6 work (rehost, InkTabBar, ScreenHeader, movement bank, fences) retained. |
| 2026-07-21 | **v4.2 "Machined"** — Relief Law, readout wells, press-inversion, machined form system, spring motion refit | User decisions D16–D18 after v4.1 review ("subtle but not premium; components raw"): tuning-board picks 1-B milled relief / 2-B debossed wells / 3-B round machined toggle / 4-A press inversion / 5-A machined option cells; full spring refit (no-dip transitions, asymmetric press); stock iOS Menu banned; form system app-wide. Demos: `tuwa-v42-premium-demos.html`, `tuwa-v42-ultra-forms.html`, `tuwa-v42-tuning-board.html`. |
| 2026-07-20 | **v4.1 polish round** — Console tab bar + Five-Primitive Interaction Law | User decisions D12–D15: Console tab bar (11pt title-case, sliding well + springy red tick, press-down 0.94); the five-primitive interaction fabric ratified with adjustments (reduced haptics, ~100ms subtle digit-roll, fixed-width dial value cells, needles never return to zero, sheet surfaces enter as one unit with no content stagger); layout recomposition across all tabs. Motion carriers `rowWell`/`digitRoll`/`tickSpring` added; `tickSpring` is the sole sanctioned overshoot. |
