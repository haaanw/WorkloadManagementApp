# CODEX-C — App Store copy draft (Track 3, PREP-ONLY)

**Parallel-safe with CODEX-A/B** — this session writes ONLY new markdown under `.planning/store/` (create the directory). Do not touch app code, xcstrings, or anything else. **RUN NO GIT COMMANDS AT ALL** — not status/diff/add/commit/reset; the orchestrator owns git. Just write the files and report their paths. NOTHING here gets published — it's drafted now, published only after the n=1 dogfood gate passes (see `.planning/notes/dogfood-protocol-n1.md`).

## Read first
`CONTEXT.md` (canonical vocabulary — use it verbatim), `docs/adr/0001-basketball-beachhead.md`, `docs/adr/0002-match-proximity-not-forecast.md`, `.planning/notes/v21-basketball-beachhead-plan.md`, `.planning/notes/strike-zone-framing.md`.

## Positioning (canonical)
- Niche: amateur competitive basketball players who also strength-train seriously, self-coached (NEVER say "hybrid athlete").
- Promise: "Stay in your strike zone — every workout." / "Your plan, made safe and optimal."
- Anti-positioning: Whoop/Bevel = scores without your plan; AI-coach apps = their plan not yours; TrainingPeaks = your plan no decisions.
- Flagship story: "Last night's game hammered your legs. Today's squat readiness is down — your bench is fine."
- Tone: calm, precise, athlete-to-athlete. No hype, no AI-slop vocabulary. Suggest-and-confirm — never commanding.

## HONESTY CONSTRAINT (hard)
Claim ONLY what ships: daily go/modify/hold verdict on your planned strength session; adjusted top-set number + one-line reason; game-proximity microdose framing (match ≤48h); cross-modal fatigue (game→legs→squat, spares bench); match tier logging (pickup/scrimmage/match); next-match date; HealthKit HRV/RHR/sleep readiness; your own plan input; felt-right tracking. NO forecasting, NO AI coach, NO team features, NO Android. When unsure whether a feature exists, grep the code or leave it out.

## Deliverables (write to `.planning/store/`)
1. `aso-keywords.md` — keyword research: basketball training niche (game-day freshness, basketball strength training, readiness, load management, strike zone, microdose…), en + zh-Hans keyword fields (100-char App Store keyword string candidates ×3 variants), title/subtitle candidates ×5 (30-char title, 30-char subtitle limits), with rationale + est. competition notes.
2. `store-description.md` — full description draft (en + zh-Hans): hook paragraph, feature bullets (honesty-constrained), the anti-positioning paragraph, closing CTA. Plus promotional text (170 chars) ×3 variants.
3. `screenshot-copy.md` — overlay copy for 6 screenshot frames (en + zh-Hans): (1) verdict card w/ microdose, (2) strike-zone bar, (3) next-match + proximity reason, (4) cross-modal story, (5) readiness/HealthKit, (6) plan-input. One headline (≤6 words) + one subline (≤12 words) each, mapped to which app screen shows it.

## Report
List files written + the single strongest title/subtitle pair with reasoning.
