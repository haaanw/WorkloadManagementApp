# Design System — Tuwa

**v6 "Field Notes" — 2026-07-30.** An **overlay on v5 "Pavilion" (Warm Stone), not a replacement.** Chosen from a 3-direction exploration (`design-system/explorations/Visual Directions.html`, option 1c). Pavilion's material, geometry, relief, motion, and interaction laws all stand unchanged; v6 engraves two things on top of them: a **Fragment Mono annotation layer** and **five metric hue identities**.

Lineage: /design-consultation 2026-03-21 · light-only v2 2026-06-17 · v3 "Ink & Grain" 2026-07-14 · v4 "Instrument" 2026-07-20–21 · v5 return-to-basis 2026-07-21 · **v6 "Field Notes" 2026-07-30**.

**Canonical source of truth for v6:** `design-system/` in this repo (`SKILL.md` → `readme.md` → `tokens/` → `guidelines/` → `components/` → `ui_kits/`). This file is the iOS-binding restatement of it; where the two disagree, `design-system/tokens/` wins on values and this file wins on iOS enforcement.

**The v6 thesis, in one line:** the card is stone; the writing on it is a scientist's.

## What v6 changes, and what it does not

**Changed by v6 (four things only):**

1. **Five metric hues** — each metric owns a hue, grown from the app icon's hue families. Legends become unnecessary.
2. **Re-tuned zone colors** — more chromatic than v5's near-grays, still label-first (nocebo guard untouched).
3. **The Fragment Mono annotation layer** — marginalia at ≤12pt, uppercase, +0.05em tracking. Annotation ONLY: never body, never headline, never a sentence.
4. **Annotation choreography** — mono labels fade in 40ms-staggered *after* the surface settles ("the card exists, then the scientist labels it").

**Unchanged and still binding (do not relitigate):** the Corner Law (`CornerTokens` 12/8/pill), the no-shadow law and the whole Relief system (`.raised`/`.debossed`), the 8pt grid (4pt `baselinePair` only), light-only appearance, sentence case for all app voice, zone-state-never-by-color-alone, the nocebo guard, one ink-filled pill CTA per screen maximum, readout wells, TickScale grammar, the Five-Primitive Interaction Law, the Motion spring law and `Motion` token chokepoint, `tickSpring` as the ONE sanctioned overshoot, the Noto Sans SC CJK cascade, and every fence in `DesignSystemFenceTests`.

## Product Context

- **What this is:** An iOS app for athlete workload management — synthesizing HRV, sleep, training load, and recovery into a single daily readiness score and a plain-English **verdict**: execute, modify, or hold today's plan.
- **Who it's for:** Serious amateur self-coached athletes (beachhead: competitive basketball players who also strength-train) who want to understand their body, not just collect data.
- **Space / industry:** Sports performance, training load management, recovery science. Competing with Whoop, Garmin Connect, TrainingPeaks, Strava — and deliberately refusing their scoreboard energy.
- **Project type:** iOS native app (SwiftUI + SwiftData + HealthKit). No third-party UI frameworks.
- **Brand personality:** calm, precise, authoritative. A scientific instrument, not a hype dashboard. "Show the decision, not the machinery. Use restraint as confidence. Suggest and explain, never overwrite."

## Aesthetic Direction

- **Direction:** International Style Minimalism rendered in warm stone (v5, unchanged) — structure IS the aesthetic; every element earns its place or it does not exist. v6 adds the **field notebook**: a scientist's terse mono marginalia annotating a stone instrument.
- **Design references:** Barcelona Pavilion (Mies, 1929 — one precious material, used once, completely), Seagram Building, Braun (Rams' control discipline), Apple Health; **new in v6:** laboratory notebooks, instrument engraving, technical drawing callouts.
- **Decoration level:** None. No textures, no gradients except the two relief gradients, no shadows, no ornament, no imagery in the app. Hierarchy is proportion, spacing, the single weight step, and physical relief.
- **Mood:** Quiet confidence. A high-end chronograph in a warm room, not a scoreboard.

**Retired with v4, still retired:** the black instrument panel, the red index, the mono *dial* voice (distinct from v6's annotation layer — see below), the aluminum palette, near-square geometry, micro-caps screen titles.

## Typography — the Two-Voice Type Law (v6)

v5's One-Voice Law is **amended, narrowly**. The app now speaks in exactly **two** faces, with strictly disjoint jobs:

| Voice | Face | Job | Size law |
|---|---|---|---|
| **Working voice** | **Instrument Sans** (static Regular 400 + Medium 500) | Everything the app *says* — titles, body, labels, values, CTAs, tab labels | The app ramp below |
| **Annotation voice** | **Fragment Mono** (Regular 400) | Everything the app *annotates* — units, deltas, timestamps, axis labels, reason trees, machine-flavored keys | **≤12pt, HARD CAP** |

- **Alpino is display-only and BANNED in the app.** It exists for marketing surfaces and slides (`--font-display`). No app view may reference it; the fence enforces this.
- **Noto Sans SC is a cascade fallback, not a voice** — retained on every token, both faces.
- **Hierarchy still comes from size + the single weight step** (400→500) in the working voice. No bold, no italic, no semantic styles.
- **Numerals:** every data numeral applies `.monospacedDigit()` at the call site. Both faces carry tabular figures.
- **Case discipline:** sentence case everywhere in the working voice. Micro-caps (+0.08em) only at micro size, Latin locales only. **The annotation voice is always uppercase** — that is the annotation layer's own law, not an exception to sentence case, because annotation is machine output, not speech.
- **RETIRED and fence-banned, unchanged:** `SourceSerif4` (v3 serif) and `IBMPlexMono` (the v4 mono *dial* voice — a display face for 30–64pt values; v6's Fragment Mono is its opposite, capped at 12pt marginalia. Reintroducing a mono at display size is still a violation).

### Type Scale

| Role          | Size | Weight | Token                  | Notes                                        |
|---------------|------|--------|------------------------|----------------------------------------------|
| Hero reading  | 64pt | 400    | `heroScore`            | Tabular, line-height 1 — colored by its metric's hue, or accent when it has no metric identity (see the Reading Color Rule) |
| Display value | 32pt | 400    | `displayAction`        | Verdict copy / standing values                |
| Page title    | 28pt | 400    | `pageTitle`            | Sentence case                                 |
| Section head  | 17pt | 500    | `sectionHead`          |                                              |
| Body          | 17pt | 400    | `body`                 | Line-height 1.55                              |
| Label         | 15pt | 400    | `label`                |                                              |
| Small label   | 13pt | 400    | `smallLabel`           |                                              |
| Micro / cap   | 11pt | 400    | `micro`                | +0.08em tracking, caps, Latin only            |
| Tab label     | 11pt | 500    | `tabLabel`             | Title case                                    |
| Key label     | 11pt | 500    | `keyLabel`             | Decision-key cells; sentence case             |
| **Annotation**    | **12pt** | 400 | **`anno`**         | **Fragment Mono, uppercase, +0.05em — the standard marginalia size** |
| **Annotation sm** | **11pt** | 400 | **`annoSmall`**    | **Fragment Mono, uppercase, +0.05em — axis labels, timestamps.** Raised 10→11pt (v6.1, HAN 2026-07-30): mono uppercase is the densest text in the app and 10pt read as too small on device. 11pt matches `micro`, keeps the ≤12pt cap, and stays one step below `anno` so the two sizes remain distinguishable |

The 12pt annotation cap is enforced at the token, not the call site: `anno`/`annoSmall` are the only routes to Fragment Mono, and a fence test asserts no larger mono size exists.

### The Annotation Layer (v6 — the visible signature)

**What annotation is for:** units (`62 MS`), deltas (`+4`, `▲`, `=`), timestamps and cycle position (`MON 07.28 · WK 31`, `D-028`), chart axis labels, machine-flavored keys (`HRV_BASELINE: TRUE`, `LOAD_HEADROOM: 0.23`), and reason trees (`├─ HRV AT BASELINE` / `└─ LOAD_HEADROOM: 0.23`).

**What annotation is never for:** body copy, headlines, verdict sentences, CTA labels, tab labels, screen titles, or any string the app *says* to the athlete. **The annotation voice annotates; it never speaks sentences.** The verdict — "HRV is at baseline and yesterday's session left headroom." — is working voice, always.

**Register:** UPPERCASE, terse, machine-flavored. Numbers precise and unitized. Deltas signed.

**The annotation glyph set** — Unicode is the icon system, rendered in Fragment Mono at ≤12pt:

| Glyphs | Use |
|---|---|
| `▲ △ ▼ ▽` | Deltas / direction |
| `● ○` | State dots (filled = live, open = crosshair marker) |
| `├─ └─` | Reason trees |
| `▁▂▃▄▅▆▇█` | Spark bars |
| `░ ▒` | Fills / sufficiency |
| `·` | Separator |

No icon font. **No emoji, ever.** The app's few true glyphs remain SF Symbols (`chevron.right`) at text sizes. The tab bar stays text-only — that is law.

**i18n:** zh-Hans gets **no case transform and no added tracking** on annotation (uppercase is meaningless and tracking harms CJK). The annotation modifier applies both conditionally on locale script — call sites do not decide this.

### Font Loading (iOS)

Bundle, and register in `Info.plist` → `UIAppFonts`:

- `InstrumentSans-Regular.ttf`, `InstrumentSans-Medium.ttf` (static faces — the variable font is NOT used; the GeneralSans variable-font PS-name trap of 2026-07-17 is why)
- `NotoSansSC-Regular.otf`, `NotoSansSC-Medium.otf`
- **`FragmentMono-Regular.ttf`** (new in v6)

Reference ONLY via `FontTokens.swift`; PostScript names live only there, are listed in `Font.Tokens.requiredPostScriptNames`, and are runtime-verified by the DEBUG launch assertion in `WorkloadApp.swift`. A font that fails to register falls back silently — that assertion is the only thing that catches it.

Sources & licenses (both SIL OFL 1.1, embedding permitted; bundle the license text beside the face):
- Instrument Sans — https://fonts.google.com/specimen/Instrument+Sans → `WorkloadApp/Resources/Fonts/InstrumentSans-LICENSE.txt`
- **Fragment Mono** (Wei Huang) — https://fonts.google.com/specimen/Fragment+Mono → `WorkloadApp/Resources/Fonts/FragmentMono-LICENSE.txt`

## Color

### Light Mode — warm stone (light-only, v5 material carried whole)

Tuwa is intentionally light-only; the app forces light appearance. One warm stone material in ascending planes of light (the relief system needs raised = brighter), warm ink, a travertine accent, and — new in v6 — five metric hues.

**Stone, ink, accent — unchanged from v5:**

| Token              | Hex       | Usage                                                       |
|--------------------|-----------|-------------------------------------------------------------|
| `--bg`             | `#F0EFEC` | Stone base plane (page/scroll canvas)                       |
| `--surface`        | `#F4F3F0` | Inline strip / control plane                                |
| `--surface-el`     | `#F8F7F4` | Card plane (canonical card fill)                            |
| `--surface-el-2`   | `#FCFBF9` | Brightest plane — raised tops, active/selected surfaces     |
| `--divider`        | `#D6D3CD` | Hairline rules                                              |
| `--divider-strong` | `#CCC9C2` | Strong hairline — key-row containers, priority boundaries   |
| `--well-top`       | `#E7E5E0` | Debossed well gradient, top                                 |
| `--well-bottom`    | `#EDEBE6` | Debossed well gradient, bottom                              |
| `--text-1`         | `#1B1A17` | Warm ink (≈15:1 on base)                                    |
| `--text-2`         | `#57544E` | Secondary (≈6.6:1 on base)                                  |
| `--text-3`         | `#8B877F` | Tertiary / micro-caps / **annotation default** (≥3:1 on card)|
| `--disabled`       | `#A19D95` | Disabled-only glyphs — never information-carrying           |
| `--ink-inverse`    | `#F4F3F0` | Light text on ink fills (the primary-CTA text color)         |
| `--accent`         | `#6F6759` | **Travertine.** Live-state marks + hero readings without a metric identity |

### Metric identities (NEW in v6)

Five hues derived from the app icon's hue families, re-tuned 2026-07-28 for mutual distinguishability (wide hue spread, varied lightness). **Each metric owns its hue** — so a legend is never needed.

| Token                | Hex       | Metric                    | Hue        |
|----------------------|-----------|---------------------------|------------|
| `--metric-readiness` | `#2E7D4F` | Readiness / recovery score| Verdant green |
| `--metric-recovery`  | `#1D7189` | HRV / recovery physiology | Teal       |
| `--metric-sleep`     | `#52589E` | Sleep                     | Indigo     |
| `--metric-strain`    | `#A8442D` | Strain / acute load       | Rust       |
| `--metric-load`      | `#8A6810` | Training load / ACWR      | Ochre      |

**Metric hues may be used as:** series lines, state dots, chart "now" markers, and hero readings (by identity).
**Metric hues may NEVER be used as:** plane fills, card backgrounds, CTA fills, decorative tints, or icon tints at rest. A hue identifies a *measurement*; it never dresses a *surface*.

These five are the **only** colors v6 adds. Adding a sixth hue is a design change requiring approval, and the fence test enumerates the set.

### Zone colors (RE-TUNED in v6)

| Token            | v5 (retired) | **v6**    | Meaning                        |
|------------------|--------------|-----------|--------------------------------|
| `--zone-optimal` | `#3F5A46`    | `#2E7D4F` | Optimal (= `metric-readiness`) |
| `--zone-caution` | `#6E5624`    | `#8A5C08` | Caution                        |
| `--zone-danger`  | `#7E362E`    | `#9E3428` | High risk                      |
| `--zone-low`     | `#46525E`    | `#52589E` | Undertrained / low (= `metric-sleep`) |

v6 zones are **more chromatic than v5's near-grays** — a deliberate legibility gain on a gym floor. They remain desaturated relative to any alarm palette, and **the Zone Color Rule is untouched: state is communicated by the text label first** ("Optimal" / "Caution" / "High risk"), color is supplementary (label + optional hairline capsule or colored rule), **never color alone**. Zone badges are text + hairline capsule — never a fill.

Note the two deliberate identities: `zone-optimal` shares the readiness hue and `zone-low` shares the sleep hue. That is intended (a zone *is* a readiness statement), not an accident to be "fixed".

### Charts

| Token             | Hex       | Usage                                       |
|-------------------|-----------|---------------------------------------------|
| `--chart-grid`    | `#E4E2DC` | Hairline grid lines (NEW in v6)             |
| `--chart-positive`| `#4E7A74` | Muted supporting hue (retained from v5)     |

Chart grammar: lines **1.5pt, hue-coded by metric**; baselines dashed; grids hairline `chart-grid`; **axis labels in `annoSmall` (10pt Fragment Mono)**; crosshair markers are open circles (`○`); one hue dot marks "now". Values typewrite; lines draw left-to-right. The v5 warm-ink series tokens (`chartATL`, `chartCTL`, `chartVolume`, `chartSleep`, `chartHRV`, `chartTSB`) remain for series that carry no metric identity; series that DO carry one take the metric hue.

### The Reading Color Rule (v6 — supersedes the v5 Accent Rule)

v5 gave the hero score to travertine. v6 gives it to the metric — because a metric owning its hue is the whole point of the hue system, and the hero *is* a metric reading. Travertine keeps everything else it had.

**A metric hue may color:**
1. **The hero reading** of a screen, taking its own metric's hue (Home readiness → `metric-readiness`; Load ACWR → `metric-load`).
2. **Series lines, state dots, and chart "now" markers** for that metric.
3. **Metric-hue annotation** (a `● READINESS` key), subject to the contrast rule below.

**`--accent` (travertine `#6F6759`) may color:**
1. **Live-state marks** — progress fills, active/selected marks, the active-tab tick, the live-recording dot, scale needles. This is accent's exclusive territory; a metric hue never takes a live-state mark.
2. **A hero reading that has no metric identity** (a composite or unlabeled standing value).

**Neither may ever be:** decorative, a CTA fill, body or label text, or an icon tint at rest. The primary CTA stays ink-filled.

**No count cap (v6.1 — HAN, 2026-07-30).** The former rule "at most one colored text element per screen — the hero reading" is **removed**. It was unworkable and self-contradictory: it forbade the metric-hue annotation key that this same section sanctions, and it was contradicted by the design system's own iOS specimen — `ui_kits/ios-app/LoadScreen.jsx:14-19` renders `ACWR ●`, the `1.23` reading, and `LOAD STEADY` as three colored elements on one card. Adoption had already diverged on it (Home carried three, Recovery one), which is the signal that the rule was wrong rather than that the screens were.

What governs instead is **identity, not arithmetic**: a colored text element must name the metric or zone whose hue it wears, hue must never be the only carrier of meaning (rule 6), and it must clear the contrast floors below. Restraint comes from how few elements legitimately *have* a hue identity — not from a quota. A hue applied to something that does not own it is still a violation; three keyed elements are not.

### Contrast floors (measured, v6)

Text ≥4.5:1 (small) / ≥3:1 (≥24pt or 19pt bold); graphical marks ≥3:1. Pure `#FFFFFF`/`#000000` never used. `--disabled` is exempt only because it never carries information.

Measured against the stone planes (all five hues and four zones):

- **On card planes (`surface-el` #F8F7F4, `surface-el-2` #FCFBF9): every metric hue and zone color clears 4.5:1** (lowest: readiness/optimal 4.71:1 on card).
- **On the base plane (`bg` #F0EFEC): `metric-readiness`/`zone-optimal` measure 4.39:1 and `metric-load` 4.49:1** — below the small-text floor, comfortably above the 3:1 large-text and graphical floor.
- **On wells (`well-top` #E7E5E0): readiness 4.01:1, load 4.10:1, recovery 4.42:1** — large-text and graphical only.

**The rule this yields — binding:**

1. **Hero readings (≥32pt) may take a metric hue on any plane** — the large-text floor is 3:1 and the worst case is 4.01:1.
2. **Metric-hue or zone-colored text below 24pt lives on a card plane** (`surfaceEl`/`surfaceEl2`), where all nine colors clear 4.5:1. This is where zone badges and metric-hue annotation keys already sit; keep them there.
3. **Marks are unrestricted** — lines, dots, needles, rules, and ticks clear the 3:1 graphical floor on every plane.
4. **Annotation default color is `text3`** and inherits the micro-label floor (≥3:1 on card; measured 3.34:1). Annotation that carries information the athlete must not miss uses `text2` (7.04:1 on card) or a metric hue on a card plane — never `text3` on a well (2.84:1, below floor).

### Corner Law (unchanged from v5)

Every radius comes from `CornerTokens` — never a hand-typed literal:

| Token                  | Value   | Applies to                                      |
|------------------------|---------|-------------------------------------------------|
| `CornerTokens.card`    | 12pt    | Cards, plates, grouped surfaces, sheets         |
| `CornerTokens.control` | 8pt     | Inputs, cells, steppers, wells, small plates    |
| `CornerTokens.pill`    | capsule | Chips, badges, and the primary CTA              |

Hairline borders stay 0.5pt; still NO shadows — elevation is plane + hairline + relief.

### The Relief Law (unchanged from v5)

Every machined surface is either RAISED or DEBOSSED; flat is reserved for the base plane and text. The two chokepoint modifiers in `CardStyle.swift` — never hand-rolled:

- **`.raised(cornerRadius:)`** — milled plate: `surfaceEl2→surfaceEl` vertical gradient, 1px `reliefHighlight` top line, `dividerStrong` hairline. Cards, option cells, keys, toggle knobs.
- **`.debossed(cornerRadius:)`** — pocket: `wellTop→wellBottom` gradient, 1.5px `reliefShade` inner top edge, 1px `reliefHighlightSoft` bottom closing line, `dividerStrong` hairline. Readout wells, focused fields, option channels, toggle tracks.
- No `.shadow()` anywhere — relief is strokes + gradients only.

**Readout wells:** every displayed value sits in a fixed-width debossed well — tabular value + annotation unit; digits change, the stone never resizes.

**Press inverts relief:** keys press in ~85ms (raised→pocket) and release on a ~300ms non-bouncy spring. The machined form system (`InstrumentForm.swift`) carries over; stock iOS `Menu` remains BANNED for settings/pickers.

### Hero Law (unchanged from v5, recolored by v6)

- One hero card per screen maximum, carrying the screen's one hero reading as `heroScore` — now in **its metric's hue** (Reading Color Rule).
- Heroes are **RAISED LIGHT CARDS**. Everything else reads in ink on the same stone. A dark surface anywhere is a design error; `panelStyle(` is fence-banned.

### TickScale (unchanged from v5)

Two-weight tick marks in warm grays (minor/major from `text3`/`text2`), numerals at micro size — **moving to `annoSmall` in v6** — optional ink zone band, optional ghost mark, and a **1.5px accent needle** (a needle is a live-state mark: accent, never a metric hue). Detent haptics stay Home-hero-only. Needles never travel back through zero.

### CTA & Key Row Law (unchanged from v5)

- **Primary CTA:** ink-filled pill — `text1` fill, `inkInverse` text, `Capsule()` geometry, `.raised` relief. One per screen at most. Never accent-filled, never hue-filled.
- **Decision rows keep the butted equal-weight grammar** inside a raised 12pt container with interior 0.5pt hairlines: the **nocebo guard** — "act" and "keep plan" carry equal visual weight; the UI never pressures the athlete toward modifying. Key labels: `keyLabel` 11pt Medium, sentence case.

### Tab bar (unchanged from v5)

InkTabBar architecture and a11y IDs unchanged. Text-only title-case labels (11pt Medium) on a flat opaque bar (`tabBarSurface` `#ECEBE7`, 0.5pt `dividerStrong` top hairline). Selection = ink step `text3→text1` + the faint sliding well (`text1` @5%, 8pt plate, `Motion.state`) + the 1.5pt **accent** tick sliding on `Motion.tickSpring` — still the ONE sanctioned overshoot. Per-item press-down scale 0.94. No icons, ever.

## Spacing (unchanged from v5)

- **Base unit:** 8pt. Structural spacing must be multiples of 8pt; 4pt only as the sanctioned `baselinePair` micro-gap (micro-label → value).

| Token | Value | Usage                                          |
|-------|-------|------------------------------------------------|
| xs    | 8pt   | Icon-label gaps, tight inline spacing          |
| sm    | 16pt  | Card internal padding (horizontal), small gaps |
| md    | 24pt  | Card internal padding (vertical), standard gaps|
| lg    | 32pt  | Section gaps                                   |
| xl    | 48pt  | Major section breaks                           |
| 2xl   | 64pt  | Page-level breathing room                      |

Separator grammar: section break = 32pt gap + 17pt Medium header; row separator = 0.5pt hairline inset 16pt.

## Layout (unchanged from v5)

- Grid-disciplined, single scrollable canvas per tab; 16pt horizontal margins.
- Screen top: context line above a 28pt sentence-case page title. In v6 that context line is the natural home of an **annotation** stamp (`MON 07.28 · WK 31`).
- Home (top → bottom): header → hero readiness card (label · 64pt hue score · zone label · TickScale) → metric rows on a card → verdict card (display value in ink · reason · equal-weight key row) → tab bar.
- Progressive disclosure: score → reasons → trends. The dashboard is a reading, not a data dump.

## Motion (v5 spring law carried whole + one v6 addition)

- **Non-bouncy springs** (interruptible, velocity-preserving) via the `Motion` token enum (`CardStyle.swift`) — the single chokepoint. Never a bare `withAnimation`, never a hand-typed curve/duration at a call site. `reduceMotion` honored via `Motion.resolved(_:reduceMotion:)`.
- **No ease-in, ever.** No content passes through full invisibility (dip-crossfade banned); tab content hands off layered.
- **Durations:** presses ~85–100ms in / ≤400ms settle; state ≤250ms; transitions ≤300ms.
- **Count-up:** hero score count-up ≤400ms — the one intentional moment of delight.
- **Haptics:** commit-only + limit/toggle detents + Home hero count-up detents. Never decorative.
- `Motion.tickSpring` remains the sole sanctioned overshoot (tab tick only).

**Annotation choreography (NEW in v6).** Mono labels fade in **40ms-staggered after the surface settles** — the card exists, then the scientist labels it. Tokens: `Motion.anno` (180ms fade) and the existing `Motion.staggerStep` (0.04 = 40ms). Implemented **once** as the `.annotationReveal(index:)` primitive in `CardStyle.swift`; screens consume it and never reimplement a stagger. Reduced Motion shows annotation immediately with no transform and no delayed work.

## The Five-Primitive Interaction Law (unchanged from v5)

Every touchable class has exactly one defined response; carriers live in `CardStyle.swift`, call sites reference styles/tokens only:

1. **Key** (commits an action) — press-inversion relief, release on the non-bouncy spring.
2. **Row** (navigates) — background well (`text1` @6%), no scale, `Motion.rowWell`.
3. **Detent control** (discrete values) — mechanical snap, ~100ms digit-roll, fixed-width readout wells, reduced haptics.
4. **Needle** (displays a measured value) — sweeps on real moments only; current→new directly, never back through zero.
5. **Surface** (sheets/expansions) — one-unit origin-aware entrance, 200–250ms, no content stagger.

Annotation is **not** a sixth primitive — it is not touchable. It is choreography on top of Surface.

## Implementation Rules for SwiftUI

1. **Corners from `CornerTokens` only** (card 12 / control 8 / pill). Hand-typed radius literals are fence failures.
2. **No `.shadow()` anywhere.** Elevation = plane + hairline + relief (`.raised`/`.debossed` only).
3. **Two voices, disjoint jobs:** working copy via `Font.Tokens.*` (Instrument Sans); marginalia via `Font.Tokens.anno` / `.annoSmall` (Fragment Mono, ≤12pt, uppercase+tracking applied by the token/modifier, not the call site). No `.system(`, no semantic styles. `IBMPlexMono`, `SourceSerif4`, and `Alpino` are banned strings app-wide. `FragmentMono` appears only in `FontTokens.swift`. All data numerals apply `.monospacedDigit()`.
4. **Reading Color Rule:** hero readings take their metric's hue; `ColorTokens.accent` owns live-state marks (progress fills, active/selected, tab tick, recording dot, needles) and identity-less hero readings. Metric hues never fill a surface. A colored text element must name the metric or zone whose hue it wears — there is **no cap on how many** do (v6.1).
5. **Hero Law:** at most one hero card per screen; raised light card. No dark surfaces; `panelStyle(` banned.
6. **Zone state = text label first**, color supplementary; never color alone. Zone badges are text + hairline capsule, never a fill.
7. **Contrast:** metric-hue/zone text below 24pt only on card planes; hero readings any plane; marks any plane; annotation defaults to `text3` and never sits on a well.
8. **Light-only** via `ColorTokens` semantic tokens; never hex literals in views; no dark-mode branches.
9. **Annotation is marginalia:** units, deltas, timestamps, axis labels, reason trees, machine keys. Never a sentence, never a headline, never a CTA or tab label. zh-Hans gets no case transform and no added tracking (handled in the modifier).
10. **CTAs:** one ink-filled pill max per screen; decision rows are equal-weight butted cells (nocebo guard).
11. **Spacing on the 8pt grid** (4pt `baselinePair` only).
12. **Motion through `Motion` tokens only**; annotation choreography through `.annotationReveal(index:)` only; interaction through the Five Primitives.

## Retired concepts (do not reintroduce)

| Concept                                   | Status                                                        |
|-------------------------------------------|---------------------------------------------------------------|
| Source Serif 4 display voice (v3)         | DELETED; name banned by fence                                 |
| Halftone signature (v3)                   | DELETED                                                       |
| IBM Plex Mono **dial** voice (v4)         | DELETED; name banned. v6's Fragment Mono is marginalia ≤12pt — a mono at display size is still a violation |
| Black instrument panel + Panel Law (v4)   | RETIRED — hero = raised light card                            |
| Red index `#D04234` (v4)                  | RETIRED — live-state marks are accent                         |
| Aluminum cool-gray palette (v4)           | REPLACED by warm stone                                        |
| Near-square 5/4pt corners (v4)            | REPLACED by 12/8/pill                                         |
| Micro-caps wide-tracked screen titles (v4)| RETIRED — editorial titles (28pt sentence case)               |
| Dark-mode palette (v1)                    | Not carried — light-only stands                               |
| Accent-as-CTA-fill (v3)                   | Still retired — CTAs are ink-filled                           |
| Stock iOS `Menu` for settings/pickers     | Still banned (v4.2)                                           |
| v5 near-gray zone colors                  | SUPERSEDED by the v6 re-tune (label-first rule unchanged)     |
| Alpino in app UI (v6)                     | BANNED — marketing/slides only                                |

Retained lineage: light-only, no shadows, 8pt grid, text-label-first zones, nocebo guard, hairline elevation, InkTabBar/ScreenHeader architecture, Motion/Haptics chokepoints, relief system, readout wells, TickScale grammar, Five-Primitive interaction fabric, fence-test enforcement, Noto Sans SC cascade.

## Decisions Log

| Date       | Decision                                         | Rationale                                                                           |
|------------|--------------------------------------------------|-------------------------------------------------------------------------------------|
| 2026-03-21 | International Style Minimalism aesthetic         | Differentiates from Whoop/Strava's aggressive energy coding                          |
| 2026-03-21 | Zone colors desaturated to near-gray             | States communicated through labels, color supplementary — calm > alarm               |
| 2026-06-17 | Tuwa v2 — light ladder, live-state accent, Motion/Haptics chokepoints | Foundation grammar retained through v6                          |
| 2026-06-27 | Light-only direction confirmed                   | Light appearance is the only supported material expression                            |
| 2026-07-14 | Tuwa v3 "Ink & Grain"                            | Superseded: on-device dogfood failed on aesthetics                                   |
| 2026-07-20 | Tuwa v4 "Instrument" (Aluminum Panel) + v4.1 polish | Superseded as costume; its machinery survives as carry-overs                       |
| 2026-07-21 | v4.2 "Machined" — Relief Law, readout wells, press-inversion, spring refit | Carried into v5/v6 whole                                    |
| 2026-07-21 | Tuwa v5 "Pavilion" (Warm Stone) — return to v1 basis | User decision (D19): v1 International Style foundation restored with ratified carry-overs ONLY. Instrument Sans picked from a 7-face shootout as the single voice; panel/red-index/micro-caps-titles retired. |
| 2026-07-28 | Metric hues re-tuned for mutual contrast         | Five icon-derived hue families spread wide in hue and lightness so a metric is identifiable without a legend |
| **2026-07-30** | **Tuwa v6 "Field Notes" — overlay on v5, direction 1c** | The stone stays; a scientist's marginalia is engraved on it. Four changes only: five metric hues, re-tuned zone colors, a Fragment Mono annotation layer capped at 12pt, and 40ms-staggered annotation choreography. One-Voice becomes Two-Voice with strictly disjoint jobs (working voice speaks, annotation voice annotates). The hero reading moves from travertine to its metric's hue (Reading Color Rule); accent keeps live-state exclusively. Alpino is display-only and banned in-app. Every v5 law not in that list is unchanged and still binding. |
| **2026-07-30** | **v6.1 — readability corrections after the first on-device look (HAN)** | Three changes, all from watching v6 run rather than from reading it. (1) **The "one colored text element per screen" cap is removed** — it forbade the metric-hue annotation key this file sanctions and was contradicted by `ui_kits/ios-app/LoadScreen.jsx`, which renders three colored elements on one card. Replaced by identity: a colored element must name the metric or zone whose hue it wears, with no quota. (2) **`annoSmall` 10pt → 11pt** — mono uppercase at +0.05em is the densest text the app renders and 10pt was too small on device. (3) **Chart reference-line keys move out of the plot area** — `HRVTrendChart`'s 7-day baseline and `SleepTrendChart`'s 7 h target were pinned to their rule marks at `.top`/`.trailing`, landing on the series and bars respectively, so label and data obscured each other. Marginalia belongs in the margin: the key now sits above the plot and the dashed rule carries the position. |

### v6 open reconciliations (recorded, resolved as stated above)

Two places where `design-system/` said two things and this file had to choose; flagged for sign-off rather than silently decided:

1. **Who owns the hero reading.** `readme.md` says travertine appears "ONLY as the hero reading and live-state marks"; the same readme says metric hues color "hero readings by identity". `tokens/typography.css` resolves it — hero is "the one colored text element (accent **or** metric hue)". Adopted: metric hue when the reading has a metric identity, accent otherwise; accent keeps live-state exclusively.
2. **Annotation tracking.** `HANDOFF.md` and the distribution plan say **+0.05em**; the `guidelines/*.card.html` specimens render `.04em`. Adopted **+0.05em** (0.6pt at 12pt, 0.5pt at 10pt) as the binding value, since both prose sources agree and the cards are illustrative.

One measured correction to a design-system claim, recorded honestly: `readme.md` and `tokens/colors.css` state the zone colors are "≥4.5:1 on stone". Measured, they clear 4.5:1 on **card** planes but `zone-optimal` reaches only 4.39:1 on the `bg` base plane (and `metric-load` 4.49:1). No token value was changed to make this pass — instead the Contrast Floors section states the measured numbers and the usage rule that keeps every one of them legal.
