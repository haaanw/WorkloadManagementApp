# Screenshot Copy Draft

Prep-only draft. Do not publish until screenshot surfaces are confirmed after the n=1 dogfood gate.

Each frame includes one headline and one subline in English and zh-Hans. English headline target: 6 words or fewer. English subline target: 12 words or fewer.

## Verification Notes

- Verdict card, adjusted top set, strike-zone bar, accept/keep/feel controls: `WorkloadApp/App/AppShell.swift`, `WorkloadApp/Services/VerdictDecision.swift`
- Match proximity microdose reason: `WorkloadApp/Services/TodayVerdictEngine.swift`, `WorkloadApp/Services/VerdictReasonBuilder.swift`
- Next match section: `WorkloadApp/Views/WorkoutLog/NextMatchSection.swift`, `WorkloadApp/App/AppShell.swift`
- Match tier logging and basketball context: `WorkloadApp/Models/Enums.swift`, `WorkloadApp/Views/WorkoutLog/ActiveWorkoutSheet.swift`
- HealthKit HRV / RHR / sleep recovery detail: `WorkloadApp/App/AppShell.swift`, `WorkloadApp/Services/ReadinessFusionEngine.swift`
- Plan input: `WorkloadApp/App/AppShell.swift`, `WorkloadApp/Models/WorkoutTemplate.swift`, `WorkloadApp/Models/PrescribedWorkout.swift`

## Frames

| # | Screen | EN Headline | EN Subline | zh-Hans Headline | zh-Hans Subline |
|---:|---|---|---|---|---|
| 1 | Workout Log -> Today verdict card | Microdose before match day | Cap the top set. Skip back-offs. | 比赛前 microdose | 封顶 top set，跳过 back-off。 |
| 2 | Workout Log -> Verdict card strike-zone bar | Stay in your strike zone | Today's number lands inside the band. | 留在今日区间 | 今天的数字落在合适范围内。 |
| 3 | Workout Log -> Next match section | Match timing matters | Set the date. Tuwa tightens nearby lifts. | 比赛时间很重要 | 设置日期，临近时自动收紧训练。 |
| 4 | Active Workout -> Match tier / session context | Games hit legs | Log pickup, scrimmage, or match context. | 比赛会打到腿 | 记录野球、对抗赛或正式比赛。 |
| 5 | Recovery Detail -> HealthKit metrics | Readiness from real signals | HRV, RHR, and sleep shape today. | 真实信号看准备度 | HRV、静息心率和睡眠影响今天。 |
| 6 | Workout Start / Plan Today -> Plan input | Your plan stays yours | Accept the trim, or keep the plan. | 计划仍然属于你 | 接受微调，或坚持原计划。 |

## Notes For Screenshot Production

- Frame 4 should not imply cross-modal carry currently changes verdicts. Use a match-tier or session-context screen, not a verdict-result screen, unless the gated cross-modal verdict path is explicitly enabled later.
- Frame 1 may show `Microdose` only when `matchProximity` is true and the verdict is modified.
- Frame 3 should show a scheduled match date, not a future projection or recurring schedule.
- Frame 6 should show the suggest-and-confirm controls or plan input, emphasizing that Tuwa modulates the athlete's authored plan rather than writing a new one.
