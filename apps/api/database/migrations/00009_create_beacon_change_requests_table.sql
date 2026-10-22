-- +goose Up
-- +goose StatementBegin

-- ============================================================================
-- Beacon delete/restore requests. Admins request, super admins approve.
-- The action is applied only when the request is approved.
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.beacon_change_requests (
    id UUID NOT NULL PRIMARY KEY DEFAULT uuidv7(),
    beacon_id UUID NOT NULL REFERENCES public.beacons(id) ON DELETE RESTRICT,
    action TEXT NOT NULL CHECK (action IN ('delete', 'restore')),
    reason TEXT NOT NULL CHECK (char_length(reason) > 0),
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    requested_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
    reviewed_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
    review_note TEXT,
    reviewed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT NULL
);

CREATE INDEX IF NOT EXISTS idx_beacon_requests_status ON public.beacon_change_requests (status);
CREATE INDEX IF NOT EXISTS idx_beacon_requests_beacon_id ON public.beacon_change_requests (beacon_id);
CREATE INDEX IF NOT EXISTS idx_beacon_requests_requested_by ON public.beacon_change_requests (requested_by);
CREATE UNIQUE INDEX IF NOT EXISTS uq_beacon_requests_pending
    ON public.beacon_change_requests (beacon_id, action)
    WHERE status = 'pending';
CREATE TRIGGER trg_beacon_change_requests_updated_at BEFORE UPDATE ON public.beacon_change_requests
    FOR EACH ROW EXECUTE FUNCTION fn_updated_at_value();

-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin

DROP TRIGGER IF EXISTS trg_beacon_change_requests_updated_at ON public.beacon_change_requests;
DROP INDEX IF EXISTS uq_beacon_requests_pending;
DROP INDEX IF EXISTS idx_beacon_requests_requested_by;
DROP INDEX IF EXISTS idx_beacon_requests_beacon_id;
DROP INDEX IF EXISTS idx_beacon_requests_status;
DROP TABLE IF EXISTS public.beacon_change_requests;

-- +goose StatementEnd
