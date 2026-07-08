# CODEX-E — Website copy-fix: retire the non-cross-modal inflation

**Run in the WEBSITE repo** (`~/Desktop/tuwa-website`, branch `beachhead-reposition`). The authoritative findings are already there: `.planning/CLAIM-AUDIT.md`.

## Ground rules
- **RUN NO GIT COMMANDS AT ALL** (status/diff/add/commit/reset). The orchestrator owns git.
- Do NOT read `~/.claude/`, `.claude/skills/`, `agents/`.
- Edit website copy only (`src/i18n/locales/`, `src/pages/`, `src/data/seoGeoPages.ts`, `src/content/blog/`). Keep structure/design/components; this is copy, not redesign. Fix BOTH en and zh-Hans where a claim has a zh twin.

## What changed since the audit (IMPORTANT — do NOT touch these)
Decision (a) was taken: **cross-modal now DRIVES the verdict** (`CrossModalShadowGate.crossModalDrivesVerdict` defaults true as of 2026-07-08). So every claim the audit marked INFLATED *for the cross-modal reason* — "last night's game hammered your legs, today's squat is down, bench is fine", "legs down, bench still fine", game→lift carryover — is now **TRUE. KEEP those claims as-is.** Do not soften cross-modal copy.

## Fix everything else the audit flagged (the non-cross-modal inflation)
Work from `.planning/CLAIM-AUDIT.md`. Apply the audit's "Recommended action" for each NON-cross-modal INFLATED / DORMANT row:
1. **Match tier as verdict driver** → soften to "match **proximity**" wherever copy says match *tier* moves the verdict/readiness/intensity band. Keep "match tier (pickup/scrimmage/match) is logged context" where it's not claimed to drive the verdict. (home.ts, compare.ts, coaching.ts, recovery-scoring.ts, for-coaches.ts)
2. **Cold-start "population-level baselines / actionable guidance from day one / confidence intervals narrow"** → rewrite around what ships (questionnaire-seeded workload profile; the verdict DEFERS rather than trimming on a guess; neutral 50 when no data). Cut the confidence-interval and population-baseline language. (cold-start.ts/.astro, readiness-score.ts, methodology.ts, support.ts)
3. **NFC coach invite** → cut. App uses athlete-code + coach-email invite, no NFC. (support.ts)
4. **Body temperature in the readiness score** → cut (or explicitly say collected-where-available but NOT part of the score). Score weights only HRV, resting HR, sleep, wellness. (support.ts)
5. **"Detects load spikes before you execute the session" / planned-session spike** → soften to "recent workload context is shown before training." Spike flags are computed AFTER a workout saves; no planned-session simulation ships. (training-load.ts, methodology.ts, support.ts)
6. **"push, maintain, reduce, swap, or recover" as app output** → align to the shipped **go / modify / hold** verdict. Keep the richer verbs only if clearly labeled as the standalone website calculator, not app output. (blog mdx, seoGeoPages.ts)
7. **Coach "unlink at any time" / "coaches log workouts on behalf of athletes"** → the shell DOES still surface coach mode/roster/invite/prescribe (audit line 5), but unlink UI and log-on-behalf are NOT surfaced. Rewrite these two as policy/future capability, not current app behavior. (privacy, terms)
8. Sweep the rest of `.planning/CLAIM-AUDIT.md` for any other non-cross-modal INFLATED/DORMANT row and apply its recommended action.

## Verify + report
Run the site build (`npm run build` or the repo's documented command) — must pass (Astro builds all pages). Report: each claim fixed (file:line, old→new gist), which cross-modal claims you deliberately KEPT, build result, anything ambiguous you left for human review.
