-- +goose Up
-- +goose StatementBegin

-- ============================================================================
-- Event <-> beacon association with the beacon's 2D floor position.
-- Beacons can be reused across events. The beacon FK is RESTRICT and the event
-- delete is soft, so history is never cascade-deleted.
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.event_beacons (
    event_id UUID NOT NULL REFERENCES public.events(id) ON DELETE CASCADE,
    beacon_id UUID NOT NULL REFERENCES public.beacons(id) ON DELETE RESTRICT,
    x DOUBLE PRECISION NOT NULL DEFAULT 0,
    y DOUBLE PRECISION NOT NULL DEFAULT 0,
    tx_power_override INTEGER,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT NULL,
    PRIMARY KEY (event_id, beacon_id)
);

CREATE INDEX IF NOT EXISTS idx_event_beacons_beacon_id ON public.event_beacons (beacon_id);
CREATE TRIGGER trg_event_beacons_updated_at BEFORE UPDATE ON public.event_beacons
    FOR EACH ROW EXECUTE FUNCTION fn_updated_at_value();

-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin

DROP TRIGGER IF EXISTS trg_event_beacons_updated_at ON public.event_beacons;
DROP INDEX IF EXISTS idx_event_beacons_beacon_id;
DROP TABLE IF EXISTS public.event_beacons;

-- +goose StatementEnd
