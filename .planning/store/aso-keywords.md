# ASO Keywords Draft

Prep-only draft. Do not publish until the n=1 dogfood gate passes.

## Verification Notes

Feature claims were checked against `WorkloadApp/` before drafting:

- Daily go / modify / hold verdict: `WorkloadApp/Services/TodayVerdictEngine.swift`
- Adjusted top-set number and one-line reason: `WorkloadApp/Services/TodayVerdictService.swift`, `WorkloadApp/Services/VerdictReasonBuilder.swift`
- Match proximity microdose from optional next match date: `WorkloadApp/Services/TodayVerdictEngine.swift`, `WorkloadApp/Views/WorkoutLog/NextMatchSection.swift`
- Match tier logging: `WorkloadApp/Models/Enums.swift`, `WorkloadApp/Models/WorkoutSession.swift`, `WorkloadApp/Views/WorkoutLog/ActiveWorkoutSheet.swift`
- HealthKit HRV / RHR / sleep readiness: `WorkloadApp/Services/ReadinessFusionEngine.swift`, `WorkloadApp/Services/ReasoningEngine.swift`, `WorkloadApp/App/AppShell.swift`
- Own-plan input and verdict accept / keep / feel inputs: `WorkloadApp/Services/VerdictDecision.swift`, `WorkloadApp/App/AppShell.swift`
- Felt-right tracking: `WorkloadApp/Services/FeltRightPromptEngine.swift`
- Cross-modal carry engine exists, but direct verdict effect is gate-controlled off by default: `WorkloadApp/Services/CrossModalShadowGate.swift`, `WorkloadApp/Services/CrossModalFatigueEngine.swift`

Competition notes are estimated, not paid-ASO data. External context checked: WHOOP recovery / strain positioning, Bevel recovery positioning, TrainingPeaks / strength trackers category saturation, and Peloton Strength+ as a current strength-planning competitor category signal.

## Keyword Clusters

| Cluster | Terms | Competition | Rationale |
|---|---|---:|---|
| Basketball strength niche | basketball training, basketball strength, game day, match readiness, pickup basketball, scrimmage | Medium | More specific than generic fitness and maps to the launch athlete. "Basketball training" is broad, but paired with strength/readiness gets sharper. |
| Readiness and recovery | readiness, recovery, HRV, RHR, sleep, HealthKit, recovery score | High | WHOOP/Bevel/Garmin/Oura-style apps crowd this space. Use as supporting relevance, not the whole positioning. |
| Training load | training load, load management, ACWR, workload, strain, overtraining | Medium-High | Relevant to shipped load surfaces; "ACWR" is niche but high intent. |
| Strength plan modulation | strength plan, workout log, top set, RPE, lift tracker, autoregulation | Medium | Strong fit for "your own plan input" and adjusted top-set verdicts. |
| Signature language | strike zone, microdose, stay fresh, plan made safe, go modify hold | Low-Medium | Lower search volume, higher distinctiveness. Good for subtitle/screenshot, less reliable for keyword field. |

## EN Keyword Field Candidates

App Store keyword field limit: 100 characters. Counts below include commas and spaces.

1. `basketball,strength,readiness,recovery,HRV,sleep,workout,tracker,load,gameday,ACWR,microdose`
   - Count: 95
   - Best for: balanced beachhead + core recovery/load relevance.

2. `training load,basketball workout,strength plan,HRV,RHR,sleep,match,pickup,scrimmage,lift,ACWR`
   - Count: 97
   - Best for: basketball schedule language + plan/lift intent.

3. `readiness,strike zone,top set,workout log,load management,recovery score,HealthKit,basketball`
   - Count: 92
   - Best for: differentiated copy language + concrete shipped surfaces.

## zh-Hans Keyword Field Candidates

1. `篮球,力量训练,恢复,HRV,睡眠,训练负荷,比赛日,准备度,微剂量,ACWR,健康数据,深蹲`
   - Count: 53
   - Best for: core Chinese basketball + readiness language.

2. `篮球训练,力量计划,恢复分数,HRV,RHR,睡眠,训练记录,比赛,野球,对抗赛,负荷管理`
   - Count: 56
   - Best for: plan/logging + match-tier vocabulary.

3. `准备度,篮球力量,训练负荷,比赛前,微剂量,深蹲,卧推,HealthKit,睡眠,恢复,ACWR`
   - Count: 59
   - Best for: strength-lift specificity and game-day freshness.

## EN Title / Subtitle Candidates

| # | Title | Count | Subtitle | Count | Notes |
|---:|---|---:|---|---:|---|
| 1 | Tuwa | 4 | Stay in your strike zone | 24 | Strongest branded option; subtitle carries the promise. |
| 2 | Tuwa Readiness | 14 | Your plan, safely tuned | 23 | Clear but less basketball-specific. |
| 3 | Tuwa Basketball | 15 | Fresh for game day | 18 | Beachhead-forward; may narrow too hard if screenshots already show basketball. |
| 4 | Strike Zone Training | 20 | Readiness for your lifts | 24 | Descriptive and searchable, weaker brand recall. |
| 5 | Tuwa Training Load | 18 | Go, modify, or hold | 19 | Honest to shipped verdict language; less emotional. |

## zh-Hans Title / Subtitle Candidates

| # | Title | Count | Subtitle | Count | Notes |
|---:|---|---:|---|---:|---|
| 1 | Tuwa | 4 | 每次训练保持在区间内 | 10 | Mirrors strike-zone promise. |
| 2 | Tuwa 准备度 | 8 | 让你的计划更稳 | 7 | Clear and calm. |
| 3 | Tuwa 篮球训练 | 9 | 为比赛日留住状态 | 9 | Strong beachhead framing. |
| 4 | Strike Zone | 11 | 今日力量该练多少 | 8 | Keeps English metaphor, direct subtitle. |
| 5 | Tuwa 训练负荷 | 9 | 练、微调，或保持 | 8 | Maps to go/modify/hold. |

## Recommended Pair

Title: `Tuwa`

Subtitle: `Stay in your strike zone`

Reasoning: `Tuwa` preserves brand space and avoids stuffing the 30-character title with generic fitness terms. The subtitle states the distinctive promise in the canonical phrase, while screenshots and keywords can carry basketball, readiness, match, and microdose specificity.
