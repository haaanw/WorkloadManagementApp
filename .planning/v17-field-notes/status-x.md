# Session X — the homepage Astro port

**State: DONE, committed, NOT pushed.**
Branch `homepage-v2` in `tuwa-website`, cut from `main` at `8fc20a6`.
Commits: `1d8ab2a` (the port — 21 files, +1613 / −647) and `dab0cdd`
(the 准备度 rename — 15 files).
`main` is untouched. tuwa.app deploys on push; HAN gates that.

**HAN's rulings, 2026-08-01 — all applied:**
- zh/fr copy review: **passed for now.** The strings stand as written; §3 below
  is left in place as the list to review whenever HAN wants it.
- Readiness term: **use 准备度.** Done site-wide, `dab0cdd` — see §7.
- Full sentences in 11px Fragment Mono: **approved.** No change; the §5.5 note
  is now a recorded decision rather than an open question.

Spec: `tuwa-website/.design-explorations/website-v2-demo/` (`index.html` +
`motion.js` + `compare.html` rows 01–11). Where demo and live site disagreed,
the demo won — with three stated exceptions in §4 below.

---

## 1. What shipped

Section contract, in order:

| # | Section | Component | Notes |
|---|---|---|---|
| — | Hero | `HomeHero.astro` | **Unpinned.** Reading counts 0→82 once on load; needle rises with it |
| 01 | Today | `StickyShowcase.astro` | Pinned; kicker + heading + body + 3 steps on screen the whole pin |
| 02 | Training load | `StrikeZoneScrub.astro` | Pinned; one card on a surface band, no phone; 0.0–2.0 axis |
| 03 | The system | `SystemFan.astro` | **New.** The fan, ±10° / ±240px, 640px tall |
| 04 | Logging | `LoggingRow.astro` | Flat three-up row, annotation captions |
| — | Stats band | `StatsBand.astro` | Figures corrected to **1,324 / 1 / 28** |
| 05 | Recovery | `RecoverySpark.astro` | Self-drawing chart; heading and body above the card |
| 06 | Methodology | `MethodologySection.astro` | **New.** ~180 lines of new copy × 3 locales |
| — | Ghost band | `GhostQuote.astro` | **New.** 82 / 1.23 / 62MS at 5% ink, −0.08 parallax |
| 07 | Privacy | `PrivacyClose.astro` | Reason-tree marginalia + plate + badge |

Renames (git-tracked, history preserved): `HeroScrub → HomeHero`,
`LoggingFan → LoggingRow`, `RecoveryQuote → RecoverySpark`.
Deleted: `VocabMarquee.astro` + the `marquee` block in all three locale files.

`src/pages/index.astro`, `src/pages/zh/index.astro` and `src/pages/fr/index.astro`
were all rebuilt — the zh and fr homepages are separate pages and would
otherwise have kept importing deleted components.

---

## 2. Verification — real outputs

```
npx astro check      Result (149 files): 0 errors, 0 warnings, 0 hints
npx tsc --noEmit     TypeScript compilation completed   (exit 0)
npm run build        66 page(s) built in 1.83s          (66 before, 66 after)
```

Playwright (system Chrome via `channel: 'chrome'` — the local Playwright cache
has builds 1194/1228 and playwright 1.62.1 wants 1234, so no bundled binary
matched; same engine, real browser):

```
69 passed / 0 failed
```

Covering, per locale (en/zh/fr) × width (390 / 768 / 1280 / 1600), after
scripted full-page scroll so every observed scene runs:

- zero horizontal overflow — 12/12
- zero broken images — 12/12 (images the layout does not render are excluded;
  the fan's outer two plates are `display:none` below 880px by design)
- zero pageerrors — 12/12
- zero failed requests — 12/12

Plus, once each:

- section contract: `#top #today #zone #system #logging #recovery #method #get` all present
- marquee gone
- stats figures are `1324 / 1 / 28`
- hero reading settles on `82`, needle at `82%`
- **reduced motion**: no residual transforms, no forced pin heights, pins are
  `static`, hero reads 82, counters at final value, nothing stuck at opacity 0,
  zero pageerrors
- **no-JS**: hero reads 82, nothing stuck hidden
- **no-CDN law**: zero off-host requests

Note on the reduced-motion assertion: this site always sets `html.motion` in
`BaseLayout.astro` and honours reduced motion through the
`prefers-reduced-motion` CSS block plus the `RM` guard in `homeMotion.ts` —
unlike the standalone demo, which withholds the class. I assert the *effect*,
not the class. That is the site's pre-existing contract; `BaseLayout` was not
touched.

Visual QA: 18 screenshots at 1280×900, 390×844 and zh 1280 were reviewed
against the demo's `shots/` frame by frame. Two fidelity gaps were found this
way and fixed (logging plate size, the missing `NOW` prefix) — neither was
caught by any automated assertion.

---

## 3. NEW zh / fr COPY — review PASSED by HAN for now

Kept as the standing list for whenever a review does happen. Nothing here is
blocking.

Everything below is new this session. The English is the locked demo text; zh
and fr are mine.

**§10 claim rails — the load-bearing ones.** These must carry the same meaning
in every locale, and no claim may be stronger in translation:

| en | zh | fr |
|---|---|---|
| status: design · not in the shipping app | 状态：设计中 · 尚未进入已上架的 App | statut : conception · pas dans l'app publiée |
| no performance or accuracy claim is made here | 此处不作任何效果或准确性承诺 | aucune promesse de performance ni de précision n'est faite ici |
| tuwa is a training tool, not a medical device | tuwa 是训练工具，不是医疗器械 | tuwa est un outil d'entraînement, pas un dispositif médical |
| it does not diagnose, treat, or prevent injury | 它不诊断、不治疗，也不预防损伤 | il ne diagnostique pas, ne traite pas et ne prévient pas les blessures |
| nothing here is finished, and nothing here is proven | 这里没有一项已经完成，也没有一项已被证明 | rien ici n'est terminé, et rien ici n'est prouvé |
| the sources below say what each paper found — nothing more | 下面的来源只说明每篇论文发现了什么——仅此而已 | les sources ci-dessous disent ce que chaque article a trouvé — rien de plus |
| a guess | 一个猜测 | une supposition |
| backed | 有依据 | étayé |

**Two word choices I want checked specifically:**

1. **fr "guess".** The English deliberately uses the plain word *guess*, not
   *hypothesis*. I chose **supposition** over *hypothèse* to keep it plain. If
   that reads as too casual for the register, *hypothèse* is the swap — but it
   makes the claim sound more formal, i.e. slightly stronger, which is the
   direction the §10 rails forbid.
2. **zh "已经在用"** for the third intent card's `03 · shipping today`. That
   card is the one true statement in the section (on-device privacy), and the
   label has to read as "this one is real" without implying the rest is.

**Bulk new copy also needing review** (`methodology` block in
`src/i18n/locales/{zh,fr}/home.ts`): the lede, three design-intent cards, the
mechanism paragraph + four-row reason tree, five weight names, the three
situation rows (name / when / change / status / confidence), the four registry
rows (claim / status / test), and the four source citations. Plus, outside
methodology: `system` (03), `logging.captions`, `recovery` heading + `spark.foot`,
`ghostBand`, `heroScrub.strapline`, `zoneScrub.barNow`.

---

## 4. Deliberate deviations from the demo — HAN's call to overrule

**a. Site nav kept; the demo's anchor nav not adopted.**
The demo header carries inline anchor links (Features / Training load / Logging
/ Methodology / Privacy + one pill). The live site's `Header.astro` is a
site-wide wordmark + "Menu" + one ink pill, with full navigation in
`NavDrawer.astro`. Porting the demo's nav would put homepage-only anchors
(`#today`, `#method`) on `/privacy`, `/terms` and ~40 SEO pages, where they
resolve to nothing. `Header.astro` is also outside my claim. **The section IDs
all exist**, so if HAN wants those links, it is a small follow-up — but it needs
a homepage-conditional nav, not the demo's markup.

**b. The `8fc20a6` forecast-claim fix beats the demo's older wording.**
The demo predates that fix and still reads "you see it days before you feel it"
(zone body) and "where it is heading over the coming weeks" (step 3). The app
has no forecast and its engines are explicitly fenced against implying one
(ADR-0002). I kept the live, HAN-authorised strings. Same reasoning extends to
`statsBand`, which DISTRIBUTION.md already told me to port as-is.

**c. Reason trees are flex rows, not one pre-formatted block.**
The demo sets `├─ KEY   VALUE` as `white-space: pre` inside one `<div>`. Column
alignment there depends on the English key lengths, and `pre` forces a
horizontal scrollbar on a phone. Each row is a flex row here, so zh and fr keys
of any length keep the columns and nothing scrolls. Visually identical in en.

---

## 5. Things worth knowing

1. **`src/styles/global.css` was edited.** Unavoidable — the whole homepage
   layout lives in it and there is no per-component style block on this site.
   I checked the blast radius first: `.sec-head`, `.plate`, `.spread`, `.ghost`,
   `.aside`, `.privacy-well`, `.intro-row` and `.sec-alt` are **shared with ~18
   feature pages and `[...seoGeo]`**, so those were left alone and the new
   sections got new class names. Only homepage-only rules were rewritten
   (`.hero-*`, `.show-*`, `.zone-*`, `.stats`, and the deleted `.marquee`/`.mq-*`).
   Verified by grep before touching anything; the claim was amended on the pair
   board (`C-x002`).
2. **One class collision caught during the build**: the demo's `.stat` (a status
   key inside the methodology tables) collides with the stats band's `.stat`
   (the big figure block). The methodology one is `.status-key` here.
3. **The hero CTA is now the App Store badge, not an ink pill**, in both the
   hero and the close — that is the demo. Consequence: the nav pill is the
   page's only ink pill, so the old "hide the nav pill while another ink CTA is
   on screen" logic in `homeMotion.ts` had nothing left to do and was removed.
4. **Terminology divergence, site vs app — RESOLVED**, see §7.
5. **Annotation voice carrying full sentences — APPROVED by HAN 2026-08-01.**
   The demo puts several full sentences into Fragment Mono at 11px (the weights
   note, the H-01 provenance line, the zone foot). DESIGN.md v6 says the
   annotation voice is "never a sentence", and v6.1/v6.2 were readability
   retunes in the opposite direction. HAN approved the demo's treatment, so the
   homepage stands as ported. Recording it as a decision, not a debt: if
   DESIGN.md is ever read strictly against this page, this note is the reason
   the page wins.
6. **Mobile**: below 880px the fan's outer two plates are hidden (as in the
   demo). No screenshot is actually lost — `active-workout` also appears in
   04 Logging and `recovery` in 07 Privacy.
7. Page height 13,904px at 1280 (demo: 11,575px; live before: 11,862px). The
   difference is the methodology section, which is the point of it.

---

## 6. Untouched, as instructed

Legal routes (`/terms`, `/zh/terms`, `/fr/terms`, `/privacy`, `/support`),
`[...seoGeo]`, OG images, `statsBand` label copy, `Header.astro`, `NavDrawer.astro`,
`BaseLayout.astro`, `siteMotion.ts`, `featureMotion.ts`, and the app repo.

CODEX's open content items from C-fn17-005 (the privacy Data-Sharing port and
the support account-deletion FAQ) are untouched and still theirs.

---

## 7. 准备度 — the readiness term, renamed site-wide (`dab0cdd`)

HAN's ruling 2026-08-01: use **准备度**, the term the app settled on in v1.7
(`fbb656b`). The website had said **准备状态** since its zh localization, so the
two surfaces named the same metric differently.

Done site-wide rather than on the homepage alone — a partial rename is exactly
the third-variant problem this fixes.

- **56 occurrences, 14 files**: nine zh locale modules (`home`, `common`,
  `methodology`, `readiness-score`, `recovery-scoring`… ) and five zh feature
  pages under `src/pages/zh/features/`.
- **Only the exact string 准备状态 was replaced.** The nine bare 准备 in the zh
  corpus are the ordinary verb — 「为……准备的」, 「做好准备」, 「准备好时推进」 —
  and were checked in context and left alone.
- **`.planning/milestones/` records left as written.** They document what was
  true when written; rewriting history there would be worse than the drift.
- **One knock-on defect fixed with it.** The zh stats-band label carried the
  measure word 分, which paired with the old figure 82. The port changed that
  figure to 1, and 「1 分准备度」is ungrammatical. The label now reads
  个准备度评分，每天早晨给出 — 「1 个准备度评分」. en and fr have no measure word
  and needed no change.

Verified in the rendered pages, not just the source: hero caption 今日准备度;
stats band 「1 个准备度评分，每天早晨给出」; `/zh/readiness-score/` title
什么是准备度评分？如何使用 — Tuwa. `astro check` 0/0/0, build 66 pages,
Playwright 69/69 after the rename.

**Not touched:** the app repo. `Localizable.xcstrings` already uses 准备度 —
this brought the site to the app, not the other way round.
