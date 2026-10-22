package models

import (
	"time"

	"github.com/gofrs/uuid/v5"
)

const CheckinTable = "public.checkins"

type CheckinReadingInput struct {
	IdentityKey      string  `json:"identity_key" validate:"required"`
	RSSISamples      []int   `json:"rssi_samples" validate:"required,min=1"`
	TxPower          *int    `json:"tx_power,omitempty"`
	PlatformDeviceID *string `json:"platform_device_id,omitempty"`
}

type SubmitCheckinRequest struct {
	ClientCheckinID string                `json:"client_checkin_id" validate:"required,uuid"`
	RecordedAt      time.Time             `json:"recorded_at" validate:"required"`
	Readings        []CheckinReadingInput `json:"readings" validate:"required,min=1,dive"`
	DeviceInfo      map[string]any        `json:"device_info,omitempty"`
}

type CheckinReading struct {
	BeaconID         *uuid.UUID `json:"beacon_id,omitempty"`
	IdentityKey      string     `json:"identity_key"`
	Matched          bool       `json:"matched"`
	MedianRSSI       int        `json:"median_rssi"`
	TxPower          *int       `json:"tx_power,omitempty"`
	DistanceM        *float64   `json:"distance_m,omitempty"`
	Samples          []int      `json:"rssi_samples"`
	PlatformDeviceID *string    `json:"platform_device_id,omitempty"`
}

type Checkin struct {
	ID              uuid.UUID        `json:"id"`
	ClientCheckinID uuid.UUID        `json:"client_checkin_id"`
	EventID         uuid.UUID        `json:"event_id"`
	UserID          uuid.UUID        `json:"user_id"`
	UserName        string           `json:"user_name"`
	UserEmail       string           `json:"user_email"`
	Status          string           `json:"status"`
	RejectReason    *string          `json:"reject_reason"`
	RecordedAt      time.Time        `json:"recorded_at"`
	ReceivedAt      time.Time        `json:"received_at"`
	IsOffline       bool             `json:"is_offline"`
	EstimatedX      *float64         `json:"estimated_x"`
	EstimatedY      *float64         `json:"estimated_y"`
	AccuracyM       *float64         `json:"accuracy_m"`
	UsedBeaconCount int              `json:"used_beacon_count"`
	Readings        []CheckinReading `json:"readings"`
	DeviceInfo      map[string]any   `json:"device_info"`
	CreatedAt       time.Time        `json:"created_at"`
}

type CheckinFilter struct {
	Status string `json:"status,omitempty" query:"status"` // accepted|rejected|all
	Limit  int    `json:"limit,omitempty" query:"limit"`
	Offset int    `json:"offset,omitempty" query:"offset"`
}

type SubmitCheckinResponse struct {
	Checkin   *Checkin `json:"checkin"`
	Duplicate bool     `json:"duplicate"`
	Reason    string   `json:"reason,omitempty"`
	Observed  []string `json:"observed_beacons,omitempty"`
}
