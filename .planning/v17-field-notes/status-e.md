# Session E — website lane (tuwa-website/)

## 2026-07-30T17:46 · Wave 2 website retheme — DONE (uncommitted at time of writing; commit follows)

Repo: `/Users/hanwen/dev/Tonus/tuwa-website` (separate git repo). No git write of any
kind was run in the parent `/Users/hanwen/dev/Tonus` tree — three iOS lanes are live
in it. CLAIM posted to `.pair/claude.md` as `C-fn17e-001` before any edit.

### What changed, per file

**`src/styles/global.css`** — the substantive change (+410/-62).
- `@font-face`: added **Fragment Mono** (annotation voice) and **Alpino** (display
  voice), both self-hosted woff2. Instrument Sans untouched.
- `:root` rewritten from `design-system/tokens/{colors,typography,fonts,spacing,motion}.css`:
  five metric hues (new), re-tuned zone colors, relief tokens, chart tokens,
  `--font-mono`/`--font-display`/`--font-cjk`, `--anno`/`--anno-sm`,
  `--tracking-anno`, `--leading-anno`, `--hairline`, full motion set
  (`--ease-exit`, `--dur-press/state/screen/entrance/countup/anno`,
  `--anno-stagger`, `--rise`), plus a labelled block aliasing the canonical
  unprefixed token names so `ui_kits/website` snippets paste in unchanged.
- `.micro` (the site's 97-use marginalia class) now speaks the annotation voice:
  Fragment Mono, 11px, uppercase, `--tracking-anno`, `text-3`, tabular figures.
  `.anno` / `.anno-sm` added as the design-system aliases. zh-Hans guard:
  `html[lang="zh"] .micro` gets the CJK cascade, no case transform, no tracking.
- `.annotation-reveal` — the annotation-choreography primitive: opacity fade on
  `--dur-anno`, delayed by `--dur-state` + `--ai × --anno-stagger` (40ms steps),
  gated on `html.motion`, with a `prefers-reduced-motion` override.
- Display voice wired onto marketing display type: `.hero-h1`, `.sec-head h2`/`.home-h2`,
  `.feat-h1`, `.seo-hero h1`, `.seo-content-grid h2`, `.seo-final-cta h2`,
  `.quote blockquote` (450, per the kit). `--weight-display` raised 400 → **650**
  (the token value; it is now Alpino's weight, so every user of it also got
  `--font-display`).
- Numerals deliberately kept OFF the display face: `.hero-score-n` and `.stat .n`
  moved to `--weight-regular` + `tabular-nums`. Alpino is for words.
- Reading Color Rule v6: `.hero-score-n` moved from travertine accent to
  `--color-metric-readiness`; the accent keeps the live-state needle beside it.
  `.hero-score .micro` dropped its accent override (annotation defaults to text-3).
- Zone band tints (`.zseg-*`) and `.zone-fill` moved from hardcoded rgba (old
  Pavilion hexes) to `color-mix()` on the zone/accent tokens, so the v6 retune
  actually reaches them.
- New `.spark-*` block for the section-04 chart.

**`src/scripts/homeMotion.ts`** (+50/-4) — the site file was already a superset of
`design-system/ui_kits/website/motion.js` (it has Lottie, marquee, nav-CTA discipline
and a pinned hero the reference lacks). Two changes only:
- **NEW scene: the self-drawing baseline chart.** IntersectionObserver at 0.4,
  line draws left→right over 900ms on `--ease` via `pathLength`/`stroke-dashoffset`,
  dashed baseline at 700ms, "now" marker at 1000ms. Reduced motion handled in CSS.
- **Retune:** ghost parallax factor `-0.06` → `-0.08`, matching `motion.js`.
- Also wired `.annotation-reveal` into the existing reveal observer (and into both
  reduced-motion / no-IO fallbacks) so the stagger is driven from one place.
- Deliberately NOT changed: count-up duration stays 400ms. `motion.js` uses 500ms,
  but `tokens/motion.css` says `--dur-countup: 400ms`. Token wins over the demo.
- Deliberately NOT changed: the zone axis maps 0.4–1.7 here vs 0.0–2.0 in
  `motion.js`. The site's bar segments are built for its own axis; adopting the
  reference number would desync needle and bands.

**`src/components/home/RecoveryQuote.astro`** (+46) — the section-04 chart card, placed
inside the site's existing `03 · recovery` section. Deliberate: the reference kit's
"section 04" IS its recovery section; the site numbers recovery 03, and renumbering
would have meant editing kicker copy in three locales for no gain.

**`src/i18n/locales/{en,zh,fr}/home.ts`** (+9/+8/+9) — a `recovery.spark` block
(caption, label, reading, 5 axis ticks, chart alt text). zh gets native text (no
case transform applies); en/fr are written lowercase for the labels the `.micro` rule
uppercases, and sentence case for the caption, which is body copy.

**`src/layouts/BaseLayout.astro`** (+5) — preload the two new woff2 (both render above
the fold).

**`src/components/Footer.astro`** (+15/-6) — `.micro` moved OFF the footer wrapper onto
the meta row only. The whole footer nav was rendering in the annotation voice, which
v6 forbids ("never a nav/tab label") and which `ui_kits/website/index.html`
contradicts too (its footer nav is sans `--text-small`; only the © line is `.anno`).
Nav links now carry the working voice at `--text-small` via a new `.footer-inner`.

**`src/components/{Hero,AboutPage,SupportPage}.astro`, `src/layouts/{Topic,Feature}PageLayout.astro`**
(+1 each) — `font-family: var(--font-display)` beside their inline
`font-weight: var(--weight-display)`. Required, not cosmetic: with `--weight-display`
now 650 and Instrument Sans shipping only 400/500 static faces, leaving these on the
sans would have produced synthetic bold. `SupportPage.astro` renders `/support`, a
release-gated route — type only, zero content change, parity-verified below.

**`src/layouts/LegalPageLayout.astro`** (1 line) — the zh/fr disclaimer box had
`border-radius: 0`, a corner-law violation; now `var(--radius-md)`. Style only.

**`public/fonts/`** (4 new files) —
`FragmentMono-Regular.woff2` + `FragmentMono-LICENSE.txt` (SIL OFL 1.1, Wei Huang),
`Alpino-Variable.woff2` + `Alpino-LICENSE.txt` (Fontshare/ITF terms).
Converted with fontTools (lossless container change; glyph data untouched) from
`WorkloadApp/Resources/Fonts/FragmentMono-Regular.ttf` and
`design-system/fonts/Alpino-Variable.ttf`. `tokens/fonts.css` imports Fragment Mono
from `fonts.googleapis.com`; that `@import` was deliberately NOT carried over.

### Verification — actual commands and output

```
$ npm run build
17:43:50 [build] 66 page(s) built in 4.92s
17:43:50 [build] Complete!
```
**66 pages — matches the expected count exactly** (baseline before my changes was also 66).

```
$ npx astro check
Result (147 files):
- 0 errors
- 0 warnings
- 0 hints
```

**No-CDN grep over `dist/`:**
```
external url() in built CSS ............................. 0
remote @import in built CSS ............................. 0
googleapis|gstatic|jsdelivr|unpkg|cdnjs|typekit in dist . 0 files
font files referenced from public/ ...................... /fonts/Alpino-Variable.woff2
                                                          /fonts/FragmentMono-Regular.woff2
                                                          /fonts/InstrumentSans-Medium.ttf
                                                          /fonts/InstrumentSans-Regular.ttf
```
Every other font in the build is `/_astro/noto-sans-sc-*` — the npm `@fontsource`
package, bundled at build time, not fetched. The only string match for
`fontshare.com` anywhere in `dist` is inside my own `Alpino-LICENSE.txt` (an
attribution URL in a text file, not a resource request). Headless Chromium
confirmed it at runtime: **OFF-HOST REQUESTS: none** on the homepage.

**Content parity — the five release-gated routes.** Text content and every
`href`/`src` target extracted from the built HTML before and after (tags stripped,
entities decoded, whitespace normalised):

| route | text | link targets |
|---|---|---|
| `/terms` | **IDENTICAL** (sha256 `a213f2f8…`) | nothing removed; +2 |
| `/zh/terms` | **IDENTICAL** | nothing removed; +2 |
| `/fr/terms` | **IDENTICAL** | nothing removed; +2 |
| `/privacy` | **IDENTICAL** | nothing removed; +2 |
| `/support` | **IDENTICAL** | nothing removed; +2 |

Set-difference (`comm`) on the link lists: **"only in BEFORE" is empty for all five.**
The two additions on each are `/fonts/Alpino-Variable.woff2` and
`/fonts/FragmentMono-Regular.woff2` — the preload hints. The CSS bundle hash changed
(`BaseLayout.DDyCmtmL.css` → `BaseLayout.B_nchYnu.css`), which is expected and is not
content. **No blocker.**

**Browser verification** (headless Chromium 1228 driven via `playwright-core`; the
Playwright MCP browser was locked by a concurrent session, so I drove the cached
binary directly). Computed-style assertions:
```
h1 font-family ......... Alpino, "Instrument Sans", sans-serif   weight 650
h2 font-family ......... Alpino, "Instrument Sans", sans-serif
.micro font-family ..... "Fragment Mono", ui-monospace, monospace   size 11px
hero score color ....... rgb(46, 125, 79)   = #2E7D4F metric-readiness
spark line stroke ...... rgb(29, 113, 137)  = #1D7189 metric-recovery
spark reading .......... same hue, Fragment Mono
spark axis ............. Fragment Mono, 10px, .annotation-reveal → in
document.fonts.check ... Alpino true · Fragment Mono true
CONSOLE ERRORS ......... none
```
Reduced-motion context: `{dashoffset: 0, baseline: 1, now: 1, axisOpacity: 1}` — the
finished chart, no animation. Mobile 390px: `scrollWidth === clientWidth === 390`
(no horizontal overflow). zh homepage: `.micro` resolves to
`"Noto Sans SC", "Instrument Sans"` with `text-transform: none` and
`letter-spacing: normal` — the CJK guard works.

Screenshots (desktop 1280 top / showcase / zone / spark chart, mobile 390, zh, and
all five legal routes full-page) taken and reviewed against
`design-system/ui_kits/website/index.html`. Kept in this session's scratchpad only —
not committed to the repo.

### Two visual regressions I found and fixed while verifying

1. **Zone legend collision.** Fragment Mono is wider than Instrument Sans at the same
   size, and the four legend labels sit in fixed-percentage columns:
   "UNDER 0.8 — UNDERTRAINING" butted straight into "0.8–1.3 — STRIKE ZONE". Fixed by
   dropping `.zone-legend .micro` to `--anno-sm` with an 8px gutter. This is a general
   hazard of the mono swap — any other fixed-width mono label is a candidate.
2. **Distorted "now" marker.** The chart plots with `preserveAspectRatio="none"` (needed
   or the trend collapses to a ~70px sliver on a phone), which squashes an SVG
   `<circle>` into an ellipse. The marker is now an absolutely-positioned HTML element
   at 780/800 across and 66/180 down, so it stays circular at every width.
   Also: `vector-effect: non-scaling-stroke` on the series path silently truncated the
   draw-on — it fights `pathLength="1"` + `stroke-dasharray`. Removed.

### Token name collisions — flagged, not silently resolved

The two systems share three names with **different meanings**. I kept the site's
meaning in each case and documented it in `global.css`; nothing was renamed, because
renaming would touch every rule and component here.

1. **`--text-body`.** `tokens/colors.css` aliases it to a *colour*
   (`var(--text-1)`); `tokens/typography.css` sets it to `17px`. The design system
   collides with itself — `styles.css` imports typography after colors, so the size
   wins there by import order alone. This site uses the 17px meaning everywhere, so
   the colour alias was **not** ported. Worth fixing upstream in `colors.css`.
2. **`--text-display`.** App ramp = 32px; this site = the marketing clamp
   `clamp(56px,7vw,96px)` (which the design system calls `--text-display-xl`). Site
   meaning kept; `--text-display-xl` added alongside with the same value.
3. **`--space-*`.** Same 8pt grid, same values, labels **offset by one step**.
   Design system: pair 4 / xs 8 / sm 16 / md 24 / lg 32 / xl 48 / 2xl 64.
   Site: xs 4 / sm 8 / md 16 / lg 24 / xl 32 / 2xl 48 / 3xl 64. Site labels kept;
   `--space-pair` added as an alias for 4px.

### Where the design system contradicts itself or the site

- **`ui_kits/website/index.html` sets ghost numerals in Fragment Mono at 200px.** The
  ≤12px mono cap is stated as a hard law in `readme.md` ("Mono annotation ≤12px") and
  in DESIGN.md v6. The kit's own demo violates it. **I kept the site's giant `.ghost`
  numerals on the sans** — holding the cap site-wide is the safer reading. Needs a
  ruling: either the cap has a decorative exemption, or the kit is wrong.
- **`tokens/fonts.css` imports Fragment Mono from a CDN** while this site has a
  no-CDN law. Resolved by self-hosting; the token file should probably grow a
  self-host note so the next porter doesn't reintroduce the `@import`.
- **`--leading-body`**: design system 1.55, site 1.6. Kept 1.6 (existing web value,
  and changing it would reflow every prose page). Low stakes, flagging anyway.
- **Alpino ships no licence file** in `design-system/fonts/`. Its embedded name-ID-13
  string is ITF/Fontshare terms, not OFL. I wrote an attribution notice from the
  font's own metadata rather than inventing licence text.
- **The site's Instrument Sans TTFs have shipped with no licence file** in
  `public/fonts/` all along (the brief assumed the site already handled this for its
  other faces — it does not). Fragment Mono and Alpino now ship theirs; Instrument
  Sans's OFL should be copied across too. Not done — outside this lane, one file.

### Not done — deliberately out of lane

- **Accent-as-label debt.** These selectors colour *labels* with the travertine
  accent, which the Accent Rule has banned since v5 and v6 restates: `.topic-kicker`,
  `.seo-answer-block span`, `.feature-loop-panel-cta`, `.feature-loop-step-label`
  (active), `.seo-breadcrumb a`/`.seo-text-link`. Fixing them is a colour-role audit
  across ~40 SEO/topic pages, not a token or motion change. Untouched and reported.
- **`src/scripts/featureMotion.ts` and `src/scripts/siteMotion.ts`** — not touched.
  The token/type change needed nothing from them; `featureMotion` drives spreads,
  ghosts and Lotties on feature pages, all of which read the same tokens.
- **`src/components/charts/{AcwrChart,RecoveryChart}.astro`** (Chart.js canvases) —
  not touched. They likely read the old zone rgba values in JS rather than tokens; a
  metric-hue pass over the Chart.js configs is a follow-up, not part of the token swap.
- **OG images** (`public/og/*`) still carry Pavilion styling. That is Session G's
  brand batch per DISTRIBUTION.md.
- **Lottie and Lenis** left exactly as-is, per the brief.
- **`src/components/Hero.astro`** is unreferenced by any page (verified by grep). I
  patched it anyway so it does not rot into synthetic-bold if it is ever mounted.

### Open blockers

None. Build 66/66, `astro check` clean, zero CDN, five gated routes byte-identical
in content. Not pushed — HAN publishes.
