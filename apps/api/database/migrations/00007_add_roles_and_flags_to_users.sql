-- +goose Up
-- +goose StatementBegin

-- ============================================================================
-- Extend users with application roles and admin onboarding flags.
-- Existing template users become role 'user' by default.
-- ============================================================================
ALTER TABLE public.users
    ADD COLUMN IF NOT EXISTS role TEXT NOT NULL DEFAULT 'user',
    ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ DEFAULT NULL,
    ADD COLUMN IF NOT EXISTS must_change_password BOOLEAN NOT NULL DEFAULT FALSE;

ALTER TABLE public.users
    ADD CONSTRAINT chk_users_role CHECK (role IN ('super_admin', 'admin', 'user'));

CREATE INDEX IF NOT EXISTS idx_users_role ON public.users (role);
CREATE INDEX IF NOT EXISTS idx_users_deleted_at ON public.users (deleted_at) WHERE deleted_at IS NOT NULL;

-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin

DROP INDEX IF EXISTS idx_users_deleted_at;
DROP INDEX IF EXISTS idx_users_role;
ALTER TABLE public.users DROP CONSTRAINT IF EXISTS chk_users_role;
ALTER TABLE public.users
    DROP COLUMN IF EXISTS must_change_password,
    DROP COLUMN IF EXISTS deleted_at,
    DROP COLUMN IF EXISTS role;

-- +goose StatementEnd
