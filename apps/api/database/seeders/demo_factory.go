package seeders

import (
	"context"
	"fmt"
	"log/slog"
	"os"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

// DemoFactory seeds a demo event and three demo beacons when SEED_DEMO_DATA=true.
// It is intentionally idempotent so it can be re-run after a reset.
func DemoFactory(ctx context.Context, pool *pgxpool.Pool) error {
	if os.Getenv("SEED_DEMO_DATA") != "true" {
		return nil
	}

	slog.Info("Seeding demo event and beacons...")

	var superAdminID string
	if err := pool.QueryRow(ctx, `SELECT id FROM public.users WHERE LOWER(email) = LOWER($1) LIMIT 1`, "superadmin@beacon.local").Scan(&superAdminID); err != nil {
		return fmt.Errorf("demo seed: super admin not found: %w", err)
	}

	now := time.Now().UTC()
	startsAt := now.Add(-1 * time.Hour)
	endsAt := now.Add(6 * time.Hour)

	const demoUUID = "00000000-0000-4000-8000-000000000001"
	beacons := []struct {
		id    string
		minor int
		label string
		major int
		tx    int
		x, y  float64
	}{
		{"00000000-0000-4000-8000-000000000011", 1, "Demo Beacon 1 - Entrance", 1, -59, 2.0, 2.0},
		{"00000000-0000-4000-8000-000000000012", 2, "Demo Beacon 2 - Stage", 1, -59, 17.0, 4.0},
		{"00000000-0000-4000-8000-000000000013", 3, "Demo Beacon 3 - Lounge", 1, -59, 10.0, 17.0},
	}

	for _, b := range beacons {
		identityKey := fmt.Sprintf("%s:%d:%d", demoUUID, b.major, b.minor)
		metadata := fmt.Sprintf(`{"demo":true,"source":"seed","measured_power":%d}`, b.tx)
		_, err := pool.Exec(ctx, `
			INSERT INTO public.beacons (
				id, identity_key, proximity_uuid, major, minor, label, local_name,
				tx_power, metadata, registered_by, registered_at, last_seen_at
			) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9::jsonb, $10, NOW(), NOW())
			ON CONFLICT (identity_key) DO UPDATE
			SET label = EXCLUDED.label,
			    local_name = EXCLUDED.local_name,
			    tx_power = EXCLUDED.tx_power,
			    metadata = EXCLUDED.metadata,
			    deleted_at = NULL,
			    deleted_by = NULL
		`, b.id, identityKey, demoUUID, b.major, b.minor, b.label, b.label, b.tx, metadata, superAdminID)
		if err != nil {
			return fmt.Errorf("demo seed: beacon %s: %w", b.label, err)
		}
	}

	const eventID = "00000000-0000-4000-8000-000000000100"
	_, err := pool.Exec(ctx, `
		INSERT INTO public.events (
			id, title, description, place_name, address, starts_at, ends_at, timezone,
			floor_width_m, floor_height_m, rssi_threshold_dbm, min_beacons,
			coverage_radius_m, path_loss_exponent, created_by
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 20, 20, -80, 1, 15, 2.0, $9)
		ON CONFLICT (id) DO UPDATE
		SET title = EXCLUDED.title,
		    description = EXCLUDED.description,
		    place_name = EXCLUDED.place_name,
		    address = EXCLUDED.address,
		    starts_at = EXCLUDED.starts_at,
		    ends_at = EXCLUDED.ends_at,
		    timezone = EXCLUDED.timezone,
		    floor_width_m = EXCLUDED.floor_width_m,
		    floor_height_m = EXCLUDED.floor_height_m,
		    rssi_threshold_dbm = EXCLUDED.rssi_threshold_dbm,
		    min_beacons = EXCLUDED.min_beacons,
		    coverage_radius_m = EXCLUDED.coverage_radius_m,
		    path_loss_exponent = EXCLUDED.path_loss_exponent,
		    deleted_at = NULL
	`, eventID, "Demo Check-In Event", "Seeded event for trying the web and mobile flows without hardware.",
		"Demo Hall", "Zero One Group HQ", startsAt, endsAt, "Asia/Jakarta", superAdminID)
	if err != nil {
		return fmt.Errorf("demo seed: event: %w", err)
	}

	for _, b := range beacons {
		_, err := pool.Exec(ctx, `
			INSERT INTO public.event_beacons (event_id, beacon_id, x, y)
			VALUES ($1, $2, $3, $4)
			ON CONFLICT (event_id, beacon_id) DO UPDATE
			SET x = EXCLUDED.x, y = EXCLUDED.y
		`, eventID, b.id, b.x, b.y)
		if err != nil {
			return fmt.Errorf("demo seed: event beacon %s: %w", b.label, err)
		}
	}

	slog.Info("Demo data seeded", "event", "Demo Check-In Event", "beacons", len(beacons))
	return nil
}
