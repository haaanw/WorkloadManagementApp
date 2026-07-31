# Handing off "Field Notes" (v6)

How to take this design system into production. The single source of truth is this project: `styles.css` → `tokens/`, `readme.md` (rules), `SKILL.md` (agent entry), `guidelines/` (spec cards), `components/` (React reference primitives), `ui_kits/` (full-screen references incl. the web motion layer).

## Part 1a — iOS app (Tonus/WorkloadApp, SwiftUI)

The app is already on v5 "Pavilion"; v6 is an overlay, not a rebuild. Order of work:

1. **Tokens first.** Port `tokens/colors.css` into the asset catalog / a `DS.Color` namespace — the five metric hues and re-tuned zone colors are the actual change; stone planes and ink ramp are mostly identical to v5. `Components/CardStyle.swift` is the chokepoint: update it and most surfaces follow.
2. **Fragment Mono annotation layer.** Bundle the TTF (check license for app embedding), add a `DS.Font.anno` style (≤12pt, uppercase, tracking +0.05em), then introduce marginalia surface-by-surface: units, deltas, timestamps, axis labels, reason trees (`├─ └─`). This is the visible v6 signature.
3. **Metric hue adoption.** Each chart/dot/hero reading takes its metric's hue. Zone states stay label-first (nocebo guard unchanged).
4. **Annotation choreography.** Mono labels fade in 40ms-staggered after the surface settles; keep the existing non-bouncy spring grammar.
5. **Guard it.** Extend `DesignSystemFenceTests.swift` with the new tokens (metric hues, anno size cap) so regressions fail CI.

## Part 1b — Website (Tonus/tuwa-website, Astro)

1. **Tokens.** Replace the custom-property block in `src/styles/global.css` with `tokens/*.css` values (names map 1:1 by intent). Fragment Mono is already **self-hosted** — `tokens/fonts.css` declares an `@font-face` pointing at `assets/fonts/FragmentMono-Regular.ttf` (SIL OFL 1.1, licence beside the file). The Google Fonts `@import` that used to sit there was removed 2026-07-31 because it broke the no-CDN law; copy the TTF into the site's own `public/fonts/` and rewrite the `src:` URL — **do not restore the `@import`**.
2. **Homepage.** `ui_kits/website/index.html` is the reference build; `motion.js` maps scene-for-scene onto your existing `homeMotion.ts` (hero scrub, showcase, zone scrub, fans, ghosts already exist there — the self-drawing chart in section 04 is the one new scene to add). Lottie/Lenis: keep as-is on the site; assessed here as nice-to-have.
3. **Alpino** stays marketing-only; wire `--font-display` and the display ramp from `tokens/typography.css`.

**Fastest path for both:** point Claude Code (or any agent) at this project folder and say "read SKILL.md and apply Field Notes to <target>". The skill file routes it to the readme, tokens, and references.

## Part 2 — Beyond app & website

- **App Store screenshots** — restyle the `scripts/frame_screenshots.swift` pipeline output with Field Notes framing + mono annotations (you localize en/zh already).
- **Pitch/investor decks** — `templates/pitch-deck` is ready; swap placeholder market figures.
- **Docs pages** (`docs/privacy.html`, support, terms) — apply tokens + type ramp for brand continuity.
- **OG / social images** (`public/og/*`) — **DONE (2026-07-31)**. `templates/og/generate_og.py` renders the four feature cards in en/zh/fr at 1200×630, deterministic and offline (fonts read from the repo). Remaining: the zh/fr `ogImage` props in `tuwa-website/src/pages/{zh,fr}/features/*.astro` still point at the English cards, and `og-default.png` is not yet regenerated.
- **Transactional email** (receipts, onboarding) — **DONE (2026-07-31)**: `templates/email/transactional.html`, table-based, all styles inline, no external assets. en only; not localised and not wired to a sender.
- **Product videos / App Store previews** — this is where Remotion actually fits; the motion grammar card defines the timing vocabulary.
- **Future surfaces** — watchOS complications (metric hues + mono numerals are made for this), widgets, blog/MDX article styles.
