---
status: partial
phase: 02-analytics-export
source: [02-VERIFICATION.md]
started: 2026-04-20T00:00:00Z
updated: 2026-04-20T00:00:00Z
---

## Current Test

[awaiting human testing]

## Tests

### 1. Time-range chart switching
expected: Tap 4W/12W/6M segments and chart redraws with animation
result: [pending]

### 2. Chart tooltip on drag
expected: Drag across chart, TooltipBubble appears showing values and disappears on release
result: [pending]

### 3. Recovery-load correlation chart rendering
expected: BarMark (ATL) + LineMark (recovery) overlay displays correctly with scaled axes
result: [pending]

### 4. WeeklySummaryCard collapse persistence
expected: Collapse card, kill app, relaunch — collapsed state preserved via AppStorage
result: [pending]

### 5. CSV export flow
expected: Pro user sees share sheet with .csv (correct headers, no biometric fields); free user sees UpgradeSheet
result: [pending]

### 6. Staleness badge
expected: After 24h+ without HealthKit data, badge appears on affected metrics in Dashboard
result: [pending]

## Summary

total: 6
passed: 0
issues: 0
pending: 6
skipped: 0
blocked: 0

## Gaps
