-- v1.7.3 feature 6 — plan-led logging: training programs + schedule (2026-09-03)
--
-- Two new tables and one column.
--
-- 1. `training_programs` — the imported, user-authored block. Phases and days ride as
--    embedded JSON (`phases_json` / `days_json`), the same shape as
--    `workout_templates.groups_json`: the program is one logical document, and embedding
--    keeps pull/push atomic per program. Day CONTENT lives in per-day rows of the existing
--    `workout_templates` table (flagged by the new `is_program_day` column) referenced from
--    `days_json` by template id.
--
-- 2. `schedule_entries` — the editable training calendar. One row per dated item
--    (planned program session, match, scrimmage, pickup, off-plan lift). Cancellation and
--    reschedules are recorded states on the row, never deletions, so the ledger survives
--    sync round-trips.
--
-- 3. `workout_templates.is_program_day` — marks a template as working storage for one
--    program day so standalone template lists can exclude it. Until this column exists the
--    client's template PUSH will be rejected (PGRST204, same failure mode as migration 009)
--    — run this file before or with the 1.7.3 rollout.
--
-- Idempotent; run in the Supabase SQL editor.

CREATE TABLE IF NOT EXISTS public.training_programs (
  id                uuid PRIMARY KEY,
  athlete_id        uuid REFERENCES public.athletes ON DELETE CASCADE NOT NULL,
  name              text NOT NULL,
  source            text NOT NULL,
  imported_at       timestamptz NOT NULL,
  duration_weeks    integer NOT NULL,
  duration_source   text NOT NULL,
  start_date        timestamptz,
  training_weekdays integer[],
  position_week     integer NOT NULL DEFAULT 1,
  position_day      integer NOT NULL DEFAULT 1,
  is_active         boolean NOT NULL DEFAULT false,
  is_archived       boolean NOT NULL DEFAULT false,
  archived_at       timestamptz,
  entry_mode        text,
  notes             text,
  phases_json       text,
  days_json         text,
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.training_programs ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'training_programs'
      AND policyname = 'training_programs_owner'
  ) THEN
    CREATE POLICY training_programs_owner ON public.training_programs
      FOR ALL
      USING (athlete_id IN (SELECT id FROM public.athletes WHERE user_id = auth.uid()))
      WITH CHECK (athlete_id IN (SELECT id FROM public.athletes WHERE user_id = auth.uid()));
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.schedule_entries (
  id                   uuid PRIMARY KEY,
  athlete_id           uuid REFERENCES public.athletes ON DELETE CASCADE NOT NULL,
  date                 timestamptz NOT NULL,
  kind                 text NOT NULL,
  status               text NOT NULL DEFAULT 'planned',
  title                text NOT NULL,
  program_id           uuid,
  program_day_id       uuid,
  moved_to_date        timestamptz,
  moved_from_date      timestamptz,
  canceled_at          timestamptz,
  completed_session_id uuid,
  is_ad_hoc            boolean NOT NULL DEFAULT false,
  duration_minutes     integer,
  note                 text,
  created_at           timestamptz NOT NULL DEFAULT now(),
  updated_at           timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS schedule_entries_athlete_date_idx
  ON public.schedule_entries (athlete_id, date);

ALTER TABLE public.schedule_entries ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'schedule_entries'
      AND policyname = 'schedule_entries_owner'
  ) THEN
    CREATE POLICY schedule_entries_owner ON public.schedule_entries
      FOR ALL
      USING (athlete_id IN (SELECT id FROM public.athletes WHERE user_id = auth.uid()))
      WITH CHECK (athlete_id IN (SELECT id FROM public.athletes WHERE user_id = auth.uid()));
  END IF;
END $$;

ALTER TABLE public.workout_templates
  ADD COLUMN IF NOT EXISTS is_program_day boolean NOT NULL DEFAULT false;

NOTIFY pgrst, 'reload schema';
