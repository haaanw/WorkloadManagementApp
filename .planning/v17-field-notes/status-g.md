# Session G — brand batch (v1.7 "Field Notes", Wave 3)

## 2026-07-31T00:05 · DONE (4/4 deliverables), 5 decisions for HAN

Branch `v1.7-field-notes`. **Nothing committed** — all changes are in the working tree.
No simulator used. No xcodebuild run (this lane touches no app source). Covered by the
orchestrator's pair CLAIM `C-fn17-005` for `docs/*.html`, `tuwa-website/public/og/*`,
`design-system/templates/`.

---

## 1. `docs/{privacy,support,terms}.html` — Field Notes restyle, content frozen

**What changed:** the `<style>` block, and *only* the `<style>` block, in each of the
three files. Everything after `</head>` is byte-identical to `HEAD`.

Applied: warm stone planes (`#F0EFEC` page / `#F8F7F4`→`#FCFBF9` card), ink ramp
(`#1B1A17` / `#57544E` / `#8B877F`), travertine `#6F6759` on the focus ring only
(a live-state mark), v6 type ramp (28/400 page title, 17/500 section head, 15/500
sub-head, 17px body @ 1.55), 8pt-grid spacing throughout, hairlines `0.5px #D6D3CD`,
corner law 12pt on the card, `color-scheme: light` (light-only, no dark branch),
**no shadows** — the page body *is* the raised light card (surface gradient + hairline
+ 1px `inset 0 1px 0 #FFFFFE` relief highlight). Support's `.contact-box` became the
emphasis card (`--surface-el-2` + `--divider-strong`). Mobile ≤640px drops the corner
and side borders to full-bleed.

**No Fragment Mono anywhere on these pages, deliberately.** v6 forbids the annotation
voice on nav labels, headlines, CTAs and sentences — and these pages contain nothing
else. Setting "Last updated: June 5, 2026" or the Privacy/Terms/Support nav in mono
would have been a law violation *and* a rendered-case change to a legal page. Zero case
transforms are applied anywhere.

**Fonts: system stack, no CDN.** `system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI',
Helvetica, Arial, sans-serif`. No `@import`, no remote asset of any kind. Self-hosting
Instrument Sans here would require adding `docs/fonts/*.ttf` — outside this lane's file
ownership (see Decision G-1).

### VERIFICATION — rendered-text parity (the required proof)

Extractor: `scratchpad/g/extract_text.py` — strips `<head>/<style>/<script>`, unescapes
entities, collapses whitespace, one logical block per line. Run against `HEAD`'s copy of
each file (before) and the working-tree copy (after).

```
$ diff -r scratchpad/g/before scratchpad/g/after && echo "IDENTICAL..."
IDENTICAL: no rendered-text differences in any of the 3 pages

$ shasum -a 256 before/privacy.txt after/privacy.txt before/support.txt after/support.txt before/terms.txt after/terms.txt
74a332a25cd477cf4407d89aea72c4a807c014ed8b90f7dce014b24712c5bd9d  before/privacy.txt
74a332a25cd477cf4407d89aea72c4a807c014ed8b90f7dce014b24712c5bd9d  after/privacy.txt
d8977eb228037db8a8d93ba87433b1bbae7fe61b247d6ef49ea95f0852d98dd8  before/support.txt
d8977eb228037db8a8d93ba87433b1bbae7fe61b247d6ef49ea95f0852d98dd8  after/support.txt
a523e98a1a4562cf95cbc823068f4ad4276311abb74978c1122c8dede80b72ad  before/terms.txt
a523e98a1a4562cf95cbc823068f4ad4276311abb74978c1122c8dede80b72ad  after/terms.txt

$ for f in privacy support terms; do diff before/$f.txt after/$f.txt; done
privacy: no differences (exit 0)
support: no differences (exit 0)
terms:   no differences (exit 0)
```

Stronger check — everything after `</head>` compared to `git show HEAD:docs/<f>.html`:

```
privacy.html: body byte-identical
support.html: body byte-identical
terms.html:  body byte-identical
```

```
$ git diff --stat -- docs/
 docs/privacy.html | 83 ++++++++++++++++++++++++++++++++-------
 docs/support.html | 94 +++++++++++++++++++++++++++++++++++++-------
 docs/terms.html   | 82 ++++++++++++++++++++++++++++++++++-----
 3 files changed, 227 insertions(+), 32 deletions(-)
```

Visual check: rendered all three in headless Chrome 149 at 900×1200 and support at
420×900, and read the PNGs. Screenshots in
`scratchpad/g/shots/docs-{privacy,support,terms,support-mobile}.png`. Card plane,
hairline nav rule, emphasis contact box and mobile full-bleed all render as intended.

---

## 2. `tuwa-website/public/og/*.png` — regenerated in Field Notes

Four cards regenerated at **exactly 1200×630**, matching the files they replace
(`sips` confirms W=1200 H=630 on all four, same as the originals). New generator:
**`design-system/templates/og/generate_og.py`** — deterministic, offline, PIL-based,
reads Instrument Sans / Fragment Mono from `WorkloadApp/Resources/Fonts/` and Alpino
from `design-system/fonts/`. Re-running is one command.

Composition: stone plane `#F0EFEC`; mono annotation strip top and bottom on `#F4F3F0`
with a hairline; Alpino 650 headline in ink; Instrument Sans sub in `--text-2`; a
**debossed readout well** (well-top→well-bottom gradient + hairline, radius 12, no
shadow) holding the hero reading; app mark + "Tuwa" wordmark bottom-left; metric-hue
readout bottom-right with a drawn state dot.

| file | metric hue | hero reading | bottom readout |
|---|---|---|---|
| `recovery-scoring.png` | recovery `#1D7189` | `82` (hue) | `RECOVERY ● HRV VS YOUR BASELINE` |
| `workload-tracking.png` | load `#8A6810` | `1.12` (hue) | `LOAD ● STRIKE ZONE 0.80–1.30` |
| `cold-start.png` | readiness `#2E7D4F` | `D-01` (hue) | `READINESS ● NO DATA STAYS NEUTRAL` |
| `smart-templates.png` | strain `#A8442D` | `1,324` (**travertine** — a movement count is not a metric) | `STRAIN ● RPE + LOAD ON EVERY SET` |

Reading Color Rule honoured throughout: every coloured text element names the metric
whose hue it wears; the one reading with no metric identity takes `--accent`. No hue
fills a surface anywhere.

Mono sizing: 20px/17px on a 1200px canvas that renders at ~600 CSS px in every OG
consumer ≈ 10/8.5 effective px — inside the ≤12px annotation cap. Tracking (+0.05em)
is applied by the `draw_tracked` helper, never at a call site.

### VERIFICATION

```
$ python3 design-system/templates/og/generate_og.py
wrote .../og/recovery-scoring.png (1200, 630)
wrote .../og/workload-tracking.png (1200, 630)
wrote .../og/cold-start.png (1200, 630)
wrote .../og/smart-templates.png (1200, 630)

$ cd tuwa-website && git status --porcelain public/og/
 M public/og/cold-start.png
 M public/og/recovery-scoring.png
 M public/og/smart-templates.png
 M public/og/workload-tracking.png
```

**I read all four output PNGs back and inspected them** (not just the file sizes). Two
defects were found and fixed in that loop: dead vertical space from top-anchored
content (now the headline block and the well are both centred on the band mid-line),
and an app mark too small to read at 48px (now 64px). En dash, middle dot and the
box-drawing glyphs all confirmed present in Fragment Mono.

---

## 3. Pitch deck — `design-system/templates/pitch-deck/PitchDeck.dc.html`

Rebuilt from 6 slides to 8, all figures re-grounded.

### Placeholder figures I could NOT ground — REMOVED, not reprinted

The previous template asserted three market numbers. **None of them appears anywhere in
`docs/market-intelligence/`, in `docs/adr/`, or in any repo source I could find.** I did
not invent replacements or "adjust" them; I deleted them:

| removed claim | status |
|---|---|
| `64M` self-coached hybrid athletes · US + EU | **unsourced.** No segment sizing of any kind exists in the intelligence pack. |
| `$4.8B` recovery-tech spend, 2026 | **unsourced.** No recovery-tech segment figure exists. |
| `31%` train through known injury risk | **unsourced.** No behavioural survey data exists. |

A provenance block at the top of the file records this so the numbers don't creep back.

### Figures now on the deck, each traceable

| figure | slide | source |
|---|---|---|
| $12.12B (2025) → $33.58B (2033), 13.40% CAGR; NA largest revenue share, iOS largest platform share | 03 | `market-map.md` L7 → Grand View Research (`sources.md`) |
| ACSM 2026: wearable tech #1, strength training #7, data-driven tech #8 | 03 | `market-map.md` L7 → ACSM 2026 trends |
| Athlytic $29.99/yr · Bevel Pro $99.99/yr · TrainingPeaks $134.99/yr · WHOOP from $199/yr · RP $299.99/yr | 04 | `competitor-index.md` L24–34, L106 |
| Garmin acquired TrainingPeaks + TrainHeroic, 2026-07-22; no integrated product announced | 06 | `commoditization-clock-2026-07-26.md` |
| The exact Tuwa gap remains unverified as a shipped competitor feature | 06 | same |
| 1,324-exercise movement bank; ACWR strike zone 0.80–1.30; iOS 17+; HealthKit read-only | 07 | `CLAUDE.md` / product |

Slides 03, 04 and 06 each carry an inline mono source line. **The deck asserts no Tuwa
traction figures** (users, revenue, retention, conversion) because none exist in any repo
source — see Decision G-4.

### Design law fixes applied

- v5-era hues `#2E6B80` / `#3F5A46` / `#743B36` → **v6.2 metric hues** where a metric is
  named (slide 07 shows all five, each with its metric named), travertine `#6F6759` for
  readings with no metric identity (market sizes, prices).
- **The dark slide is gone.** Old slide 05 was `background:#1B1A17` — a dark surface,
  which Hero Law forbids. It is now a light stone slide (new slide 06, "Why now").
- Mono capped at **12px** everywhere. *(Corrected in Round 3 — the original wording,
  "(was 13–14px)", read as though all the deck's mono had been oversized. Measured against
  `HEAD:design-system/templates/pitch-deck/PitchDeck.dc.html`: 21 Fragment Mono
  declarations at 11px ×10, 12px ×6, **13px ×3** (:28, :38, :76) and **14px ×2** (:54, :58).
  So five declarations broke the ≤12pt cap, not all of them.)* The reason-tree treatment survives
  only as marginalia: every slide's actual claim now sits in Instrument Sans or Alpino,
  which is where the argument belongs.
- One ink-filled pill CTA, on slide 08 only.
- `box-shadow:inset 0 1px 0 #FFFFFE` retained — that is the relief highlight, not a shadow.

### VERIFICATION

Served the repo over `python3 -m http.server 8791` (the `.dc.html` harness fetches itself,
so `file://` fails) and rendered in headless Chrome 149 at 1360px. Screenshots:
`scratchpad/g/shots/deck-{a,b,c}.png`. **All 8 slides read back and inspected.** Three
defects found and fixed in that loop: the RP price card was taller than its row-mates
(jagged bottom edge — row is now `align-items:stretch`), `RECOVERY ● HRV VS BASE` wrapped
to two lines (shortened to `HRV DELTA`), and slide 06's Alpino 450 headline read as a
visibly different face from the other slides (now 650, consistent).

Caveat, stated honestly: in my offline render Fragment Mono fell back to the system
monospace, because `design-system/tokens/fonts.css` pulls it from Google Fonts. The
layout is verified; the *mono face* is not. See Decision G-2 — this is a real no-CDN
violation in a file I do not own.

---

## 4. Transactional email template — `design-system/templates/email/transactional.html`

New file. Table-based, fixed 600px shell, **every style inline** (Gmail strips `<style>`
in clipped/forwarded views), `<style>` block is progressive enhancement only.

- Stone surfaces: `#F0EFEC` body, `#F8F7F4` card with `1px #D6D3CD` hairline, radius 12.
- **No shadows.** Elevation is plane + hairline. Email cannot render the relief gradient
  reliably, so relief is *omitted* rather than faked with a shadow.
- **One ink-filled pill CTA** — `#1B1A17` fill, `#F4F3F0` text, radius 999px, with a VML
  `roundrect` so the pill shape survives Outlook's Word engine. Never accent-filled.
- **No external assets at all**: no webfont, no CDN, no remote or background image. The
  mark is set as type, so nothing depends on "download images".
- Two-voice type with email-safe stacks: `'Instrument Sans', -apple-system, 'Helvetica
  Neue', Helvetica, Arial` speaks; `'Fragment Mono', ui-monospace, SFMono-Regular, Menlo,
  Consolas, 'Courier New', monospace` annotates at 11px uppercase +0.05em, applied by the
  style — eyebrow, readout key and footer machine line only, never a sentence or the CTA.
- Optional **readout block**: a flattened well with the reading in its metric's hue and a
  key that names that metric. Marked with delete-me comments for messages with no reading.
- Light-only: `color-scheme`/`supported-color-schemes` meta + `:root` declaration.
- Preheader, 620px responsive breakpoint, unsubscribe/support links, and the
  not-medical-advice line (matching `docs/terms.html` §7 language).
- 13 merge tokens documented in the header comment.

### VERIFICATION

Filled every token with a realistic "modify day" verdict message, rendered at 760×1400 in
headless Chrome 149, **read the PNG back**
(`scratchpad/g/shots/email.png`). All blocks render correctly: masthead + annotation
eyebrow, headline, body, readout well (`58` in readiness green with `READINESS · TODAY`),
second body, ink pill, hairline, reason tree in mono, and the outside-card legal block.
Token substitution left nothing unfilled (the one `{{token}}` match is the literal string
inside the how-to-use comment).

---

## Decisions for HAN

**G-1 · Fonts on `docs/*.html`: system stack (shipped) vs self-hosted.**
The pages currently use the system sans stack — fully no-CDN-compliant, but not
Instrument Sans, so they are Field Notes in colour/scale/material and not in *voice*.
Self-hosting means adding `docs/fonts/InstrumentSans-{Regular,Medium}.ttf` (~170 KB
duplicated), which is outside this lane's granted file list. **Recommendation:** leave as
is unless these pages are actually served — see G-5. Low cost to change later.

**G-2 · `design-system/tokens/fonts.css` violates the no-CDN law (not my file).**
Line 3 is `@import url('https://fonts.googleapis.com/css2?family=Fragment+Mono&display=swap')`.
Every design-system surface that loads that file — guidelines cards, ui_kits, the deck —
depends on Google's CDN for the annotation voice, and renders in fallback monospace
offline. `FragmentMono-Regular.ttf` is already in the repo at
`WorkloadApp/Resources/Fonts/`. **Recommendation:** copy it to
`design-system/assets/fonts/` and replace the `@import` with a `@font-face`. I did not do
this — the file is not in my ownership list. Filed as a request below.

**G-3 · Deck slide 05 was dark; I made it light.**
The old quote slide used `background:#1B1A17`. Hero Law says no dark surfaces, and the
design system allows exactly one on the web (the device bezel). I converted it rather
than preserving it. If you want a dark slide as a deliberate deck-only exception, say so
and I will restore it as a documented carve-out.

**G-4 · The deck has no traction slide.**
No user, revenue, retention or conversion number exists in any repo source, and the WTP
instrumentation has zero data (per the v2.0 memory note). I asserted none. The deck is
therefore a market/positioning/product deck, not a fundraising deck. Adding traction
requires real numbers from you.

**G-5 · Are `docs/*.html` still served anywhere?**
The live legal pages are the Astro routes (tuwa.app/terms etc., Session E's). DISTRIBUTION
calls these "legacy copies". If they are dead, the honest move is to delete them rather
than maintain two divergent copies of a legal document — a real App Review risk if they
ever drift. If they are live (GitHub Pages on `docs/`), G-1 becomes worth doing. I did not
delete anything.

---

## Requests to other lanes / the orchestrator

1. **`design-system/tokens/fonts.css`** — self-host Fragment Mono, drop the Google Fonts
   `@import` (G-2). Not mine to edit; affects every design-system surface.
2. **`tuwa-website/public/og-default.png`** — still the old plain card ("Tuwa" + tagline,
   no Field Notes treatment), and it now looks visibly unrelated to the four cards I
   regenerated. It sits *outside* `public/og/`, so outside my ownership. It is the JSON-LD
   default (`src/seo/schema.ts` L6) **and is explicitly referenced by 10+ pages**:
   `features/verdict.astro` (+ zh/fr), `methodology`, `compare`, `training-load`,
   `readiness-score` (+ zh twins), and every blog post without a cover image. This is the
   highest-leverage remaining OG fix. `generate_og.py` can produce it in ~10 lines. Needs
   an ownership grant.
3. **`tuwa-website/src/pages/features/verdict.astro`** (+ zh/fr twins) explicitly sets
   `ogImage="/og-default.png"` even though the daily verdict is the headline feature and
   the other four features each have a dedicated card. Adding `og/verdict.png` is easy on
   my side; changing the prop is a `tuwa-website/src/` edit, which is CODEX's.
4. **Session F** — the OG generator's stone/mono/well vocabulary
   (`design-system/templates/og/generate_og.py`) is directly reusable for the App Store
   screenshot frames if that helps keep the two surfaces consistent.

## Not done

- **`og-default.png` not regenerated** (out of ownership — request 1 above). The site's
  default share card is therefore still off-brand relative to the four feature cards.
- **No `og/verdict.png`** created, since nothing could reference it (request 3).
- **The deck was not exported to PDF/slides.** It is the `.dc.html` template only; I have
  no export path in this lane and no instruction to produce a distributable artefact.
- **The email template is not wired to a sender.** No ESP exists in this repo; it is a
  template, not an integration. Not localised — en only; zh-Hans/fr versions would need
  the CJK no-case-transform / no-tracking rules applied to the annotation lines.
- **Fragment Mono not visually verified** in the deck render (G-2); layout verified,
  face not.
- **No Astro build run.** I changed only binary assets under `public/`, which Astro copies
  verbatim, and the deck/email live outside the website repo. Session E / CODEX own
  `npm run build`.
- **`docs/*.html` not checked in a real browser matrix** — headless Chromium only. No
  Safari/Firefox/Outlook render. The email template especially is written to the known
  Outlook/Gmail rules but has not been through Litmus or an equivalent.

---

# Session G — Round 2 (adversarial-review fixes)

## 2026-07-31T01:37 · 7/7 Round 1 findings addressed + HAN ruling #4 implemented

Branch `v1.7-field-notes`, HEAD `8742629`. **Nothing committed, staged, stashed or
pushed.** No app source touched, no `xcodebuild`, no simulator, no test run.

Files changed this round:

```
 M docs/privacy.html                                   (rewritten as a canonical redirect)
 M docs/support.html                                   (rewritten as a canonical redirect)
 M docs/terms.html                                     (rewritten as a canonical redirect)
 M design-system/tokens/fonts.css                      (@import -> self-hosted @font-face)
 M design-system/templates/pitch-deck/PitchDeck.dc.html
 M design-system/templates/og/generate_og.py           (locale axis)
 M design-system/templates/email/transactional.html
?? design-system/assets/fonts/FragmentMono-Regular.ttf
?? design-system/assets/fonts/FragmentMono-LICENSE.txt
```

In the nested `tuwa-website` repo:

```
 M public/og/{cold-start,recovery-scoring,smart-templates,workload-tracking}.png
?? public/og/fr/   (4 new cards)
?? public/og/zh/   (4 new cards)
```

---

## HAN ruling #4 — `docs/*.html` are now canonical redirects

All three files rewritten from a generator (`scratchpad/g2/mk_redirect.py`) so they
cannot drift apart. **The GitHub Pages paths are unchanged** — `docs/privacy.html`,
`docs/terms.html`, `docs/support.html` — because build 17's paywall
(`UpgradeSheet.swift:184-189`) hard-codes
`haaanw.github.io/WorkloadManagementApp/{terms,privacy}.html` and build 17 is in review.
The legal prose is gone from all three; each file now carries a header comment recording
the ruling, the load-bearing consumer, and the drift it removes, so nobody re-pastes a
second copy of the Terms.

**Mechanism (no JavaScript anywhere in the files — `grep -c '<script' docs/*.html` = 0):**
`<meta http-equiv="refresh" content="0; url=…">` + `<link rel="canonical">` +
`<meta name="robots" content="noindex, follow">` + a visible Field Notes card with a real
`<a>` to the destination. `content="0"` is deliberate: a non-zero delay would violate
WCAG 2.2 SC 2.2.1, which only exempts an immediate refresh.

**Targets verified against the live site and against the Astro sources, not guessed.**
Astro has no `trailingSlash` override and builds in `directory` format, so the canonical
URL each page emits carries a trailing slash — I matched that exactly:

```
$ grep -o 'rel="canonical"[^>]*' tuwa-website/dist/{terms,support,privacy}/index.html
dist/terms/index.html:rel="canonical" href="https://tuwa.app/terms/"
dist/support/index.html:rel="canonical" href="https://tuwa.app/support/"
dist/privacy/index.html:rel="canonical" href="https://tuwa.app/privacy/"

$ curl -sS -o /dev/null -w "%{http_code}\n" -m 15 https://tuwa.app/terms/ https://tuwa.app/support/ https://tuwa.app/privacy/
tuwa.app/terms/   -> HTTP 200
tuwa.app/support/ -> HTTP 200
tuwa.app/privacy/ -> HTTP 200

$ (fallback <a> href -> Astro route file on disk)
terms     href=https://tuwa.app/terms/      astro=tuwa-website/src/pages/terms.astro EXISTS
privacy   href=https://tuwa.app/privacy/    astro=tuwa-website/src/pages/privacy.astro EXISTS
support   href=https://tuwa.app/support/    astro=tuwa-website/src/pages/support.astro EXISTS
```

**Support has a real live route** (`support.astro` -> `SupportPage.astro`, plus zh/fr
twins), so `docs/support.html` redirects to `/support/` — no compromise was needed. The
three fallback nav links point at the same three real routes.

### VERIFICATION — the redirect actually fires with JavaScript OFF

Rendered each real file in headless Chrome 149 with `--disable-javascript` and read the
resulting PNG back. All three landed on the live tuwa.app page, not on the stub:

```
$ "Google Chrome" --headless=new --disable-javascript --virtual-time-budget=9000 \
    --screenshot=shots/redirect-followed-<f>.png file:///…/docs/<f>.html
```

| file | where the browser ended up (read from the screenshot) |
|---|---|
| `docs/privacy.html` | tuwa.app "Privacy Policy", *Last updated: March 27, 2026* |
| `docs/terms.html`  | tuwa.app "Terms of Service", *Last updated: July 26, 2026* |
| `docs/support.html`| tuwa.app "Support" hero |

That render is also the proof of the drift the ruling was about: the file I deleted said
**June 5, 2026** and had 11 sections; the page it now forwards to says **July 26, 2026**
and carries "11. Apple App Store terms".

### VERIFICATION — the visible fallback card

`--disable-javascript`, meta-refresh line stripped so the card stays on screen
(`scratchpad/g2/fallback/`), read back at 1000×700 and at 500×760 (below the 640px
breakpoint, so the mobile branch is exercised):
`scratchpad/g2/shots/fallback-{privacy,terms,support}.png`, `fallback-terms-narrow500.png`.

A layout probe with JS on confirmed there is **no horizontal overflow** —
`{"docClientW":500,"mainW":468,"mainLeft":16,"scrollW":500}` (scrollWidth == clientWidth).
Note for anyone re-running this: headless Chrome on macOS floors the CSS viewport at
500px regardless of `--window-size`, so a 390px "screenshot" is a crop, not a 390px
layout. The earlier apparent overflow was that artefact. The grid centring was still
hardened to `grid-template-columns: minmax(0,1fr)` so the track can shrink below the
card's min-content width on a real phone.

### Design-law self-audit on the three pages

```
$ grep -n "ease-in\|ease-out\|140ms" docs/*.html        -> (no matches)
$ grep -n "box-shadow" docs/*.html                      -> only "inset 0 1px 0 var(--relief-highlight)" ×3
$ grep -i "http://\|<script\|googleapis\|cdn" docs/*.html -> only the prose in the header comment
$ px/ms literals outside the :root token block          -> 1px 2px 520px 640px
     (1px = relief highlight, 2px = focus ring, 520px = card max-width, 640px = breakpoint)
```

Finding 7 answered: every type size, spacing step, radius, colour and duration is a
`var(--token)` declared in a `:root` block transcribed from
`design-system/tokens/{colors,spacing,typography}.css` and the readme type ramp; motion
uses the design system's documented state band (`--duration-state:250ms`,
`--ease-state:cubic-bezier(0.22,1,0.36,1)` from `guidelines/motion.card.html`). The
`140ms ease-out` and bare `h1 28px` are gone.

Contrast measured, not assumed (card plane `#F9F8F5`):

```
text-1 on card plane: 16.39:1
text-2 on card plane:  7.10:1
text-3 on card plane:  3.37:1   <- why nothing on these pages uses text-3
ink-inverse on CTA fill: 15.68:1
```

`.destination` and the nav were moved text-3 -> text-2 for this reason (they are
sentences at 15/13px, not marginalia).

**Fonts: still the system sans stack, deliberately.** Self-hosting Instrument Sans here
means adding font binaries under `docs/`, which is outside this lane's granted paths, and
the Fragment Mono annotation voice must not be faked with `ui-monospace`. These pages
therefore carry no marginalia at all. Decision G-1 from Round 1 stands, now much cheaper:
the page is 12 words of chrome, not a legal document.

---

## Finding 1 — OG cards: locale axis added

`design-system/templates/og/generate_og.py` gained a `LOCALES` table and a per-locale
`copy` block on every card. Output:

```
$ python3 design-system/templates/og/generate_og.py
wrote tuwa-website/public/og/recovery-scoring.png (1200, 630)
wrote tuwa-website/public/og/workload-tracking.png (1200, 630)
wrote tuwa-website/public/og/cold-start.png (1200, 630)
wrote tuwa-website/public/og/smart-templates.png (1200, 630)
wrote tuwa-website/public/og/fr/recovery-scoring.png (1200, 630)
wrote tuwa-website/public/og/fr/workload-tracking.png (1200, 630)
wrote tuwa-website/public/og/fr/cold-start.png (1200, 630)
wrote tuwa-website/public/og/fr/smart-templates.png (1200, 630)
wrote tuwa-website/public/og/zh/recovery-scoring.png (1200, 630)
wrote tuwa-website/public/og/zh/workload-tracking.png (1200, 630)
wrote tuwa-website/public/og/zh/cold-start.png (1200, 630)
wrote tuwa-website/public/og/zh/smart-templates.png (1200, 630)
```

`--locale zh` / `--locale fr` render one locale. The en path is byte-path-identical to
what the 12 existing `ogImage` props already reference — nothing existing breaks.

**The copy is not invented and not machine-translated.** Every headline is the locale's
own `class="feat-h1"` and every sub is trimmed from its own `class="feat-lead"`, harvested
out of `src/pages/{,,zh/,fr/}features/*.astro`. That also fixes the second half of the
finding — the review was right that I had replaced short titles with English marketing
sentences; the headlines are now "Readiness you can read" / "看得懂的准备状态" /
"Une forme que tu peux lire", i.e. exactly what the page says.

Things the reviewer will want to check, and what I did about them:

- **PIL has no font fallback**, so a Chinese card set in Instrument Sans is tofu. Added a
  `Face` class that reads each face's real `cmap` (fontTools) and dispatches **per
  character** — the PIL equivalent of `--font-sans:'Instrument Sans','Noto Sans SC'`.
  Every draw/measure/wrap helper goes through it. A `missing()` check prints a loud
  stderr warning per card if any glyph would render as tofu; **the run above emitted
  none**.
- **zh-Hans law**: `anno_upper=False`, `anno_track=0.0` live in the LOCALE table, and
  `draw_text()` takes tracking as a parameter — a call site cannot add tracking or
  uppercase to Chinese. en/fr keep uppercase + 0.05em.
- **zh drops Alpino** (Latin display face, no CJK) and sets the headline in Noto Sans SC
  Medium. Line breaking switches to per-character with a leading-punctuation guard
  (`NO_LINE_START`) instead of word splitting, since Chinese has no spaces.
- Two defects found by reading the renders back and fixed in the loop: (a) the shipped
  Noto Sans SC subset has **no U+2014**, so `——` fell through to Instrument Sans and read
  as two detached hyphens — the zh recovery sub now uses `，而不是` (better Chinese
  anyway); (b) CJK fills its em box, so the display→body gap needed two 8pt steps
  (16 → 32) to stop reading as cramped.
- fr number format: `reading` is overridable per locale, so the fr movement-bank card
  reads `1 324`, matching its own sub text, while en reads `1,324`.
- The footer readout auto-trims its tail if a longer translation would collide with the
  wordmark, so no locale can silently overflow.

**I read back 6 of the 12 cards** (zh ×3, fr ×3, en ×1 — `zh/recovery-scoring`,
`zh/cold-start`, `zh/workload-tracking`, `fr/recovery-scoring`, `fr/cold-start`,
`fr/smart-templates`, `cold-start`). All render correctly, no tofu, no clipping.

**NOT DONE — needs CODEX.** The `.astro` prop changes are in `tuwa-website/src/`, which
is CODEX's. Until they land, zh/fr pages still serve the English card. Exact edit:

```
src/pages/zh/features/<card>.astro : ogImage="/og/zh/<card>.png"
src/pages/fr/features/<card>.astro : ogImage="/og/fr/<card>.png"
      cards: recovery-scoring · workload-tracking · cold-start · smart-templates
```

---

## Finding 2 — Fragment Mono self-hosted, and the mono face verified

```
$ cp WorkloadApp/Resources/Fonts/FragmentMono-{Regular.ttf,LICENSE.txt} design-system/assets/fonts/
$ shasum -a 256 WorkloadApp/Resources/Fonts/FragmentMono-Regular.ttf design-system/assets/fonts/FragmentMono-Regular.ttf
0fe011f425873c2e0fc73a189e394e340ad48d2b9a99a576bdeec75cee000460  WorkloadApp/…/FragmentMono-Regular.ttf
0fe011f425873c2e0fc73a189e394e340ad48d2b9a99a576bdeec75cee000460  design-system/assets/fonts/FragmentMono-Regular.ttf
```

`design-system/tokens/fonts.css:3` — the Google Fonts `@import` — is replaced by a local
`@font-face` with a comment telling the next agent not to restore it. The SIL OFL licence
file ships beside the binary.

### The mono face now demonstrably loads (Round 1 could not prove this)

`ds-base.js` injects `../../tokens/fonts.css`, so the deck picks the change up. Served the
repo at `127.0.0.1:8794` and probed with `document.fonts`:

```
$ curl -o /dev/null -w "%{http_code} %{size_download}\n" http://127.0.0.1:8794/design-system/assets/fonts/FragmentMono-Regular.ttf
200 125368

$ (font probe, headless Chrome 149, offline except localhost)
{"faces":["Fragment Mono:loaded","Instrument Sans:unloaded", … ],
 "check":true,
 "w_fragment":741.599853515625,
 "w_system_mono":722.4609375,
 "identical":false}
```

`Fragment Mono:loaded`, `document.fonts.check('12px "Fragment Mono"') === true`, and the
measured advance width **differs from the system monospace** — so this is the real face,
not a silent fallback that happens to be monospaced. The deck was then re-rendered and all
8 slides read back (`scratchpad/g2/shots/deck-s1..s8.png`): the mono eyebrows, the
`├─ └─` source lines and the readout keys are all Fragment Mono.

---

## Finding 3 — email template: hue is a token, instruction names the real line

- `transactional.html:117` hard-coded `color:#2E7D4F` on the readout `<td>`. It is now
  `color:{{readout_hue}}`. `grep` confirms **no metric hex remains in the markup** — the
  five values appear only inside the HOW TO USE comment.
- The instruction no longer references a `<span>` that never existed. It names the actual
  line ("the readout `<td>` inside the READOUT block, the 44px `{{readout_value}}` cell"),
  lists the five hues plus the identity-less→accent case, states there is **no default**,
  and requires `{{readout_key}}` to name the same metric.
- Also added: `{{footer_reason}}` needs explicit `<br />` (HTML collapses newlines) — a
  real gap I hit while filling the template.

Rendered with a **sleep** message (`readout_hue=#52589E`) precisely to prove the bug is
gone, and read the PNG back (`scratchpad/g2/shots/email.png`): the reading is indigo, the
key reads `SLEEP · LAST NIGHT`. Token sweep left nothing unfilled (`{{token}}` inside the
how-to-use prose is the only match).

---

## Findings 4, 5, 6 — pitch deck

**4 · 8pt grid.** Every cited value snapped, and I swept the whole file rather than only
the cited lines:

| was | now | where |
|---|---|---|
| `padding:20px 20px 24px` ×5 | `padding:24px` | slide 04 price cards |
| `margin-top:20px` ×2 | `margin-top:24px` | slide 05 comparison lists |
| `margin-top:12px` ×2 | `margin-top:16px` | slide 06 sub-lines |
| `padding-bottom:12px` | `padding-bottom:8px` | slide 03 right column |
| `margin-top:40px`, `margin:24px 0 40px` | `48px` | slides 04, 05 |

```
$ (every padding/margin/gap literal in the file, deduped)
4px 8px 16px 24px 32px 48px 64px 72px 88px
```

4px is the sanctioned `baselinePair` micro-gap. 72/88 are the slide frame (9×8 / 11×8) —
multiples of 8 but not on the named 8/16/24/32/48/64 token scale; I left the frame alone
rather than reflow all 8 slides, and am flagging it rather than hiding it.

**5 · Accent misuse.** `grep -c 6F6759 PitchDeck.dc.html` = **2**, and one of those is the
header comment. Travertine now appears exactly once in the deck:

> **Baseline note (added Round 3).** The "before" states in this list are my own
> *mid-session* working tree, not `HEAD`. `HEAD`'s deck is six slides with four accent
> occurrences, all of them eyebrow labels — slides 05/07/08 and every accent-set reading
> below were authored inside this session. Read the list as "what I changed while
> working", not as a diff against the last commit.

- slide 03 `$33.6B` (184px) — the one identity-less hero reading, which is what
  DESIGN.md:187-189 licenses. **Kept.**
- slide 03 `$12.12B` and `13.40%` (44px) — accent → `#57544E` (text-2), secondary.
- slide 04 the five competitor prices (32px) — accent → `#1B1A17` (text-1). Slide 04 has
  no hero reading, so none of them may wear accent.
- **Additionally** (not in the findings, same violation class): the mono eyebrow labels
  were set in accent. "Never … labels" is explicit in the Reading Color Rule, so they are
  now `#8B877F` (text-3, the annotation default), matching slide 01 which was already
  correct.
  *(Corrected in Round 3 — the original wording, "seven mono eyebrow labels
  (`02 · THE PROBLEM` … `08 · ASK`)", is not reproducible from any committed state and was
  the count in my own mid-session working tree.* `HEAD` *has a **six**-slide deck with
  **four** accent eyebrows —* `02 · THE PROBLEM` *(:25),* `03 · THE MARKET` *(:34),*
  `04 · POSITIONING` *(:49),* `06 · ASK` *(:71); the other three of today's seven are on
  slides 05/07/08, which this session created. Verified:*
  `git show HEAD:design-system/templates/pitch-deck/PitchDeck.dc.html | grep -c 6F6759`
  *→ **4**, all four on eyebrows; the working tree is **2**, one of which is the header
  comment.)*

The header comment was rewritten to state the new rule, so the old wording ("market
sizes, prices take travertine accent") can't be used to justify restoring it.

**6 · Stale comment.** `:31` "Alpino 650/450 is the display voice" → "Alpino 650 is the
display voice" (the file only ever used 500 and 650, and now only 650 on headlines).

Re-rendered over `python3 -m http.server 8794` in headless Chrome at 1400px and **read all
8 slides back** (`scratchpad/g2/shots/deck-s1..s8.png`). No layout regressions from the
spacing changes; slide 04's five price cards still bottom-align (`align-items:stretch`).

---

## Explicitly NOT done

- **`tuwa-website/src/**` untouched.** The 8 zh/fr `ogImage` prop edits are CODEX's — see
  the block under Finding 1. Until they land, the new zh/fr cards are unreferenced files.
- **`og-default.png` still not regenerated** (Round 1 request 2, no ownership grant). It
  is the JSON-LD default and is referenced by 10+ pages including `features/verdict.astro`
  and every cover-less blog post, and it now looks unrelated to 12 Field Notes cards
  instead of 4. `generate_og.py` could emit it in ~10 lines.
- **No `og/verdict.png`** — nothing would reference it (Round 1 request 3).
- **No Astro build.** I only wrote PNGs under `public/`, which Astro copies verbatim, and
  the deck/email live outside that repo. `npm run build` is Session E / CODEX.
- **No PDF/slide export of the deck.** Still the `.dc.html` template only.
- **Email not localised and not wired to a sender.** en only; zh-Hans/fr versions would
  need the no-case-transform / no-tracking rules applied to the annotation lines.
- **Browser matrix is headless Chrome 149 only.** No Safari, Firefox, Outlook or Litmus.
  For the redirect pages this matters: some corporate mail/proxy stacks strip
  `<meta http-equiv="refresh">`, which is exactly why the visible `<a>` fallback exists,
  but I have not tested one.
- **True narrow-viewport render (≤390px CSS) not obtained** — headless Chrome on macOS
  floors the CSS viewport at 500px. Verified structurally instead (mobile branch active at
  500px, `scrollWidth == clientWidth`, `minmax(0,1fr)` grid track). A real-device check is
  a human step.
- **No app source, no `xcodebuild`, no test run, no git write of any kind.**

## Decisions / requests for HAN

- **G-6 (new) · The redirect pages are unbranded typographically.** They are Field Notes
  in material, colour, spacing and corner law, but set in the system sans because the
  brand faces cannot be self-hosted from `docs/` without adding binaries outside this
  lane. Say the word and I will add `docs/fonts/InstrumentSans-{Regular,Medium}.ttf`
  (~170 KB) and make them speak in the working voice.
- **G-7 (new) · `design-system/assets/fonts/` is missing `NotoSansSC-LICENSE.txt`.** The
  Instrument Sans and (now) Fragment Mono licences are there; the Noto one is only under
  `WorkloadApp/Resources/Fonts/`. One `cp` — I did not do it because only the Fragment
  Mono copy was granted.
- **G-8 (new) · Deck slide frame is `72px 88px`,** a multiple of 8 but not a named token.
  Left as-is. Snap to `64px 88px` or `72px 96px` if you want strict named-scale purity.
- **G-3, G-4 from Round 1 still open** (light quote slide; deck asserts no traction
  figures). G-1 superseded by G-6. G-2 **resolved** (Fragment Mono self-hosted). G-5
  **resolved by HAN ruling #4** (pages are live and load-bearing; now redirects).

---

# ROUND 3 — fix session

## 2026-07-31T01:59Z · 6/6 findings addressed, 0 disputed

Branch `v1.7-field-notes`, HEAD still `8742629`. **No commit, stage, stash, checkout,
reset or push.** No app source, no `xcodebuild`, no simulator, no test run.
Dynamic Type untouched — no `UIFontMetrics` / `@ScaledMetric` / `relativeTo:` /
`dynamicTypeSize` anywhere in this lane's files, and `DESIGN.md` is not modified by me
(it stays at v6.2).

### Finding 1 (MAJOR) — `text3` on a well in the OG generator · **FIXED**

Reviewer's evidence verified against the file as it stood: `:415` `well_h = px(208)`,
`:417` `debossed_well(img, well)`, `:427` drew the reading key at `well[1] + px(144)` —
inside the well — in `TEXT_3` (`#8B877F`). Contrast recomputed independently (WCAG 2.x
relative luminance):

```
$ python3 - <<'EOF'   (sRGB relative luminance, (L1+0.05)/(L2+0.05))
#8B877F on #E7E5E0 (well-top)     2.84   <- below the 3:1 micro floor
#8B877F on #EDEBE6 (well-bottom)  3.00   <- at the floor, no margin
#57544E on #E7E5E0                5.99
#57544E on #EDEBE6                6.33
EOF
```

DESIGN.md:226 and :323 both say "never `text3` on a well". **All 12 shipped cards carried
it.** Fixed by moving the key to `TEXT_2` inside the well (not lifting it out — the key
belongs to the reading it labels, and `TEXT_2` clears 5.99:1 across the whole gradient).
A four-line comment at the call site records the measured numbers so it cannot regress
silently, and the module's `DESIGN LAW APPLIED HERE` docstring gained the rule.

**Regenerated all 12 cards:**

```
$ python3 design-system/templates/og/generate_og.py
wrote tuwa-website/public/og/recovery-scoring.png (1200, 630)
wrote tuwa-website/public/og/workload-tracking.png (1200, 630)
wrote tuwa-website/public/og/cold-start.png (1200, 630)
wrote tuwa-website/public/og/smart-templates.png (1200, 630)
wrote tuwa-website/public/og/fr/recovery-scoring.png (1200, 630)
wrote tuwa-website/public/og/fr/workload-tracking.png (1200, 630)
wrote tuwa-website/public/og/fr/cold-start.png (1200, 630)
wrote tuwa-website/public/og/fr/smart-templates.png (1200, 630)
wrote tuwa-website/public/og/zh/recovery-scoring.png (1200, 630)
wrote tuwa-website/public/og/zh/workload-tracking.png (1200, 630)
wrote tuwa-website/public/og/zh/cold-start.png (1200, 630)
wrote tuwa-website/public/og/zh/smart-templates.png (1200, 630)
```

**Pixel proof, all 12** — histogram of the key band (`y 358–374`, `x 834–1143`, i.e. the
text row inside the well). The stem plateau lands on `#57544E`, not `#8B877F`:

```
og/recovery-scoring.png     #53504A ×16, #5C5953 ×15, #5B5852 ×11, #5D5A54 ×10, #57544E ×10
og/zh/cold-start.png        #57544E ×17, #5E5B55 ×14, #5C5953 ×12, #5D5A54 ×11, #58554F ×11
og/fr/workload-tracking.png #918E88 ×13, #5A5751 ×10, #57544F ×10, #53504A ×8,  #615E58 ×8
```

(The scattered values darker than `#57544E` are Lanczos ringing from the 2× supersample
downsample at glyph stems; `#918E88` in the fr sample is the reading's antialias skirt
overlapping the band. Neither is a drawn colour.)

**Read back with the Read tool** (visual, not just bytes): `og/recovery-scoring.png`,
`og/zh/cold-start.png`, `og/fr/workload-tracking.png`. All three read correctly — key
visibly darker, layout unchanged, no reflow, CJK and French diacritics intact.

While measuring I also checked the two remaining `TEXT_3` positions in the generator so
they are not the same bug in a different place. Both are legal and were left alone:
`:379/:380` (top strip) and `:411` (footer tail) sit on `SURFACE #F4F3F0`, where `#8B877F`
measures **3.22:1** — above the micro floor. The footer's metric-hue label on that same
plane measures 4.55–5.83:1 across the five hues, above 4.5:1.

### Finding 2 (MAJOR) — same violation in the email readout key · **FIXED**

Verified: `transactional.html:131` sets the readout table to `background-color:#EDEBE6`;
`:136` set the key to `color:#8B877F` — **3.00:1**, the same failure I had just fixed one
file over. Changed to `#57544E` (6.33:1) and the block comment now states the reason and
the number, so the next editor cannot "restore" it.

Swept the rest of the file for the same class. The three other `#8B877F` uses are legal
and untouched: `:100` masthead eyebrow and `:195` legal footer sit outside the card on
`#F0EFEC` (**3.11:1**); `:184` machine line sits on the card `#F8F7F4` (**3.34:1**, the
sanctioned annotation default). No well but the readout uses `#EDEBE6`.

### Finding 3 (MINOR) — unreproducible before/after figures · **FIXED (corrected in place)**

The reviewer is right that a before/after number in the deck section matches no committed
or working-tree state. Two corrections, both with the command that produces them:

1. `:178` "Mono capped at 12px everywhere (was 13–14px)" implied the whole deck was
   oversized. Measured against `HEAD`: 21 Fragment Mono declarations — 11px ×10, 12px ×6,
   13px ×3 (`HEAD` lines 28, 38, 76), 14px ×2 (54, 58). Five broke the cap, not all.
   Reworded with those counts and line numbers.
2. `:622` "seven mono eyebrow labels (`02 · THE PROBLEM` … `08 · ASK`) were set in accent"
   is **not reproducible from any committed state** — it was the count in my own
   mid-session working tree. `HEAD`'s deck is six slides with **four** accent occurrences:

   ```
   $ git show HEAD:design-system/templates/pitch-deck/PitchDeck.dc.html | grep -c 6F6759
   4
   ```
   ```
   HEAD:25  color:#6F6759  02 · THE PROBLEM
   HEAD:34  color:#6F6759  03 · THE MARKET
   HEAD:49  color:#6F6759  04 · POSITIONING
   HEAD:71  color:#6F6759  06 · ASK
   ```
   Slides 05, 07 and 08 — and every accent-set *reading* in that list — were authored
   inside this session, so their "before" state was never committed. Reworded, plus a
   `Baseline note` block at the head of item 5 saying the whole list is intra-session, not
   a diff against `HEAD`.

Working tree for comparison: `grep -c 6F6759` → **2** (one is the header comment, one is
slide 03's `$33.6B`). That number *is* reproducible and stands.

### Finding 4 (MINOR) — `design-system/HANDOFF.md` stale on the font CDN · **FIXED**

Verified: `HANDOFF.md:17` still read "Self-host Fragment Mono (it is CDN-imported in
`tokens/fonts.css` — the one outstanding caveat)", but `tokens/fonts.css:3-7` now carries a
self-hosted `@font-face` and the Google `@import` is gone (`HEAD:tokens/fonts.css:3` had
`@import url('https://fonts.googleapis.com/css2?family=Fragment+Mono&display=swap')`).
Rewritten to say the face is already self-hosted, where the TTF and its OFL licence live,
what a site integrator still has to do (copy into `public/fonts/`, rewrite the `src:`
URL), and **do not restore the `@import`**.

Two adjacent lines in the same doc described this batch's own deliverables as future work;
both corrected to DONE with their residual gaps named: `:28` OG images (zh/fr `ogImage`
props still unported, `og-default.png` still not regenerated) and `:29` transactional
email (en only, no sender).

**Left stale on purpose, flagged not fixed:** `HANDOFF.md:7` ("The app is already on v5
Pavilion; v6 is an overlay") and steps 1–5 of Part 1a describe iOS work that Waves 1–2
have since done. That is lanes A–H's ledger, not mine — rewriting it from this lane would
be guessing at their end state.

### Finding 5 (MINOR) — deck header comment mis-states where metric hues appear · **FIXED**

Verified against what the file actually does — every metric-hue hex, with its slide:

```
:123 [05 Positioning] readiness #2E7D4F  "READINESS ● TUWA" key, 11px mono
:160 [07 Product]     readiness #2E7D4F  feature card key
:161 [07 Product]     recovery  #1D7189  feature card key
:162 [07 Product]     sleep     #52589E  feature card key
:163 [07 Product]     strain    #A8442D  feature card key
:164 [07 Product]     load      #8A6810  feature card key
```

The header said "Metric hues appear only where a real metric is named (slide 07)" —
slide 05 was missing, which would have read to the next editor as an unlicensed hue.
Both are in fact legal: each is an annotation key naming its own metric, and each sits on
a raised card plane (`linear-gradient(#FCFBF9,#F8F7F4)`, `:122` and `:160-164`), which is
where DESIGN.md requires sub-24pt hue text. Header now names both places and states the
card-plane condition and the "never a plane fill / CTA / tint" prohibition.

### Finding 6 (MINOR) — no-git-write proof over all four deliverable directories · **FIXED**

The Round 2 proof only ran `git status --porcelain public/og/` inside `tuwa-website`.
Re-run over every directory this lane wrote to, in both repos (`tuwa-website/` is a nested
repo and is gitignored from `Tonus` — `.gitignore:61` — so it needs its own check):

```
$ date -u "+%Y-%m-%dT%H:%M:%SZ"
2026-07-31T01:59:08Z

$ git status --porcelain -- docs/ design-system/ .planning/v17-field-notes/ tuwa-website/
 M .planning/v17-field-notes/DISTRIBUTION.md
 M design-system/HANDOFF.md
 M design-system/templates/pitch-deck/PitchDeck.dc.html
 M design-system/tokens/fonts.css
 M docs/privacy.html
 M docs/support.html
 M docs/terms.html
?? .planning/v17-field-notes/dynamic-type-grid.txt
?? .planning/v17-field-notes/dynamic-type-shots/
?? .planning/v17-field-notes/spec-h-charts.md
?? .planning/v17-field-notes/spec-t-dynamic-type.md
?? .planning/v17-field-notes/status-f.md
?? .planning/v17-field-notes/status-g.md
?? .planning/v17-field-notes/status-h.md
?? .planning/v17-field-notes/status-p.md
?? .planning/v17-field-notes/status-t.md
?? design-system/assets/fonts/FragmentMono-LICENSE.txt
?? design-system/assets/fonts/FragmentMono-Regular.ttf
?? design-system/templates/email/
?? design-system/templates/og/
?? docs/market-intelligence/commoditization-clock-2026-07-26.md

$ git log --oneline -1
8742629 docs(v1.7): Wave 3 open — kickoff prompts for lanes F/G/H/P/T

$ git reflog -3 --date=iso
8742629 HEAD@{2026-07-30 21:09:53 +0800}: commit: docs(v1.7): Wave 3 open — ...
b2590d6 HEAD@{2026-07-30 21:01:56 +0800}: commit: fix(v1.7): DeltaIndicator ...
e2453f8 HEAD@{2026-07-30 20:17:32 +0800}: commit: fix(v1.7): v6.2 — micro 11pt → 12pt

$ cd tuwa-website && git status --porcelain public/og/
 M public/og/cold-start.png
 M public/og/recovery-scoring.png
 M public/og/smart-templates.png
 M public/og/workload-tracking.png
?? public/og/fr/
?? public/og/zh/

$ cd tuwa-website && git log --oneline -1
b4d2f25 feat(v1.7): Field Notes v6 retheme — tokens, two new voices, self-drawing chart

$ cd tuwa-website && git reflog -2 --date=iso
b4d2f25 HEAD@{2026-07-30 17:46:37 +0800}: commit: feat(v1.7): Field Notes v6 retheme — ...
bfed11f HEAD@{2026-07-26 22:51:37 +0800}: commit: legal(terms): Apple minimum EULA ...
```

Both reflogs end at a commit made before this session opened: nothing in either repo was
staged, committed, stashed, checked out, reset or pushed. Everything is working tree.
Not-mine entries above (`DISTRIBUTION.md`, `spec-h`, `status-f/h/p/t`, `dynamic-type-*`,
`market-intelligence/`) belong to the orchestrator and other lanes.

### Files changed this round

```
design-system/templates/og/generate_og.py             finding 1 (+ docstring)
design-system/templates/email/transactional.html      finding 2 (+ comment)
design-system/templates/pitch-deck/PitchDeck.dc.html  finding 5 (comment only, no render change)
design-system/HANDOFF.md                              finding 4
.planning/v17-field-notes/status-g.md                 findings 3, 6, and this section
tuwa-website/public/og/**/*.png  (12 files)           regenerated for finding 1
```

`PitchDeck.dc.html` changed only inside the `<!-- ... -->` header block, so the deck does
not need re-rendering; the 8 slide screenshots from Round 2 remain valid.

---

# HAND-OFF TO CODEX — website content gaps opened by the `docs/*.html` redirects

**Status: not a request to reconsider.** HAN reviewed the counter-evidence below and
**reaffirmed that all three `docs/*.html` redirects ship as they are**
(DISTRIBUTION.md "Wave 3 — HAN rulings, round 2", ruling 6). The redirects are correct;
the website is now the single source of truth, and it is missing two things the old
static pages carried. This section exists so porting them is mechanical.

`tuwa-website/src/**` is CODEX's. Session G wrote nothing under it.

## Why this exists

`docs/privacy.html` and `docs/support.html` were last edited **June 5, 2026**;
`tuwa.app/privacy` still says **March 27, 2026**. Two paragraphs drifted out:

| gap | in `docs/*.html` | on tuwa.app | consequence |
|---|---|---|---|
| **Data Sharing** section | yes (`HEAD:docs/privacy.html`) | **absent** — `en/privacy.ts` has no `dataSharing` key | the "we do not sell/share your data" commitment now has no public statement |
| **Account-deletion answer** | yes (`HEAD:docs/support.html`) | **absent** — no FAQ entry in any `support.ts` | App Review **5.1.1(v)** expects a discoverable deletion path; the app's own paywall links here |

Verified absent, not just hard to find:

```
$ grep -ril "data sharing\|dataSharing" tuwa-website/src/i18n/locales/
(no matches)
$ grep -ril "delete my account\|account deletion\|删除我的账户\|supprimer mon compte" tuwa-website/src/i18n/locales/*/support.ts
(no matches)
$ grep -n lastUpdated tuwa-website/src/i18n/locales/*/privacy.ts
en/privacy.ts:  lastUpdated: 'March 27, 2026',
zh/privacy.ts:  lastUpdated: '2026年3月27日',
fr/privacy.ts:  lastUpdated: '27 mars 2026',
```

`docs/privacy.html` does have a `Data Retention and Deletion` section that survived into
`privacy.ts` as `dataRetention` — that is a *different* section. `Data Sharing` is the
missing one.

## Port 1 — the Data Sharing paragraph into privacy

### Exact source text

`git show HEAD:docs/privacy.html`, the section between `How Data Is Stored` and
`Third-Party Services`, quoted verbatim:

```html
  <h2>Data Sharing</h2>
  <p>Tuwa does not share your training or recovery data with coaches, other users, advertisers, or data brokers. If future sharing features are added, they will require your explicit consent.</p>
```

### Where it goes (four files, plus three `lastUpdated` bumps)

The English privacy page is **not** locale-driven — `src/pages/privacy.astro` is hardcoded
HTML with `lastUpdated="March 27, 2026"` on line 4. zh and fr **are** locale-driven
(`usePrivacyTranslations('zh'|'fr')` → `LegalPageLayout lastUpdated={t.meta.lastUpdated}`).
`en/privacy.ts` is still the source of the exported `Privacy` type
(`src/i18n/utils.ts:56`), so the key must be added there too even though the en page does
not read it.

1. **`src/i18n/locales/en/privacy.ts`** — insert between `howDataIsStored` and
   `thirdPartyServices` (i.e. after the block closing at `:72`):

```ts
  dataSharing: {
    heading: 'Data Sharing',
    p1: 'Tuwa does not share your training or recovery data with coaches, other users, advertisers, or data brokers. If future sharing features are added, they will require your explicit consent.',
  },
```

2. **`src/i18n/locales/zh/privacy.ts`** — same position. Draft, matching the file's
   existing 您 register:

```ts
  dataSharing: {
    heading: '数据共享',
    p1: 'Tuwa 不会将您的训练或恢复数据共享给教练、其他用户、广告商或数据经纪商。若日后新增共享功能，将需要您的明确同意。',
  },
```

3. **`src/i18n/locales/fr/privacy.ts`** — same position. Draft, matching the file's
   existing tutoiement:

```ts
  dataSharing: {
    heading: 'Partage des données',
    p1: 'Tuwa ne partage pas tes données d\'entraînement ou de récupération avec des coachs, d\'autres utilisateurs, des annonceurs ou des courtiers en données. Si des fonctionnalités de partage sont ajoutées à l\'avenir, elles nécessiteront ton consentement explicite.',
  },
```

4. **`src/pages/privacy.astro`** — insert the literal HTML above between the
   `How Data Is Stored` `</ul>` (`:36`) and `<h2>Third-Party Services</h2>` (`:38`).

5. **`src/pages/zh/privacy.astro`** and **`src/pages/fr/privacy.astro`** — insert before
   the `{t.thirdPartyServices.heading}` heading (zh: `:51`):

```astro
  <h2>{t.dataSharing.heading}</h2>
  <p>{t.dataSharing.p1}</p>
```

6. **Bump `lastUpdated` in all four places** — `en/zh/fr privacy.ts` `meta.lastUpdated`
   **and** the hardcoded `lastUpdated="March 27, 2026"` on `src/pages/privacy.astro:4`.
   The source page it is being reconciled with is dated **June 5, 2026**; the honest value
   is the date this edit ships, in each locale's existing format
   (`June 5, 2026` / `2026年6月5日` / `5 juin 2026` if you date it to the source edit).

### Two judgement calls for CODEX / HAN, flagged not decided

- The sentence enumerates **"coaches"**. Coach mode was dropped in v1.6 (athlete-only
  app). It is a *negative* commitment, so it stays true, but you may prefer dropping the
  word rather than naming a role the product no longer has. Either way, keep the
  enumeration exhaustive — the value of the paragraph is that it names advertisers and
  data brokers explicitly.
- zh/fr are **drafts by an English-first author**. Both files carry
  `disclaimer.text` = "This is a translation. The English version is the legally binding
  document.", which limits the exposure, but a native read is still worth one pass.

## Port 2 — account-deletion FAQ on the support page

### Exact source text

`git show HEAD:docs/support.html:51-52`, verbatim:

```html
  <h2>How do I delete my account?</h2>
  <p>Sign out in the app via <strong>Profile &gt; Sign Out</strong>, then email us at <a href="mailto:hanwenma09@gmail.com">hanwenma09@gmail.com</a> to request full data deletion from our servers.</p>
```

**Substitute the address.** The website uses `support@tuwa.app` throughout
(`en/support.ts:48`, `contact.*`); `hanwenma09@gmail.com` is the old personal address and
must not be reintroduced to tuwa.app.

### Where it goes (three files, no component change)

All three locales render the support page from the locale files through
`src/components/SupportPage.astro` (`useSupportTranslations(locale)` → `t.faq.map`), so
**adding an array entry is the whole change** — no `.astro` edit.

Append to the `faq` array in each of `src/i18n/locales/{en,zh,fr}/support.ts`. Suggested
placement: directly after the existing "How do I manage my subscription?" entry, so the
two account-lifecycle answers sit together; App Review only requires that it be
discoverable on the page.

```ts
    {
      q: 'How do I delete my account?',
      a: 'Sign out in the app via Profile > Sign Out, then email us at support@tuwa.app to request full deletion of your account and data from our servers. Deletion is permanent and removes your workout logs, recovery scores, training load snapshots, and personal records.',
    },
```

zh draft (您 register, matching the file):

```ts
    {
      q: '如何删除我的账户？',
      a: '在应用中前往"个人资料 > 退出登录"，然后发送邮件至 support@tuwa.app，申请从我们的服务器完全删除您的账户和数据。删除不可撤销，您的训练记录、恢复评分、训练负荷快照和个人纪录都会被永久移除。',
    },
```

fr draft (tutoiement, matching the file):

```ts
    {
      q: 'Comment supprimer mon compte ?',
      a: 'Déconnecte-toi dans l\'application via Profil > Se déconnecter, puis écris-nous à support@tuwa.app pour demander la suppression complète de ton compte et de tes données de nos serveurs. La suppression est définitive : journaux d\'entraînement, scores de récupération, instantanés de charge et records personnels sont supprimés.',
    },
```

The second sentence is not in the `docs/` source — it is lifted from the privacy page's
own `dataRetention.outro`, so nothing new is being asserted. Drop it if you want a
one-sentence answer.

## Third item, lower priority — still open from Round 2

The eight zh/fr OG cards now exist (`tuwa-website/public/og/{zh,fr}/*.png` — four each,
twelve including en, all regenerated 2026-07-31) but nothing references them. Eight
`ogImage` props still point at the English cards, so a page shared from a Chinese or
French feature page previews in English:

```
src/pages/zh/features/<card>.astro : ogImage="/og/<card>.png"  ->  "/og/zh/<card>.png"
src/pages/fr/features/<card>.astro : ogImage="/og/<card>.png"  ->  "/og/fr/<card>.png"
   cards: recovery-scoring, workload-tracking, cold-start, smart-templates
```

Regenerate any time with `python3 design-system/templates/og/generate_og.py`
(offline, deterministic, `--locale` is repeatable). `og-default.png` is still on the old
design and is referenced by 10+ pages — ~10 lines in the generator would emit it.

