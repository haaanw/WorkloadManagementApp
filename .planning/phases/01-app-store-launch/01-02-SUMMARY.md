---
phase: 01-app-store-launch
plan: 02
subsystem: screenshots
tags: [app-store, screenshots, marketing, automation]
dependency_graph:
  requires: [01-01]
  provides: [framed-screenshots]
  affects: [app-store-connect-upload]
tech_stack:
  added: [CoreGraphics-scripting]
  patterns: [xcuitest-screenshot-capture, cg-based-image-composition]
key_files:
  created:
    - scripts/frame_screenshots.swift
  modified:
    - workload management/ScreenshotTests/ScreenshotTests.swift
decisions:
  - Used iPhone 17 Pro Max (6.7") and iPhone 17 Pro (6.3") as simulators since iPhone 15 series was unavailable
  - Used CoreGraphics for frame composition instead of SwiftUI ImageRenderer for reliability
metrics:
  duration: ~25min
  completed: 2026-04-20
---

# Phase 01 Plan 02: App Store Screenshots Summary

Marketing-framed screenshots for 4 screens at 2 device sizes using XCUITest capture and CoreGraphics frame composition with DM Sans headlines.

## Tasks Completed

| Task | Description | Commit | Key Files |
|------|-------------|--------|-----------|
| 1 | Capture raw screenshots and create marketing frame script | eb64176 | scripts/frame_screenshots.swift |
| 2 | Human verification - user approved screenshots | - | - |

## What Was Built

- **XCUITest screenshots** captured for Dashboard, Recovery, Workload, and ActiveWorkout screens
- **Frame script** (`scripts/frame_screenshots.swift`) that composites raw screenshots into marketing-ready images with:
  - Flat rectangular device frame (no rounded corners, no shadows)
  - DM Sans Medium headline text above each screenshot
  - Warm off-white background (#F4F1ED)
  - 8pt grid spacing throughout
- **8 final images** output to `/tmp/AppStoreScreenshots/` in two size directories:
  - `6_7_framed/` (1320x2868 - iPhone 17 Pro Max)
  - `6_3_framed/` (1206x2622 - iPhone 17 Pro)

## Headlines Applied

| Screen | Headline |
|--------|----------|
| Dashboard | Know Your Readiness |
| Recovery | Recovery, Decoded |
| Workload | Track Training Load |
| ActiveWorkout | Log Every Rep |

## Deviations from Plan

### Device Simulator Availability

**1. [Rule 3 - Blocking] Used iPhone 17 series instead of iPhone 15**
- **Found during:** Task 1
- **Issue:** iPhone 15 Pro Max and iPhone 15 Pro simulators were not available in the Xcode environment; only iPhone 17 series was installed
- **Fix:** Used iPhone 17 Pro Max (6.7") and iPhone 17 Pro (6.3") which produce the same resolution screenshots required by App Store Connect
- **Files modified:** workload management/ScreenshotTests/ScreenshotTests.swift

### Implementation Approach

**2. [Rule 3 - Blocking] Used CoreGraphics instead of SwiftUI ImageRenderer**
- **Found during:** Task 1
- **Issue:** SwiftUI ImageRenderer requires a running app context and is unreliable in script-only execution
- **Fix:** Implemented frame composition using CoreGraphics (CGContext, CGImage) which runs standalone as a Swift script
- **Files modified:** scripts/frame_screenshots.swift

## Known Stubs

None - all screenshots are fully rendered with real framing logic.

## Self-Check: PASSED
