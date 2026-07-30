# Tuwa Design System — "Field Notes"

Tuwa is an iOS app for athlete workload management: it fuses HRV, sleep, training load, and recovery into a daily readiness score and a plain-English **verdict** — execute, modify, or hold today's plan. Users are serious self-coached hybrid athletes (beachhead: competitive basketball players who also strength-train). It competes with Whoop, Garmin, TrainingPeaks — and deliberately refuses their aggressive scoreboard energy.

**Brand personality:** calm, precise, authoritative. A scientific instrument, not a hype dashboard. "Show the decision, not the machinery. Use restraint as confidence. Suggest and explain, never overwrite."

## This system: "Field Notes" (v6, chosen 2026-07-28)

An evolution of the app's v5 "Pavilion" warm-stone language, chosen from a 3-direction exploration (`explorations/Visual Directions.html`, option 1c). Pavilion's material stays; a **mono annotation layer** and **metric hue identities** are engraved on top:

1. **The card is stone; the writing on it is a scientist's.** Warm-stone planes, 12/8/pill corners, hairlines, no shadows — plus Fragment Mono marginalia (units, deltas, axes, timestamps) at ≤12px.
2. **Each metric owns a hue** — five hues grown from Tuwa's app icon families, re-tuned for mutual contrast (wide hue spread, varied lightness): verdant green = readiness, teal = HRV/recovery, indigo = sleep, rust = strain, ochre = load. Legends become unnecessary.
3. **Three voices max:** Instrument Sans (the app's voice), Fragment Mono (annotation), Alpino (display — marketing/slides only, never app UI). Noto Sans SC is the CJK cascade fallback, not a voice.

## Sources

- Local codebase `Tonus/` (attached, read-only): iOS app `WorkloadApp/` (SwiftUI; `Components/CardStyle.swift` is the primitives chokepoint), marketing site `tuwa-website/` (Astro; tokens in `src/styles/global.css`), design spec `DESIGN.md` (v5 "Pavilion", 2026-07-21 — the ground truth this system evolves), `PRODUCT.md`, App Store screenshots, uploaded brand fonts (`fonts/Alpino-Variable.ttf`).
- Website: https://tuwa.app
- No wordmark asset exists in the sources; the mark is the app icon (`assets/icon-512.png`, abstract athlete of five ellipses). Wordmark = "Tuwa" set in Instrument Sans Medium.

## CONTENT FUNDAMENTALS

- **Sentence case everywhere.** Screen titles ("Today"), buttons ("Keep plan"), section heads. Micro-caps exist only at micro-label size (11px, +0.08em tracking, Latin locales only).
- **The verdict voice:** short declarative sentences addressed to "you", present tense, no exclamation points, no emoji ever. "Proceed as planned." · "HRV is at baseline and yesterday's session left headroom." Explanation follows decision, always.
- **Never alarmist, never punitive.** Zone states are "Optimal / Caution / High Risk" as text labels; recovery language avoids diagnosis and shame (explicit accessibility rule). The **nocebo guard**: "Adjust load" and "Keep plan" get equal visual weight — the UI never pressures the athlete toward modifying.
- **Numbers are precise and unitized:** "62 ms", "7.6 h", "1.12 ACWR". Data numerals always tabular. Deltas are signed: "+4", "=".
- **Marketing register** (tuwa.app): confident second person, benefit-first, science-backed without jargon. Headline pattern: short imperative or verdict-like ("Know when to push."). Anti-references: hype scoreboards, chatbot-coach framing, loud orange/red social fitness.
- **Annotation register (new in Field Notes):** mono marginalia is UPPERCASE, terse, machine-flavored: `HRV_BASELINE: TRUE`, `MON 07.28 · WK 31`, `D-028`, `62ms +4`. It annotates; it never speaks sentences.
- **i18n:** en / zh-Hans / fr ship today. Chinese gets no case transforms and no added tracking; zh chips widen horizontal padding (16 vs 8).

## VISUAL FOUNDATIONS

- **Color:** warm stone planes in ascending light (`--bg` → `--surface-el-2`); warm ink ramp; travertine `--accent #6F6759` under the **Accent Rule** — it may appear ONLY as the hero reading and live-state marks (progress fills, active ticks, needles, recording dot). Never decorative, never CTA fill, never labels. Metric hues (icon-derived) color series, dots, and hero readings by identity. Zone colors desaturated; state = text label first, color supplementary, never color alone. Light-only (locked decision — gym-floor readability). Pure #FFF/#000 never used.
- **Type:** hierarchy by size + one weight step (400→500). Ramp: 64 hero / 32 display / 28 page title / 17 section-500 / 17 body / 15 label / 13 small / 11 micro-caps. Mono annotation ≤12px, uppercase. Alpino only on marketing surfaces and slides, 650 weight, tight tracking.
- **Backgrounds:** flat stone. No textures, no gradients except the two relief gradients; no imagery in the app. Marketing may use the dotted-grid paper motif sparingly.
- **Elevation & cards:** NO shadows anywhere. Elevation = plane + 0.5px hairline + relief. Cards: `--surface-el` fill, 0.5px `--divider` border, 12px radius, 16px/24px padding. Emphasis card: `--surface-el-2` + `--divider-strong`. **Relief law:** every machined surface is raised (surface-el-2→surface-el gradient + 1px top highlight) or debossed (well-top→well-bottom + inner top shade); values sit in fixed-width debossed **readout wells** — digits change, the stone never resizes.
- **Borders & radii:** corner law 12 (cards) / 8 (controls) / pill (chips, badges, primary CTA). Hairlines 0.5px. Never other radii.
- **Buttons:** primary CTA = ink-filled pill (`--text-1` fill, `--ink-inverse` text), ONE per screen, never accent-filled. Secondary = hairline rectangle, 8px radius. Decision rows = butted equal-weight cells in one 12px container with interior hairlines.
- **Hover (web):** color shifts to ink or accent, 100–180ms ease-out; cards lift ≤2px translate, border darkens toward accent-mixed divider. No opacity fades on text.
- **Press:** relief inversion — the key sinks (raised→pocket) in ~100ms, releases on a ~300ms non-bouncy spring. Scale 0.94–0.98 only on light chrome.
- **Motion:** non-bouncy interruptible springs; no ease-in ever; no content passes through invisibility. Presses ~100ms, state ≤250ms, transitions ≤300ms, hero count-up ≤400ms (the one moment of delight). One sanctioned overshoot: the tab tick. **Annotation choreography (new):** mono labels fade in 40ms-staggered after the surface settles. Reduced motion honored.
- **Charts:** ink lines 1.5px, hue-coded by metric; dashed baselines; `--chart-grid` hairline grids; mono axis labels at 10px; crosshair markers (open circles); one accent/hue dot for "now". Values typewrite; lines draw left-to-right.
- **Transparency/blur:** none. Opaque planes only.
- **Imagery:** app has none. Marketing: framed app screenshots in a CSS device frame (dark bezel is the ONE dark surface allowed on the site); photography not part of the brand today.
- **Layout:** single scrollable canvas per tab, 16px margins, sections separated by 32px gap + 17px/500 header; row separators 0.5px inset 16px. Progressive disclosure: score → reasons → trends.

## ICONOGRAPHY

- **The app is essentially icon-free by design.** Tab bar is text-only (title-case 11px/500 labels — no icons, law). The app's few glyphs are SF Symbols (`chevron.right`, etc.) at text sizes; on web, use thin 1.5px-stroke line glyphs matching SF proportions, or Unicode/box-drawing marks.
- **The annotation glyph set (Field Notes):** Unicode is the icon system — `▲ △ ▼ ▽` deltas, `● ○` state dots, `├─ └─` reason trees, `▁▂▃▄▅▆▇█` spark bars, `░ ▒` fills, `·` separators. All render in Fragment Mono at ≤12px.
- **No icon font, no emoji, ever.** Website SVGs are minimal inline line-icons (feature dropdown); the App Store badge is the stock Apple SVG (`assets/app-store-badge.svg`).
- **Mark:** app icon only (`assets/icon-512.png`, `assets/favicon.svg`). Never redraw it.

## Index

- `styles.css` → `tokens/` (fonts, colors, typography, spacing, motion)
- `assets/` — icon-512.png, favicon.svg, app-store-badge.svg, fonts/, screens/ (8 real app screenshots, v1.6)
- `fonts/Alpino-Variable.ttf` — uploaded display face
- `explorations/Visual Directions.html` — the 3-direction board (1c chosen)
- `explorations/Logo Color Variations.html` — icon recolor experiments (2026-07-29, **rejected — original icon hues stand**; renders live in `assets/logo-experiments/`)
- `guidelines/` — specimen cards (Design System tab)
- `components/` — React primitives:
  - **actions/** Button · IconButton · KeyRow
  - **forms/** Toggle · SegmentedControl · TextField · Stepper · ReadoutWell
  - **display/** Card · MetricRow · MetricTile · ZoneBadge · TagChip · DeltaIndicator · AttentionBanner · Toast
  - **navigation/** TabBar · ScreenHeader · SectionHeader
  - **instruments/** TickScale · Sparkline · SparkBar · SufficiencyRing
- `ui_kits/` — full-screen recreations (iOS Dashboard, Workload, Active Workout; marketing homepage **with the live motion layer** — `website/motion.js` ports the homeMotion engine from tuwa.app: hero line masks, count-ups, reveals, pinned strike-zone scrub, sticky 3-step showcase, fanned spread, ghost numerals, self-drawing chart. Demos: `website/motion-addons-demo.html` (Lottie + Lenis, self-hosted in `assets/vendor/`, `assets/lottie/`), `website/motion-iterations.html`)
- `templates/` — deck slide templates
- `SKILL.md` — agent skill entry point

### Intentional additions
- **Annotation glyph set + mono layer** — the chosen 1c direction's signature; not in the v5 app (which this system intentionally evolves).
- **Alpino display voice** — user-uploaded brand font, scoped to marketing/slides.
- **Web motion layer** — homeMotion engine ported into the homepage kit as reference implementation; Lottie/Lenis assessed and kept demo-only (nice-to-have).

## Handoff

See `HANDOFF.md` for applying this system to the production app (SwiftUI) and website (Astro), plus further surfaces.
