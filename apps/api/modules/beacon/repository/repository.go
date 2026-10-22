package repository

import (
	"context"
	"encoding/json"
	"errors"
	"log/slog"
	"strconv"
	"time"

	"api/modules/beacon/models"

	"github.com/gofrs/uuid/v5"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
)

var (
	ErrNotFound            = errors.New("not found")
	ErrBeaconExists        = errors.New("beacon already registered")
	ErrBeaconInActiveEvent = errors.New("beacon is attached to an ongoing or upcoming event")
	ErrRequestNotPending   = errors.New("change request is not pending")
)

const beaconColumns = `id, identity_key, proximity_uuid, major, minor, label, local_name,
	platform_device_id, device_address_type, tx_power, metadata, gatt_info, gatt_read_at,
	registered_by, registered_at, last_seen_at, deleted_at, deleted_by, created_at, updated_at`

type BeaconRepository interface {
	Create(ctx context.Context, beacon *models.Beacon) error
	GetByID(ctx context.Context, id uuid.UUID) (*models.Beacon, error)
	GetByIdentity(ctx context.Context, identityKey string) (*models.Beacon, error)
	Lookup(ctx context.Context, identities []string) ([]*models.Beacon, error)
	List(ctx context.Context, filter *models.BeaconFilter) ([]*models.Beacon, error)
	UpdateLabel(ctx context.Context, id uuid.UUID, label string) (*models.Beacon, error)
	SoftDelete(ctx context.Context, id, actorID uuid.UUID) error
	Restore(ctx context.Context, id uuid.UUID) error
	HasActiveEvents(ctx context.Context, id uuid.UUID) (bool, error)
	Usage(ctx context.Context, id uuid.UUID) ([]models.BeaconUsage, error)

	CreateChangeRequest(ctx context.Context, req *models.ChangeRequest) error
	ListChangeRequests(ctx context.Context, status string) ([]models.ChangeRequest, error)
	GetChangeRequest(ctx context.Context, id uuid.UUID) (*models.ChangeRequest, error)
	ApproveChangeRequest(ctx context.Context, id, reviewerID uuid.UUID, note string) error
	RejectChangeRequest(ctx context.Context, id, reviewerID uuid.UUID, note string) error
	HasPendingRequest(ctx context.Context, beaconID uuid.UUID, action string) (bool, error)
}

type beaconRepository struct {
	pool   *pgxpool.Pool
	logger *slog.Logger
}

func NewBeaconRepository(pool *pgxpool.Pool, logger *slog.Logger) BeaconRepository {
	return &beaconRepository{pool: pool, logger: logger}
}

func (r *beaconRepository) Create(ctx context.Context, beacon *models.Beacon) error {
	if beacon.ID == uuid.Nil {
		beacon.ID = uuid.Must(uuid.NewV7())
	}
	if beacon.RegisteredAt.IsZero() {
		beacon.RegisteredAt = time.Now().UTC()
	}
	if beacon.CreatedAt.IsZero() {
		beacon.CreatedAt = time.Now().UTC()
	}
	metadata, err := marshalJSON(beacon.Metadata)
	if err != nil {
		return err
	}
	gattInfo, err := marshalJSON(beacon.GattInfo)
	if err != nil {
		return err
	}

	query := `INSERT INTO ` + models.BeaconTable + ` (
		id, identity_key, proximity_uuid, major, minor, label, local_name,
		platform_device_id, device_address_type, tx_power, metadata, gatt_info, gatt_read_at,
		registered_by, registered_at, last_seen_at, deleted_at, deleted_by, created_at, updated_at
	) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11::jsonb,$12::jsonb,$13,$14,$15,$16,$17,$18,$19,$20)`
	_, err = r.pool.Exec(ctx, query,
		beacon.ID, beacon.IdentityKey, beacon.ProximityUUID, beacon.Major, beacon.Minor, beacon.Label,
		beacon.LocalName, beacon.PlatformDeviceID, beacon.DeviceAddressType, beacon.TxPower,
		metadata, gattInfo, beacon.GattReadAt, beacon.RegisteredBy, beacon.RegisteredAt,
		beacon.LastSeenAt, beacon.DeletedAt, beacon.DeletedBy, beacon.CreatedAt, beacon.UpdatedAt,
	)
	if err != nil {
		if isUniqueViolation(err) {
			return ErrBeaconExists
		}
		return err
	}
	return nil
}

func (r *beaconRepository) GetByID(ctx context.Context, id uuid.UUID) (*models.Beacon, error) {
	row := r.pool.QueryRow(ctx, `SELECT `+beaconColumns+` FROM `+models.BeaconTable+` WHERE id = $1`, id)
	return scanBeacon(row)
}

func (r *beaconRepository) GetByIdentity(ctx context.Context, identityKey string) (*models.Beacon, error) {
	row := r.pool.QueryRow(ctx, `SELECT `+beaconColumns+` FROM `+models.BeaconTable+` WHERE identity_key = $1`, identityKey)
	return scanBeacon(row)
}

func (r *beaconRepository) Lookup(ctx context.Context, identities []string) ([]*models.Beacon, error) {
	rows, err := r.pool.Query(ctx, `SELECT `+beaconColumns+` FROM `+models.BeaconTable+` WHERE identity_key = ANY($1)`, identities)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var beacons []*models.Beacon
	for rows.Next() {
		beacon, err := scanBeacon(rows)
		if err != nil {
			return nil, err
		}
		beacons = append(beacons, beacon)
	}
	return beacons, rows.Err()
}

func (r *beaconRepository) List(ctx context.Context, filter *models.BeaconFilter) ([]*models.Beacon, error) {
	query := `SELECT ` + beaconColumns + ` FROM ` + models.BeaconTable
	args := []any{}
	where := []string{}
	argIdx := 1

	if filter != nil {
		switch filter.Status {
		case "active":
			where = append(where, "deleted_at IS NULL")
		case "deleted":
			where = append(where, "deleted_at IS NOT NULL")
		default:
			if !filter.IncludeDeleted {
				where = append(where, "deleted_at IS NULL")
			}
		}
		if filter.Search != "" {
			where = append(where, "(label ILIKE $"+itoa(argIdx)+" OR identity_key ILIKE $"+itoa(argIdx)+" OR local_name ILIKE $"+itoa(argIdx)+")")
			args = append(args, "%"+filter.Search+"%")
			argIdx++
		}
	} else {
		where = append(where, "deleted_at IS NULL")
	}

	if len(where) > 0 {
		query += " WHERE " + join(where, " AND ")
	}
	query += " ORDER BY created_at DESC"
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

	var beacons []*models.Beacon
	for rows.Next() {
		beacon, err := scanBeacon(rows)
		if err != nil {
			return nil, err
		}
		beacons = append(beacons, beacon)
	}
	return beacons, rows.Err()
}

func (r *beaconRepository) UpdateLabel(ctx context.Context, id uuid.UUID, label string) (*models.Beacon, error) {
	row := r.pool.QueryRow(ctx, `UPDATE `+models.BeaconTable+` SET label = $1, updated_at = NOW() WHERE id = $2 RETURNING `+beaconColumns, label, id)
	return scanBeacon(row)
}

func (r *beaconRepository) SoftDelete(ctx context.Context, id, actorID uuid.UUID) error {
	cmd, err := r.pool.Exec(ctx, `UPDATE `+models.BeaconTable+` SET deleted_at = NOW(), deleted_by = $2, updated_at = NOW() WHERE id = $1 AND deleted_at IS NULL`, id, actorID)
	if err != nil {
		return err
	}
	if cmd.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

func (r *beaconRepository) Restore(ctx context.Context, id uuid.UUID) error {
	cmd, err := r.pool.Exec(ctx, `UPDATE `+models.BeaconTable+` SET deleted_at = NULL, deleted_by = NULL, updated_at = NOW() WHERE id = $1`, id)
	if err != nil {
		return err
	}
	if cmd.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

func (r *beaconRepository) HasActiveEvents(ctx context.Context, id uuid.UUID) (bool, error) {
	var exists bool
	err := r.pool.QueryRow(ctx, `
		SELECT EXISTS (
			SELECT 1 FROM public.event_beacons eb
			JOIN public.events e ON e.id = eb.event_id
			WHERE eb.beacon_id = $1 AND e.deleted_at IS NULL AND e.ends_at > NOW()
		)`, id).Scan(&exists)
	return exists, err
}

func (r *beaconRepository) Usage(ctx context.Context, id uuid.UUID) ([]models.BeaconUsage, error) {
	rows, err := r.pool.Query(ctx, `
		SELECT e.id, e.title, e.starts_at, e.ends_at, eb.x, eb.y, e.deleted_at
		FROM public.event_beacons eb
		JOIN public.events e ON e.id = eb.event_id
		WHERE eb.beacon_id = $1
		ORDER BY e.starts_at DESC`, id)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var usage []models.BeaconUsage
	for rows.Next() {
		var item models.BeaconUsage
		if err := rows.Scan(&item.EventID, &item.Title, &item.StartsAt, &item.EndsAt, &item.X, &item.Y, &item.DeletedAt); err != nil {
			return nil, err
		}
		usage = append(usage, item)
	}
	return usage, rows.Err()
}

func (r *beaconRepository) CreateChangeRequest(ctx context.Context, req *models.ChangeRequest) error {
	if req.ID == uuid.Nil {
		req.ID = uuid.Must(uuid.NewV7())
	}
	if req.CreatedAt.IsZero() {
		req.CreatedAt = time.Now().UTC()
	}
	_, err := r.pool.Exec(ctx, `INSERT INTO `+models.ChangeRequestTable+`
		(id, beacon_id, action, reason, status, requested_by, created_at)
		VALUES ($1,$2,$3,$4,'pending',$5,$6)`,
		req.ID, req.BeaconID, req.Action, req.Reason, req.RequestedBy, req.CreatedAt)
	if err != nil && isUniqueViolation(err) {
		return errors.New("a pending request already exists for this beacon and action")
	}
	return err
}

func (r *beaconRepository) ListChangeRequests(ctx context.Context, status string) ([]models.ChangeRequest, error) {
	query := changeRequestSelect
	args := []any{}
	if status != "" {
		query += ` WHERE r.status = $1`
		args = append(args, status)
	}
	query += ` ORDER BY r.created_at DESC`

	rows, err := r.pool.Query(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	return scanChangeRequests(rows)
}

func (r *beaconRepository) GetChangeRequest(ctx context.Context, id uuid.UUID) (*models.ChangeRequest, error) {
	rows, err := r.pool.Query(ctx, changeRequestSelect+` WHERE r.id = $1`, id)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	items, err := scanChangeRequests(rows)
	if err != nil {
		return nil, err
	}
	if len(items) == 0 {
		return nil, ErrNotFound
	}
	return &items[0], nil
}

func (r *beaconRepository) ApproveChangeRequest(ctx context.Context, id, reviewerID uuid.UUID, note string) error {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback(ctx) }()

	var beaconID uuid.UUID
	var action, status string
	if err := tx.QueryRow(ctx, `SELECT beacon_id, action, status FROM `+models.ChangeRequestTable+` WHERE id = $1 FOR UPDATE`, id).Scan(&beaconID, &action, &status); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return ErrNotFound
		}
		return err
	}
	if status != "pending" {
		return ErrRequestNotPending
	}

	switch action {
	case "delete":
		var active bool
		if err := tx.QueryRow(ctx, `
			SELECT EXISTS (
				SELECT 1 FROM public.event_beacons eb
				JOIN public.events e ON e.id = eb.event_id
				WHERE eb.beacon_id = $1 AND e.deleted_at IS NULL AND e.ends_at > NOW()
			)`, beaconID).Scan(&active); err != nil {
			return err
		}
		if active {
			return ErrBeaconInActiveEvent
		}
		if _, err := tx.Exec(ctx, `UPDATE `+models.BeaconTable+` SET deleted_at = NOW(), deleted_by = $2, updated_at = NOW() WHERE id = $1 AND deleted_at IS NULL`, beaconID, reviewerID); err != nil {
			return err
		}
	case "restore":
		if _, err := tx.Exec(ctx, `UPDATE `+models.BeaconTable+` SET deleted_at = NULL, deleted_by = NULL, updated_at = NOW() WHERE id = $1`, beaconID); err != nil {
			return err
		}
	default:
		return errors.New("invalid request action")
	}

	if _, err := tx.Exec(ctx, `UPDATE `+models.ChangeRequestTable+`
		SET status = 'approved', reviewed_by = $2, review_note = NULLIF($3,''), reviewed_at = NOW(), updated_at = NOW()
		WHERE id = $1`, id, reviewerID, note); err != nil {
		return err
	}
	return tx.Commit(ctx)
}

func (r *beaconRepository) RejectChangeRequest(ctx context.Context, id, reviewerID uuid.UUID, note string) error {
	cmd, err := r.pool.Exec(ctx, `UPDATE `+models.ChangeRequestTable+`
		SET status = 'rejected', reviewed_by = $2, review_note = NULLIF($3,''), reviewed_at = NOW(), updated_at = NOW()
		WHERE id = $1 AND status = 'pending'`, id, reviewerID, note)
	if err != nil {
		return err
	}
	if cmd.RowsAffected() == 0 {
		return ErrRequestNotPending
	}
	return nil
}

func (r *beaconRepository) HasPendingRequest(ctx context.Context, beaconID uuid.UUID, action string) (bool, error) {
	var exists bool
	err := r.pool.QueryRow(ctx, `SELECT EXISTS (SELECT 1 FROM `+models.ChangeRequestTable+` WHERE beacon_id = $1 AND action = $2 AND status = 'pending')`, beaconID, action).Scan(&exists)
	return exists, err
}

const changeRequestSelect = `
	SELECT r.id, r.beacon_id, r.action, r.reason, r.status, r.requested_by, r.reviewed_by,
	       r.review_note, r.reviewed_at, r.created_at, r.updated_at,
	       b.label, b.identity_key,
	       COALESCE(req.display_name, 'Unknown') AS requester_name,
	       rev.display_name AS reviewer_name
	FROM ` + models.ChangeRequestTable + ` r
	JOIN public.beacons b ON b.id = r.beacon_id
	LEFT JOIN public.users req ON req.id = r.requested_by
	LEFT JOIN public.users rev ON rev.id = r.reviewed_by`

func scanChangeRequests(rows pgx.Rows) ([]models.ChangeRequest, error) {
	var items []models.ChangeRequest
	for rows.Next() {
		var item models.ChangeRequest
		if err := rows.Scan(
			&item.ID, &item.BeaconID, &item.Action, &item.Reason, &item.Status,
			&item.RequestedBy, &item.ReviewedBy, &item.ReviewNote, &item.ReviewedAt,
			&item.CreatedAt, &item.UpdatedAt, &item.BeaconLabel, &item.BeaconIdentity,
			&item.RequesterName, &item.ReviewerName,
		); err != nil {
			return nil, err
		}
		items = append(items, item)
	}
	return items, rows.Err()
}

func scanBeacon(row pgx.Row) (*models.Beacon, error) {
	var beacon models.Beacon
	var metadataBytes, gattBytes []byte
	err := row.Scan(
		&beacon.ID, &beacon.IdentityKey, &beacon.ProximityUUID, &beacon.Major, &beacon.Minor,
		&beacon.Label, &beacon.LocalName, &beacon.PlatformDeviceID, &beacon.DeviceAddressType,
		&beacon.TxPower, &metadataBytes, &gattBytes, &beacon.GattReadAt, &beacon.RegisteredBy,
		&beacon.RegisteredAt, &beacon.LastSeenAt, &beacon.DeletedAt, &beacon.DeletedBy,
		&beacon.CreatedAt, &beacon.UpdatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	if len(metadataBytes) > 0 {
		_ = json.Unmarshal(metadataBytes, &beacon.Metadata)
	}
	if len(gattBytes) > 0 {
		_ = json.Unmarshal(gattBytes, &beacon.GattInfo)
	}
	return &beacon, nil
}

func marshalJSON(value map[string]any) ([]byte, error) {
	if value == nil {
		return nil, nil
	}
	return json.Marshal(value)
}

func isUniqueViolation(err error) bool {
	var pgErr *pgconn.PgError
	return errors.As(err, &pgErr) && pgErr.Code == "23505"
}

func itoa(i int) string {
	return strconv.Itoa(i)
}

func join(items []string, sep string) string {
	if len(items) == 0 {
		return ""
	}
	result := items[0]
	for i := 1; i < len(items); i++ {
		result += sep + items[i]
	}
	return result
}
