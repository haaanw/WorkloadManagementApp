# Session B — Dashboard + Recovery lane status

Lane: `Views/Dashboard/`, `Views/Recovery/`. Branch `v1.7-field-notes`. No commits (orchestrator commits).

---

## 2026-07-30T18:5x · **ORCHESTRATOR-RECONSTRUCTED RECORD — not Session B's own report**

**Provenance warning, stated up front so nobody reads this as a lane self-report:** Session B was
killed by a stall watchdog mid-verification and **its transcript was unrecoverable** (`SendMessage`
→ "No transcript found"). C and D were resumed and wrote their own files; B could not be. So this
entry is the orchestrator's reconstruction **from the diff alone**. It therefore cannot state B's
intent, and two things are permanently lost:

- **Which in-scope files B skipped deliberately vs. never reached.** Untouched in B's scope:
  `NotificationPrePermissionCard.swift`, `PRSDualRunCard.swift`, `TrainingProfileCard.swift`,
  `WelcomeActionCard.swift`. Whether these had nothing to adopt or were simply not reached
  **is unknown** and must be re-inspected by whoever picks the lane up, not assumed complete.
- **Any frozen-file request B was holding.** None is recorded; absence of evidence only.

### Cause of death (orchestrator's error, not the lane's)

I instructed all three iOS lanes to run the full `xcodebuild test` suite as their final step. Three
concurrent xcodebuild invocations plus three simulator clones on one machine starved each other past
the 600s stall watchdog. All three died at the same point — B at "let me visually verify on the
simulator before running the suite", C and D at "now the full unit suite". **Fix applied: the
orchestrator runs verification serially, once, centrally; lanes are told not to build.** Wave 3 must
not repeat the concurrent-final-suite pattern.

### What landed (read from `git diff`, 9 files, +199 −119)

**`DashboardView.swift`** (+66 −36)
- Hero readiness reading `accent` → **`metricReadiness`** (Reading Color Rule v6). The comment
  correctly records that travertine is not merely replaced but *reassigned* to live-state.
- Hero context stamp ("READINESS · TUE 21 JUL") micro+manual-tracking → `AnnotationLabel`,
  colored `metricReadiness`. **See the open contradiction below — this is the one contested call.**
- Readiness reason tree: factor deltas → `AnnotationLabel` prefixed `├─` / `└─`, with
  `factorRow` gaining `index:`/`isLast:` to drive the box-drawing and the stagger. The factor
  *name* deliberately stays working voice (it is a label the app says and the row navigates) —
  correct per rule 9.
- ACWR progress fill `text1` → **`accent`**, on the reasoning that a progress fill is a live-state
  mark and v6 freed travertine when the hero moved to its hue. **Verified against DESIGN.md 184:
  "progress fills" are named explicitly in accent's exclusive territory. Correct.**
- `LoadStatCell` gains `index:`; `ACWR`/`ATL`/`CTL`/`TSB` machine keys and the estimated qualifier
  → `AnnotationLabel(size: .small)`, staggered 0–3 in reading order. Readings stay working voice
  with tabular digits — the right split.
- Session `RPE 7` → `AnnotationLabel`.

**`HRVDetailView.swift`** (+37 −22) — stat band keys/units → `AnnotationLabel(size: .small)`;
`LATEST` value takes **`metricRecovery`**, baseline and delta stay ink (one colored reading);
hardcoded `8`/`16`/`32`/`24` paddings → `Spacing` tokens. The "About HRV" eyebrow was left in the
working voice with an explicit comment that annotation never takes a headline — correct restraint.

**`SleepDetailView.swift`** (+~30) — same pattern, `LAST NIGHT` takes **`metricSleep`**; paddings
→ `Spacing`.

**`WeeklySummaryCard.swift`** (+39 −? ) — marginalia to annotation voice.

**`RecoveryView.swift`** — hero recovery score takes **`metricReadiness`** (DESIGN.md maps that hue
to "readiness / recovery score"); `/ 100` denominator → annotation voice; everything else inked.

**`InsightCard.swift`, `BehaviorCorrelationRow.swift`** — sample-provenance footnotes
("Based on N occurrences", "N days with, N without") → `AnnotationLabel(size: .small)` while the
claim sentence stays working voice. This is a good reading of the annotation register: provenance
is marginalia, the claim is speech.

### Two pre-existing defects B found and fixed — worth recording as the lane's best work

Neither was in scope; both are real.

1. **`MorningCheckInSheet.swift` — nocebo-guard violation predating v6.** The wellness-score
   preview carried its state **by color alone**, with no zone label anywhere near it, via a
   `wellnessScoreColor` helper. B inked the reading and **deleted the helper**. Rule 6 forbids
   color-alone state; this had been shipping.
2. **`NiggleLogSheet.swift` + `MorningCheckInSheet.swift` — contrast floor.** Zone-colored readings
   sat on a debossed `ReadoutWell` (4.01:1) and on the base plane (4.39:1), both below the 4.5:1
   small-text floor. B inked the readings and **left the segment bars in zone color**, correctly
   invoking "marks are unrestricted" so the state channel survives. `ReadoutWell(color:)` arguments
   were dropped at these call sites.

### OPEN CONTRADICTION — needs a ruling, do not let a lane decide it again

**`DESIGN.md` contradicts itself on whether metric-hue annotation is allowed, and B resolved it
inconsistently across its own two screens.**

- **Line 182** — metric hues may color: "**Metric-hue annotation** (a `● READINESS` key), subject
  to the contrast rule below." → *permits* a colored annotation stamp.
- **Line 188** — "There is still at most **one colored text element per screen** — the hero
  reading." → *forbids* it, since the hero reading already spends the budget.

Consequence in shipped code right now: **Home has two green text elements** (the annotation stamp
*and* the 64pt reading), while **Recovery has one** (B inked everything but the score, and its
comment cites the one-element rule). Both screens cite DESIGN.md; the document supports both.

This is a one-line fix in either direction, but it is a **design-law question, not a lane
question** — routing to HAN / Session A's follow-up queue rather than picking silently. The two
coherent resolutions:

- **(a) Strict one-element:** ink the Home stamp. Then line 182's "metric-hue annotation" clause
  should be struck or narrowed, because nothing can legally use it.
- **(b) One colored *reading* + permitted hue annotation:** keep the stamp; reword line 188 to
  budget one colored *reading* rather than one colored *element*, and say explicitly that a
  metric-hue annotation key does not consume the budget.

Until ruled, Home and Recovery are stylistically inconsistent with each other.

### Verification

**No verification was completed by this lane** — it died before the suite ran, and its last
pre-stall build result is unrecoverable. Stating that plainly rather than inheriting the
orchestrator's green run as if it were B's.

Orchestrator's independent verification, covering B's files along with C's and D's (single serial
run, `~/.tonus-dd-claude`, from `workload management/`):

```
xcodebuild test -scheme "workload management" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -derivedDataPath ~/.tonus-dd-claude -only-testing:WorkloadAppTests
```
→ `** TEST SUCCEEDED **`, **762 passed / 0 failed**, 0 compile errors across all 54 Wave 2 files.
Design-system fence suite **17/17 green**, including the six new v6 fences
(`test_metricHueTokens_existAndAreComplete`, `test_retunedZoneColors_matchV6`,
`test_annotationFace_reachableOnlyViaFontTokens`, `test_annotationSizeCap_isEnforcedAndNotBypassed`,
`test_annotationChoreography_hasOneImplementation`, `test_alpinoDisplayFace_bannedInApp`) plus
`noHardcodedColors`, `noSystemFonts`, `noShadowModifiers`, `cornerRadii`, `faceName`, and both
spacing-grid fences.

**Frozen-file boundary: clean.** `CardStyle.swift`, `ColorTokens.swift`, `FontTokens.swift`,
`DesignSystemFenceTests.swift`, `DESIGN.md`, both twins, and `.pbxproj` all unmodified.

### Not done in this lane

- Four files untouched (listed above) — **status unknown**, re-inspect rather than assume.
- **No on-simulator visual check of Dashboard or Recovery.** B died immediately before its own
  visual pass, so nothing in this lane has been looked at by eye. The annotation choreography
  (40ms stagger after surface settle) is *structurally* correct and fence-verified, but its
  actual appearance on Home — four load keys staggering left→right, the reason-tree glyphs
  aligning — is unverified. This is the largest open risk in the lane and belongs in the
  orchestrator's cross-screen visual sweep.
