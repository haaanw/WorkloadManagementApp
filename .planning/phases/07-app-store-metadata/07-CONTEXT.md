# Phase 7: App Store Metadata - Context

**Gathered:** 2026-04-26
**Status:** Ready for planning

<domain>
## Phase Boundary

App Store listing is optimized for discoverability and conversion — title, subtitle, keyword field, description, marketing screenshots with captions, categories, age rating. Also adds Apple Sign-In and Google Sign-In as authentication options (required for App Review compliance).

</domain>

<decisions>
## Implementation Decisions

### App Store Copy
- **D-01:** Data-driven athlete tone — technical, performance-focused. Target serious lifters, runners, and coaches who recognize training load terminology.
- **D-02:** Claude's discretion on metric specificity — recommended approach: lead with benefits/outcomes, mention ACWR/HRV/EWMA in feature detail section for credibility.

### Keyword Strategy
- **D-03:** Primary keyword focus is workload management — "training load", "ACWR", "overtraining prevention", "workload tracking". Niche but high-intent athletes.
- **D-04:** Claude's discretion on competitor name targeting in keyword field.

### Screenshot Content
- **D-05:** 6 screenshots — Dashboard (hero readiness), Workload charts, Recovery view, Workout log, Coach roster, PDF export. Covers full value prop for both athlete and coach users.
- **D-06:** Benefit-oriented captions — outcome-focused phrases like "Know when to push, when to rest", not feature labels.
- **D-07:** Screenshots for both 6.7" (iPhone 15 Pro Max / iPhone 16 Pro Max) and 6.5" (iPhone 11 Pro Max) device sizes per ASO-03.

### Categories & Age Rating
- **D-08:** Primary category: Health & Fitness. Secondary category: Claude's discretion (Sports likely).
- **D-09:** Age rating: 4+ (no objectionable content, health data is user's own).

### Authentication — Social Login
- **D-10:** Add Apple Sign-In — mandatory per App Review when offering any sign-in method. Use Supabase Auth Apple provider.
- **D-11:** Add Google Sign-In — popular option, use Supabase Auth Google provider. Requires GoogleService-Info.plist.
- **D-12:** Keep existing email/password authentication — social logins supplement, don't replace.
- **D-13:** Login/SignUp views need updating to show all three auth options.

### Claude's Discretion
- Metric specificity in description (D-02) — recommended: benefits first, metrics in detail
- Competitor names in keywords (D-04)
- Secondary App Store category (D-08)
- Screenshot caption exact wording
- Social login button ordering and styling on LoginView/SignUpView (follow Apple HIG for Sign in with Apple button placement)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Design System
- `DESIGN.md` — All visual decisions (0pt corners, no shadows, DM Sans, 8pt grid, accent rules)

### Requirements
- `.planning/REQUIREMENTS.md` — ASO-01 through ASO-04 acceptance criteria

### Existing Infrastructure
- `WorkloadApp/App/AppRouter.swift` — SCREENSHOT_MODE flag, auth flow routing
- `workload management/ScreenshotTests/ScreenshotTests.swift` — Existing screenshot automation
- `WorkloadApp/Views/Auth/LoginView.swift` — Current email/password login (needs social login buttons)
- `WorkloadApp/Views/Auth/SignUpView.swift` — Current sign-up flow (needs social login buttons)
- `WorkloadApp/Services/AuthService.swift` — Supabase Auth service (needs Apple/Google providers)

### Apple Guidelines
- Apple Human Interface Guidelines: Sign in with Apple button requirements
- App Store Connect metadata field limits: title (30 chars), subtitle (30 chars), keywords (100 chars)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `SCREENSHOT_MODE` launch argument: bypasses auth, seeds mock data in DEBUG builds
- `ScreenshotTests.swift`: XCUITest target for automated screenshot capture
- `AuthService`: Supabase Auth wrapper — already supports email/password, needs Apple/Google provider methods
- `SubscriptionService.overrideForScreenshots()`: Forces Pro/Coach state for screenshot capture

### Established Patterns
- Auth flow: AppRouter checks Keychain → LoginView / MainTabView routing
- Supabase Swift SDK handles all auth providers — adding Apple/Google is configuration + UI
- Screenshot tests use XCUIApplication with launch arguments

### Integration Points
- LoginView/SignUpView: Add Apple/Google sign-in buttons
- AuthService: Add `signInWithApple()` and `signInWithGoogle()` methods
- AppRouter: Handle social auth callback URLs
- Info.plist: URL schemes for Google Sign-In callback
- ScreenshotTests: Capture 6 screens at two device sizes

</code_context>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches for ASO copy, keyword research, and screenshot composition.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 07-app-store-metadata*
*Context gathered: 2026-04-26*
