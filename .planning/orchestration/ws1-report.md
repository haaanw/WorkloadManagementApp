# WS1 · Interaction Fabric + Console Tab Bar — Report

Date: 2026-07-20. Worker: WS1 (canonical checkout, no branch, uncommitted per Coordination rule 1).
Build: **BUILD SUCCEEDED** (sim `8E872500-703D-4292-9758-38ADFCCFB126`, `~/.tonus-dd`). Waited for a concurrent build to clear before building (rule 2). Did NOT run `xcodebuild test` (orchestrator runs the gate).

## Files touched (all within the WS1 ownership row)
- `WorkloadApp/Components/CardStyle.swift` — Motion tokens, Key/Row button styles, DialValueCell, haptic policy, toggle-flip haptic.
- `WorkloadApp/Components/TickScale.swift` — opt-in detents + sweep-policy doc.
- `WorkloadApp/Components/InkTabBar.swift` — Console restyle.
- `DESIGN.md` — v4.1 amendment (Console spec, Five-Primitive Interaction Law, rule 12, decisions row).
- `WorkloadAppTests/DesignSystemFenceTests.swift` — new `test_tickSpring_overshootReservedForTabTick` fence.

No other files edited. `FontTokens.xcstrings/pbxproj` untouched.

## What shipped, by handoff item

### 1. DESIGN.md v4.1 amendment
- New **"The Five-Primitive Interaction Law (v4.1)"** section with the D13 adjustments baked in: Key (0.97 + brighten, 120ms), Row (6% ink well, ~110ms, no scale), Detent control (mechanical snap; ~100ms subtle digit-roll; **fixed-width value cells**; haptics ONLY at min/max limits + toggle flips + Home hero band detents), Needle (sweep only on load/re-measure; current→new, **never via zero**; opt-in Home-only detents), Surface (one-unit entrance, **no content stagger**).
- Rewrote the **Tab bar → Console** subsection; added Implementation Rule 12; added a decisions-log row; stamped the header as amended v4.1.

### 2. CardStyle.swift
- **Motion tokens:** `rowWell` (110ms), `digitRoll` (100ms), and `tickSpring` — the ONE sanctioned overshoot curve `timingCurve(0.3, 1.15, 0.4, 1, 220ms)`, documented as tab-tick-only.
- **Key:** extended `PressableButtonStyle` with `pressedBrightness` and a `.key` convenience (scale 0.97 + brighten, no dim) — the ink-filled key lights under the finger. Applied `.key` to `PrimaryActionButton`.
- **Row:** new `RowWellButtonStyle` + `.rowWell` / `.rowWell(cornerRadius:)` — background well on press, no scale, `CornerTokens.control` clip.
- **DialValueCell:** fixed-width dial reading (hidden `widthTemplate` reserves the widest reading; live value drawn over it, right/center-aligned; `.contentTransition(.numericText())` on `digitRoll`; `rolls:` toggle; a11y = the reading). Satisfies D13(c).
- **Haptic policy (D13a):** added `Haptics.limit()` (min/max bump); rewrote the `Haptics` doc to encode the reduced policy (silent steps; haptic only at limits + toggle flips + Home band detents); added the sanctioned `Haptics.tap()` to `DesignToggleStyle`'s flip.

### 3. InkTabBar → Console
- Labels: **11pt Medium `keyLabel`, title-case** (removed `.textCase(.uppercase)`), modest ~0.13em tracking (Latin only; zh → 0). Unselected raised from `--disabled` to `--text-3`; selected `--text-1`.
- **Sliding well** (`text1`@5%, `CornerTokens.control` plate, inset off bar edges) via `matchedGeometryEffect(id:"ink.tab.well")`, sliding on the container's `Motion.state`.
- **Springy red tick** above the active label via `matchedGeometryEffect(id:"ink.tab.tick")` with its own `Motion.tickSpring` transaction (overshoot), tick width 36→38.
- **Per-item press-down 0.94** via `.pressable(scale: 0.94, opacity: 1)`.
- Architecture, mount, and all a11y IDs (`tabbar.ink`, `tab.*`) unchanged. Glyph variant retired (text-only per D12); `Item.glyph` field retained for source compat, unrendered.

**Weight-shift judgment call (documented in DESIGN.md + InkTabBar doc):** D12's mock selects at font-weight 600, but General Sans is Regular/Medium-only and DESIGN.md bans bold — a same-size 500→600 bump is fake-bolding. Selection is therefore carried by color step + sliding well + springy tick (the handoff's sanctioned "color+size, not fake bolding" path). A literal within-law Regular→Medium shift would need an **11pt-Regular tab token in FontTokens.swift** (not in WS1's ownership) — noted below for the orchestrator.

### 4. TickScale sweep policy
- Added `detents: Bool = false` — detent haptics are now **opt-in, default off** (D13). `trackDetents()` and the generator warm-up are gated on it. Verdict microscale (TodayVerdictCard) and Load ACWR (WorkloadView) now render silently, as required.
- Documented the sweep policy on the type: the needle is a pure `Animatable` function of `value`, so changes interpolate **current→new directly, never via zero**; sweep-from-zero is a call-site initial-state concern only.
- **Verified the "never returns to zero" invariant** (handoff item 4): `DashboardView.updateDisplayedScore(to:)` sets `displayedScore = score` inside `withAnimation(Motion.scoreCountUp)` — it never re-seeds to 0. Initial appearance animates 0→score (sanctioned); re-loads animate current→new; tab revisits keep `@State` so no re-sweep. `TickScale` itself holds no zero-reset path. **Clean — no fix needed in the count-up logic.**

### 5. Fences
- Added `test_tickSpring_overshootReservedForTabTick` — asserts `Motion.tickSpring` is referenced only by CardStyle.swift (def) + InkTabBar.swift (use). The existing `.timingCurve(`/`.spring(` fence already confines the overshoot *literal* to CardStyle.
- The fixed-width dial-cell rule is not reliably grep-checkable → documented in DESIGN.md (rule 12 + Detent primitive) rather than fenced.
- Self-audited all fences against my diffs: Corner/Shadow/Color/Font/Panel/Spacing/Motion all pass (new curve literal lives inside CardStyle; all call-site animations reference `Motion.*`; `.padding` uses tokens only).

## Verification artifacts (`/tmp/ws1/`)
- `02-home.png`, `crop-bar.png` — Home: Console bar, well + red tick above **Home**.
- `c-recovery-bar.png`, `recovery-full.png` (Log), plus mid-walk stills — well + tick correctly slid to **Log** and **Recovery** (confirms the slide tracks each tab).
- `ws1-fabric.mp4` (14s) — tab walk (well + springy tick sliding) + a held START SESSION Key press. Frame extract `press-sheet.png`: the key is **visibly brighter** during the held press (Key brighten confirmed).

## Deferrals / required follow-ups for the orchestrator
1. **Home hero detents (WS2 / DashboardView — REQUIRED):** now that `TickScale` detents default OFF, the Home hero count-up no longer clicks at band crossings. The Home hero call at `WorkloadApp/Views/Dashboard/DashboardView.swift:398` (`TickScale(... theme: .panel ...)`) must add **`detents: true`** to restore its sanctioned band detents (D13: Home hero is the ONE place detents fire). One-line change; owned by WS2's file, so not made here.
2. **Optional 11pt-Regular tab token (FontTokens.swift):** to realize a literal within-law weight shift on tab select, add an 11pt Regular token and use it for unselected labels. Not required — the color+well+tick selection grammar is complete without it. FontTokens is unowned by any WS; flagged for the orchestrator.
3. **Adoption of the new primitives (WS2/WS3):** `RowWellButtonStyle` (`.rowWell`) and `DialValueCell` are delivered but not yet adopted by any view (WS2 layout / WS3 controls own the call sites). The demo `§2` is their spec.
