# Feature Landscape

**Domain:** iOS fitness/training app — v1.1 App Store launch readiness features
**Researched:** 2026-04-22
**Context:** Tonus is functionally complete (auth, sync, subscriptions, analytics, intelligence, onboarding). This research covers only what remains for App Store submission: ASO, push notifications, streak tracking, PDF export, QA, and performance audit.

## Table Stakes

Features users expect at App Store launch. Missing = product feels incomplete, gets rejected, or is invisible in search.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| **App Store metadata (title, subtitle, keywords, description)** | Required for submission; primary discovery mechanism. Apple indexes title (30 chars) + subtitle (30 chars) + keyword field (100 chars). Description is NOT indexed -- write for humans only. | Low | Copywriting task in App Store Connect. No code changes. |
| **App Store screenshots (6.7" + 6.5")** | Required for submission; most influential conversion factor. Users decide to install in 3 seconds based on screenshots. | Medium | Screenshot automation framework already exists. Need final marketing-quality captures with benefit-oriented captions. |
| **App Review compliance pass** | Common rejections: incomplete features, missing privacy labels, broken links, crash on launch, HealthKit misuse. One rejection delays launch by 1-2 weeks. | Medium | Must verify: PrivacyInfo.xcprivacy matches actual data usage, all links work (privacy policy, ToS, support), no placeholder text, HealthKit NSHealthShareUsageDescription accurate, subscription metadata matches RevenueCat offerings. |
| **Systematic QA pass** | App Store reviewers test edge cases. Crashes during review = automatic rejection. Users rate 1-star for bugs. | Medium | Unknown scope until bugs found. Must test: empty states, first-run without data, HealthKit denied, no network, subscription states, coach vs athlete mode switching. |
| **Performance audit** | Reviewers test on older devices. Launch time >5s or scroll hitches = poor first impression. Memory leaks crash on devices with 3GB RAM. | Medium | Profile on oldest supported device (iPhone X class, iOS 17). Target <2s cold launch. Check SwiftData @Query performance with 100+ sessions. |
| **Accessibility baseline** | Apple frequently rejects apps with insufficient VoiceOver support. Also legally advisable. Tonus uses custom fonts (DM Sans) which need explicit accessibility sizing. | Medium | VoiceOver labels on all interactive elements, Dynamic Type support for DM Sans via custom scaling, color contrast verification against DESIGN.md tokens. |

## Differentiators

Features that set Tonus apart from competitors. Not expected by every user, but valued by target audience and improve retention/conversion.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **PDF report export** | Coaches need formatted reports to share with athletes, parents, or staff. CSV is for data analysis; PDF is for communication. TrainingPeaks and TeamBuildr offer PDF exports -- coaches expect it at the Coach tier price point. | Medium | Use UIGraphicsPDFRenderer (Core Graphics) for generation -- NOT PDFKit which is viewing/modifying only. Include: date range header, weekly load summary, recovery trend, ACWR zone history, PR highlights, session log. Gate behind Pro/Coach subscription. Builds on existing CSVExportEngine data queries. |
| **Push notifications (weekly summary)** | Retention driver. Data shows 1-3 pushes/week is the safe range for fitness apps. Athlytic alerts on abnormal metrics; Alpha Progression notifies on monthly reports. A weekly summary is the minimum viable notification. | Medium | Use local notifications via UNUserNotificationCenter -- NOT remote push (APNs). Zero server infrastructure needed. Schedule recurring Monday morning delivery. Rich content: "Your week: 4 sessions, 2 PRs, recovery trending up." Ask permission in-context (after first completed week), not on first launch. |
| **Streak tracking** | Behavioral hook exploiting loss aversion -- the strongest gamification mechanic in fitness (Core Drive 8). Athlytic shows calendar streaks. Duolingo proved streaks drive daily retention. Serious athletes track consistency as a meta-metric. | Low-Medium | Track two streaks: workout streak (sessions logged) and check-in streak (wellness check-ins completed). 48-hour forgiveness window (not midnight reset) -- punishing streaks cause churn. Display on Dashboard hero area. Pure computation engine + SwiftData model + UI component. |
| **ASO-optimized listing** | Tonus competes against TrainingPeaks ("training plan"), Athlytic ("AI fitness coach"), HRV4Training ("HRV"). Long-tail keywords are winnable: "workload management", "training load tracker", "ACWR", "recovery score". | Low | Keyword research + copywriting in App Store Connect. Consider Custom Product Pages (CPPs) for separate coach vs athlete search intents -- different screenshots for "coach training app" vs "workout recovery tracker". |
| **Share cards (visual summaries)** | Athlytic's share cards got a 2025 design refresh -- athletes post recovery/workout cards to Instagram stories. Organic growth channel at zero CAC. | Low | Render SwiftUI view to image via ImageRenderer (iOS 16+). Include: readiness score, week summary, Tonus branding. Share via UIActivityViewController. Could be deferred to post-launch but low effort. |

## Anti-Features

Features to explicitly NOT build for this milestone.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| **Daily push notifications** | More than 1-3/week causes opt-out and uninstalls. Aggressive notifications are the #1 reason users disable them in fitness apps. | Weekly summary only. Streaks visible on app open handle daily motivation passively. |
| **Remote push notifications (APNs)** | Requires server infrastructure (Supabase Edge Functions or dedicated push service). Over-engineered for a weekly local reminder. Adds App Review complexity (push certificate, server-side logic). | Local notifications via UNUserNotificationCenter. Scheduled on-device. Zero server cost. |
| **Leaderboards / social comparison** | Out of scope per PROJECT.md. High complexity, moderation burden, privacy concerns with health data. | Streaks are personal only. PRs serve as self-improvement achievements. |
| **Badges / achievement system** | Over-engineered gamification for a data-driven training app. Serious athletes find it patronizing. Tonus's audience is analytical. | Streaks + PRs are the natural gamification layer. Two mechanics, not twenty. |
| **Complex PDF templates with coach branding** | Custom branding is a feature for established platforms (TrainingPeaks Enterprise, TeamBuildr). Premature for launch. | Single clean PDF template with Tonus branding. Revisit coach-customizable templates if requested post-launch. |
| **Streak shields / streak freeze purchases** | IAP gamification mechanics conflict with Tonus's serious athlete brand. Adds StoreKit complexity for minimal revenue. | 48-hour forgiveness window baked into streak logic. Merciful by default. |
| **Apple Watch companion app** | Explicitly out of scope per PROJECT.md. Separate binary, separate review, 2-3 weeks of work minimum. | HealthKit reads from Apple Watch data that syncs to iPhone automatically. |
| **Onboarding-time notification permission** | Asking for notification permission on first launch before the user sees value causes 40-60% denial rate. | Ask after the user's first completed week -- contextual permission request with preview of what they will receive. |

## Feature Dependencies

```
App Store Metadata ──> Screenshots (metadata informs screenshot captions/story)
Performance Audit ──> QA Pass (perf issues found during audit become QA items)
QA Pass ──> App Review Compliance (bugs must be fixed before compliance check)
App Review Compliance ──> Final Screenshots (capture after all fixes)

Streak Tracking ──> Dashboard UI update (display streak counters)
Streak Tracking ──> Weekly Summary content (notification includes streak count)
Weekly Summary ──> Push Notification scheduling (notification delivers summary)

CSV Export (already exists) ──> PDF Export (PDF reuses same data queries, adds layout)
PDF Export ──> Coach value prop (PDF is the coach-facing export format)

All features ──> Final QA Pass (regression check before submission)
```

## Competitor Feature Matrix

| Feature | TrainingPeaks | HRV4Training | Athlytic | Alpha Progression | Tonus (current) | Tonus (v1.1 target) |
|---------|--------------|--------------|----------|-------------------|-----------------|---------------------|
| Weekly summary | Compliance bar (premium) | In-app weekly/monthly views | Calendar + streaks | Monthly reports | Weekly summary card (exists) | Weekly summary + notification |
| Push notifications | Workout/coach alerts (premium) | Not prominent | Abnormal metric alerts | Report availability | None | Weekly local notification |
| Streak tracking | Compliance colors | Not featured | Calendar streaks | Not featured | None | Workout + check-in streaks |
| Data export | Full CSV/FIT | CSV via Dropbox/email | Share cards only | CSV | CSV (exists) | CSV + PDF |
| PDF reports | Via WKO5 integration | Not found | Not found | Not found | None | Branded PDF with charts |
| ASO optimization | Strong (dominant keywords) | Niche ("HRV") | "AI Fitness Coach" | "Gym Workout" | Not submitted | Long-tail keywords |

## MVP Recommendation

**Priority order for App Store launch (build sequence):**

1. **Streak tracking** (Low-Med) -- Pure engine + model + UI. Ships fast, adds visible engagement feature for screenshots, provides data for notifications.
2. **Push notifications - weekly summary** (Medium) -- Depends on streak data for rich content. Local-only via UNUserNotificationCenter.
3. **PDF report export** (Medium) -- Builds on existing CSVExportEngine data queries. Coach-tier differentiator.
4. **ASO metadata** (Low) -- Copywriting in App Store Connect. Informs screenshot captions. Can be done in parallel with code work.
5. **Systematic QA pass** (Medium) -- Find and fix bugs across all features including new ones.
6. **Performance audit** (Medium) -- Profile, optimize, verify on older devices.
7. **App Review compliance** (Low-Med) -- Final checklist after all features and fixes land.
8. **Final screenshots** (Medium) -- Capture with all features in place, marketing captions, real-looking data.

**Defer to post-launch:** Share cards (low effort but not blocking submission).

## Complexity Estimates

| Feature | New Files | Existing File Changes | Subscription Gate | Risk |
|---------|-----------|----------------------|-------------------|------|
| Streak tracking | ~3 (StreakEngine.swift, streak UI component, possible StreakRecord model) | DashboardView, DashboardViewModel, possibly Athlete model (streak fields) | Free (engagement) | Low -- pure computation + UI display |
| Push notifications | ~2 (NotificationService.swift, WeeklySummaryBuilder.swift) | AppRouter (permission flow), ProfileView (settings toggle), Info.plist (notification usage) | Free (retention) | Low -- local only, no server dependency |
| PDF report export | ~2 (PDFReportEngine.swift, export UI trigger) | WorkloadView or ProfileView (export button), UpgradeSheet (gate) | Pro/Coach | Medium -- Core Graphics coordinate math, chart rendering to PDF context |
| ASO metadata | 0 (App Store Connect) | None | N/A | Low -- copywriting, iterative |
| QA pass | 0 new | Bug fixes across codebase | N/A | Medium -- unknown scope |
| Performance audit | 0 new | Optimizations | N/A | Medium -- depends on findings |
| App Review compliance | 0-1 | Minor fixes | N/A | Low -- checklist |
| Screenshots | 0 new | ScreenshotTests updates | N/A | Low -- framework exists |

## Sources

- [TrainingPeaks notification management](https://help.trainingpeaks.com/hc/en-us/articles/360053198451-Manage-Alerts-Notifications-on-the-TrainingPeaks-Mobile-App)
- [TrainingPeaks premium features](https://www.trainingpeaks.com/blog/best-trainingpeaks-premium-features/)
- [Athlytic App Store listing](https://apps.apple.com/us/app/athlytic-ai-fitness-coach/id1543571755)
- [Athlytic review 2026](https://newzapiens.com/brands/athlytic)
- [Alpha Progression review 2026](https://fitnessdrum.com/alpha-progression-app-review/)
- [HRV4Training App Store listing](https://apps.apple.com/us/app/hrv4training/id686923970)
- [ASO complete guide 2026](https://asomobile.net/en/blog/aso-in-2026-the-complete-guide-to-app-optimization/)
- [iOS metadata and keyword strategy](https://dev.to/arshtechpro/ios-app-store-optimization-metadata-keyword-strategy-3f6p)
- [ASO best practices 2026 (AppTweak)](https://www.apptweak.com/en/aso-blog/app-store-optimization-aso-best-practices)
- [iOS push notification best practices 2026](https://evangelistsoftware.com/blog/the-role-of-push-notifications-in-ios-apps/)
- [UNUserNotificationCenter documentation](https://developer.apple.com/documentation/usernotifications/unusernotificationcenter)
- [Creating PDFs in Swift (Kodeco)](https://www.kodeco.com/4023941-creating-a-pdf-in-swift-with-pdfkit)
- [PDFKit Apple documentation](https://developer.apple.com/documentation/pdfkit)
- [Gamification in fitness apps (Yu-kai Chou)](https://yukaichou.com/gamification-analysis/top-10-gamification-in-fitness/)
- [Fitness app features 2025](https://geeksofkolachi.com/blogs/fitness-app-features-2025-user-engagement/)
- [Trainerize PDF export feature request](https://ideas.trainerize.com/forums/167887-coach-trainer-abc-trainerize/suggestions/45589054-exporting-workouts-programs-to-pdf)
