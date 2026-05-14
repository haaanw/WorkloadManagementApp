-- Phase 17: Add cycle tracking fields to athletes table
-- Nullable columns, no default needed, no backfill required
ALTER TABLE athletes ADD COLUMN is_on_hormonal_contraceptive BOOLEAN;
ALTER TABLE athletes ADD COLUMN is_pregnant BOOLEAN;
ALTER TABLE athletes ADD COLUMN is_lactating BOOLEAN;
