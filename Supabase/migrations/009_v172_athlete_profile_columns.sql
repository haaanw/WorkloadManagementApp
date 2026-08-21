-- v1.7.2 audit repair — athlete profile columns (2026-08-21)
--
-- Context: `SyncService.pushAthlete` sends eleven fields. No committed migration ever
-- created five of the columns they land in, so PostgREST rejects the whole athlete
-- upsert with PGRST204 ("Could not find the '…' column"). The athlete push has NO Sync
-- Status row, so that rejection has always been silent — the athlete sees a green sync
-- screen while their unit, ACWR method, load metric, max HR and date of birth never
-- leave the device.
--
-- The app-side half of audit finding M1 (the pull restored only 4 of the 11 fields) is
-- fixed in `SyncService.apply(_:to:)`. Without these columns that fix has nothing to
-- read back, so the two ship together.
--
-- Idempotent: safe to run repeatedly. Run in the Supabase SQL editor.

-- 1. Columns the app pushes on every athlete upsert.
ALTER TABLE public.athletes ADD COLUMN IF NOT EXISTS weight_unit             text;
ALTER TABLE public.athletes ADD COLUMN IF NOT EXISTS acwr_method             text;
ALTER TABLE public.athletes ADD COLUMN IF NOT EXISTS load_metric_preference  text;
ALTER TABLE public.athletes ADD COLUMN IF NOT EXISTS max_heart_rate          int;
ALTER TABLE public.athletes ADD COLUMN IF NOT EXISTS date_of_birth           date;

-- PRIVACY: reproductive-health flags (is_on_hormonal_contraceptive, is_pregnant,
-- is_lactating, has_pcos, is_perimenopausal) and next_match_date are device-local by
-- design and are NOT columns here. Do not add them. (Phase 18 / CR-01)

-- 2. training_profiles is UNIQUE(athlete_id) (migration 006) while every device mints its
-- own primary key. The app now upserts with `onConflict: "athlete_id"`; this asserts the
-- constraint that target needs, for any table created before 006 was applied.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.training_profiles'::regclass
      AND contype = 'u'
      AND conkey = ARRAY[
        (SELECT attnum FROM pg_attribute
          WHERE attrelid = 'public.training_profiles'::regclass AND attname = 'athlete_id')
      ]::smallint[]
  ) THEN
    ALTER TABLE public.training_profiles
      ADD CONSTRAINT training_profiles_athlete_id_key UNIQUE (athlete_id);
  END IF;
END $$;

-- 3. Make PostgREST pick up the new columns immediately.
NOTIFY pgrst, 'reload schema';
