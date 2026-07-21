# WS-A · Spring Motion Refit — implementation + proof

Implements DESIGN.md v4.2 "Machined" **D16 (Spring Motion Law)** and **pick 4-A (Press
inverts relief)**. All changes route through the single motion chokepoint, `CardStyle.swift`;
the design fence (`DesignSystemFenceTests`) passed 11/11 after the refit.

## 1. Motion tokens → non-bouncy springs

Every `Motion.*` token moved off fixed timing curves onto `.spring(duration:bounce: 0)` —
critically damped (zero overshoot), interruptible, velocity-preserving (Emil Kowalski's model).
The one helper `Motion.snap(_:)` is the whole law; each token is an instance of it. Premium-fast
band preserved: press attack ~85ms, state ≤250ms, screen ≤300ms, hero count-up ≤400ms.

Two carriers deliberately keep timing curves:
- `tickSpring` — the single sanctioned OVERSHOOT (Console tab tick only; fence-reserved).
- `exit` — removals leave on a fast ease-out (a spring tail on a disappearing view is wasted).

## 2. The dip-crossfade — rebuilt, with frame-extraction proof

**Before:** `TabCrossfadeModifier` set `contentOpacity = 0` then animated back to 1 — the
incoming tab passed through *full invisibility*, producing a one-frame empty-background flash.

**After (D16 layered handoff):** on becoming selected the incoming content lands a pre-handoff
state — opacity `handoffFloor = 0.5` (a VISIBLE floor, never 0) + a `riseOffset = 6pt` rise — in
one update cycle, then springs to rest (`Motion.tabSwitch`) in the next. The floor guarantees
every rendered frame shows substantial content; the incoming rises into place *over* the
outgoing rather than blinking in from black.

### Proof (`ws-a-crossfade-proof.png`)

Recorded the running app (SCREENSHOT_MODE) switching across all five tabs — 8 transitions, 925
frames at ~34fps — and analyzed every frame's content region (rows 16–90% of height, excluding
status bar + tab bar) with two independent, threshold-free metrics:

| metric | blank value | measured minimum across 925 frames |
|---|---|---|
| dark-pixel fraction (`lum < 200`) | ~0% | **3.16%** |
| mean deviation from background (`mean\|lum−232\|`) | 0.0 | **8.54** |

**Frames below any blank threshold (<2% / <2.0): 0.** The lowest-signal frames are simply the
sparse Profile/Recovery screens *fully rendered*, not transition artifacts.

The montage (`ws-a-crossfade-proof.png`, a Recovery→Dashboard switch) shows the middle frames
with BOTH screens superimposed — the incoming Dashboard fading up over the outgoing Recovery.
The content region is populated in every frame; no empty frame exists.

## 3. Asymmetric press with relief-inversion on keys (pick 4-A)

New `ReliefPressButtonStyle`: pressing INVERTS the key's relief — a dark cut along the top inner
edge + a lit line along the bottom inner edge fade in (surface reads as recessed into a pocket),
the key drops 0.5px, and its face lifts in brightness. Timing is **asymmetric**: fast ~85ms
attack (`Motion.pressIn`) / unhurried ~300ms non-bouncy spring release (`Motion.keyReliefRelease`).
Scale-only key presses are retired. Implemented as a tint-neutral OVERLAY (shade+highlight, no
opaque fill) so it inverts correctly over both aluminum keys and ink CTAs without owning their
resting face. Wired into `KeyRow` cells, `PrimaryActionButton` (ink), `SecondaryActionButton`.

## 4. Rise + stagger entrances

`EntranceRevealModifier` now glides content up `Motion.riseOffset` (6pt) as it fades in on the
non-bouncy `entrance` spring, staggered 40ms/step — replacing the v4 scale-up pop.

## 5. Spring glides on well / tick / needle

Free from the token conversion: the InkTabBar sliding well (`Motion.state`), the TickScale needle
(inherits the call-site `Motion.state` / `Motion.scoreCountUp` transaction), and every state
settle now glide on non-bouncy springs. The tab tick keeps its one sanctioned `tickSpring` throw.
