# Stage 3″ Brief — Motion Pass (mechanical, crisp, Emil framework)

Lane contract for the v4 Stage 3 worker. Orchestrator verifies + commits. Prerequisites: Stages 0″/1″/2″ committed. Read `.planning/orchestration/2026-07-20-v4-instrument.md` (motion law) + DESIGN.md v4 Motion section + the two skill files at `/tmp/ek-skills/skills/improve-animations/SKILL.md` and `/tmp/ek-skills/skills/review-animations/STANDARDS.md` if present (if /tmp was cleaned, `git clone --depth 1 https://github.com/emilkowalski/skills /tmp/ek-skills`).

## Direction
v2's motion was "calm with life" (gentle springs). v4 is a precision instrument: crisp, mechanical, fast. Emil's laws (now in DESIGN.md): strong ease-out `cubic-bezier(0.23,1,0.32,1)` ≈ SwiftUI `.timingCurve(0.23,1,0.32,1,duration:)`; press 100–160ms; UI transitions 150–250ms; NEVER >300ms; no ease-in; stagger 30–80ms; springs ONLY for gesture/momentum (damping ≈1.0); frequent actions ≈ instant.

## Work items
1. **Motion token retune** (CardStyle.swift ONLY — the animation-literal fence): `state` → timingCurve strong-ease-out 0.18s; `entrance` → 0.24s same curve (no spring); `screen` → 0.20s; `exit` → easeOut 0.15s (never ease-in); `scoreCountUp` → 0.35s easeOut; `staggerStep` 0.05 → 0.04, cap unchanged; keep `resolved(_:reduceMotion:)` + aliases. PressableButtonStyle: press scale 0.97, 120ms curve. Document each with the law reference.
2. **Needle motion**: TickScale needle position changes animate via `Motion.state` (mechanical snap-settle, no overshoot) — verify count-up sweep on Home reads instrument-like; add `Haptics.select` detent when the needle crosses a zone-band boundary during count-up (fire max once per crossing; reduceMotion: no sweep, still settle value).
3. **Tab switches are frequent** (Emil: reduce drastically): tabCrossfade 0.28→0.15s or opacity-only near-instant; tick matchedGeometry keeps `Motion.state` (now 0.18 curve).
4. **KeyRow/press coverage**: every key cell + all restyled buttons get pressable 0.97/120ms; verify no dead-feeling controls remain on the 5 tabs (hunt with the improve-animations checklist).
5. **Sheet/transition audit**: route crossfade, sheet presentations, disclosure expands, segmented switches, filter rail underline slide — all through retuned tokens; kill any remaining >300ms or default-spring paths outside CardStyle (fence: literals only in CardStyle.swift — migrate strays to tokens).
6. **Reduced Motion audit**: every new/changed path flows through `Motion.resolved` or equivalent; needle sweeps degrade to settle.

## Verify (you MUST)
Build; SCREENSHOT_MODE sim; record video: Dashboard load (count-up needle sweep) + full tab walk + verdict accept flow via `xcrun simctl io ... recordVideo` (SIGINT to stop) + axe taps. Watch it: no snaps, no floatiness, nothing >300ms. Report video path(s). Screenshots insufficient for this lane.

## Hard constraints
- NO git. NO `xcodebuild test` (build only). AppShell/xcstrings untouched. Animation literals ONLY in CardStyle.swift (fence). No new springs outside gesture contexts. Haptics: prepare() before first fire; no haptic spam (detents only on boundary crossings).
- Behavior unchanged: same actions, same navigation.

## Deliverable
Report: token table before→after; every migrated literal (file → token); detent implementation; RM audit result; video paths; verbatim build tail; deferrals.
