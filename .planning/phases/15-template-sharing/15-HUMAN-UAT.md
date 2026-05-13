---
status: partial
phase: 15-template-sharing
source: [15-VERIFICATION.md]
started: 2026-05-13T00:00:00Z
updated: 2026-05-13T00:00:00Z
---

## Current Test

[awaiting human testing]

## Tests

### 1. Share code generation and display
expected: Tapping "Share Template" context menu shows ShareCodeSheet with 8-char code, copy button works
result: [pending]

### 2. Import flow sheet transition
expected: Dismiss-then-present sequence for ShareImportPreviewSheet transitions smoothly without race condition
result: [pending]

### 3. Universal link deep link
expected: Opening tuwa.app/t/{code} link opens app directly to import preview (requires AASA file on server)
result: [pending]

### 4. Weight stripping in imported template
expected: Imported template shows nil weight values in template editor (no sharer's personal data)
result: [pending]

### 5. Expired code error message
expected: Entering expired share code shows red error text explaining code is expired
result: [pending]

## Summary

total: 5
passed: 0
issues: 0
pending: 5
skipped: 0
blocked: 0

## Gaps
