-- shared_templates table for template sharing via short codes
-- Phase 15: Template Sharing

CREATE TABLE public.shared_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    share_code TEXT NOT NULL UNIQUE,
    owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    template_json JSONB NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Index for pg_cron cleanup performance
CREATE INDEX idx_shared_templates_expires_at ON public.shared_templates (expires_at);

-- RLS
ALTER TABLE public.shared_templates ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read shared templates"
ON public.shared_templates FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "Owner can share templates"
ON public.shared_templates FOR INSERT
TO authenticated
WITH CHECK (owner_id = auth.uid());

CREATE POLICY "Owner can delete shared templates"
ON public.shared_templates FOR DELETE
TO authenticated
USING (owner_id = auth.uid());

-- pg_cron cleanup job: run daily at 3 AM UTC, delete expired shares
SELECT cron.schedule(
    'cleanup-expired-shares',
    '0 3 * * *',
    $$DELETE FROM public.shared_templates WHERE expires_at < now()$$
);
