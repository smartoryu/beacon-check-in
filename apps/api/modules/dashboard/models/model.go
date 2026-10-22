package models

import "time"

type Summary struct {
	UserCounts       map[string]int  `json:"user_counts"`
	EventCounts      map[string]int  `json:"event_counts"`
	ActiveBeacons    int             `json:"active_beacons"`
	DeletedBeacons   int             `json:"deleted_beacons"`
	CheckinsToday    int             `json:"checkins_today"`
	PendingApprovals int             `json:"pending_approvals"`
	RecentCheckins   []RecentCheckin `json:"recent_checkins"`
}

type RecentCheckin struct {
	ID         string    `json:"id"`
	EventID    string    `json:"event_id"`
	EventTitle string    `json:"event_title"`
	UserName   string    `json:"user_name"`
	Status     string    `json:"status"`
	RecordedAt time.Time `json:"recorded_at"`
}
