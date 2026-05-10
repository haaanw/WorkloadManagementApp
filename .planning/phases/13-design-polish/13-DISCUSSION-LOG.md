# Phase 13: Design Polish - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-10
**Phase:** 13-design-polish
**Areas discussed:** Font sourcing & weights, Size adjustments, TextField style approach, DESIGN.md update

---

## Font Sourcing & Weights

| Option | Description | Selected |
|--------|-------------|----------|
| FontShare — Regular + Medium | Download Alpino Regular (400) + Medium (500) from FontShare | |
| FontShare — Regular + SemiBold | Use Regular + SemiBold if no Medium weight | |
| Already have files | User already downloaded — provide filenames | ✓ |

**User's choice:** Already have files — `Alpino_Complete/` folder in project root with full font family from FontShare (ITF FFL license). OTF files: Alpino-Regular.otf and Alpino-Medium.otf selected for use.

---

## Size Adjustments

| Option | Description | Selected |
|--------|-------------|----------|
| Keep sizes, verify visually | Keep current pt sizes, adjust iteratively on device | |
| Bump all +1pt preemptively | Add 1pt across the board as starting point | |
| You decide | Claude picks approach during implementation | ✓ |

**User's choice:** Claude's discretion
**Notes:** Keep current sizes as default, adjust where Alpino's x-height causes readability issues.

---

## TextField Style Approach

| Option | Description | Selected |
|--------|-------------|----------|
| Single shared TextFieldStyle | Create `SharpTextFieldStyle`, apply everywhere. One-line change per file. | ✓ |
| ViewModifier on each | Apply `.clipShape(Rectangle())` inline at each call site | |

**User's choice:** Single shared TextFieldStyle (Recommended)

---

## DESIGN.md Update

| Option | Description | Selected |
|--------|-------------|----------|
| Update to Alpino | Replace DM Sans references with Alpino. Live source of truth. | ✓ |
| Keep DM Sans, add note | Leave original text, add migration note at top | |

**User's choice:** Update to Alpino (Recommended)

---

## Claude's Discretion

- Font size fine-tuning based on Alpino's x-height
- PostScript name verification from .otf metadata
- FontTokens.swift file naming

## Deferred Ideas

None
