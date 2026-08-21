-- v1.7.2 LLM parse quota (2026-08-17)
--
-- Context: Phase B of voice/log-mode workout parsing routes free-text
-- through an LLM (OpenAI for plan mode, DeepSeek for log mode). A per-user
-- daily call cap protects against runaway cost from a single account. This
-- table exists only to back increment_parse_usage() below — nothing else
-- reads or writes it.
--
-- Caller: the parse-workout edge function, using its service-role key, once
-- per authenticated request (either mode). No user-facing client ever
-- queries this table directly.
--
-- Idempotent: safe to run repeatedly. Run in the Supabase SQL editor.

-- 1. Usage table: one row per (user, UTC day), incremented on every parse call.
CREATE TABLE IF NOT EXISTS public.llm_parse_usage (
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  day     date NOT NULL DEFAULT (now() AT TIME ZONE 'utc')::date,
  count   integer NOT NULL DEFAULT 0,
  PRIMARY KEY (user_id, day)
);

-- 2. RLS: enabled with zero policies. Only a SECURITY DEFINER function
-- (which runs as the table owner, bypassing RLS) or the service-role key
-- (which bypasses RLS entirely) can ever touch this table — an
-- authenticated user's own JWT cannot see or modify their row directly.
ALTER TABLE public.llm_parse_usage ENABLE ROW LEVEL SECURITY;

-- 3. increment_parse_usage: atomically bumps today's count for a user and
-- returns the new total. The edge function compares this against
-- PARSE_DAILY_LIMIT (env var, defaults to 40) to allow/reject the call.
CREATE OR REPLACE FUNCTION public.increment_parse_usage(p_user_id uuid)
RETURNS integer
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  INSERT INTO llm_parse_usage (user_id, day, count)
  VALUES (p_user_id, (now() AT TIME ZONE 'utc')::date, 1)
  ON CONFLICT (user_id, day) DO UPDATE SET count = llm_parse_usage.count + 1
  RETURNING count;
$$;

-- 4. Lock the RPC down to the service role. The parse-workout edge function
-- is the only intended caller. Without this, any authenticated user could
-- call increment_parse_usage with an arbitrary p_user_id and inflate — or,
-- combined with the edge function's own quota check, indirectly deny
-- service to — another athlete's daily quota.
--
-- NOTE: Postgres grants EXECUTE on new functions to PUBLIC by default, and
-- anon/authenticated inherit that PUBLIC grant — revoking from the roles
-- alone would NOT block them. Revoke from PUBLIC, then grant service_role
-- back explicitly.
REVOKE EXECUTE ON FUNCTION public.increment_parse_usage(uuid) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.increment_parse_usage(uuid) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.increment_parse_usage(uuid) TO service_role;

-- 5. Make PostgREST pick up the new table/function immediately.
NOTIFY pgrst, 'reload schema';
