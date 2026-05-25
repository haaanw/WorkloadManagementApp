-- Phase 18 / CR-01: Remove reproductive-health flags from Supabase.
-- These fields (hormonal contraceptive, pregnancy, lactation) drive the
-- cycle-aware recovery confidence gate but are reproductive-health data and
-- must never leave the device. They stay local-only on the SwiftData Athlete
-- model; the sync AthleteRow no longer encodes/decodes them. This reverses the
-- Phase 17 migration `add_cycle_fields_to_athletes.sql`.
--
-- Run against the Supabase `athletes` table.
ALTER TABLE athletes DROP COLUMN IF EXISTS is_on_hormonal_contraceptive;
ALTER TABLE athletes DROP COLUMN IF EXISTS is_pregnant;
ALTER TABLE athletes DROP COLUMN IF EXISTS is_lactating;
