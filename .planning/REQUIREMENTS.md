# Requirements: Tonus

**Defined:** 2026-04-22
**Core Value:** Recovery + load tracked over time — giving athletes long-term insight into how their body responds to training, so they can train smarter and avoid injury.

## v1.1 Requirements

Requirements for App Store launch. Each maps to roadmap phases.

### Streaks

- [ ] **STRK-01**: User can see current workout streak (consecutive weeks with 1+ logged session) on dashboard
- [ ] **STRK-02**: Dashboard displays streak badge showing current streak count

### Notifications

- [ ] **NOTF-01**: User receives weekly local push notification summarizing sessions, PRs, and streak
- [ ] **NOTF-02**: App shows pre-permission screen explaining notification value before iOS permission dialog
- [ ] **NOTF-03**: User can configure notification day/time and toggle on/off in Profile settings

### Export

- [ ] **EXPRT-01**: User can generate PDF athlete report with recovery scores, workload trends, and PRs (composite data only)
- [ ] **EXPRT-02**: Coach can generate PDF multi-athlete summary report
- [ ] **EXPRT-03**: PDF export is gated behind Pro/Coach subscription (free users retain CSV)

### App Store Metadata

- [ ] **ASO-01**: App Store listing has optimized title (30 chars), subtitle (30 chars), and keyword field (100 chars)
- [ ] **ASO-02**: App Store description communicates core value proposition
- [ ] **ASO-03**: Marketing screenshots with benefit-oriented captions for 6.7" and 6.5" device sizes
- [ ] **ASO-04**: App Store categories and age rating configured correctly

### App Review Compliance

- [ ] **CMPL-01**: Pre-seeded demo account with 2-3 weeks of data for App Review team
- [ ] **CMPL-02**: PrivacyInfo.xcprivacy audit passes (all API declarations accurate)
- [ ] **CMPL-03**: Subscription terms, restore purchase, and cancellation flows verified
- [ ] **CMPL-04**: All in-app links (privacy policy, ToS, support) resolve correctly
- [ ] **CMPL-05**: HealthKit usage descriptions are accurate and detailed in Review Notes

### QA & Performance

- [ ] **QA-01**: Systematic QA pass across all user flows, edge cases, and empty states
- [ ] **QA-02**: Performance audit — cold launch < 2s, 60fps scroll, no memory leaks
- [ ] **QA-03**: Accessibility audit — VoiceOver navigation, Dynamic Type support, contrast compliance
- [ ] **QA-04**: MetricKit telemetry integrated for post-launch crash and performance reporting

## Future Requirements

### Deferred from v1.1

- **STRK-03**: Check-in streak (consecutive days/weeks with wellness check-ins)
- **STRK-04**: Streak freeze/forgiveness (48-hour grace period)
- **SHARE-01**: Share cards (social summaries via ImageRenderer)
- **NOTF-04**: Remote push notifications for coach-assigns-workout events
- **ASO-05**: Custom Product Pages for athlete vs coach search intents

## Out of Scope

| Feature | Reason |
|---------|--------|
| Real-time chat between coach and athlete | High complexity, not core to training insight |
| Social/sharing features | Focus on individual athlete value first |
| Video analysis | Different product category |
| Android | iOS-first, revisit after establishing market fit |
| Apple Watch companion app | Defer until core iOS experience is polished |
| Manual mesocycle/ATP planner | TrainingPeaks owns this space; Tonus's value is automated detection |
| AI chatbot / conversational coach | LLM cost + liability; keep autoregulation rule-based |
| Remote push notifications | Defer to v1.2 when event-driven coach actions need server-side triggers |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| STRK-01 | — | Pending |
| STRK-02 | — | Pending |
| NOTF-01 | — | Pending |
| NOTF-02 | — | Pending |
| NOTF-03 | — | Pending |
| EXPRT-01 | — | Pending |
| EXPRT-02 | — | Pending |
| EXPRT-03 | — | Pending |
| ASO-01 | — | Pending |
| ASO-02 | — | Pending |
| ASO-03 | — | Pending |
| ASO-04 | — | Pending |
| CMPL-01 | — | Pending |
| CMPL-02 | — | Pending |
| CMPL-03 | — | Pending |
| CMPL-04 | — | Pending |
| CMPL-05 | — | Pending |
| QA-01 | — | Pending |
| QA-02 | — | Pending |
| QA-03 | — | Pending |
| QA-04 | — | Pending |

**Coverage:**
- v1.1 requirements: 21 total
- Mapped to phases: 0
- Unmapped: 21 ⚠️

---
*Requirements defined: 2026-04-22*
*Last updated: 2026-04-22 after initial definition*
