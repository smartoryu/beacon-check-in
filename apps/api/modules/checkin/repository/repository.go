package repository

import (
	"context"
	"encoding/json"
	"errors"
	"log/slog"
	"strconv"

	"api/modules/checkin/models"

	"github.com/gofrs/uuid/v5"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
)

var (
	ErrNotFound         = errors.New("not found")
	ErrDuplicate        = errors.New("duplicate check-in")
	ErrAlreadyCheckedIn = errors.New("already checked in")
)

const checkinSelect = `
	SELECT c.id, c.client_checkin_id, c.event_id, c.user_id,
	       COALESCE(u.display_name, ''), COALESCE(u.email, ''),
	       c.status, c.reject_reason, c.recorded_at, c.received_at, c.is_offline,
	       c.estimated_x, c.estimated_y, c.accuracy_m, c.used_beacon_count,
	       c.readings, c.device_info, c.created_at
	FROM public.checkins c
	LEFT JOIN public.users u ON u.id = c.user_id`

type CheckinRepository interface {
	Create(ctx context.Context, checkin *models.Checkin) error
	GetByClientID(ctx context.Context, clientCheckinID uuid.UUID) (*models.Checkin, error)
	ExistsAccepted(ctx context.Context, eventID, userID uuid.UUID) (bool, error)
	ListByEvent(ctx context.Context, eventID uuid.UUID, filter *models.CheckinFilter) ([]*models.Checkin, error)
	ListByUser(ctx context.Context, userID uuid.UUID, filter *models.CheckinFilter) ([]*models.Checkin, error)
}

type checkinRepository struct {
	pool   *pgxpool.Pool
	logger *slog.Logger
}

func NewCheckinRepository(pool *pgxpool.Pool, logger *slog.Logger) CheckinRepository {
	return &checkinRepository{pool: pool, logger: logger}
}

func (r *checkinRepository) Create(ctx context.Context, checkin *models.Checkin) error {
	readings, err := json.Marshal(checkin.Readings)
	if err != nil {
		return err
	}
	deviceInfo, err := json.Marshal(checkin.DeviceInfo)
	if err != nil {
		return err
	}

	err = r.pool.QueryRow(ctx, `
		INSERT INTO public.checkins (
			client_checkin_id, event_id, user_id, status, reject_reason, recorded_at,
			received_at, is_offline, estimated_x, estimated_y, accuracy_m,
			used_beacon_count, readings, device_info
		) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13::jsonb,$14::jsonb)
		RETURNING id, created_at`,
		checkin.ClientCheckinID, checkin.EventID, checkin.UserID, checkin.Status, checkin.RejectReason,
		checkin.RecordedAt, checkin.ReceivedAt, checkin.IsOffline, checkin.EstimatedX,
		checkin.EstimatedY, checkin.AccuracyM, checkin.UsedBeaconCount, readings, deviceInfo,
	).Scan(&checkin.ID, &checkin.CreatedAt)
	if err != nil {
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23505" {
			switch pgErr.ConstraintName {
			case "uq_checkins_client_checkin_id":
				return ErrDuplicate
			case "uq_checkins_accepted_event_user":
				return ErrAlreadyCheckedIn
			}
			return ErrDuplicate
		}
		return err
	}
	return nil
}

func (r *checkinRepository) GetByClientID(ctx context.Context, clientCheckinID uuid.UUID) (*models.Checkin, error) {
	row := r.pool.QueryRow(ctx, checkinSelect+` WHERE c.client_checkin_id = $1`, clientCheckinID)
	return scanCheckin(row)
}

func (r *checkinRepository) ExistsAccepted(ctx context.Context, eventID, userID uuid.UUID) (bool, error) {
	var exists bool
	err := r.pool.QueryRow(ctx, `SELECT EXISTS (SELECT 1 FROM public.checkins WHERE event_id=$1 AND user_id=$2 AND status='accepted')`, eventID, userID).Scan(&exists)
	return exists, err
}

func (r *checkinRepository) ListByEvent(ctx context.Context, eventID uuid.UUID, filter *models.CheckinFilter) ([]*models.Checkin, error) {
	query := checkinSelect + ` WHERE c.event_id = $1`
	args := []any{eventID}
	argIdx := 2
	if filter != nil && (filter.Status == "accepted" || filter.Status == "rejected") {
		query += ` AND c.status = $` + itoa(argIdx)
		args = append(args, filter.Status)
		argIdx++
	}
	query += ` ORDER BY c.recorded_at DESC`
	if filter != nil && filter.Limit > 0 {
		query += ` LIMIT $` + itoa(argIdx)
		args = append(args, filter.Limit)
		argIdx++
	}
	if filter != nil && filter.Offset > 0 {
		query += ` OFFSET $` + itoa(argIdx)
		args = append(args, filter.Offset)
	}
	return r.queryCheckins(ctx, query, args...)
}

func (r *checkinRepository) ListByUser(ctx context.Context, userID uuid.UUID, filter *models.CheckinFilter) ([]*models.Checkin, error) {
	query := checkinSelect + ` WHERE c.user_id = $1`
	args := []any{userID}
	argIdx := 2
	if filter != nil && (filter.Status == "accepted" || filter.Status == "rejected") {
		query += ` AND c.status = $` + itoa(argIdx)
		args = append(args, filter.Status)
		argIdx++
	}
	query += ` ORDER BY c.recorded_at DESC`
	if filter != nil && filter.Limit > 0 {
		query += ` LIMIT $` + itoa(argIdx)
		args = append(args, filter.Limit)
		argIdx++
	}
	if filter != nil && filter.Offset > 0 {
		query += ` OFFSET $` + itoa(argIdx)
		args = append(args, filter.Offset)
	}
	return r.queryCheckins(ctx, query, args...)
}

func (r *checkinRepository) queryCheckins(ctx context.Context, query string, args ...any) ([]*models.Checkin, error) {
	rows, err := r.pool.Query(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var items []*models.Checkin
	for rows.Next() {
		item, err := scanCheckin(rows)
		if err != nil {
			return nil, err
		}
		items = append(items, item)
	}
	return items, rows.Err()
}

func scanCheckin(row pgx.Row) (*models.Checkin, error) {
	var checkin models.Checkin
	var readingsBytes, deviceBytes []byte
	err := row.Scan(
		&checkin.ID, &checkin.ClientCheckinID, &checkin.EventID, &checkin.UserID,
		&checkin.UserName, &checkin.UserEmail, &checkin.Status, &checkin.RejectReason,
		&checkin.RecordedAt, &checkin.ReceivedAt, &checkin.IsOffline,
		&checkin.EstimatedX, &checkin.EstimatedY, &checkin.AccuracyM,
		&checkin.UsedBeaconCount, &readingsBytes, &deviceBytes, &checkin.CreatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	if len(readingsBytes) > 0 {
		_ = json.Unmarshal(readingsBytes, &checkin.Readings)
	}
	if len(deviceBytes) > 0 {
		_ = json.Unmarshal(deviceBytes, &checkin.DeviceInfo)
	}
	return &checkin, nil
}

func itoa(i int) string {
	return strconv.Itoa(i)
}
