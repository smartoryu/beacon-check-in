-- +goose Up
-- +goose StatementBegin
SET timezone = 'UTC';

-- ============================================================================
-- Register some PosgreSQL extensions
-- ============================================================================
-- CREATE EXTENSION IF NOT EXISTS pg_stat_statements; -- Track planning and execution statistics of all SQL statements executed
-- CREATE EXTENSION IF NOT EXISTS citext;    -- Case-insensitive text type (slower than varchar or text columns)
-- CREATE EXTENSION IF NOT EXISTS hstore;    -- Key-Value pairs for storing unstructured data
CREATE EXTENSION IF NOT EXISTS pg_trgm;   -- Text similarity measurement and index searching based on trigrams
CREATE EXTENSION IF NOT EXISTS pgcrypto;  -- Cryptographic functions for hashing and encryption
CREATE EXTENSION IF NOT EXISTS plpgsql;   -- PL/pgSQL procedural language

-- ============================================================================
-- Portable UUIDv7 generator.
--
-- PostgreSQL 18 ships a built-in uuidv7(), but Supabase commonly runs
-- PostgreSQL 15/17. Defining public.uuidv7() keeps the migration chain
-- portable and shadows the built-in on PostgreSQL 18 (public is first in the
-- migration search_path).
-- ============================================================================
CREATE OR REPLACE FUNCTION public.uuidv7()
RETURNS uuid
LANGUAGE plpgsql
VOLATILE
AS $$
DECLARE
    unix_ts_ms bytea;
    uuid_bytes bytea;
BEGIN
    unix_ts_ms := substring(
        int8send((extract(epoch FROM clock_timestamp()) * 1000)::bigint)
        FROM 3
    );
    uuid_bytes := unix_ts_ms || gen_random_bytes(10);
    -- Version 7 in the high nibble of byte 6.
    uuid_bytes := set_byte(uuid_bytes, 6, (get_byte(uuid_bytes, 6) & 15) | 112);
    -- RFC 4122 variant (10xxxxxx) in byte 8.
    uuid_bytes := set_byte(uuid_bytes, 8, (get_byte(uuid_bytes, 8) & 63) | 128);
    RETURN encode(uuid_bytes, 'hex')::uuid;
END;
$$;

-- ============================================================================
-- Create auto-update function, fill updated_at column automatically.
-- CURRENT_TIMESTAMP similar to timezone('utc'::text, now())::timestamptz
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_updated_at_value()
RETURNS TRIGGER AS $$ BEGIN NEW.updated_at = CURRENT_TIMESTAMP; RETURN NEW; END; $$
LANGUAGE plpgsql;

-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin

-- Drop custom functions but keep the extensions.
DROP FUNCTION IF EXISTS public.uuidv7();
DROP FUNCTION IF EXISTS fn_updated_at_value();

-- +goose StatementEnd
