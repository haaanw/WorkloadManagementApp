---
status: partial
phase: 05-streaks-notifications
source: [05-VERIFICATION.md]
started: 2026-04-22T13:10:00Z
updated: 2026-04-22T13:10:00Z
---

## Current Test

[awaiting human testing]

## Tests

### 1. Streak row visual appearance and conditional hide
expected: Flame icon, numeric streak count, "week streak" label in expanded WeeklySummaryCard. Hidden when no current-week sessions.
result: [pending]

### 2. Pre-permission card first-visit flow
expected: Card visible once below WeeklySummaryCard, permanently dismissed by either button, no system dialog on "Not Now".
result: [pending]

### 3. Enable Notifications full flow
expected: iOS system permission sheet on tap, card disappears if granted, notification scheduled for Sunday 7 PM.
result: [pending]

### 4. Profile NOTIFICATIONS section — toggle and picker interactions
expected: Toggle on triggers auth, schedules notification; day/time changes reschedule; toggle off cancels; pickers disabled when off.
result: [pending]

### 5. Denied authorization state guidance
expected: Toggle reverts to off; guidance text appears below toggle row when notifications denied in Settings.
result: [pending]

### 6. Notification delivery verification
expected: Local notification on lock screen with title "Your Week in Review" and body with session count, streak, PR data.
result: [pending]

## Summary

total: 6
passed: 0
issues: 0
pending: 6
skipped: 0
blocked: 0

## Gaps
