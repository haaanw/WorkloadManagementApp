-- Source: Decisions D-14 through D-17
-- v1.2 Foundation: TrainingProfile + WorkoutTemplate extensions + RLS

-- 1. New table: training_profiles
CREATE TABLE IF NOT EXISTS training_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    athlete_id UUID NOT NULL REFERENCES athletes(id) ON DELETE CASCADE,
    sessions_per_week INT NOT NULL,
    avg_duration_minutes INT NOT NULL,
    typical_srpe DOUBLE PRECISION NOT NULL,
    weeks_at_level INT NOT NULL,
    training_age_years INT,
    periodization_preference TEXT,
    movement_types TEXT[],
    injury_history JSONB,
    seeded_atl DOUBLE PRECISION NOT NULL,
    seeded_ctl DOUBLE PRECISION NOT NULL,
    seeded_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    bias_estimated_atl DOUBLE PRECISION,
    bias_estimated_ctl DOUBLE PRECISION,
    bias_actual_atl DOUBLE PRECISION,
    bias_actual_ctl DOUBLE PRECISION,
    bias_captured_at TIMESTAMPTZ,
    cold_start_completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(athlete_id)
);

-- 2. RLS on training_profiles (D-17)
ALTER TABLE training_profiles ENABLE ROW LEVEL SECURITY;

-- Athlete CRUD own profile
CREATE POLICY "Athletes manage own training profile"
    ON training_profiles FOR ALL
    USING (athlete_id IN (SELECT id FROM athletes WHERE user_id = auth.uid()))
    WITH CHECK (athlete_id IN (SELECT id FROM athletes WHERE user_id = auth.uid()));

-- Coach can read linked athletes' profiles
CREATE POLICY "Coaches read linked athlete profiles"
    ON training_profiles FOR SELECT
    USING (athlete_id IN (
        SELECT athlete_id FROM coach_athlete_relationships
        WHERE coach_id IN (SELECT id FROM athletes WHERE user_id = auth.uid())
        AND status = 'accepted'
    ));

-- 3. Extend workout_templates (D-01, D-02)
ALTER TABLE workout_templates
    ADD COLUMN IF NOT EXISTS is_athlete_owned BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS athlete_id UUID,
    ADD COLUMN IF NOT EXISTS is_favorite BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS is_archived BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS last_used_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS usage_count INT NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS scheduled_days INT[];

-- 4. Athlete RLS on workout_templates (D-15, D-16 -- additive, existing policy unchanged)
-- Athletes can manage their own athlete-owned templates
CREATE POLICY "Athletes manage own templates"
    ON workout_templates FOR ALL
    USING (
        is_athlete_owned = true
        AND athlete_id IN (SELECT id FROM athletes WHERE user_id = auth.uid())
    )
    WITH CHECK (
        is_athlete_owned = true
        AND athlete_id IN (SELECT id FROM athletes WHERE user_id = auth.uid())
    );

-- Athletes can SELECT coach-assigned templates (via relationship)
CREATE POLICY "Athletes read coach templates via relationship"
    ON workout_templates FOR SELECT
    USING (
        is_athlete_owned = false
        AND coach_id IN (
            SELECT coach_id FROM coach_athlete_relationships
            WHERE athlete_id IN (SELECT id FROM athletes WHERE user_id = auth.uid())
            AND status = 'accepted'
        )
    );

-- 5. Indexes
CREATE INDEX IF NOT EXISTS idx_training_profiles_athlete ON training_profiles(athlete_id);
CREATE INDEX IF NOT EXISTS idx_workout_templates_athlete ON workout_templates(athlete_id) WHERE is_athlete_owned = true;
