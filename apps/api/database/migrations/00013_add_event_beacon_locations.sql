-- +goose Up
-- +goose StatementBegin

-- ============================================================================
-- Per-event GPS location for attached beacons.
--
-- A physical beacon can be reused across events and can be moved between
-- venues, so the confirmed location belongs to the event <-> beacon pairing.
-- Location changes are append-only in event_beacon_location_history.
-- ============================================================================
ALTER TABLE public.event_beacons
    ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS location_accuracy_m DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS location_source TEXT,
    ADD COLUMN IF NOT EXISTS location_confirmed_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS location_confirmed_by UUID REFERENCES public.users(id) ON DELETE SET NULL;

ALTER TABLE public.event_beacons
    DROP CONSTRAINT IF EXISTS chk_event_beacons_latitude,
    DROP CONSTRAINT IF EXISTS chk_event_beacons_longitude,
    DROP CONSTRAINT IF EXISTS chk_event_beacons_location_accuracy,
    DROP CONSTRAINT IF EXISTS chk_event_beacons_location_source;

ALTER TABLE public.event_beacons
    ADD CONSTRAINT chk_event_beacons_latitude
        CHECK (latitude IS NULL OR latitude BETWEEN -90 AND 90),
    ADD CONSTRAINT chk_event_beacons_longitude
        CHECK (longitude IS NULL OR longitude BETWEEN -180 AND 180),
    ADD CONSTRAINT chk_event_beacons_location_accuracy
        CHECK (location_accuracy_m IS NULL OR location_accuracy_m >= 0),
    ADD CONSTRAINT chk_event_beacons_location_source
        CHECK (location_source IS NULL OR location_source IN ('gps', 'manual'));

CREATE TABLE IF NOT EXISTS public.event_beacon_location_history (
    id UUID NOT NULL PRIMARY KEY DEFAULT uuidv7(),
    event_id UUID NOT NULL REFERENCES public.events(id) ON DELETE CASCADE,
    beacon_id UUID NOT NULL REFERENCES public.beacons(id) ON DELETE RESTRICT,
    latitude DOUBLE PRECISION NOT NULL CHECK (latitude BETWEEN -90 AND 90),
    longitude DOUBLE PRECISION NOT NULL CHECK (longitude BETWEEN -180 AND 180),
    accuracy_m DOUBLE PRECISION CHECK (accuracy_m IS NULL OR accuracy_m >= 0),
    source TEXT NOT NULL DEFAULT 'gps' CHECK (source IN ('gps', 'manual')),
    recorded_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_event_beacon_location_history_event_beacon
    ON public.event_beacon_location_history (event_id, beacon_id, created_at DESC);

-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin

DROP INDEX IF EXISTS idx_event_beacon_location_history_event_beacon;
DROP TABLE IF EXISTS public.event_beacon_location_history;

ALTER TABLE public.event_beacons
    DROP CONSTRAINT IF EXISTS chk_event_beacons_location_source,
    DROP CONSTRAINT IF EXISTS chk_event_beacons_location_accuracy,
    DROP CONSTRAINT IF EXISTS chk_event_beacons_longitude,
    DROP CONSTRAINT IF EXISTS chk_event_beacons_latitude;

ALTER TABLE public.event_beacons
    DROP COLUMN IF EXISTS location_confirmed_by,
    DROP COLUMN IF EXISTS location_confirmed_at,
    DROP COLUMN IF EXISTS location_source,
    DROP COLUMN IF EXISTS location_accuracy_m,
    DROP COLUMN IF EXISTS longitude,
    DROP COLUMN IF EXISTS latitude;

-- +goose StatementEnd
