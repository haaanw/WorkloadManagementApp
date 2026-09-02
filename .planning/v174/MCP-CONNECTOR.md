# MCP connector exploration — Tuwa as a data source for the user's own AI

Status: EXPLORATION QUEUED (HAN idea, 2026-09-02). Research-first; not a
v1.7.3 item (that release is full). Target: research now, build decision
after 1.7.3 ships.

## The idea (HAN)

Let users connect Tuwa to ChatGPT and Claude — especially on mobile — so
they can monitor their training and discuss it with their own AI agent in
real time.

## Why this FITS the thesis instead of violating it

The core product law says: no chat coach inside the app — the LLM is an
engine, never a chat UI. An MCP connector keeps that law intact: the chat
happens in the USER'S agent (ChatGPT/Claude), and Tuwa remains the
sports-science staff layer that feeds it structured, opinionated data.
"Your plan, your agent, our decision layer" extends the positioning; it
does not contradict it. It is also a real differentiator: no competitor in
the readiness category exposes an agent-readable interface today.

## Architecture sketch (to validate, not decide, in research)

- **Vehicle: a remote MCP server** (streamable HTTP), which both Claude
  (connectors) and ChatGPT (connector/deep-research surface) can attach to
  — including their mobile apps. This is the "MCP connector" HAN named.
- **Host it where the data already is: Supabase.** An edge function
  speaking MCP, authenticated per user via OAuth against Supabase Auth
  (MCP's OAuth 2.1 flow). No new infrastructure.
- **Read-only tool surface, v1:** today's readiness + verdict + reason,
  training-load state (ACWR zone, 7-day curve), recent sessions, plan
  position / next proposal, PR list. Structured, unit-labeled JSON with
  the same claim discipline as the app ("score 78, partial confidence,
  based on 3 of 4 signals").
- **Privacy inheritance is automatic and must stay that way:** the server
  can only serve what already syncs — composite scores and workouts. Raw
  HealthKit data never reaches Supabase, so it CANNOT leak through MCP.
  Any request to widen the sync payload "for the agent" is refused on the
  existing law.

## Open questions for the research lane

1. Current mobile reality: exactly what do Claude iOS and ChatGPT iOS
   support for user-added remote MCP servers today, on which plan tiers?
   (This moves fast; verify the week the lane opens, not from memory.)
2. OAuth UX: how many taps from "Connect Tuwa" to a working connector in
   each client; can the app deep-link the setup?
3. Quota/abuse: per-user rate limits; an agent polling in a loop must not
   run up edge-function cost.
4. Write surface (v2 question, default NO): should an agent ever log a
   workout or answer the morning check-in? Gut: no — capture belongs in
   the app where the confirm-before-save law lives.
5. App Review exposure: any policy angle on an app advertising an
   AI-agent connector.
6. Marketing: this is an X-article-sized launch on its own ("I gave my
   training data an MCP server").

## Non-goals

No chat UI in the app, ever. No LLM-generated advice served BY Tuwa
through MCP — the server serves data and Tuwa's own computed verdicts;
whatever the user's agent says on top is the agent's, in the agent's
voice, on the user's initiative.
