# Website update brief — v1.7.2 ships voice logging (2026-08-24)

App version 1.7.2 (20) is submitted. The site (`tuwa-website/`, live at
tuwa.app, deployed on push to origin/main) does not mention the release's
flagship feature anywhere. Ownership note: `tuwa-website/` is the CODEX lane
per `.pair/PROTOCOL.md` §4; a CLAUDE session executing this brief must CLAIM
the touched paths on the pair board first (precedent C-007 / C-fn17e-001).

## The work, ranked

1. **Voice logging on the homepage.** The logging section (§04) still shows
   only manual set entry. Add the "say the session" story: speak, type, or
   dictate → editable draft → confirm. en + zh + fr. The feature is SHIPPED
   and free on every tier, so full present-tense claims are sanctioned (§10).
   Never frame it as a chat/AI-coach UI — the LLM is a parsing engine
   (CONTEXT.md anti-positioning).
2. **A voice-logging feature page** (`features/` has five pages; none covers
   logging). Follow the existing feature-page pattern + locale modules ×3.
   Reference copy: `.planning/asc/v172-draft/4-description-en.txt` "SAY THE
   SESSION" block and the What's New files (6/7).
3. **Privacy page: disclose LLM parsing.** New in 1.7.2: the workout
   narrative TEXT the athlete submits is sent to the parse-workout backend
   and processed by a third-party LLM (DeepSeek) to produce the draft;
   JWT-gated, daily-quota'd. The privacy page must say this. Raw health data
   still never leaves the device — keep that claim intact and separate.
4. **The two standing App-Review-path gaps (C-fn17-005, still open):** the
   privacy page lacks the Data Sharing section that `docs/privacy.html`
   carries, and the support page lacks an account-deletion answer (App
   Review 5.1.1(v)). Port both, en/zh/fr, bump `lastUpdated` (also hardcoded
   at `src/pages/privacy.astro:4`).
5. **All app-UI depictions site-wide, not only set entry (HAN 2026-08-24).**
   Audit every place the site renders the app — coded plates, mockups, any
   real screenshots on homepage/feature pages/OG cards — and bring them to
   the shipped 1.7.2 UI: the always-visible scrub scale with TARGET and
   LAST markers, the voice capture sheet. Fresh framed 1.7.2 store sets
   exist at `appstore screenshots/1.7-{en,zh-Hans}/framed/` as reference.
6. **A voice-logging row on `compare.astro` — REQUIRED (HAN 2026-08-24).**
   Voice logging is a distribution highlight; the compare page is where it
   lands hardest (no listed competitor parses a spoken narrative into an
   editable draft — verify each cell claim against the competitor's shipped
   product before stating it).

## Constraints (standing site law)

- No CDN references — every asset self-hosted.
- §10 claim rails: sleep-score v2 and estimator v2 are UNSHIPPED — nothing
  outward about them. Voice logging is shipped — full claims fine.
- Vocabulary: 准备度 site-wide; never "hybrid athlete"; app name Tuwa only.
- Legal routes (`/terms`, `/privacy`, `/support`, + zh/fr) are in App
  Review's path — content edits above are sanctioned, but verify the routes
  still 200 and the EULA-cited URLs stay stable.
- Verification: `npm run build` (66 pages ± the new feature page ×3),
  `npx astro check` 0/0/0, the Playwright suite green, zero off-host
  requests. Commit locally; NO push — tuwa.app deploys on push and HAN
  gates it.
