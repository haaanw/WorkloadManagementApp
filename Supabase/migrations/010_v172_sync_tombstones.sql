-- v1.7.2 audit repair — deletion tombstones (2026-08-21)
--
-- Audit finding H6, "deletion resurrection". Sync is a full upsert with no dirty flags,
-- so the server had no way to learn that a row was deleted on a device: delete a workout,
-- and the next pull read the row that was still on the server and put it straight back.
--
-- This table is the record of a deletion. It is deliberately SEPARATE from the entity
-- tables rather than a `deleted_at` column on each of them, because a full-row upsert from
-- a device that still holds the row would push `deleted_at = NULL` and undo the deletion.
-- Nothing an entity upsert writes can touch this table.
--
-- Client behaviour, for whoever reads this next:
--   * On delete, the app writes a LOCAL tombstone in the same transaction as the delete.
--     That alone fixes the single-device defect, with or without this migration.
--   * On each sync it upserts pending tombstones here, then hard-deletes the underlying
--     rows. The tombstone is what makes the hard delete safe — a device that has not
--     synced since still learns the row is gone, so its next push cannot resurrect it.
--   * On each sync it reads this table and removes those rows locally.
-- Until this migration runs, the upsert leg fails per-entity and retries; deletions simply
-- do not cross devices yet.
--
-- Idempotent: safe to run repeatedly. Run in the Supabase SQL editor.

CREATE TABLE IF NOT EXISTS public.sync_tombstones (
  athlete_id uuid NOT NULL REFERENCES public.athletes ON DELETE CASCADE,
  entity     text NOT NULL,
  row_id     uuid NOT NULL,
  deleted_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (athlete_id, entity, row_id)
);

CREATE INDEX IF NOT EXISTS sync_tombstones_athlete_idx
  ON public.sync_tombstones (athlete_id);

ALTER TABLE public.sync_tombstones ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'sync_tombstones'
      AND policyname = 'sync_tombstones_owner'
  ) THEN
    CREATE POLICY sync_tombstones_owner ON public.sync_tombstones
      FOR ALL
      USING (
        athlete_id IN (SELECT id FROM public.athletes WHERE user_id = auth.uid())
      )
      WITH CHECK (
        athlete_id IN (SELECT id FROM public.athletes WHERE user_id = auth.uid())
      );
  END IF;
END $$;

-- The client hard-deletes rows from these tables once the tombstone lands, so each needs a
-- DELETE-capable owner policy. 007 created workout_sessions' policy FOR ALL; assert the
-- rest so a hard delete cannot be silently refused by RLS.
DO $$
DECLARE
  target text;
BEGIN
  FOREACH target IN ARRAY ARRAY[
    'workout_templates', 'personal_records', 'behavior_tags', 'wellness_check_ins'
  ] LOOP
    IF to_regclass('public.' || target) IS NULL THEN
      CONTINUE;
    END IF;
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', target);
    IF NOT EXISTS (
      SELECT 1 FROM pg_policies
      WHERE schemaname = 'public' AND tablename = target
        AND policyname = target || '_owner_delete'
    ) THEN
      EXECUTE format(
        'CREATE POLICY %I ON public.%I FOR DELETE USING (%s)',
        target || '_owner_delete',
        target,
        CASE target
          WHEN 'workout_templates'
            THEN 'coach_id IN (SELECT id FROM public.athletes WHERE user_id = auth.uid())'
          ELSE 'athlete_id IN (SELECT id FROM public.athletes WHERE user_id = auth.uid())'
        END
      );
    END IF;
  END LOOP;
END $$;

NOTIFY pgrst, 'reload schema';
