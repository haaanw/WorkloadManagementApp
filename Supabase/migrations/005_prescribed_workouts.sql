-- Prescribed Workouts feature: templates + prescriptions

-- Coach's reusable workout templates
CREATE TABLE IF NOT EXISTS workout_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    coach_id UUID NOT NULL REFERENCES athletes(id) ON DELETE CASCADE,
    template_name TEXT NOT NULL,
    sport_type TEXT NOT NULL DEFAULT 'lifting',
    session_type TEXT NOT NULL DEFAULT 'strength',
    notes TEXT,
    groups_json TEXT,  -- JSON-encoded exercise groups with exercises and sets
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- RLS: coaches can CRUD their own templates
ALTER TABLE workout_templates ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Coaches manage own templates"
    ON workout_templates FOR ALL
    USING (coach_id IN (SELECT id FROM athletes WHERE user_id = auth.uid()))
    WITH CHECK (coach_id IN (SELECT id FROM athletes WHERE user_id = auth.uid()));

-- Prescribed workouts assigned to athletes
CREATE TABLE IF NOT EXISTS prescribed_workouts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    coach_id UUID NOT NULL REFERENCES athletes(id) ON DELETE CASCADE,
    athlete_id UUID NOT NULL REFERENCES athletes(id) ON DELETE CASCADE,
    template_id UUID REFERENCES workout_templates(id) ON DELETE SET NULL,
    scheduled_date DATE NOT NULL,
    status TEXT NOT NULL DEFAULT 'assigned',
    completed_session_id UUID REFERENCES workout_sessions(id) ON DELETE SET NULL,
    notes TEXT,
    template_name TEXT NOT NULL,
    sport_type TEXT NOT NULL DEFAULT 'lifting',
    session_type TEXT NOT NULL DEFAULT 'strength',
    groups_json TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- RLS: coach can manage prescriptions for their athletes; athlete can read own
ALTER TABLE prescribed_workouts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Coaches manage prescriptions for their athletes"
    ON prescribed_workouts FOR ALL
    USING (is_coach_for(athlete_id))
    WITH CHECK (is_coach_for(athlete_id));

CREATE POLICY "Athletes read own prescriptions"
    ON prescribed_workouts FOR SELECT
    USING (athlete_id IN (SELECT id FROM athletes WHERE user_id = auth.uid()));

CREATE POLICY "Athletes update own prescription status"
    ON prescribed_workouts FOR UPDATE
    USING (athlete_id IN (SELECT id FROM athletes WHERE user_id = auth.uid()))
    WITH CHECK (athlete_id IN (SELECT id FROM athletes WHERE user_id = auth.uid()));

-- Indexes
CREATE INDEX idx_workout_templates_coach ON workout_templates(coach_id);
CREATE INDEX idx_prescribed_workouts_athlete ON prescribed_workouts(athlete_id);
CREATE INDEX idx_prescribed_workouts_coach ON prescribed_workouts(coach_id);
CREATE INDEX idx_prescribed_workouts_scheduled ON prescribed_workouts(scheduled_date);
