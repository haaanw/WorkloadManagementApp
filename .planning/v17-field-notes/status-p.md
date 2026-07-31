# Session P — punch list (Wave 3)

Branch `v1.7-field-notes`. No commits, no staging, no simulator, no test suite run.
DerivedData: `~/.tonus-dd-claude-p`.

---

## 2026-07-31T00:03 · Items 1–6 worked; item 7 (zh screenshots) deferred by the orchestrator

### Verification — the actual command and the actual output

Run three times: after batch 1 (7 files), after batch 2 (ActiveWorkoutSheet), and once
more at the end. Green each time; pasted below is the final run.

```
cd "/Users/hanwen/dev/Tonus/workload management"
xcodebuild build -scheme "workload management" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -derivedDataPath ~/.tonus-dd-claude-p
```

```
ProcessInfoPlistFile …/workload management.app/Info.plist …/workload-management-Info.plist
  (in target 'workload management' from project 'workload management')
    cd /Users/hanwen/dev/Tonus/workload management
    builtin-infoPlistUtility …

** BUILD SUCCEEDED **
```

A filtered pass over the same output (`grep -E "error:|BUILD"`) returned exactly one
line, `** BUILD SUCCEEDED **` — zero compile errors.

**No test run.** Per the Wave 3 rule I did not invoke `xcodebuild test` at all, not even a
single class. See "Verification I did NOT do" below for what that leaves open.

---

## Item 1 — Session B's four untouched files

Identified from `git show --stat 6788e3b` against `Views/Dashboard/` + `Views/Recovery/`
(13 files in scope, 9 in the commit). The four are all in `Views/Dashboard/`:

| File | Verdict | Action |
|---|---|---|
| `NotificationPrePermissionCard.swift` | Incomplete — zh violation | Fixed |
| `TrainingProfileCard.swift` | Incomplete — zh violation | Fixed |
| `WelcomeActionCard.swift` | Incomplete — zh violation | Fixed |
| `PRSDualRunCard.swift` | **Complete by nature** | None |

**What was actually wrong, and it is not what "untouched" suggested.** Three of the four
carry a micro-caps eyebrow (`NOTIFICATIONS`, `GET STARTED`, `TRAINING PROFILE`) built as
`.font(.Tokens.micro).tracking(0.9)` with **no locale guard**. That is the same defect
class as REQ-D2: DESIGN.md scopes micro-caps to "Latin locales only", and `micro`'s own
docstring in `FontTokens.swift` delegates case + tracking to the call site — so an
unguarded call site applies 0.9pt tracking to Chinese. All three keys are localized
(`通知`, `开始使用`, `训练档案`), so this was live in zh-Hans, not latent.

Fixed with the codebase's established `isLatin` idiom (`languageCode != "zh"`), and the
case transform made explicit and guarded at the same time — a no-op in en (the strings are
authored uppercase) but it moves case out of the translation and under the locale guard,
so a future lowercase translation cannot silently lose it.

These are **eyebrows, not annotation.** I deliberately did NOT convert them to
`AnnotationLabel`. They name what the card is about; DESIGN.md rule 9 says annotation is
never a headline, and B set the precedent in `HRVDetailView` ("the eyebrow is a section
head the app SAYS — working voice"). Keeping the working voice here keeps Dashboard
internally consistent with what B already shipped.

`PRSDualRunCard` genuinely has nothing to adopt: one label line, an explanation sentence,
and two comparison columns — all working voice by law, no units, deltas, timestamps or
machine keys anywhere. **B's omission there was correct, not unreached.** (Its two
`String(localized:)` column titles predate Wave 2 and are outside the regression class the
orchestrator repaired, so I left them.)

**Not a claim I can make:** whether B *intended* any of this. The transcript is gone. What
I can say is what the code needed, which is the question that mattered.

## Item 2 — Session C's leftovers

**`TemplatePickerSheet.swift` — off-token spacing, done.** Ten literals
(`spacing: 16`, `.padding(.horizontal, 16)`, `.padding(.vertical, 24)`, `spacing: 8`,
the `LazyVGrid` column/row spacings) → `Spacing.sm` / `.md` / `.xs`. Fence-legal before,
tokenised now; zero visual change (every literal already equalled its token's value).

**`ActiveWorkoutSheet.swift` — the four un-audited regions, audited.** C's own list of
what remained was partly wrong, which is worth recording:

- **There is no rest timer and no `SessionStartChooser` in this file.** Neither string
  appears anywhere in it (`SessionStartPicker` is a separate Component, Session D's).
- **`weightPlaceholder` (lines 1156–1161) is dead code** — declared, never referenced. It
  is the "textbook `ReadoutWell` unit" C flagged as a strong annotation candidate; it
  cannot be one, because nothing renders it. `WeightBlockPicker` replaced that field. I
  did **not** delete it (out of scope for a restyle lane, and it is one line of a request
  below).
- Lines 330–900 are pure logic — zero `Text(` / `.font(` — so the real view surface is
  four regions, all now read end to end.

Two real changes came out of it:

1. **A zh-Hans live-switching regression introduced by Wave 2, fixed.** C changed
   `setHeaderRow(columns:)` from `[(LocalizedStringKey, CGFloat)]` to `[(String, CGFloat)]`
   because `AnnotationLabel` had no key initializer, which pushed all four call sites onto
   `String(localized:)`. That reads the **process** locale while `AppRouter` pins the app's
   language via `.environment(\.locale, …)` — so the set-table headers (`SET` / `WEIGHT` /
   `REPS` / `DIST (M)` / `TIME (S)` / `TIME (MIN)`) had stopped following an in-app
   language switch. All six keys carry zh-Hans translations (`组次`, `重量`, `次数`,
   `距离(米)`, `时间(秒)`, `时间(分)`), so this was a visible regression, not a formality.
   The orchestrator added `AnnotationLabel(key:)` during Wave 2 verification precisely for
   this class and migrated 16 sites; this tuple-shaped helper was not among them. Signature
   reverted to `LocalizedStringKey`, call sites back to bare keys, rendering via
   `AnnotationLabel(key:)`. **This also removes the churn C filed as its priority-1
   frozen-file request.**
2. **The progression-suggestion row → annotation voice.** `▲ 82.5KG SUGGESTED` /
   `= MAINTAIN 80KG`, replacing `Image(systemName:) + Text` at `.label`/`text3`. It was
   already tertiary marginalia hanging off a row's reading. The SF Symbol became a
   sanctioned glyph (`▲` rise, `=` hold) so the line renders in one face at one size
   instead of mixing an icon into 12pt mono. **The a11y label is unchanged** — VoiceOver
   still speaks the sentence-cased "Suggested: 82.5kg suggested" form. See the judgment
   call flagged for HAN below.

**Left in the working voice, on purpose** (each is data or speech, not marginalia): the
elapsed-time readout, `summaryText`, the set index, the `+ RPE` chip, the warmup toggle
label, the Fill / Repeat / Add-set / Add-exercise actions, and `suggestionRationale`
(a sentence). This matches the rule C stated and B applied.

**`ExercisePickerView.swift` — the un-audited regions contain no annotation candidates.**
I read the filter bar, `FilterChip`, the equipment facet menu, `headerRow`, `instantAddRow`,
`emptyRow`, `AddCustomExerciseSheet` and the toolbar. Every string in them is a control
label, a section head, an action, or a sentence — all working voice by law. Spacing is
already fully tokenised; chips are `Capsule()`; selection is carried by plane + border +
ink, not colour alone. **No change made, and that is the finding** — not a lane running out
of time. (Two pre-existing non-v6 violations found there are filed as requests below.)

## Item 3 — `RadialPicker` `== "en"` → `isLatin`

`isEnglish` (`languageCode == "en"`) → `isLatin` (`languageCode != "zh"`), matching
`AnnotationLabel`, `ZoneBadge`, `MetricCell`, and `RuledSectionHeader`. Both use sites
updated. Effect: **French now gets micro-caps case and 1.2pt tracking**, which the `== "en"`
test wrongly stripped — the same fix Session D applied elsewhere in Wave 2 and left here.

## Item 4 — REQ-D2, `ScreenHeader.context`

Fixed at source in `CardStyle.swift`. **Two sites, not one:**

- `context` — `.textCase(.uppercase)` was unconditional while its *tracking* was already
  guarded, so the struct's own docstring ("Micro-caps case/tracking on the context line and
  action slot are locale-aware (Chinese gets none)") described behaviour the code did not
  have. Latent today: no caller passes `context:` (verified — all five `ScreenHeader(` call
  sites pass only `title:`).
- **The trailing action slot has the identical defect and is NOT latent.** `DashboardView`,
  `WorkloadView` and `WorkoutLogView` all pass a trailing action, so zh-Hans has been
  shipping an uppercase transform on Chinese action labels. Same struct, same line of
  reasoning, same guard applied. I judged it wrong to fix the dormant half of a defect and
  leave the live half.

**Ownership conflict, flagged rather than assumed away:** my brief lists `ScreenHeader` and
`StatusBadge` as files I own *and* says I do not own `CardStyle.swift`. Both structs live
in `CardStyle.swift` (lines 768 and 1186). I read the itemised instruction "REQ-D2 … fix at
source" as the more specific of the two and made the edit, keeping it to those two lines
plus comments. `AnnotationLabel`, `Motion`, the relief modifiers, and every other primitive
in that file are untouched. If the orchestrator wanted `CardStyle.swift` frozen absolutely,
revert those two hunks — nothing else in this lane depends on them.

## Item 5 — REQ-D3, `StatusBadge`: **DEAD**

`grep -rn "StatusBadge" WorkloadApp/ "workload management/" WorkloadAppTests/` returns
exactly one hit: its own declaration at `CardStyle.swift:1186`. No call site in app source,
no test, no preview. Per instruction I did **not** delete it.

> **REQUEST TO ORCHESTRATOR — remove `StatusBadge` (`CardStyle.swift:1186–1199`).**
> It is unreferenced and it is also *wrong* by three current laws, which is why leaving it
> is worse than dead weight — it is a wrong pattern sitting in the primitives file where the
> next author will copy it: (a) unguarded `.tracking(1.2)` with no locale test, (b) no
> backing plane, so zone-coloured text at `micro` would land on whatever plane the caller
> used and fail the 4.5:1 floor on `bg`/wells, (c) `color:` defaults to `statusNeutral` with
> no text label requirement, i.e. it invites colour-alone state. `ZoneBadge`
> (`MetricTile.swift:65`) is the corrected version of exactly this component and already
> carries its own `surfaceEl2` capsule. Deleting is a 14-line removal with no call-site
> churn; the alternative is porting three fixes into a component nobody uses.

## Item 6 — `WeeklyZoneBadge` card-plane treatment: **applied**

It needed more than the contrast fix the Wave 2 note anticipated. Three changes:

1. **Card-plane backing.** It filled itself with `ColorTokens.background` — the **base**
   plane, where `zone-optimal` measures 4.39:1 and `metric-load` 4.49:1, under the 4.5:1
   small-text floor. Now `surfaceEl2`, following `ZoneBadge`'s rule of carrying its own
   plane rather than trusting the one beneath it. Legal wherever it is dropped, not legal
   by luck.
2. **It had no state channel at all.** Every zone rendered in uniform `text2` with a
   `divider` hairline, so `Optimal`, `Caution`, `High risk` and `Undertrained` were
   visually identical — a *distribution* chart with the distribution's meaning removed. The
   zone name now takes `ColorTokens.acwrZoneColor(zone)` and the hairline capsule follows
   it. Text-label-first is intact (rule 6): the word carries the state, the hue is
   supplementary, and the capsule is a hairline, never a fill.
3. **Micro-caps at micro size**, Latin-guarded, with zh's wider horizontal padding — byte
   for byte `ZoneBadge`'s treatment. It was 15pt `label`, a full size step above every other
   badge in the app.

The count stays a working-voice tabular numeral in ink: it is the chip's data, and
annotation is marginalia *around* data, never the data itself.

**Wants a HAN eye:** this puts up to four hued chips in one row on Home. v6.1 removed the
count cap and governs by identity — each chip names the zone whose hue it wears — so it is
legal, but "legal" and "calm" are different questions and this lane could not look at it.

---

## Judgment calls I made that HAN may want to reverse (each is a one-line revert)

1. **The progression-suggestion row in mono.** "82.5kg suggested" sits on the boundary
   between a machine qualifier and a phrase the app says. I converted it (it was already
   `text3` marginalia and it hangs off a reading). Revert = restore the `HStack` with
   `Image(systemName: suggestionIcon)` + `Text(text)` at `.label`.
2. **`▲` / `=` replacing `arrow.up` / `arrow.right`.** Both glyphs are in v6's sanctioned
   set; `=` for "hold" comes from the design system's own content fundamentals ("Deltas are
   signed: +4, ="). SF Symbols remain correct everywhere they are real UI glyphs.
3. **Zone hues on `WeeklyZoneBadge`** — see item 6.
4. **Guarded `.textCase` on the three Dashboard eyebrows.** No-op today in both shipping
   locales; it exists so a future translation cannot lose the caps silently.

## Requests to other lanes / the orchestrator

- **REQ-P1 — delete `StatusBadge`** (item 5, full argument above). Orchestrator, since it
  is a removal in a primitives file.
- **REQ-P2 — the unguarded micro-caps defect is systemic; 8 more sites, none of them mine.**
  REQ-D2 and B's three cards are instances of one pattern: `.font(.Tokens.micro)` +
  `.tracking(…)` with no `isLatin` test, because `micro`'s docstring explicitly delegates
  case and tracking to the call site. Remaining offenders, each applying tracking (and
  sometimes `.textCase(.uppercase)`) to Chinese:
  `DashboardView.swift:400` (the hero **zone label** — the most visible of them),
  `HRVDetailView.swift:85` and `SleepDetailView.swift:69` (**Session H owns both this
  wave**), `TemplateEditorSheet.swift:88,394`, `UpgradeSheet.swift:216,221`,
  `TemplateCarouselSection.swift:253`, and `ShareCodeSheet.swift:91` (`tracking(2.0)`).
  **The durable fix is a `.microCaps()` modifier in `CardStyle.swift`** that owns the case
  transform, the ≈0.9pt tracking and the locale guard — the working-voice twin of what
  `AnnotationLabel` already does for the annotation voice. That is a primitives change and a
  ~10-site sweep; I did neither, and I have not touched any file above.
- **REQ-P3 — `ExerciseDetailSheet.metadataRow` carries the same `String(localized:)`
  regression I fixed in `ActiveWorkoutSheet.setHeaderRow`.** C changed that signature
  `LocalizedStringKey → String` for the same reason and the four call sites still resolve
  against the process locale. Now that `AnnotationLabel(key:)` exists it is the same
  ~6-line revert. File is not mine (Session C's).
- **REQ-P4 — two pre-existing bans still live in `ExercisePickerView.swift`.** The
  equipment facet uses a stock iOS `Menu` (line ~189) and `AddCustomExerciseSheet` uses
  `.pickerStyle(.menu)` (line ~634). DESIGN.md still lists "Stock iOS `Menu` for
  settings/pickers" as banned (v4.2, carried through v6). Both predate v6 and replacing a
  28-value facet picker is a redesign, not a punch-list edit — needs a scoped decision, and
  `RadialPicker`'s own accessibility fallback also uses `Menu` deliberately (D-14), so the
  ban evidently has an accessibility carve-out that is not written down.
- **REQ-P5 — `ActiveWorkoutSheet.weightPlaceholder` (lines 1156–1161) is dead.** Six lines,
  no references. Safe removal, but it is code deletion rather than restyle so I left it.

## Verification I did NOT do — stated plainly

- **No test run of any kind**, including the 17-fence design-system suite. My changes touch
  tracking, spacing, glyph strings and colour-token usage — the exact surface those fences
  police. I self-checked against the fence sources instead (`test_structuralSpacingLiterals`,
  `test_directionalPaddingLiterals`: every literal I introduced is a `Spacing` token;
  `test_noHardcodedColors`: only `ColorTokens.*`; `test_noSystemFonts` / `test_faceName`:
  only `Font.Tokens.*`; `test_animationCurveLiterals`: no animation added). That is an
  argument, not evidence. **The orchestrator's serial gate run is what proves it.**
- **Nothing was looked at on a simulator.** `WeeklyZoneBadge` changed appearance (size,
  colour, plane) and the progression row changed face — neither has been seen by eye. Both
  belong in the cross-screen visual sweep.
- **No zh-Hans pass** (item 7, deferred by the orchestrator). Three of my six items are
  zh-Hans correctness fixes verified by construction and a green build only. The zh screens
  still have not been looked at by anyone, in either wave.

## Boundary check

`git status --short -- WorkloadApp/` shows 9 modified files; 8 are mine. The 9th,
`Resources/Localizable.xcstrings`, was **already modified before this session started**
(present in the opening `git status`, mtime `2026-07-30T20:54`, ~3h before my first edit) —
it is not mine and my three builds did not rewrite it. I touched no chart component
(`HRVTrendChart`, `SleepTrendChart`, `LoadTrendChartView` — Session H), not
`FontTokens.swift` (Session T), not `ColorTokens.swift`, not the fence tests, not
`.pbxproj`, not `DESIGN.md` / `CLAUDE.md` / `AGENTS.md`. No git write of any kind.

---

# Round 3 — app-source FIX session (2026-07-31 10:13 CST)

Sole Swift-touching session this round. Build path `~/.tonus-dd-claude-p`. No git write.

## A. HAN's sleep ruling, fully migrated

**A1 — `ReasoningEngine.swift`.** The Dashboard sleep Factor measured against a hard-typed
`420`, while the row it navigates into (`DashboardView.trendDestination` → `SleepDetailView`)
reports against `RecoveryScoreEngine.sleepTargetHours`. Confirmed at `:65-69` before the edit.
Now reads the constant (`let targetMinutes = RecoveryScoreEngine.sleepTargetHours * 60`), and
the copy was rewritten: `delta.minAboveAverage` / `delta.minBelowAverage` → new keys
`delta.minAboveTarget` / `delta.minBelowTarget` ("%d min above/below target", en + zh-Hans),
because "above/below average" named neither the athlete's baseline nor the target.
The two doc comments at `:114` / `:177` that called 7 h "the legacy fixed target" were reworded.

`ReasoningEngineTests.swift`: the stale `// 5.5h = 90 min below 7h target` fixture is now
`360` min (6 h = 90 min below 7.5 h) and the weak `.negative`-only assertion is replaced by an
exact-copy assertion (`"90 min below target"`). Added `test_sleep_referenceIsTheAppWideTarget`,
which pins the reference to `RecoveryScoreEngine.sleepTargetHours` and asserts the exact night
the reviewer named: 435 min → `"15 min below target"` (it used to read "15 min above average").

**A2 — `MockDataSeeder.swift:88`.** `420.0 + phase * 6` → `456.0 + phase * 6` (456–492 min =
7.6–8.2 h), so the App Store screenshot seed no longer shows a permanently under-target athlete.

**A3 — app-wide sweep (mine, not the reviewer's).**
`grep -rn "420\|7h\|7 h\|7-hour\|7 hour\|seven hour" --include="*.swift" WorkloadApp/ WorkloadAppTests/ ScreenshotTests/`
plus a scripted scan of every en and zh-Hans value in `Localizable.xcstrings` for
`7\s*(h|hour|小时)`. Result after the fix: **zero** remaining 7-hour assumptions in app code
or copy. Every remaining `420` is a neutral test fixture (`DayBucketerTests`,
`BaselineStateModelTests`, `PRSReadinessInputBuilderTests`, `TodayVerdictServiceTests`,
`DashboardViewModelDualRunTests`, `TodayVerdictViewModelTests`, `WorkloadCalculatorTests`) that
carries no target semantics. Onboarding, `NotificationService`, and the tooltip/disclosure copy
carry no sleep-target number at all. All sleep-target reads now route through
`RecoveryScoreEngine.sleepTargetHours` / `.sleepDeficitFloorHours` — verified by grep.

## B. Recovery press well — FIXED

Confirmed: `RowWellButtonStyle.makeBody` (`CardStyle.swift`) attaches the well to
`configuration.label`, and `cardStyle()` supplies its own interior padding, so the
`.padding(.horizontal, Spacing.sm)` inside the `NavigationLink` label made the well 32pt wider
than the card. Moved the page margin from the label to the link on **both** links
(`RecoveryView.swift`, HRV and Sleep sections).

## C. Mixed-locale headers — FIXED

`statCell(label:)` in `SleepDetailView` and `HRVDetailView` now takes `LocalizedStringKey` and
renders via `AnnotationLabel(key:)`. Five call sites converted
(`sleep.detail.label.lastNight`, `detail.label.sevenDayAvg` ×2, `hrv.detail.label.latest`,
`hrv.detail.label.delta`). `unit:` stays a literal — `ms` is a machine unit, never translated.

## D. Hard-coded English — FIXED

New xcstrings keys (en **and** zh-Hans, both `translated`), all resolved through
`LocalePinnedStrings.localized(_:locale:)` — the `HRVDetailChart:147-161` pattern — and all
**authored lowercase** so `AnnotationLabel` owns the uppercase transform and drops it for CJK:

| key | en | zh-Hans |
|---|---|---|
| `detail.readout.now` | `● now` | `● 当前` |
| `sleep.detail.readout.onTarget` | `= target` | `= 达到目标` |
| `sleep.detail.readout.aboveTarget` | `%1$@ +%2$lldm vs target` | `%1$@ 比目标多 %2$lld 分钟` |
| `sleep.detail.readout.belowTarget` | `%1$@ -%2$lldm vs target` | `%1$@ 比目标少 %2$lld 分钟` |
| `hrv.detail.readout.vsBase` | `%1$@ %2$+.1f%% vs base` | `%1$@ 相对基线 %2$+.1f%%` |
| `hrv.detail.delta.vsAvg` | `%@ vs 7-day avg` | `%@ 相对 7 天平均` |

(`%lld`, not `%d` — Swift `Int` is 64-bit and positional `%d` in `String(format:)` is a
truncation trap.)

Reason-tree rows: `"LAST NIGHT:"` → `"LAST_NIGHT:"`, `"7D AVG:"` → `"AVG_7D:"`. That takes the
reviewer's second option — they are now true machine keys in the same register as the rows
under them (`SLEEP_DEBT_7D`, `NIGHTS_BELOW_6H`, `SCORE_CONTRIB`), so they read as untranslated
**by design** rather than as untranslated English.

`hrv.detail.delta.vsAvg` was **not** on the reviewer's list — I found it while fixing the file.
`HRVDetailView.deltaText` returned the English literal `"...% vs 7-day avg"` straight into the
DELTA stat cell's working-voice `Text`.

## E. The 8 h = 90 anchor — RESTORED

Not arithmetically forced, so it is back. The curve is now
`<5h=10 · 6h=40 · 7.5h=70 · 8h=90 · 9h+=100`; only HAN's knee moved.

**The numbers HAN should see, because the shape did change.** With 6 h pinned at 40 and the
knee at 7.5 h, the segment below the knee is forced to 20 pts/h (was 30), and holding 8 h = 90
forces 40 pts/h for the half-hour above it. Slope ladder: **was 30 / 20 / 10** across
6–7 / 7–8 / 8–9 h (monotonically diminishing returns); **is now 20 / 40 / 10**. The alternative
— the Round-2 form, a flat 20 pts/h above the floor — restores diminishing returns but cuts
8 h from 90 to 80, an unordered score cut for well-slept athletes. I picked the anchor over the
shape because HAN ruled on one number and neither of the others was up for change; the one-line
revert is written into the docstring if HAN prefers the smooth curve.

`RecoveryScoreEngineTests.test_sleepCurve_anchors` now asserts 480 min → 90 explicitly, plus a
new monotonicity sweep over 240–600 min in 5-min steps (a non-monotonic sleep score would be a
bug regardless of which shape wins).

## F. Scrub gesture vs ScrollView — REAL, FIXED

`ChartTooltipGesture` mounted `DragGesture(minimumDistance: 0)`, which recognises on
touch-DOWN before any translation exists, so the enclosing `ScrollView`'s pan recogniser never
gets the touch. On the glance cards that is a small dead zone; on the two detail screens it is
224pt of a scrolling page.

Added `yieldsToScroll: Bool = false`. The default path is byte-identical for both glance call
sites. `true` (passed by `SleepDetailChart` and `HRVDetailChart`) swaps in the SwiftUI default
`minimumDistance` of 10pt — the same slop `UIScrollView`'s pan uses, so a vertical pan resolves
to the scroll and a horizontal one to the scrub — and adds a `simultaneousGesture(SpatialTapGesture())`
so tap-to-select survives (the zero-distance drag had been providing it for free via `onChanged`).

**Honest limit:** verified by construction and a green build. I did **not** put a finger on a
simulator. This needs one on-device scrub-and-scroll check on both detail screens.

## G. Lane P's outstanding defects

1. **Process-locale regressions — all converted.**
   `ActiveWorkoutSheet:1344` (`set.warmup.label`), `WeeklySummaryCard` ×3 via
   `metricCell(title:)` (signature now `LocalizedStringKey`, body `AnnotationLabel(key:)`),
   `VerdictOutcomeSheet:28`, `FeltRightPromptRow:31`, `SeanEllisPromptSheet:29`, and
   `ExerciseDetailSheet.metadataRow` (signature now `LocalizedStringKey`, 4 call sites).
   `ActiveWorkoutSheet.setHeaderRow` was **already** on `LocalizedStringKey` — fixed in an
   earlier round, not by me.
   Proof: `grep -rn "AnnotationLabel(String(localized" --include="*.swift" .` → **one hit, the
   docstring in `CardStyle.swift:626` that names the anti-pattern.** Zero call sites.
2. **DESIGN.md rule-9 violation — fixed.** `ActiveWorkoutSheet:1619` put the whole progression
   line through `AnnotationLabel`, including `set.suggestion.maintain` = "maintain %@kg" /
   "保持 %@kg". Split the voices: the `▲`/`=` mark stays `AnnotationLabel` (sanctioned glyph
   set, `accessibilityHidden`), the imperative returns to `Text(...).font(.Tokens.label)` /
   `ColorTokens.text3`. The combined a11y label is preserved.
3. **Fabricated contrast figure — corrected.** Recomputed WCAG: `zone-caution` #8A5C08 on
   #F0EFEC = **5.05:1**, `metric-load` #8A6810 on #F0EFEC = **4.49:1**. The reviewer and
   DESIGN.md:201 are right; the docstring was wrong. Comment now names `zone-optimal` (4.39)
   and `metric-load` (4.49) as the only sub-floor pairs and records the mis-attribution.
4. **`.tracking(1.2)` → `0.9`** in `WeeklyZoneBadge`. Note this **breaks the docstring's
   "matching `ZoneBadge` exactly" claim on purpose**: `ZoneBadge` (`MetricTile.swift:75`) still
   hand-types 1.2, a pre-existing deviation in a file this session does not own. Copying it
   would have propagated the deviation; the comment now flags it instead.
5. **`StatusBadge` deleted.** Re-confirmed zero call sites across `WorkloadApp/`,
   `WorkloadAppTests/`, `ScreenshotTests/` and `.pbxproj` before deleting — the only hits were
   its own declaration and planning prose. Replaced with a comment recording why it went (three
   v6 violations sitting in the primitives file, where readers look for the pattern to copy).

## Verification (actual commands, actual output)

```
xcodebuild build -project "workload management/workload management.xcodeproj" \
  -scheme "workload management" -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -derivedDataPath ~/.tonus-dd-claude-p
→ ** BUILD SUCCEEDED **                         (run twice: after batch 1, and after all edits)

xcodebuild test ... -only-testing:WorkloadAppTests/RecoveryScoreEngineTests \
                    -only-testing:WorkloadAppTests/ReasoningEngineTests
→ ** TEST SUCCEEDED ** — 40 test cases, 0 failures
  (incl. test_sleepCurve_anchors, test_sevenAndAHalfHourSleep_isTheSeventyPointKnee,
   test_sleep_referenceIsTheAppWideTarget, test_sleep_short_negativeMaxImpact)

xcodebuild test ... -only-testing:WorkloadAppTests/DesignSystemFenceTests
→ ** TEST SUCCEEDED ** — 17 fence cases passed
```

Frozen-file check: `git diff --stat HEAD --` on `FontTokens.swift`, `InkTabBar.swift`,
`TickScale.swift`, `DesignSystemFenceTests.swift`, `DESIGN.md` → **empty**. Repo-wide grep for
`UIFontMetrics|ScaledMetric|dynamicTypeSize` → zero (the `relativeTo:` hits are
`RelativeDateTimeFormatter` and a `SubscriptionService` test helper). DESIGN.md stays at v6.2.

## xcstrings hygiene note (self-reported)

My first write of `Localizable.xcstrings` used Python's default JSON separators and re-sorted
the keys, producing a 10,900-line reformat. I caught it in the same turn and rebuilt the file:
Xcode's `"key" : {` separators, Xcode's `{\n\n}` empty-object form, and the **HEAD key order**
preserved for every pre-existing key, with new keys inserted at their case-insensitive
positions. The diff vs HEAD is now additions and pre-existing deletions only — verified by
`git diff -U0 | grep '^+' | grep '" : {'`, which returns only the new keys. No key was lost
(1033 → 1040) and the other lanes' 18 additions and 82 deletions in that file are intact.

## NOT fixed, and why

- **`TodayVerdictCard.swift:66`** — `AnnotationLabel("\(String(localized: "verdictCard.title", …)) · …")`.
  Same process-locale class as G1, hidden from the reviewer's grep by the string interpolation.
  **Not in this session's ownership list**, so untouched. Fix is `AnnotationLabel` + a
  `LocalePinnedStrings.localized("verdictCard.title", locale: locale)` prefix.
- **`InviteConfirmationSheet.swift:49`** — `AnnotationLabel(mode == … ? "COACH REQUEST" : "LINK ATHLETE")`,
  hard-coded English, no key. Not in ownership; also a retired coach surface.
- **`MetricTile.swift:75` (`ZoneBadge`)** — hand-typed `.tracking(1.2)` where `micro` specifies
  0.9. Not in ownership. Flagged in the `WeeklyZoneBadge` docstring.
- **`sleep.detail.header.title` = `"SLEEP TREND"` / `hrv.detail.header.title`** — rendered at
  28pt `pageTitle`, i.e. an ALL-CAPS screen title. DESIGN.md retires "micro-caps wide-tracked
  screen titles" and mandates sentence case in the working voice. This is a **copy** decision
  and was not in any finding, so I did not change user-facing strings unilaterally. HAN: this
  probably wants to be "Sleep trend" / "HRV trend".
- **Nothing was seen on a simulator.** Finding B (press-well geometry) and finding F (scrub vs
  scroll) are both *interaction* fixes verified by reasoning and a green build. Both need one
  on-device look before this wave ships.
- **No zh-Hans screen pass.** Six of my fixes are zh-Hans correctness fixes verified by
  construction only. The new zh strings are my translations and have not been reviewed by HAN.
