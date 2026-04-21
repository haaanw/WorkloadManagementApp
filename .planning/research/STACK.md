# Technology Stack

**Project:** Tonus - Training Analytics, Periodization Detection, and Data Export
**Researched:** 2026-04-20

## Current Stack (Keep As-Is)

These are already in the project and remain the correct choices. No changes needed.

| Technology | Purpose | Status |
|------------|---------|--------|
| SwiftUI + SwiftData | UI + persistence | Existing, keep |
| Swift Charts | Data visualization | Existing, keep |
| HealthKit | Biometric data (HRV, RHR, sleep) | Existing, keep |
| Supabase Swift SDK | Auth + sync | Existing, keep |
| RevenueCat | Subscriptions | Existing, keep |

## New Stack Additions

### Training Analytics Engine

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| Accelerate (vDSP) | Apple framework (iOS 17+) | Vectorized math for trend analysis, moving averages, correlation | Already on device, zero dependency cost. vDSP provides optimized sliding window operations, mean/variance calculations, and cross-correlation -- exactly what periodization detection and fatigue pattern analysis need. Faster than naive Swift loops on large datasets (28-90 day windows). | HIGH |

**Rationale:** The app already has EWMA calculations in `WorkloadCalculator.swift` using simple arithmetic. For the new analytics features (weekly summaries over 12+ weeks, periodization detection over 90+ days, fatigue-recovery correlation), Accelerate/vDSP provides hardware-accelerated vector operations. No SPM dependency -- it ships with iOS.

**What NOT to use:**
- Create ML / Core ML for periodization detection. Overkill. The patterns (progressive overload phases, deload weeks, volume cycling) are detectable with straightforward statistical analysis (slope of CTL over rolling windows, variance of weekly volume). ML adds model management complexity with no benefit for structured numerical time series this small.
- Third-party stats libraries (SwiftNumerics, Surge). Accelerate covers everything needed and has zero dependency overhead.

### Data Export - CSV

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| No library (native String building) | N/A | CSV export | CSV generation for workout/snapshot data is trivially simple -- join columns with commas, rows with newlines, escape quotes. The app's data models already conform to Codable. Adding CodableCSV (0.6.7) for this would be dependency overhead for ~30 lines of code. | HIGH |

**What NOT to use:**
- CodableCSV (dehesa/CodableCSV). Good library, but the app only needs to WRITE CSV, never parse it. Writing CSV is trivial in Swift. The overhead of an SPM dependency is not justified.
- SwiftCSV. Same reasoning -- read-focused library, unnecessary for export-only use case.

### Data Export - PDF Reports

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| ImageRenderer + UIGraphicsPDFRenderer | Apple framework (iOS 16+) | PDF report generation with embedded charts | ImageRenderer can snapshot any SwiftUI view (including Swift Charts) into a CGContext. UIGraphicsPDFRenderer handles multi-page PDF document creation. Combined, they let you compose report pages in SwiftUI, then render to PDF. Zero dependencies. | HIGH |

**Rationale:** The app already uses SwiftUI views for all its charts (workload trends, recovery scores, HRV charts). ImageRenderer captures these views pixel-perfectly into a PDF context. UIGraphicsPDFRenderer manages pages, metadata, and file output. This is the Apple-blessed approach as of iOS 16+ and works well for reports that are essentially "print this screen."

**What NOT to use:**
- TPPDF (techprimate/TPPDF, v2.x). Good for programmatic PDF layout (invoices, forms), but the app's PDF reports should mirror its existing SwiftUI charts and layouts. Rendering existing views via ImageRenderer is simpler and visually consistent. TPPDF would mean rebuilding chart layouts in a different API.
- WebKit-based HTML-to-PDF. Heavyweight, requires loading a WKWebView offscreen, unreliable timing, and doesn't leverage existing SwiftUI components.

### Chart Enhancements for Analytics

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| Swift Charts (enhanced usage) | iOS 17+ | Scrollable charts, annotations, multi-series overlays | Already a dependency. iOS 17 added `chartScrollableAxes()`, `chartXVisibleDomain()`, and `chartScrollPosition()` for scrollable time-series charts. Annotations via `.annotation()` modifier on marks. | MEDIUM |

**Caveat (iOS 18 regression):** There is a known issue where annotation popover and horizontal scrolling conflict in iOS 18 -- tap gestures and scroll gestures interfere. Workaround: use a ZStack with two overlaid charts (one scrollable for data, one static for annotation overlay). This is documented in Apple Developer Forums and should be accounted for in implementation.

**What NOT to use:**
- DGCharts (formerly Charts by Daniel Gindi). Was the go-to before Swift Charts existed. Now redundant -- Apple's Swift Charts covers line, bar, area, and rule marks needed for training analytics. DGCharts adds ~2MB binary size and a large API surface for no benefit over the native framework.

### Sharing / Export Delivery

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| UIActivityViewController / ShareLink | Apple framework | Share CSV/PDF via system share sheet | Standard iOS sharing. ShareLink (SwiftUI-native, iOS 16+) or UIActivityViewController for more control. Supports AirDrop, email, Files, iCloud, third-party apps. | HIGH |

## Periodization Detection - Algorithm Stack (No Libraries)

This is custom business logic, not a library decision. Documenting the approach here because it drives architecture.

**Detection approach:** Statistical analysis on existing EWMA time series data.

| Analysis | Method | Input | Output |
|----------|--------|-------|--------|
| Phase detection (accumulation/intensification/deload) | Slope of CTL over 7-14 day windows | WorkloadSnapshot.ctl history | Phase label + duration |
| Volume cycling | Coefficient of variation of weekly TSS | WorkoutSession.tss grouped by week | Periodization quality score |
| Overreaching detection | TSB sustained below -20 for 5+ days | WorkloadSnapshot.tsb history | Warning flag + duration |
| Fatigue-recovery correlation | Pearson correlation between daily TSS and next-day recovery score | WorkloadSnapshot + RecoverySnapshot | Correlation coefficient + lag |
| Weekly summary | Aggregation (sum TSS, mean recovery, session count, volume delta vs prior week) | Existing snapshots + sessions | WeeklySummary struct |

**Why no ML:** The dataset per athlete is small (30-180 days of daily snapshots). Classical statistics (mean, slope, variance, correlation) are interpretable, debuggable, and deterministic. ML would require a training corpus the app doesn't have.

**Accelerate usage:** `vDSP.linearRegression` for slope detection, `vDSP.meanSquare` for variance, `vDSP.multiply` + `vDSP.add` for correlation. Falls back to simple Swift if arrays are too small (< 7 elements).

## Full Dependency List

### SPM Dependencies (existing, no additions)

```
https://github.com/supabase/supabase-swift
https://github.com/RevenueCat/purchases-ios.git
```

### Apple Frameworks (existing + expanded usage)

```
SwiftUI          -- UI
SwiftData        -- Persistence
Charts           -- Visualization (expanded: scrolling, annotations, multi-series)
HealthKit        -- Biometrics
Accelerate       -- NEW: vectorized math for analytics (add to project, no SPM needed)
UIKit            -- PDF rendering (UIGraphicsPDFRenderer, ImageRenderer)
UniformTypeIdentifiers -- NEW: file type declarations for export (CSV, PDF UTIs)
```

### No New SPM Dependencies

The entire analytics + export feature set can be built with Apple frameworks only. This is intentional:

1. **Zero dependency risk** -- no third-party breakage on Xcode/iOS updates
2. **Smaller binary** -- no added framework size
3. **Consistent with existing architecture** -- the app's engines are pure structs with static methods; adding Accelerate fits this pattern perfectly
4. **App Store review** -- fewer dependencies = fewer potential rejection vectors

## Alternatives Considered

| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| Analytics math | Accelerate (vDSP) | Create ML | Overkill for small structured time series; adds model management |
| Analytics math | Accelerate (vDSP) | Surge / SwiftNumerics | Extra dependency for what Accelerate already provides |
| CSV export | Native String building | CodableCSV 0.6.7 | Only writing CSV, never parsing; 30 lines of code vs a dependency |
| PDF reports | ImageRenderer + UIGraphicsPDFRenderer | TPPDF 2.x | Reports mirror existing SwiftUI views; TPPDF would duplicate layout code |
| PDF reports | ImageRenderer + UIGraphicsPDFRenderer | HTML-to-PDF via WKWebView | Heavyweight, unreliable, doesn't leverage SwiftUI |
| Charts | Swift Charts (Apple) | DGCharts | Native framework covers all needed chart types; no benefit from third-party |
| Periodization | Classical statistics | Core ML | Dataset too small per athlete; stats are interpretable and deterministic |

## Installation

No new SPM packages to install. Add framework imports where needed:

```swift
import Accelerate  // In analytics engines
import UniformTypeIdentifiers  // In export service
```

For Accelerate, add to the Xcode project's "Frameworks, Libraries, and Embedded Content" if not already linked (usually auto-linked on import).

## Sources

- [vDSP Apple Documentation](https://developer.apple.com/documentation/accelerate/vdsp) -- HIGH confidence
- [UIGraphicsPDFRenderer Apple Documentation](https://developer.apple.com/documentation/uikit/uigraphicspdfrenderer) -- HIGH confidence
- [ImageRenderer Apple Documentation](https://developer.apple.com/documentation/swiftui/imagerenderer) -- HIGH confidence
- [Swift Charts scrolling (iOS 17)](https://swiftwithmajid.com/2023/07/25/mastering-charts-in-swiftui-scrolling/) -- MEDIUM confidence
- [Swift Charts iOS 18 annotation+scroll conflict](https://developer.apple.com/forums/thread/775162) -- MEDIUM confidence
- [CodableCSV GitHub](https://github.com/dehesa/CodableCSV) -- evaluated and rejected
- [TPPDF GitHub](https://github.com/techprimate/TPPDF) -- evaluated and rejected
- [EWMA ACWR sports science](https://pubmed.ncbi.nlm.nih.gov/28003238/) -- HIGH confidence (validates existing approach)
