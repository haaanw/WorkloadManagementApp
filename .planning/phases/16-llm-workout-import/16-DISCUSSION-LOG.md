# Phase 16: LLM Workout Import - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-14
**Phase:** 16-llm-workout-import
**Areas discussed:** Input Method UX, Edge Function Architecture, Parse Result Preview, Error Handling UX
**Mode:** --auto (all decisions auto-selected)

---

## Input Method UX

| Option | Description | Selected |
|--------|-------------|----------|
| Single sheet with segmented picker | One import button, three tabs for text/PDF/photo | ✓ |
| Separate entry points per type | Three distinct buttons/menu items | |
| Action sheet first | Tap import → choose type from action sheet → type-specific sheet | |

**User's choice:** [auto] Single sheet with segmented picker (recommended)
**Notes:** Keeps entry point simple — one toolbar button. Consistent with existing sheet patterns.

---

## Edge Function Architecture

| Option | Description | Selected |
|--------|-------------|----------|
| Single edge function, client-side extraction | PDF/OCR on device, send text to one endpoint | ✓ |
| Separate edge functions per type | text/pdf/image each have own endpoint | |
| Server-side everything | Send raw PDF/image bytes to server | |

**User's choice:** [auto] Single edge function with client-side extraction (recommended)
**Notes:** Keeps server simple. PDFKit and Vision framework handle extraction on-device. Only text goes to LLM.

---

## Parse Result Preview

| Option | Description | Selected |
|--------|-------------|----------|
| Reuse TemplateEditorSheet | Pre-fill existing editor with parsed data | ✓ |
| Dedicated preview sheet | Read-only preview with "Edit" and "Save" buttons | |
| Inline preview in import sheet | Show parsed result below input area | |

**User's choice:** [auto] Reuse TemplateEditorSheet (recommended)
**Notes:** Consistent editing UX. User already knows how to edit templates. No new component needed.

---

## Error Handling UX

| Option | Description | Selected |
|--------|-------------|----------|
| Inline error banner + retry | Show error in sheet, offer retry, show partial results | ✓ |
| Alert dialog | System alert with error message and retry/cancel | |
| Toast notification | Non-modal toast, auto-dismiss | |

**User's choice:** [auto] Inline error banner + retry (recommended)
**Notes:** Graceful degradation — partial results are still useful. User can fix manually.

---

## Claude's Discretion

- Edge function prompt engineering
- PDF text extraction approach
- Vision framework OCR configuration
- Timeout/retry logic
