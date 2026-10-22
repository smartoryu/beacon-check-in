-- +goose Up
-- +goose StatementBegin

-- ============================================================================
-- Physical iBeacon devices registered by admins.
-- Identity is the iBeacon proximity UUID + major + minor.
-- Soft-deleted rows keep their identity so the same physical device must be
-- restored instead of registered twice.
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.beacons (
    id UUID NOT NULL PRIMARY KEY DEFAULT uuidv7(),
    identity_key TEXT NOT NULL,
    proximity_uuid UUID NOT NULL,
    major INTEGER NOT NULL CHECK (major BETWEEN 0 AND 65535),
    minor INTEGER NOT NULL CHECK (minor BETWEEN 0 AND 65535),
    label TEXT NOT NULL CHECK (char_length(label) > 0),
    local_name TEXT,
    platform_device_id TEXT,
    device_address_type TEXT,
    tx_power INTEGER,
    metadata JSONB,
    gatt_info JSONB,
    gatt_read_at TIMESTAMPTZ,
    registered_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
    registered_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_seen_at TIMESTAMPTZ,
    deleted_at TIMESTAMPTZ,
    deleted_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT NULL,
    CONSTRAINT uq_beacons_identity_key UNIQUE (identity_key),
    CONSTRAINT uq_beacons_ibeacon_identity UNIQUE (proximity_uuid, major, minor)
);

CREATE INDEX IF NOT EXISTS idx_beacons_proximity_uuid ON public.beacons (proximity_uuid);
CREATE INDEX IF NOT EXISTS idx_beacons_label ON public.beacons USING gin (label gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_beacons_deleted_at ON public.beacons (deleted_at) WHERE deleted_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_beacons_registered_at ON public.beacons (registered_at);
CREATE INDEX IF NOT EXISTS idx_beacons_last_seen_at ON public.beacons (last_seen_at) WHERE last_seen_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_beacons_metadata_gin ON public.beacons USING GIN (metadata);
CREATE TRIGGER trg_beacons_updated_at BEFORE UPDATE ON public.beacons
    FOR EACH ROW EXECUTE FUNCTION fn_updated_at_value();

-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin

DROP TRIGGER IF EXISTS trg_beacons_updated_at ON public.beacons;
DROP INDEX IF EXISTS idx_beacons_metadata_gin;
DROP INDEX IF EXISTS idx_beacons_last_seen_at;
DROP INDEX IF EXISTS idx_beacons_registered_at;
DROP INDEX IF EXISTS idx_beacons_deleted_at;
DROP INDEX IF EXISTS idx_beacons_label;
DROP INDEX IF EXISTS idx_beacons_proximity_uuid;
DROP TABLE IF EXISTS public.beacons;

-- +goose StatementEnd
