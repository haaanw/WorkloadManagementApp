---
status: testing
phase: 17-cycle-data-foundation
source: [17-01-SUMMARY.md, 17-02-SUMMARY.md, 17-03-SUMMARY.md, 17-04-SUMMARY.md, 17-VERIFICATION.md]
started: 2026-05-16T00:00:00Z
updated: 2026-05-16T00:00:00Z
---

## Current Test

number: 1
name: Cycle & Hormones section visible in Profile
expected: |
  In Profile tab, below Training Profile and above Preferences, a "CYCLE & HORMONES" section appears with 3 toggles: Hormonal Contraceptive, Pregnant, Lactating. Section only visible when cycle data exists or any flag is set. For fresh install: temporarily set one toggle via code or insert a MenstrualCycleSnapshot record.
awaiting: user response

## Tests

### 1. Cycle & Hormones section visible in Profile
expected: Profile tab shows "CYCLE & HORMONES" section header with 3 toggles (Hormonal Contraceptive, Pregnant, Lactating) between Training Profile and Preferences sections.
result: [pending]

### 2. Toggle persistence
expected: Toggle any of the 3 cycle flags ON, navigate away from Profile tab, come back. Toggle stays ON. Kill and relaunch app — toggle still ON.
result: [pending]

### 3. Design compliance — Profile section
expected: 0pt corners (no rounded rectangles), no shadows, General Sans font, 8pt grid spacing (16pt vertical padding per toggle row), ColorTokens colors only.
result: [pending]

### 4. Dashboard soft prompt banner appears
expected: On Dashboard tab, a banner appears with heading "Cycle-Aware Recovery", body copy explaining the feature, an X dismiss button (top-right), and an "Open Settings" link. Banner shows only when no cycle snapshots exist and not previously dismissed.
result: [pending]

### 5. Banner dismiss is permanent
expected: Tap X on the banner. Banner disappears. Navigate away and back — still gone. Kill and relaunch app — still gone.
result: [pending]

### 6. Design compliance — Dashboard banner
expected: 0pt corners, no shadows, hairline border (Rectangle stroke), General Sans font, ColorTokens colors.
result: [pending]

### 7. HealthKit authorization includes menstrual data
expected: When app requests HealthKit permissions (first launch or Settings > Health > Tuwa), the permission list includes menstrual cycle categories (Menstrual Flow, Contraceptive, etc.) alongside the existing heart rate/sleep types.
result: [pending]

## Summary

total: 7
passed: 0
issues: 0
pending: 7
skipped: 0
blocked: 0

## Gaps

[none yet]
