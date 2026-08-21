-- v1.7.2 audit repair — daily-row identity + behavior_tags DDL (2026-08-21)
--
-- Two findings.
--
-- M5. Recovery snapshots, workload snapshots and wellness check-ins are DERIVED from a
-- calendar day, so their real identity is (athlete_id, date) — the row id is an artefact
-- of whichever device wrote them first. Nothing enforced that, so two devices produced two
-- rows for the same day and the hero recovery score depended on which one a fetch happened
-- to return. The app now resolves incoming rows by day and adopts the server's id; this
-- migration makes the server agree.
--
-- M3. `behavior_tags` has been syncing in both directions since v1.2 with NO committed DDL
-- — the table exists only because it was created by hand. That is documentation debt with
-- teeth: nobody can rebuild the schema, and the column types the client assumes were never
-- written down. This is the first committed definition; it asserts rather than replaces.
--
-- Idempotent, and non-destructive: the de-duplication below KEEPS the most recently updated
-- row for each (athlete, day) and deletes only the older siblings, which by construction
-- carry values the app has already superseded. Run in the Supabase SQL editor.
--
-- Why the client still upserts on the primary key rather than on (athlete_id, date): an
-- ON CONFLICT target needs its constraint to already exist, so a client that named
-- (athlete_id, date) would fail with 42P10 on every push until this file was run by hand.
-- The client instead resolves incoming rows by DAY on pull and adopts the server's id, so
-- a second device is carrying the server's id before it ever pushes. The constraint below
-- is the backstop: if a race does slip through, it surfaces as a visible 23505 on the Sync
-- Status screen instead of silently forking the day into two rows.

-- 1. behavior_tags: assert the table and every column the client sends.
CREATE TABLE IF NOT EXISTS public.behavior_tags (
  id         uuid PRIMARY KEY,
  athlete_id uuid REFERENCES public.athletes ON DELETE CASCADE NOT NULL,
  date       timestamptz NOT NULL,
  tag_name   text NOT NULL,
  is_active  boolean NOT NULL DEFAULT false,
  is_custom  boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- The check-in a tag was recorded against. The pull used to drop this link entirely, so a
-- restored device saw every check-in with an empty tag set.
ALTER TABLE public.behavior_tags
  ADD COLUMN IF NOT EXISTS wellness_check_in_id uuid;

ALTER TABLE public.behavior_tags ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'behavior_tags'
      AND policyname = 'behavior_tags_owner'
  ) THEN
    CREATE POLICY behavior_tags_owner ON public.behavior_tags
      FOR ALL
      USING (athlete_id IN (SELECT id FROM public.athletes WHERE user_id = auth.uid()))
      WITH CHECK (athlete_id IN (SELECT id FROM public.athletes WHERE user_id = auth.uid()));
  END IF;
END $$;

-- 2. One row per athlete per day on the three derived daily tables.
--    De-duplicate first — adding the constraint to a table that already holds duplicates
--    fails outright.
DO $$
DECLARE
  target text;
  day_column text;
BEGIN
  FOREACH target IN ARRAY ARRAY[
    'recovery_snapshots', 'wellness_check_ins', 'workload_snapshots'
  ] LOOP
    IF to_regclass('public.' || target) IS NULL THEN
      CONTINUE;
    END IF;
    day_column := CASE target WHEN 'workload_snapshots' THEN 'snapshot_date' ELSE 'date' END;

    -- Keep the newest updated_at per (athlete_id, day); drop the rest.
    EXECUTE format($f$
      DELETE FROM public.%1$I t
      USING (
        SELECT id,
               row_number() OVER (
                 PARTITION BY athlete_id, %2$I::date
                 ORDER BY updated_at DESC NULLS LAST, id
               ) AS rank
        FROM public.%1$I
      ) ranked
      WHERE t.id = ranked.id AND ranked.rank > 1
    $f$, target, day_column);

    IF NOT EXISTS (
      SELECT 1 FROM pg_constraint
      WHERE conrelid = ('public.' || target)::regclass
        AND conname = target || '_athlete_day_key'
    ) THEN
      EXECUTE format(
        'ALTER TABLE public.%1$I ADD CONSTRAINT %2$I UNIQUE (athlete_id, %3$I)',
        target, target || '_athlete_day_key', day_column
      );
    END IF;
  END LOOP;
END $$;

NOTIFY pgrst, 'reload schema';
