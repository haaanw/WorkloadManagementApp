# Phase 23: Multi-language in-app support (Simplified Chinese) - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-26
**Phase:** 23-multi-language-in-app-support-simplified-chinese
**Areas discussed:** Scope + terminology, String catalog tech, Locale switching UX, CJK font fallback, Translation workflow, Dynamic user content, First-launch default

---

## Gray Area Selection

| Option | Description | Selected |
|--------|-------------|----------|
| Scope + terminology | What gets localized AND how technical terms (ACWR/HRV/TSS) are handled. | ✓ |
| String catalog tech | Xcode 15 .xcstrings vs legacy .strings. | ✓ |
| Locale switching UX | System locale only vs in-app picker; live vs restart. | ✓ |
| CJK font fallback | System PingFang SC vs bundled Noto/Source Han Sans. | ✓ |

**User's choice:** All four areas.

---

## Localization Scope

| Option | Description | Selected |
|--------|-------------|----------|
| Core UI strings | All View labels, buttons, tabs, alerts, empty states, onboarding. | ✓ |
| Errors + paywall + legal | Auth/sync errors, UpgradeSheet, privacy + ToS. | ✓ |
| Push notifications | Streak/reminder copy localized per device locale. | ✓ |
| App Store metadata | Localized ASC name, description, screenshots, keywords. | ✓ |

**User's choice:** All four scopes ship in this phase.

---

## Technical Terminology

| Option | Description | Selected |
|--------|-------------|----------|
| Keep English acronyms | ACWR/HRV in Latin — common in CN sport-science community. | |
| Hybrid: Chinese + acronym | 训练负荷比 (ACWR), 心率变异性 (HRV) — educational, longer strings. | ✓ |
| Full translation | Chinese-only — max localization, less familiar to serious athletes. | |

**User's choice:** Hybrid.
**Notes:** Final Chinese glossary to be proposed by researcher; first occurrence per screen uses hybrid form.

---

## String Catalog Technology

| Option | Description | Selected |
|--------|-------------|----------|
| Xcode 15 .xcstrings | Modern catalog, auto-extract, per-string state, native plurals. | ✓ |
| Legacy .strings + .stringsdict | Manual extraction, broad tooling. | |

**User's choice:** .xcstrings.

---

## Locale Switching UX

| Option | Description | Selected |
|--------|-------------|----------|
| System locale only | User changes language in iOS Settings; zero in-app UI. | |
| In-app picker (Profile), restart | Picker with restart prompt — easier to implement cleanly. | |
| In-app picker, live switch | Custom environment locale, reload root view; most polish. | ✓ |

**User's choice:** In-app picker, live switch.

---

## CJK Font Handling

| Option | Description | Selected |
|--------|-------------|----------|
| System PingFang SC fallback | Zero bundle cost, native look, aesthetic mismatch w/ Latin. | |
| Bundle Noto / Source Han Sans SC | Consistent aesthetic, +5–15 MB bundle. | ✓ |
| PingFang SC now, revisit later | Ship system fallback, evaluate user feedback first. | |

**User's choice:** Bundle Noto / Source Han Sans SC.
**Notes:** Researcher picks specific family + weights matching General Sans Regular/Medium; bundle-size budget +8 MB.

---

## Translation Workflow

| Option | Description | Selected |
|--------|-------------|----------|
| LLM-assisted draft, you review | Claude/Codex drafts, user reviews + edits in Xcode catalog. | ✓ |
| You write manually | Full manual control, slow. | |
| Professional translator | Outsource; budget + turnaround required. | |

**User's choice:** LLM-assisted draft + human review.

---

## Dynamic User Content

| Option | Description | Selected |
|--------|-------------|----------|
| Store as-entered, no translation | User content stays in entered language. | ✓ |
| Tag content with locale, warn on mismatch | Source-locale stored, mismatch indicator. | |

**User's choice:** As-entered, no translation.

---

## First-Launch Default

| Option | Description | Selected |
|--------|-------------|----------|
| Match system locale silently | Standard iOS behavior, no prompt. | |
| Match system, allow change in onboarding | Language step in onboarding (and tip for existing users). | ✓ |

**User's choice:** Match system + onboarding step.

---

## Claude's Discretion

- Choice between Noto Sans SC and Source Han Sans SC — researcher decides on weight-axis fidelity.
- Final Chinese glossary wording for each technical term — researcher proposes, user reviews.
- Phase split / sub-plan structure — planner decides.

## Deferred Ideas

- Traditional Chinese and other locales — future phases per locale family.
- Locale tagging on user-entered content — revisit only if real mismatch reports surface.
- RTL language support — defer until real demand.
- Font subsetting toolchain — fallback only.
- Alpino font swap (v1.3 backlog) — coordinate later; don't bundle two new font families simultaneously.
