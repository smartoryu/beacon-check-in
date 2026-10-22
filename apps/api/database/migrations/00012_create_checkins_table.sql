-- +goose Up
-- +goose StatementBegin

-- ============================================================================
-- Every check-in attempt (accepted or rejected) for audit and triangulation
-- debugging. `client_checkin_id` is generated on the device and makes retries
-- idempotent. `recorded_at` is the device timestamp used for event-window
-- validation; `received_at` is when the server persisted the attempt.
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.checkins (
    id UUID NOT NULL PRIMARY KEY DEFAULT uuidv7(),
    client_checkin_id UUID NOT NULL,
    event_id UUID NOT NULL REFERENCES public.events(id) ON DELETE RESTRICT,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
    status TEXT NOT NULL CHECK (status IN ('accepted', 'rejected')),
    reject_reason TEXT,
    recorded_at TIMESTAMPTZ NOT NULL,
    received_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    is_offline BOOLEAN NOT NULL DEFAULT FALSE,
    estimated_x DOUBLE PRECISION,
    estimated_y DOUBLE PRECISION,
    accuracy_m DOUBLE PRECISION,
    used_beacon_count INTEGER NOT NULL DEFAULT 0,
    readings JSONB NOT NULL DEFAULT '[]'::jsonb,
    device_info JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_checkins_client_checkin_id UNIQUE (client_checkin_id),
    CONSTRAINT chk_checkins_reject_reason
        CHECK ((status = 'accepted' AND reject_reason IS NULL) OR (status = 'rejected' AND reject_reason IS NOT NULL))
);

-- One accepted check-in per user per event; rejected attempts remain as history.
CREATE UNIQUE INDEX IF NOT EXISTS uq_checkins_accepted_event_user
    ON public.checkins (event_id, user_id)
    WHERE status = 'accepted';

CREATE INDEX IF NOT EXISTS idx_checkins_event_id ON public.checkins (event_id);
CREATE INDEX IF NOT EXISTS idx_checkins_user_id ON public.checkins (user_id);
CREATE INDEX IF NOT EXISTS idx_checkins_status ON public.checkins (status);
CREATE INDEX IF NOT EXISTS idx_checkins_recorded_at ON public.checkins (recorded_at);
CREATE INDEX IF NOT EXISTS idx_checkins_received_at ON public.checkins (received_at);
CREATE INDEX IF NOT EXISTS idx_checkins_event_status ON public.checkins (event_id, status);

-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin

DROP INDEX IF EXISTS idx_checkins_event_status;
DROP INDEX IF EXISTS idx_checkins_received_at;
DROP INDEX IF EXISTS idx_checkins_recorded_at;
DROP INDEX IF EXISTS idx_checkins_status;
DROP INDEX IF EXISTS idx_checkins_user_id;
DROP INDEX IF EXISTS idx_checkins_event_id;
DROP INDEX IF EXISTS uq_checkins_accepted_event_user;
DROP TABLE IF EXISTS public.checkins;

-- +goose StatementEnd
