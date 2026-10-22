-- +goose Up
-- +goose StatementBegin

-- ============================================================================
-- Events with a 2D floor grid used for beacon placement and triangulation.
-- Time is stored as timestamptz (UTC); timezone is used for display/input.
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.events (
    id UUID NOT NULL PRIMARY KEY DEFAULT uuidv7(),
    title TEXT NOT NULL CHECK (char_length(title) > 0),
    description TEXT,
    place_name TEXT NOT NULL CHECK (char_length(place_name) > 0),
    address TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    starts_at TIMESTAMPTZ NOT NULL,
    ends_at TIMESTAMPTZ NOT NULL,
    timezone TEXT NOT NULL DEFAULT 'Asia/Jakarta',
    floor_width_m DOUBLE PRECISION NOT NULL DEFAULT 20 CHECK (floor_width_m > 0),
    floor_height_m DOUBLE PRECISION NOT NULL DEFAULT 20 CHECK (floor_height_m > 0),
    rssi_threshold_dbm INTEGER NOT NULL DEFAULT -75 CHECK (rssi_threshold_dbm BETWEEN -120 AND 0),
    min_beacons INTEGER NOT NULL DEFAULT 1 CHECK (min_beacons >= 1),
    coverage_radius_m DOUBLE PRECISION CHECK (coverage_radius_m IS NULL OR coverage_radius_m > 0),
    path_loss_exponent DOUBLE PRECISION NOT NULL DEFAULT 2.0 CHECK (path_loss_exponent > 0),
    created_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT NULL,
    deleted_at TIMESTAMPTZ,
    CONSTRAINT chk_events_time_range CHECK (ends_at > starts_at)
);

CREATE INDEX IF NOT EXISTS idx_events_starts_at ON public.events (starts_at);
CREATE INDEX IF NOT EXISTS idx_events_ends_at ON public.events (ends_at);
CREATE INDEX IF NOT EXISTS idx_events_deleted_at ON public.events (deleted_at) WHERE deleted_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_events_title ON public.events USING gin (title gin_trgm_ops);
CREATE TRIGGER trg_events_updated_at BEFORE UPDATE ON public.events
    FOR EACH ROW EXECUTE FUNCTION fn_updated_at_value();

-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin

DROP TRIGGER IF EXISTS trg_events_updated_at ON public.events;
DROP INDEX IF EXISTS idx_events_title;
DROP INDEX IF EXISTS idx_events_deleted_at;
DROP INDEX IF EXISTS idx_events_ends_at;
DROP INDEX IF EXISTS idx_events_starts_at;
DROP TABLE IF EXISTS public.events;

-- +goose StatementEnd
