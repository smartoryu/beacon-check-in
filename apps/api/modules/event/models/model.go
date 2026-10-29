package models

import (
	"time"

	"github.com/gofrs/uuid/v5"
)

const EventTable = "public.events"
const EventBeaconTable = "public.event_beacons"

type Event struct {
	ID               uuid.UUID     `json:"id" db:"id"`
	Title            string        `json:"title" db:"title"`
	Description      *string       `json:"description" db:"description"`
	PlaceName        string        `json:"place_name" db:"place_name"`
	Address          *string       `json:"address" db:"address"`
	Latitude         *float64      `json:"latitude" db:"latitude"`
	Longitude        *float64      `json:"longitude" db:"longitude"`
	StartsAt         time.Time     `json:"starts_at" db:"starts_at"`
	EndsAt           time.Time     `json:"ends_at" db:"ends_at"`
	Timezone         string        `json:"timezone" db:"timezone"`
	FloorWidthM      float64       `json:"floor_width_m" db:"floor_width_m"`
	FloorHeightM     float64       `json:"floor_height_m" db:"floor_height_m"`
	RSSIThresholdDBM int           `json:"rssi_threshold_dbm" db:"rssi_threshold_dbm"`
	MinBeacons       int           `json:"min_beacons" db:"min_beacons"`
	CoverageRadiusM  *float64      `json:"coverage_radius_m" db:"coverage_radius_m"`
	PathLossExponent float64       `json:"path_loss_exponent" db:"path_loss_exponent"`
	CreatedBy        *uuid.UUID    `json:"created_by" db:"created_by"`
	CreatedAt        time.Time     `json:"created_at" db:"created_at"`
	UpdatedAt        *time.Time    `json:"updated_at" db:"updated_at"`
	DeletedAt        *time.Time    `json:"deleted_at" db:"deleted_at"`
	Beacons          []EventBeacon `json:"beacons"`
	CheckinCount     int           `json:"checkin_count"`
}

type EventBeacon struct {
	BeaconID                uuid.UUID  `json:"beacon_id"`
	IdentityKey             string     `json:"identity_key"`
	Label                   string     `json:"label"`
	LocalName               *string    `json:"local_name"`
	TxPower                 *int       `json:"tx_power"`
	TxPowerOverride         *int       `json:"tx_power_override"`
	X                       float64    `json:"x"`
	Y                       float64    `json:"y"`
	BeaconDeletedAt         *time.Time `json:"beacon_deleted_at"`
	Latitude                *float64   `json:"latitude"`
	Longitude               *float64   `json:"longitude"`
	LocationAccuracyM       *float64   `json:"location_accuracy_m"`
	LocationSource          *string    `json:"location_source"`
	LocationConfirmedAt     *time.Time `json:"location_confirmed_at"`
	LocationConfirmedBy     *uuid.UUID `json:"location_confirmed_by"`
	LocationConfirmedByName *string    `json:"location_confirmed_by_name"`
}

type EventBeaconLocationHistory struct {
	ID             uuid.UUID  `json:"id"`
	EventID        uuid.UUID  `json:"event_id"`
	BeaconID       uuid.UUID  `json:"beacon_id"`
	Latitude       float64    `json:"latitude"`
	Longitude      float64    `json:"longitude"`
	AccuracyM      *float64   `json:"accuracy_m"`
	Source         string     `json:"source"`
	RecordedBy     *uuid.UUID `json:"recorded_by"`
	RecordedByName *string    `json:"recorded_by_name"`
	CreatedAt      time.Time  `json:"created_at"`
}

type EventFilter struct {
	Search         string `json:"search,omitempty" query:"search"`
	Status         string `json:"status,omitempty" query:"status"` // upcoming|ongoing|past|all
	IncludeDeleted bool   `json:"include_deleted,omitempty" query:"include_deleted"`
	Limit          int    `json:"limit,omitempty" query:"limit"`
	Offset         int    `json:"offset,omitempty" query:"offset"`
}
