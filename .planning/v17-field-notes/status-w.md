# Session W — homepage demo (status)

Lane: website homepage rebuild to the `ui_kits/website` layout, **demo-first**.
Scope authority: `DISTRIBUTION.md` → "Post-1.7 — Session W" + HAN clarifications 2026-08-01.

---

## 2026-08-01 — DONE (round 1). Stopped for HAN's review.

### What exists

All work is in **`tuwa-website/.design-explorations/website-v2-demo/`** (untracked scratch,
precedent: `v16-motion-demos`).

```
website-v2-demo/
├─ index.html        the demo homepage (single self-contained file)
├─ compare.html      section-by-section demo vs live tuwa.app
├─ motion.js         motion layer (ported from the kit + 2 additions)
├─ styles.css        imports tokens/*.css, nothing else
├─ tokens/*.css      copied verbatim from design-system/tokens/
├─ fonts/            Alpino-Variable.ttf (path the kit's fonts.css expects)
├─ assets/           fonts, 8 app screens, icon, App Store badge,
│                    vendor/{lenis,lottie}.min.js, lottie/*.json
└─ shots/            28 capture PNGs + 2 full-page PNGs
```

### How to look at it

```
cd /Users/hanwen/dev/Tonus/tuwa-website/.design-explorations/website-v2-demo
python3 -m http.server 8899
# then open http://localhost:8899/compare.html  (start here)
#            http://localhost:8899/index.html   (the demo itself)
```

A server is required, not `open` — Lottie fetches its JSON over XHR, which `file://`
blocks. Everything else works from disk.

**Start with `compare.html`.** It is the deliverable HAN asked for: every section paired
against the live site at the same viewport, with a note on what the kit layout changes and
what decision it needs. It ends with a six-item decision list.

### Structure built (kit order, adapted)

| # | Section | Source of layout | Source of copy |
|---|---|---|---|
| — | Header + line-reveal hero, readiness count-up | kit | live `heroScrub` |
| 01 | Today — pinned 3-step showcase + verdict Lottie | kit | live `showcase` (verbatim) |
| 02 | Training load — pinned strike-zone scrub + needle Lottie | kit | live `zoneScrub` (verbatim) |
| 03 | The system — fanned spread | kit | kit heading + live `logging` body |
| — | Stats band (1,324 / 1 / 28) | kit | kit |
| 04 | Recovery — self-drawing HRV chart | kit | live `recovery` + `recovery.spark` |
| **05** | **Methodology — sleep score, in development** | **new** | **new, from research §9–§10** |
| — | Ghost numerals + quote | kit | live `recovery.quote` (verbatim) |
| 06 | Privacy close | kit | live `privacyClose` (verbatim) |
| — | Footer | kit | kit |

The live site's vocabulary marquee has no kit counterpart and is not in the demo — flagged
as a decision, not dropped silently.

### Section 05 and the §10 claim ladder

The sleep engine is **not built**, so nothing may be presented as live or validated. What
the section does:

- States on its face, in two chips at the top: `STATUS: DESIGN · NOT IN THE SHIPPING APP`
  and `NO PERFORMANCE OR ACCURACY CLAIM IS MADE HERE`.
- Presents §10's three points as **design intents**, not benefits. The only card labelled
  `SHIPPING TODAY` is on-device privacy — true of the current build.
- Publishes the mechanism (state vector → profile match → clamped, renormalised weight
  deltas → stored per night) and the §5 base weights, with the note that they are argued,
  not fitted, and registered as H-01.
- Shows three of six profiles with an explicit evidence column that separates
  evidence-backed *direction* from hypothesis *magnitude*, and says outright that the one
  direct test of load against sleep need was null (H-03).
- Shows four of ten hypothesis-registry rows, each with the measurement that would revise
  or retire it — including H-10, which cites no source and says so.
- Closes with a rails block: not a medical device; no diagnostic, treatment or
  injury-prevention claim; stages come from the athlete's own wearable compared to their
  own history; nothing on the page is a validated result or a shipped feature; sources
  describe what the paper found.
- Cites Borbély 2016, Kredlow 2015, Wittmann & Roenneberg 2006, Van Dongen 2003, each with
  what it actually supports.

No fear framing, no debt shaming — the nocebo guard is applied to the copy.

### Design-law check

- Tokens only, imported from `design-system/tokens/*.css`; no hex literal in the demo.
- Corners 12 / 8 / pill; hairlines 0.5px; **no shadows** anywhere.
- Two voices: Instrument Sans speaks, Fragment Mono annotates at 10–11px, uppercase,
  never a sentence. Alpino on marketing headings only (h1/h2), as the kit does.
- One ink-filled pill per screen (header CTA); App Store badge is the stock SVG.
- Zone states are written-out labels with colour supplementary; the "colour is
  supplementary" footer line is kept.
- All data numerals `tabular-nums`.
- Annotation choreography implemented as one primitive: mono marks fade in 40 ms apart,
  240 ms **after** the surface settles.
- No CDN. Lenis and Lottie are the vendored copies from `design-system/assets/vendor/`.
- Reduced motion verified by measurement, not assertion — see below.

### Verification

`node` + Playwright 1.56.1, Chromium, 1280×900 @2x.

```
demo  → title OK · pageerrors: []  · broken images: []  · scrollHeight 11575
        fonts: Fragment Mono loaded, Instrument Sans ×2 loaded, Alpino loaded
compare → title OK · pageerrors: [] · broken images: []
reduced-motion (reducedMotion:'reduce'):
        {"motionClass":false,"heroScore":"82","counts":["1,324","1","28"],
         "dash":"0px","baselineOp":"1","annoOp":"1","spread":"1"}  errors []
```

That is the whole reduced-motion contract: no `motion` class, count-ups at final value,
chart fully drawn, baseline and now-dot opaque, annotations opaque, fan spread at `--p:1`.

Captures: 15 demo + 12 live section shots + 2 full-page shots, all in `shots/`.

### Git

**Zero commits, zero pushes, nothing staged.** `tuwa-website/src/`, the legal routes and
the app repo were not touched. The only new paths are inside
`.design-explorations/website-v2-demo/` and this file.

---

## Decisions I asked for in round 1

1. Hero composition — **answered, see round 2.**
2. **Vocabulary marquee** — still open. Keep it or drop it. Not in the kit, so not in the demo.
3. **Logging** — still open. Its own section again (as live), or folded into the fan (as now).
4. **Stats band** — still open. Kit's `1,324 / 1 / 28` (what the demo uses) or live's
   `1,324 / 82 / 7`. I think the kit's is stronger; it states the product rather than
   quoting a sample score.
5. **Section 05** — still open. Length, tone, and whether the two tables survive. It is the
   longest section on the page by some margin.
6. **Judgement call to confirm** — still open. The base-weight bars are drawn in
   `--metric-sleep`. I read them as a chart series, which the colour law permits. If you
   read them as plane fill, they become ink and the hue moves to the reading only.

---

## 2026-08-01 — round 2. HAN's ruling applied. Stopped again for review.

**HAN's ruling:** adopt the demo everywhere, with two things pulled back from the live
site — the hero's readiness numeral and diagram instead of the screenshot, and the live
site's light screenshot frames.

### 1. Hero — the live reading replaces the framed device shot

Ported the live composition rather than approximating it. Values read off tuwa.app's
computed styles, not guessed:

- Numeral absolutely positioned top-right, `clamp(140px, 24vw, 300px)`, weight 400,
  `letter-spacing:-0.03em`, `tabular-nums`, in **`--metric-readiness`** — readiness owns a
  hue, so the Reading Color Rule puts the hero reading in it, not in the accent.
- Caption `READINESS TODAY` in the annotation voice at `--text-3`.
- Tick rail: 16px tall, `repeating-linear-gradient(90deg, --divider-strong 0 2px,
  transparent 2px 12px)`, needle 2px wide overhanging 6px top and bottom in
  **`--accent`** — the needle is a live-state mark, which is exactly what travertine is for.
- Headline `max-width:12ch` at `z-index:1` so it sits over the numeral, as live does.

**One thing live does not do:** the needle now rises with the count-up — same 700 ms cubic
ease as the numeral, so the reading and its mark move together instead of the mark being
parked at 82% from the first frame. Final values stay baked into the markup, so no-JS and
reduced-motion still land on 82 / `left:82%`.

The mono strapline lost its duplicated `READINESS 82 ● GO` — the numeral says it now. It
reads `TUWA // THE SPORTS-SCIENCE BACK ROOM`.

**Side effect worth naming:** the 82-vs-71 mismatch I flagged in round 1 is gone. No
screenshot sits beside the reading any more.

### 2. Device frames — light, and the dark bezel is deleted

The kit's `#1F2225` bezel is out everywhere (hero had one, three plates, three fan phones,
privacy). Frame recipe taken from live:

```
border: 1px solid var(--divider-strong)   radius 48 / image 40   padding 10px
box-shadow: inset 0 1px 0 0 rgba(255,255,255,.7)   ← the raised relief top highlight
```

Two deliberate departures from live, both because the kit's layout overlaps and live's
does not:

- **Frame body is `--surface-el-2`, not transparent.** Live can afford transparent because
  its phones never overlap. In the fan they do, and transparent frames let the rear
  frames' hairlines show through the front one — it read as wireframe clutter. An opaque
  raised plane is also the more correct relief reading.
- **Fan height 560 → 640px.** At ±10° the outer two phones were clipping top and bottom.

Net effect on design law: **there is now no dark surface anywhere on the page.** The kit's
dark bezel was the one sanctioned exception, and it is no longer used.

### 3. Responsive defects found and fixed while re-verifying

Not part of HAN's ruling, but the round-1 report claimed responsive handling, so I
measured it instead of assuming. At 390px the page scrolled horizontally to 703px. Three
causes, all fixed:

- The header nav did not collapse — links now hide below 900px, wordmark and pill stay.
- Two `repeat(3,1fr)` grids (stats band, the three design-intent cards) never collapsed —
  tagged `data-g3` and folded to one column.
- **The real one:** grid children default to `min-width:auto`, so the `white-space:pre`
  reason trees forced their tracks open instead of scrolling inside their own cards.
  Fixed with `min-width:0` on grid children.

Also added a narrow-screen hero rule: below 900px the reading stops hiding behind the
headline and leads the section, at `clamp(96px, 24vw, 140px)` — which is what live does.

### Verification (round 2)

```
normal 1280×900 : score 82 · needle left:82% · phone bg rgb(252,251,249)
                  border rgb(204,201,194) · radius 40px · pageerrors []
dark-surface scan: only #railFill (2px ink progress mark) — correct, not a plane
reduced motion  : {"motion":false,"score":"82","needle":"82%","dash":"0px","spread":"1"}
                  pageerrors []
overflow scan   : 390 ok · 768 ok · 1280 ok · 1600 ok   (scrollWidth == clientWidth, all)
compare.html    : 0 broken images · pageerrors []
```

All 15 demo captures + the full-page shot re-taken; `shots/demo-narrow-hero.png` added.
The live captures are unchanged from round 1. `compare.html` row 01 and row 04 rewritten,
and the decision list now separates settled from open.

### Git (round 2)

Still **zero commits, zero pushes, nothing staged.** `tuwa-website/src/`, the legal routes
and the app repo remain untouched.

---

---

## 2026-08-01 — round 3. Marquee dropped, stats band corrected.

**HAN's ruling:** drop the marquee, fix the stats band.

### 1. Marquee — dropped

No change to the demo; it never had one. Recorded as settled so it does not resurface when
the Astro port is scoped. For the record, what is being dropped: a 122px band between the
hero and section 01, looping six product terms — **strike zone · microdose · match tier ·
readiness · one fatigue budget · go / modify / hold** — in Instrument Sans at ~32px,
separated by 3×12px travertine ticks, with a `PAUSE` toggle. Track `aria-hidden`, sr-only
sentence behind it. Capture kept at `shots/live-marquee.png`. The port must also drop
`VocabMarquee.astro` and the `marquee` block in the three locale files.

### 2. Stats band — one figure kept, one claim removed

Final: **1,324 · exercises in the movement bank** / **1 · readiness, scored every morning**
/ **28 · days of load behind every ratio**.

The middle figure was already the kit's and stays: "1" is a count that agrees with its
label, where live's "82" is a sample score wearing a counting label.

The third one was the real finding. Checking whether 7 or 28 was correct showed **the app
has no forecast**, and its source is explicitly fenced against implying one:

```
Athlete.swift:28              "ONE optional date — no recurrence, no forecasting"
TodayVerdictEngine.swift:30   "ADR-0002 — one date, one rule, NO trajectory math"
CrossModalFatigueEngine:21    "It NEVER forecasts"
Views/Workload/               two files, no projection in either
```

7 and 28 are the two *history* windows the ratio is built from — verified in
`WorkloadCalculator.swift`: `ctlLambda = 1.0 / 28.0`, and the rolling path takes
`suffix(7)/7` against `suffix(28)/28`. So 28 is a real, checkable number; "forecast" was
the wrong noun for it. New label states what the number is without claiming a capability
the build refuses to have.

### 3. Filed for the website lane — not this demo's to fix

**`statsBand.labels[2]` on tuwa.app says "days of load forecast" today**, in
`src/i18n/locales/{en,zh,fr}/home.ts`. The app does not forecast and is fenced against
implying it, so the live line claims a capability the product deliberately refuses. Three
locale strings, no code. It should not wait on the homepage rebuild — routing it to
whoever holds the website lane is the orchestrator's call.

Note the adjacency: this is the same failure mode section 05 is built to avoid. Worth
sweeping the rest of the live copy for forward-looking claims — `showcase.steps[2]` and
`zoneScrub` both say load is "heading" somewhere, which reads as projection. I have not
audited those; flagging, not asserting.

### Verification (round 3)

```
stats band DOM : ["1,324 — EXERCISES IN THE MOVEMENT BANK",
                  "1 — READINESS, SCORED EVERY MORNING",
                  "28 — DAYS OF LOAD BEHIND EVERY RATIO"]
marquee present: false
compare.html   : 0 broken images · pageerrors []
demo captures  : all 15 + full page re-taken · pageerrors []
```

### Git (round 3)

Still **zero commits, zero pushes, nothing staged.**

---

---

## 2026-08-01 — round 4. Logging restored, methodology tone made plain.

**HAN's ruling:** logging gets its own section; section 05's length is good and the tables
stay, but the tone should be more concise and easier to understand.

### 1. Logging — restored as section 04

Live's heading and body, word for word. **Not** a second fan — two fanned sections back to
back would read as one repeated trick — so it is a flat three-up row on a surface band,
each screen captioned in the annotation voice: find the movement → start the session →
the record keeps itself.

The fan (now 03) hands back the movement-bank sentence and keeps only what it shows:
recovery, today's decision, and the set you are in the middle of.

Caught while checking the assets: I had captioned the middle plate "log the set", but
`active-workout.png` is the **session-setup** screen, not set entry. Caption changed to
match the screen. Showing live set entry there needs a new app capture, not a copy change.

**Renumbering:** recovery 04→05, methodology 05→06, privacy 06→07. Nav gained a Logging
link. `compare.html` rows renumbered 01–11 with the new row 05.

### 2. Section 06 — same structure, plain language

Length unchanged, both tables kept. The rewrite replaced jargon with the meaning it was
carrying:

| Was | Now |
|---|---|
| profiles | situations |
| state vector | what it reads |
| weight deltas / clamped / renormalised | what it nudges, within fixed limits |
| falsification test | what would change our mind |
| HYPOTHESIS · H-03 | a guess (H-03) |
| "What moves, when, and how well we can defend it" | "What changes, and how sure we are" |
| "Every unproven assumption … its own kill switch" | "Every guess, written down with the test that kills it" |

The four sources now lead with what each establishes in one sentence, then the citation.
The reason tree became four plain questions. Table cells were cut roughly a third.

**Nothing was softened.** Still on the page, in plainer words: not in the shipping app; no
performance or accuracy claim; nothing here is finished or proven; not a medical device;
does not diagnose, treat or prevent injury. H-03 still states the only direct test found
nothing. H-10 still states it has no study behind it, only our judgement.

### Verification (round 4)

```
sections     : 01 TODAY · 02 TRAINING LOAD · 03 THE SYSTEM · 04 LOGGING ·
               05 RECOVERY · 06 METHODOLOGY · 07 PRIVACY
overflow     : 390 ok · 768 ok · 1280 ok · 1600 ok   (scrollWidth == clientWidth)
broken images: 0 at every width · pageerrors [] at every width
reduced      : {"motion":false,"score":"82","dash":"0px","logCapOp":"1"}
compare.html : 0 broken images · pageerrors []
```

Captures renumbered to match the sections: 16 demo shots + full page. `demo-05-logging.png`
is new.

### Git (round 4)

Still **zero commits, zero pushes, nothing staged.**

---

**Next step is HAN's**: one item still open — whether the sleep-hue weight bars read as a
chart series (as now) or a plane fill (which would make them ink). Then further refinements
or approval so the Astro port can be scoped as a separate brief. Also still queued for the
website lane, independent of this demo: the "days of load forecast" string live on
tuwa.app. No repo work proceeds until then.
