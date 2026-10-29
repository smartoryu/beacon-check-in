package repository

import (
	"context"
	"errors"
	"log/slog"
	"strconv"
	"strings"
	"time"

	"api/modules/event/models"

	"github.com/gofrs/uuid/v5"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

var (
	ErrNotFound       = errors.New("not found")
	ErrBeaconNotFound = errors.New("one or more beacons were not found or are deleted")
)

const eventColumns = `e.id, e.title, e.description, e.place_name, e.address, e.latitude, e.longitude,
	e.starts_at, e.ends_at, e.timezone, e.floor_width_m, e.floor_height_m, e.rssi_threshold_dbm,
	e.min_beacons, e.coverage_radius_m, e.path_loss_exponent, e.created_by, e.created_at,
	e.updated_at, e.deleted_at`

const checkinCountSubquery = `(SELECT COUNT(*) FROM public.checkins c WHERE c.event_id = e.id AND c.status = 'accepted') AS checkin_count`

type EventRepository interface {
	Create(ctx context.Context, event *models.Event) error
	Update(ctx context.Context, event *models.Event) error
	Get(ctx context.Context, id uuid.UUID) (*models.Event, error)
	List(ctx context.Context, filter *models.EventFilter) ([]*models.Event, error)
	Active(ctx context.Context) ([]*models.Event, error)
	SoftDelete(ctx context.Context, id uuid.UUID) error
	SetBeacons(ctx context.Context, eventID uuid.UUID, beacons []models.EventBeaconInput) error
	EnsureActiveBeacons(ctx context.Context, ids []uuid.UUID) error
	ConfirmBeaconLocation(ctx context.Context, eventID, beaconID, actorID uuid.UUID, req *models.ConfirmEventBeaconLocationRequest) (*models.EventBeacon, *models.EventBeaconLocationHistory, error)
	ListBeaconLocationHistory(ctx context.Context, eventID, beaconID uuid.UUID) ([]models.EventBeaconLocationHistory, error)
}

type eventRepository struct {
	pool   *pgxpool.Pool
	logger *slog.Logger
}

func NewEventRepository(pool *pgxpool.Pool, logger *slog.Logger) EventRepository {
	return &eventRepository{pool: pool, logger: logger}
}

func (r *eventRepository) Create(ctx context.Context, event *models.Event) error {
	if event.ID == uuid.Nil {
		event.ID = uuid.Must(uuid.NewV7())
	}
	now := time.Now().UTC()
	if event.CreatedAt.IsZero() {
		event.CreatedAt = now
	}

	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback(ctx) }()

	_, err = tx.Exec(ctx, `INSERT INTO `+models.EventTable+` (
		id, title, description, place_name, address, latitude, longitude, starts_at, ends_at,
		timezone, floor_width_m, floor_height_m, rssi_threshold_dbm, min_beacons,
		coverage_radius_m, path_loss_exponent, created_by, created_at
	) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18)`,
		event.ID, event.Title, event.Description, event.PlaceName, event.Address,
		event.Latitude, event.Longitude, event.StartsAt, event.EndsAt, event.Timezone,
		event.FloorWidthM, event.FloorHeightM, event.RSSIThresholdDBM, event.MinBeacons,
		event.CoverageRadiusM, event.PathLossExponent, event.CreatedBy, event.CreatedAt,
	)
	if err != nil {
		return err
	}

	if err := insertEventBeacons(ctx, tx, event.ID, inputsFromEventBeacons(event.Beacons)); err != nil {
		return err
	}
	return tx.Commit(ctx)
}

func (r *eventRepository) Update(ctx context.Context, event *models.Event) error {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback(ctx) }()

	cmd, err := tx.Exec(ctx, `UPDATE `+models.EventTable+` SET
		title=$2, description=$3, place_name=$4, address=$5, latitude=$6, longitude=$7,
		starts_at=$8, ends_at=$9, timezone=$10, floor_width_m=$11, floor_height_m=$12,
		rssi_threshold_dbm=$13, min_beacons=$14, coverage_radius_m=$15, path_loss_exponent=$16,
		updated_at=NOW()
		WHERE id=$1 AND deleted_at IS NULL`,
		event.ID, event.Title, event.Description, event.PlaceName, event.Address,
		event.Latitude, event.Longitude, event.StartsAt, event.EndsAt, event.Timezone,
		event.FloorWidthM, event.FloorHeightM, event.RSSIThresholdDBM, event.MinBeacons,
		event.CoverageRadiusM, event.PathLossExponent,
	)
	if err != nil {
		return err
	}
	if cmd.RowsAffected() == 0 {
		return ErrNotFound
	}

	if event.Beacons != nil {
		if err := syncEventBeacons(ctx, tx, event.ID, inputsFromEventBeacons(event.Beacons)); err != nil {
			return err
		}
	}
	return tx.Commit(ctx)
}

func (r *eventRepository) Get(ctx context.Context, id uuid.UUID) (*models.Event, error) {
	row := r.pool.QueryRow(ctx, `SELECT `+eventColumns+`, `+checkinCountSubquery+` FROM `+models.EventTable+` e WHERE e.id=$1`, id)
	event, err := scanEvent(row)
	if err != nil {
		return nil, err
	}
	event.Beacons, err = r.loadBeacons(ctx, id)
	if err != nil {
		return nil, err
	}
	return event, nil
}

func (r *eventRepository) List(ctx context.Context, filter *models.EventFilter) ([]*models.Event, error) {
	query := `SELECT ` + eventColumns + `, ` + checkinCountSubquery + ` FROM ` + models.EventTable + ` e`
	args := []any{}
	where := []string{}
	argIdx := 1
	now := time.Now().UTC()

	if filter == nil || !filter.IncludeDeleted {
		where = append(where, "e.deleted_at IS NULL")
	}
	if filter != nil {
		switch filter.Status {
		case "upcoming":
			where = append(where, "e.starts_at > $"+itoa(argIdx))
			args = append(args, now)
			argIdx++
		case "ongoing":
			where = append(where, "e.starts_at <= $"+itoa(argIdx)+" AND e.ends_at >= $"+itoa(argIdx))
			args = append(args, now)
			argIdx++
		case "past":
			where = append(where, "e.ends_at < $"+itoa(argIdx))
			args = append(args, now)
			argIdx++
		}
		if filter.Search != "" {
			where = append(where, "(e.title ILIKE $"+itoa(argIdx)+" OR e.place_name ILIKE $"+itoa(argIdx)+")")
			args = append(args, "%"+filter.Search+"%")
			argIdx++
		}
	}
	if len(where) > 0 {
		query += " WHERE " + strings.Join(where, " AND ")
	}
	query += " ORDER BY e.starts_at DESC"
	if filter != nil && filter.Limit > 0 {
		query += " LIMIT $" + itoa(argIdx)
		args = append(args, filter.Limit)
		argIdx++
	}
	if filter != nil && filter.Offset > 0 {
		query += " OFFSET $" + itoa(argIdx)
		args = append(args, filter.Offset)
	}

	rows, err := r.pool.Query(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var events []*models.Event
	for rows.Next() {
		event, err := scanEvent(rows)
		if err != nil {
			return nil, err
		}
		events = append(events, event)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	for _, event := range events {
		event.Beacons, err = r.loadBeacons(ctx, event.ID)
		if err != nil {
			return nil, err
		}
	}
	return events, nil
}

func (r *eventRepository) Active(ctx context.Context) ([]*models.Event, error) {
	rows, err := r.pool.Query(ctx, `SELECT `+eventColumns+`, `+checkinCountSubquery+` FROM `+models.EventTable+` e
		WHERE e.deleted_at IS NULL AND e.ends_at > NOW()
		ORDER BY e.starts_at ASC LIMIT 100`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var events []*models.Event
	for rows.Next() {
		event, err := scanEvent(rows)
		if err != nil {
			return nil, err
		}
		events = append(events, event)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	for _, event := range events {
		event.Beacons, err = r.loadBeacons(ctx, event.ID)
		if err != nil {
			return nil, err
		}
	}
	return events, nil
}

func (r *eventRepository) SoftDelete(ctx context.Context, id uuid.UUID) error {
	cmd, err := r.pool.Exec(ctx, `UPDATE `+models.EventTable+` SET deleted_at=NOW(), updated_at=NOW() WHERE id=$1 AND deleted_at IS NULL`, id)
	if err != nil {
		return err
	}
	if cmd.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

func (r *eventRepository) SetBeacons(ctx context.Context, eventID uuid.UUID, beacons []models.EventBeaconInput) error {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback(ctx) }()

	var exists bool
	if err := tx.QueryRow(ctx, `SELECT EXISTS (SELECT 1 FROM `+models.EventTable+` WHERE id=$1 AND deleted_at IS NULL)`, eventID).Scan(&exists); err != nil {
		return err
	}
	if !exists {
		return ErrNotFound
	}
	if err := syncEventBeacons(ctx, tx, eventID, beacons); err != nil {
		return err
	}
	if _, err := tx.Exec(ctx, `UPDATE `+models.EventTable+` SET updated_at=NOW() WHERE id=$1`, eventID); err != nil {
		return err
	}
	return tx.Commit(ctx)
}

func (r *eventRepository) EnsureActiveBeacons(ctx context.Context, ids []uuid.UUID) error {
	if len(ids) == 0 {
		return ErrBeaconNotFound
	}
	var count int
	if err := r.pool.QueryRow(ctx, `SELECT COUNT(*) FROM public.beacons WHERE id = ANY($1) AND deleted_at IS NULL`, ids).Scan(&count); err != nil {
		return err
	}
	if count != len(ids) {
		return ErrBeaconNotFound
	}
	return nil
}

func (r *eventRepository) loadBeacons(ctx context.Context, eventID uuid.UUID) ([]models.EventBeacon, error) {
	rows, err := r.pool.Query(ctx, `
		SELECT b.id, b.identity_key, b.label, b.local_name, b.tx_power, eb.tx_power_override,
		       eb.x, eb.y, b.deleted_at, eb.latitude, eb.longitude, eb.location_accuracy_m,
		       eb.location_source, eb.location_confirmed_at, eb.location_confirmed_by,
		       u.display_name
		FROM public.event_beacons eb
		JOIN public.beacons b ON b.id = eb.beacon_id
		LEFT JOIN public.users u ON u.id = eb.location_confirmed_by
		WHERE eb.event_id = $1
		ORDER BY b.label`, eventID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var beacons []models.EventBeacon
	for rows.Next() {
		var item models.EventBeacon
		if err := rows.Scan(&item.BeaconID, &item.IdentityKey, &item.Label, &item.LocalName, &item.TxPower, &item.TxPowerOverride, &item.X, &item.Y, &item.BeaconDeletedAt,
			&item.Latitude, &item.Longitude, &item.LocationAccuracyM, &item.LocationSource,
			&item.LocationConfirmedAt, &item.LocationConfirmedBy, &item.LocationConfirmedByName); err != nil {
			return nil, err
		}
		beacons = append(beacons, item)
	}
	return beacons, rows.Err()
}

func syncEventBeacons(ctx context.Context, tx pgx.Tx, eventID uuid.UUID, beacons []models.EventBeaconInput) error {
	ids := make([]uuid.UUID, 0, len(beacons))
	for _, b := range beacons {
		beaconID, err := uuid.FromString(b.BeaconID)
		if err != nil {
			return err
		}
		ids = append(ids, beaconID)
	}

	if _, err := tx.Exec(ctx, `DELETE FROM `+models.EventBeaconTable+` WHERE event_id=$1 AND NOT (beacon_id = ANY($2))`, eventID, ids); err != nil {
		return err
	}

	for _, b := range beacons {
		beaconID, err := uuid.FromString(b.BeaconID)
		if err != nil {
			return err
		}
		if _, err := tx.Exec(ctx, `INSERT INTO `+models.EventBeaconTable+` (event_id, beacon_id, x, y, tx_power_override)
			VALUES ($1,$2,$3,$4,$5)
			ON CONFLICT (event_id, beacon_id) DO UPDATE
			SET x=EXCLUDED.x, y=EXCLUDED.y, tx_power_override=EXCLUDED.tx_power_override`,
			eventID, beaconID, b.X, b.Y, b.TxPowerOverride); err != nil {
			return err
		}
	}
	return nil
}

func (r *eventRepository) ConfirmBeaconLocation(ctx context.Context, eventID, beaconID, actorID uuid.UUID, req *models.ConfirmEventBeaconLocationRequest) (*models.EventBeacon, *models.EventBeaconLocationHistory, error) {
	source := req.Source
	if source == "" {
		source = "gps"
	}
	now := time.Now().UTC()

	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return nil, nil, err
	}
	defer func() { _ = tx.Rollback(ctx) }()

	var eventExists bool
	if err := tx.QueryRow(ctx, `SELECT EXISTS (SELECT 1 FROM `+models.EventTable+` WHERE id=$1 AND deleted_at IS NULL)`, eventID).Scan(&eventExists); err != nil {
		return nil, nil, err
	}
	if !eventExists {
		return nil, nil, ErrNotFound
	}

	var attached bool
	if err := tx.QueryRow(ctx, `SELECT EXISTS (SELECT 1 FROM `+models.EventBeaconTable+` WHERE event_id=$1 AND beacon_id=$2)`, eventID, beaconID).Scan(&attached); err != nil {
		return nil, nil, err
	}
	if !attached {
		return nil, nil, ErrBeaconNotFound
	}

	if _, err := tx.Exec(ctx, `UPDATE `+models.EventBeaconTable+`
		SET latitude=$3, longitude=$4, location_accuracy_m=$5, location_source=$6,
		    location_confirmed_at=$7, location_confirmed_by=$8
		WHERE event_id=$1 AND beacon_id=$2`,
		eventID, beaconID, *req.Latitude, *req.Longitude, req.AccuracyM, source, now, actorID); err != nil {
		return nil, nil, err
	}

	history := &models.EventBeaconLocationHistory{
		EventID:    eventID,
		BeaconID:   beaconID,
		Latitude:   *req.Latitude,
		Longitude:  *req.Longitude,
		AccuracyM:  req.AccuracyM,
		Source:     source,
		RecordedBy: &actorID,
		CreatedAt:  now,
	}
	if err := tx.QueryRow(ctx, `INSERT INTO public.event_beacon_location_history
		(event_id, beacon_id, latitude, longitude, accuracy_m, source, recorded_by, created_at)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8)
		RETURNING id`,
		eventID, beaconID, *req.Latitude, *req.Longitude, req.AccuracyM, source, actorID, now).Scan(&history.ID); err != nil {
		return nil, nil, err
	}
	var actorName string
	if err := tx.QueryRow(ctx, `SELECT display_name FROM public.users WHERE id=$1`, actorID).Scan(&actorName); err == nil {
		history.RecordedByName = &actorName
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, nil, err
	}

	beacons, err := r.loadBeacons(ctx, eventID)
	if err != nil {
		return nil, nil, err
	}
	for _, beacon := range beacons {
		if beacon.BeaconID == beaconID {
			item := beacon
			return &item, history, nil
		}
	}
	return nil, history, nil
}

func (r *eventRepository) ListBeaconLocationHistory(ctx context.Context, eventID, beaconID uuid.UUID) ([]models.EventBeaconLocationHistory, error) {
	rows, err := r.pool.Query(ctx, `
		SELECT h.id, h.event_id, h.beacon_id, h.latitude, h.longitude, h.accuracy_m,
		       h.source, h.recorded_by, u.display_name, h.created_at
		FROM public.event_beacon_location_history h
		LEFT JOIN public.users u ON u.id = h.recorded_by
		WHERE h.event_id=$1 AND h.beacon_id=$2
		ORDER BY h.created_at DESC`, eventID, beaconID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var items []models.EventBeaconLocationHistory
	for rows.Next() {
		var item models.EventBeaconLocationHistory
		if err := rows.Scan(&item.ID, &item.EventID, &item.BeaconID, &item.Latitude, &item.Longitude,
			&item.AccuracyM, &item.Source, &item.RecordedBy, &item.RecordedByName, &item.CreatedAt); err != nil {
			return nil, err
		}
		items = append(items, item)
	}
	return items, rows.Err()
}

func insertEventBeacons(ctx context.Context, tx pgx.Tx, eventID uuid.UUID, beacons []models.EventBeaconInput) error {
	for _, b := range beacons {
		beaconID, err := uuid.FromString(b.BeaconID)
		if err != nil {
			return err
		}
		if _, err := tx.Exec(ctx, `INSERT INTO `+models.EventBeaconTable+` (event_id, beacon_id, x, y, tx_power_override)
			VALUES ($1,$2,$3,$4,$5)`, eventID, beaconID, b.X, b.Y, b.TxPowerOverride); err != nil {
			return err
		}
	}
	return nil
}

func inputsFromEventBeacons(beacons []models.EventBeacon) []models.EventBeaconInput {
	inputs := make([]models.EventBeaconInput, 0, len(beacons))
	for _, b := range beacons {
		inputs = append(inputs, models.EventBeaconInput{
			BeaconID:        b.BeaconID.String(),
			X:               b.X,
			Y:               b.Y,
			TxPowerOverride: b.TxPowerOverride,
		})
	}
	return inputs
}

func scanEvent(row pgx.Row) (*models.Event, error) {
	var event models.Event
	err := row.Scan(
		&event.ID, &event.Title, &event.Description, &event.PlaceName, &event.Address,
		&event.Latitude, &event.Longitude, &event.StartsAt, &event.EndsAt, &event.Timezone,
		&event.FloorWidthM, &event.FloorHeightM, &event.RSSIThresholdDBM, &event.MinBeacons,
		&event.CoverageRadiusM, &event.PathLossExponent, &event.CreatedBy, &event.CreatedAt,
		&event.UpdatedAt, &event.DeletedAt, &event.CheckinCount,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	return &event, nil
}

func itoa(i int) string {
	return strconv.Itoa(i)
}
