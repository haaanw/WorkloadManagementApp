-- v1.7.1 sync repair (2026-08-05)
--
-- Context: the Sync Status screen showed Workouts "Sync error" while Recovery /
-- Wellness / Training Load failed with "Data format error". The client-side decode
-- defect (Postgres DATE columns vs the .iso8601 decoder) is fixed in the app. This
-- migration covers the server side of the Workouts failure: the app upserts columns
-- on workout_sessions that no committed migration ever created, so a schema-cache
-- miss (PGRST204 "Could not find the '…' column") rejects every push.
--
-- Idempotent: safe to run repeatedly. Run in the Supabase SQL editor.

-- 1. Ensure the table exists (no-op when it already does).
CREATE TABLE IF NOT EXISTS public.workout_sessions (
  id         uuid PRIMARY KEY,
  athlete_id uuid REFERENCES public.athletes NOT NULL,
  date       timestamptz NOT NULL,
  updated_at timestamptz DEFAULT now()
);

-- 2. Ensure every column the app's WorkoutSessionRow sends exists.
ALTER TABLE public.workout_sessions ADD COLUMN IF NOT EXISTS session_name       text;
ALTER TABLE public.workout_sessions ADD COLUMN IF NOT EXISTS sport_type         text;
ALTER TABLE public.workout_sessions ADD COLUMN IF NOT EXISTS duration_seconds   int;
ALTER TABLE public.workout_sessions ADD COLUMN IF NOT EXISTS session_rpe        double precision;
ALTER TABLE public.workout_sessions ADD COLUMN IF NOT EXISTS session_type       text NOT NULL DEFAULT 'strength';
ALTER TABLE public.workout_sessions ADD COLUMN IF NOT EXISTS logged_by_coach_id uuid;
ALTER TABLE public.workout_sessions ADD COLUMN IF NOT EXISTS notes              text;
ALTER TABLE public.workout_sessions ADD COLUMN IF NOT EXISTS total_volume       double precision NOT NULL DEFAULT 0;
ALTER TABLE public.workout_sessions ADD COLUMN IF NOT EXISTS external_load      double precision NOT NULL DEFAULT 0;
ALTER TABLE public.workout_sessions ADD COLUMN IF NOT EXISTS internal_load      double precision NOT NULL DEFAULT 0;
ALTER TABLE public.workout_sessions ADD COLUMN IF NOT EXISTS training_stress    double precision NOT NULL DEFAULT 0;
ALTER TABLE public.workout_sessions ADD COLUMN IF NOT EXISTS updated_at         timestamptz DEFAULT now();

-- 2b. Backfill: IF NOT EXISTS skips a pre-existing column entirely, so a column that
-- already existed as nullable keeps its NULLs. The app decodes these defensively now,
-- but clean data beats defensive decoding.
UPDATE public.workout_sessions SET session_type    = 'strength' WHERE session_type    IS NULL;
UPDATE public.workout_sessions SET total_volume    = 0          WHERE total_volume    IS NULL;
UPDATE public.workout_sessions SET external_load   = 0          WHERE external_load   IS NULL;
UPDATE public.workout_sessions SET internal_load   = 0          WHERE internal_load   IS NULL;
UPDATE public.workout_sessions SET training_stress = 0          WHERE training_stress IS NULL;
UPDATE public.workout_sessions SET updated_at      = now()      WHERE updated_at      IS NULL;

-- 2c. Athlete profile columns the app pushes but no committed migration ever created.
-- Without them, EVERY athlete push after onboarding fails silently (the athlete push
-- has no Sync Status row), so profile edits never reach the server.
ALTER TABLE public.athletes ADD COLUMN IF NOT EXISTS training_frequency text;
ALTER TABLE public.athletes ADD COLUMN IF NOT EXISTS experience_level   text;

-- 3. RLS: enable and add the owner policy only if it is missing.
ALTER TABLE public.workout_sessions ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'workout_sessions'
      AND policyname = 'workout_sessions_owner'
  ) THEN
    CREATE POLICY workout_sessions_owner ON public.workout_sessions
      FOR ALL
      USING (
        athlete_id IN (SELECT id FROM public.athletes WHERE user_id = auth.uid())
      )
      WITH CHECK (
        athlete_id IN (SELECT id FROM public.athletes WHERE user_id = auth.uid())
      );
  END IF;
END $$;

-- 4. Make PostgREST pick up the new columns immediately.
NOTIFY pgrst, 'reload schema';
