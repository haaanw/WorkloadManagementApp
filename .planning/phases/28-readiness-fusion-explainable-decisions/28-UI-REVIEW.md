# Phase 28 — Dual-Run "Method Updated" Surface — UI Visual Review

**Date:** 2026-05-31 · **Reviewer:** Claude (driven visual review on iPhone 17 Pro Max sim, iOS 26.1)
**Verdict:** PASS — DESIGN.md compliant, placement sensible, copy correct. Provisional placement endorsed; no blocking issues.

## How it was reviewed
`PRSActivation` has no launch-arg hook (test-only override), so the live card can't be shown via a flag flip.
Captured by a THROWAWAY render: forced `PRSDualRunCard` with a representative `DualRunMessage` under a
`PRS_UIREVIEW` launch arg in SCREENSHOT_MODE, installed the fresh Debug build on the sim, screenshotted the
Dashboard, then reverted both throwaway edits (DashboardView + ScreenshotTests — working tree clean, only the
real flag-gated mount `560a194` remains). Screenshot: `/tmp/prs-dashboard2.png` (session-local).

Note: the headline strings ("Maintain…", "Reduce volume ~20%…") were illustrative sample text. In production
they come from the real `AutoregulationEngine.TrainingRecommendation.headline` (legacy vs readiness×strain).

## Rendered result
Card sits directly below the hero readiness block (42 + metrics + "Moderate Training OK"), above the
Training-Profile card. Layout:
- Title: "Recommendation method updated"
- One-line explanation (honest "method updated" framing, names Tuwa)
- Two columns separated by a vertical hairline: **Previous** | **Updated**

## DESIGN.md checklist
| Constraint | Result |
|---|---|
| 0pt corners (Rectangle, never RoundedRectangle) | PASS — square corners, `Rectangle().stroke` border |
| No shadows (hairline borders) | PASS — top/bottom/column hairlines, no shadow |
| Accent only on hero readiness number | PASS — card uses text1/text2/divider/surface only, no accent |
| General Sans (Font.Tokens.*) | PASS — label/smallLabel/body tokens |
| 8pt-grid spacing | PASS — padding 16, spacing 8/16 |
| Zone via text, not color alone | PASS — informational text; guidance is words |
| Dark + light via ColorTokens | PASS (light verified; dark inferred — all semantic tokens) |
| "Tuwa" name, never "injury prediction" | PASS — "Tuwa now reads…"; no injury-prediction copy |

## Observations (optional polish, non-blocking)
1. Text-dense block immediately under the hero; the two-column full-sentence headlines run long. Could tighten
   the recommendation headlines or shorten the explanation for faster scanning. Taste call.
2. Consider a touch more vertical breathing room between the hero block and the card (currently VStack spacing 0
   + the card's own 16pt padding). Minor.
3. Placement directly after the current recommendation ("Moderate Training OK") reads well — it explains the
   recommendation the user just saw. Recommend KEEPING this placement.

## Status
Provisional placement endorsed. Card renders only when `PRSActivation.isEnabled` (default FALSE → EmptyView →
Dashboard byte-identical, fence-locked). The "autonomous:false" human visual-review checkpoint is now satisfied.
Nothing activated; flags FALSE; not pushed.
