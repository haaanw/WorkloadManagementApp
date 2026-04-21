# Phase 4 — Subscriptions Design

**Date:** 2026-03-25
**Status:** Approved

---

## Overview

Integrate RevenueCat to monetise the app with a Free / Pro subscription model. Free tier provides 7-day history. Pro tier unlocks full history and coach mode. Subscriptions are sold via the App Store using RevenueCat as the entitlement layer.

---

## Tier Definitions

| Feature | Free | Pro |
|---------|------|-----|
| Workout log history | Last 7 days | All time |
| Workload / ACWR charts | Last 7 days | All time |
| Coach mode (manage athletes) | Gated — upgrade prompt | ✅ |
| Being coached (accept invites, see coach-logged sessions) | ✅ Free | ✅ Free |
| Dashboard, recovery, wellness check-ins | ✅ Free | ✅ Free |

Coach features are gated **coach-side only**. An athlete on the free tier can still be invited by a Pro coach and receive coach-logged sessions. Only the coach must be Pro.

---

## RevenueCat Configuration

**Products (App Store Connect):**
- `workload_pro_monthly` — $9.99/month, 7-day introductory free trial
- `workload_pro_annual` — $79.99/year, 7-day introductory free trial

**Entitlement:** `pro` — granted by either product.

**Offering:** `default` — contains both products. Annual is the default selected option.

---

## Gating Strategy — Hybrid (Hard Gate + Teaser)

History is hard-truncated at 7 days. No blurred/locked rows are rendered. Instead, a `HistoryTeaserBanner` appears at the end of truncated lists with a personalised count of locked sessions. Tapping the banner presents `UpgradeSheet`.

Coach mode is visible in the UI but access-gated: the `ContextSwitcher` renders the coach option for all users; tapping it while non-Pro presents `UpgradeSheet` with the coach-specific headline instead of switching modes.

---

## New Components

### `SubscriptionService`

`@MainActor final class`. Owned by `AppContainer`. Wraps RevenueCat SDK.

**Responsibilities:**
- Configure RevenueCat on app launch (API key from `Config.swift`)
- Expose `isPro: Bool` (derived from `Purchases.shared.customerInfo`)
- `fetchOffering() async throws -> Offering`
- `purchase(package:) async throws`
- `restorePurchases() async throws`
- Cache entitlement locally via RevenueCat's built-in persistence — no SwiftData involvement

**Entitlement check:** `customerInfo.entitlements["pro"]?.isActive == true`

### `UpgradeSheet`

SwiftUI `.sheet`. Presented from two trigger points with different headlines:

1. **History trigger** — `"You have \(n) weeks of training history waiting"`
2. **Coach trigger** — `"Coach your athletes from one place"`

**Structure (top → bottom):**
1. Context-aware headline + subtitle
2. Plan toggle: Annual (pre-selected, "BEST VALUE") / Monthly
3. Primary CTA: `"Start 7-Day Free Trial"` (or `"Subscribe"` if trial already used — determined by `Package.storeProduct.introductoryDiscount`)
4. Single-line feature summary: `"Full history · Coach mode · Advanced charts"`
5. "Team plans — coming soon" note (small, muted)
6. Footer: `"Restore purchases"` · `"Terms"` · `"Privacy"`

### `HistoryTeaserBanner`

Reusable banner view rendered at the bottom of `WorkoutLogView`'s session list and `WorkloadView`'s chart/history area when `!isPro`.

Counts total `WorkoutSession` records in SwiftData, subtracts the visible 7-day set, derives weeks. Example text: `"14 weeks of training data locked — unlock with Pro"`. Tapping presents `UpgradeSheet(trigger: .history(lockedWeeks: n))`.

---

## Integration Points

### `AppContainer`

Add `subscriptionService: SubscriptionService`. Initialise first, before `AuthService`, so entitlement state is available before the first view render. `Purchases.configure(withAPIKey:)` is called inside `SubscriptionService.init()` — not in `AppRouter` or `WorkloadApp`.

`isPro` is a stored `var` (not a computed property) so `@Observable` can track changes. Updated inside a `Purchases.shared.getCustomerInfo` callback and after each `purchase()` / `restorePurchases()` call — views re-render reactively.

### `WorkoutLogView`

- `@Query` fetches all sessions (SwiftData `@Query` requires compile-time predicates; runtime `isPro` cannot be passed in directly)
- ViewModel post-filters the result set to 7 days when `!isPro`; or use a `FetchDescriptor` with a dynamic predicate inside the ViewModel's load path
- After the last visible row, conditionally show `HistoryTeaserBanner`

### `WorkloadView`

- Chart data and history list filtered to 7 days when `!isPro` (same post-filter approach)
- `HistoryTeaserBanner` shown below the chart

### `ContextSwitcher`

- Renders coach option regardless of entitlement
- Tapping coach option while `!isPro`: present `UpgradeSheet(trigger: .coach)` instead of switching mode

---

## Edge Cases

| Scenario | Behaviour |
|----------|-----------|
| Subscription lapses (coach) | `ContextSwitcher` re-gates coach mode. Existing `CoachAthleteRelationship` records persist in SwiftData — restored when Pro is renewed. |
| Restore purchases | `SubscriptionService.restorePurchases()` re-fetches `customerInfo`, updates `isPro`. Views rerender reactively. |
| Network offline | RevenueCat caches last-known entitlement locally. App uses cached state — no gating on offline. |
| Trial already used | `Package.storeProduct.introductoryDiscount` is nil — CTA changes to `"Subscribe"`. No free trial CTA shown. |
| Free athlete coached by Pro coach | No gating applied. Athlete sees all coach-logged sessions regardless of own tier. |

---

## Out of Scope (Phase 4)

- **Team plan** — multi-coach shared roster for clubs/squads. Requires workspace architecture and B2B sales flow (Stripe + web dashboard). Planned for a future phase. Signalled on the paywall as "coming soon."
- **Web paywall / Stripe** — App Store only for Phase 4.
- **Promotional codes / referrals** — RevenueCat supports these but not wired in Phase 4.
- **Analytics / conversion funnel** — RevenueCat dashboard provides baseline; no custom events in Phase 4.

---

## Open Questions (resolved)

| Question | Decision |
|----------|----------|
| Soft vs hard gate | Hybrid: hard cutoff + teaser banner |
| Free trial | On request — CTA on paywall sheet |
| Coach gating | Coach-side only |
| Pricing | $9.99/mo · $79.99/yr |
| Paywall layout | Context-aware headline, pricing above fold |
| Team tier | Out of scope Phase 4 — signal "coming soon" |
