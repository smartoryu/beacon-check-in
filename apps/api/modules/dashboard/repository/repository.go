package repository

import (
	"context"

	"api/modules/dashboard/models"

	"github.com/jackc/pgx/v5/pgxpool"
)

type DashboardRepository struct {
	pool *pgxpool.Pool
}

func NewDashboardRepository(pool *pgxpool.Pool) *DashboardRepository {
	return &DashboardRepository{pool: pool}
}

func (r *DashboardRepository) Summary(ctx context.Context) (*models.Summary, error) {
	summary := &models.Summary{
		UserCounts:  map[string]int{"super_admin": 0, "admin": 0, "user": 0},
		EventCounts: map[string]int{"upcoming": 0, "ongoing": 0, "past": 0},
	}

	userRows, err := r.pool.Query(ctx, `SELECT role, COUNT(*) FROM public.users WHERE deleted_at IS NULL GROUP BY role`)
	if err != nil {
		return nil, err
	}
	defer userRows.Close()
	for userRows.Next() {
		var role string
		var count int
		if err := userRows.Scan(&role, &count); err != nil {
			return nil, err
		}
		summary.UserCounts[role] = count
	}

	eventRows, err := r.pool.Query(ctx, `
		SELECT
			COUNT(*) FILTER (WHERE starts_at > NOW()) AS upcoming,
			COUNT(*) FILTER (WHERE starts_at <= NOW() AND ends_at >= NOW()) AS ongoing,
			COUNT(*) FILTER (WHERE ends_at < NOW()) AS past
		FROM public.events WHERE deleted_at IS NULL`)
	if err != nil {
		return nil, err
	}
	defer eventRows.Close()
	if eventRows.Next() {
		var upcoming, ongoing, past int
		if err := eventRows.Scan(&upcoming, &ongoing, &past); err != nil {
			return nil, err
		}
		summary.EventCounts["upcoming"] = upcoming
		summary.EventCounts["ongoing"] = ongoing
		summary.EventCounts["past"] = past
	}

	if err := r.pool.QueryRow(ctx, `SELECT COUNT(*) FROM public.beacons WHERE deleted_at IS NULL`).Scan(&summary.ActiveBeacons); err != nil {
		return nil, err
	}
	if err := r.pool.QueryRow(ctx, `SELECT COUNT(*) FROM public.beacons WHERE deleted_at IS NOT NULL`).Scan(&summary.DeletedBeacons); err != nil {
		return nil, err
	}
	if err := r.pool.QueryRow(ctx, `SELECT COUNT(*) FROM public.checkins WHERE status='accepted' AND recorded_at >= date_trunc('day', NOW())`).Scan(&summary.CheckinsToday); err != nil {
		return nil, err
	}
	if err := r.pool.QueryRow(ctx, `SELECT COUNT(*) FROM public.beacon_change_requests WHERE status='pending'`).Scan(&summary.PendingApprovals); err != nil {
		return nil, err
	}

	rows, err := r.pool.Query(ctx, `
		SELECT c.id, c.event_id, e.title, COALESCE(u.display_name, ''), c.status, c.recorded_at
		FROM public.checkins c
		JOIN public.events e ON e.id = c.event_id
		LEFT JOIN public.users u ON u.id = c.user_id
		ORDER BY c.recorded_at DESC
		LIMIT 10`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	summary.RecentCheckins = []models.RecentCheckin{}
	for rows.Next() {
		var item models.RecentCheckin
		if err := rows.Scan(&item.ID, &item.EventID, &item.EventTitle, &item.UserName, &item.Status, &item.RecordedAt); err != nil {
			return nil, err
		}
		summary.RecentCheckins = append(summary.RecentCheckins, item)
	}

	return summary, nil
}
