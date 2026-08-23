# Optional description block — the sleep-score-v2 paragraph

**Status, verified in source 2026-08-22: built, and dark.** `SleepScoreEngine.swift` is a
complete 662-line engine and `RecoveryPipeline` runs it nightly — but its output goes into
local-only `SleepShadowNight` rows that no view, view model or component reads, and the live
recovery score still comes from `RecoveryScoreEngine` with the fixed 7.5-hour target. An
athlete on 1.7.2 gets nothing from it. Full evidence in `1-keyword-metadata-audit.md` §6.

The default descriptions in `4-description-en.txt` / `5-description-zh-Hans.txt` therefore
**do not mention it**, per HAN's rule of 2026-08-22: list it if it is built *for the user*,
otherwise not yet. Describing it now would describe behaviour the binary does not have, and
this listing has already been rejected twice.

**This file is for the release that wires the shadow to the live score.** On that day the
paragraph below is no longer a hedge — it becomes a genuine differentiator, and the stronger
move is a What's New entry plus a description block, not this alone.

If HAN wants it in the listing *before* that, this is the graded version. It carries the same
three rails the website's Methodology section carries — *status: design · not in the shipping
app*, *no performance or accuracy claim is made here*, *nothing here is finished* — so no
claim is stronger in the listing than it is on the site.

**Insert position:** immediately before the `PRIVACY` block.

---

## English

```
WHAT WE HAVEN'T BUILT YET
Sleep is scored today against a fixed 7.5-hour target. We are designing a version that weighs the night against the day it followed — and the whole design, including the weights and the parts we are least sure of, is published at tuwa.app before any of it ships. None of it is in the app yet, and no accuracy claim is made for it.
```

## Simplified Chinese

```
还没做出来的部分
今天的睡眠评分对照的是固定的 7.5 小时目标。我们正在设计一个会结合白天状态来评价这一晚的版本——完整设计、权重，以及我们自己最没把握的部分，都会在上线之前公开在 tuwa.app 上。这些目前都不在 App 里，我们也不对它作任何准确性承诺。
```

---

## Cost check

Adding the English block takes the description from 2,390 to roughly 2,790 characters,
well inside the 4,000 limit. No other copy needs to move.
