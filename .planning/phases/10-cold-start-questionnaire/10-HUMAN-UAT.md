---
status: partial
phase: 10-cold-start-questionnaire
source: [10-VERIFICATION.md]
started: 2026-05-08T00:00:00Z
updated: 2026-05-08T00:00:00Z
---

## Current Test

[awaiting human testing]

## Tests

### 1. TrainingProfileCard renders on dashboard
expected: Dashboard shows card with "TRAINING PROFILE" micro-caps, "Set up your training profile" title, "Complete Profile" button with hairline border. Card placed after WelcomeActionCard.
result: [pending]

### 2. Questionnaire form interaction and EST annotations
expected: Save Profile disabled until all 4 required fields set. After save, sheet dismisses, dashboard shows estimated ATL/CTL/ACWR/TSB with "EST" label below each. TrainingProfileCard disappears.
result: [pending]

### 3. "Building baseline..." cold-start card
expected: During cold-start, "Building baseline..." text replaces FatigueAttentionBanner. Label font, text2 color, surface background, hairline border.
result: [pending]

### 4. ProfileView Training Profile section
expected: Between ATHLETE and PREFERENCES sections. Shows 4 summary rows if profile exists, "Set up training profile" if not. "Edit Profile" opens TrainingProfileSheet with pre-filled values.
result: [pending]

## Summary

total: 4
passed: 0
issues: 0
pending: 4
skipped: 0
blocked: 0

## Gaps
