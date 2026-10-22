package models

import "time"

type EventBeaconInput struct {
	BeaconID        string  `json:"beacon_id" validate:"required,uuid"`
	X               float64 `json:"x"`
	Y               float64 `json:"y"`
	TxPowerOverride *int    `json:"tx_power_override,omitempty"`
}

type CreateEventRequest struct {
	Title            string             `json:"title" validate:"required,min=1,max=200"`
	Description      *string            `json:"description,omitempty"`
	PlaceName        string             `json:"place_name" validate:"required,min=1,max=200"`
	Address          *string            `json:"address,omitempty"`
	Latitude         *float64           `json:"latitude,omitempty"`
	Longitude        *float64           `json:"longitude,omitempty"`
	StartsAt         time.Time          `json:"starts_at" validate:"required"`
	EndsAt           time.Time          `json:"ends_at" validate:"required"`
	Timezone         string             `json:"timezone"`
	FloorWidthM      float64            `json:"floor_width_m"`
	FloorHeightM     float64            `json:"floor_height_m"`
	RSSIThresholdDBM int                `json:"rssi_threshold_dbm"`
	MinBeacons       int                `json:"min_beacons"`
	CoverageRadiusM  *float64           `json:"coverage_radius_m,omitempty"`
	PathLossExponent float64            `json:"path_loss_exponent"`
	Beacons          []EventBeaconInput `json:"beacons" validate:"required,min=1,dive"`
}

type UpdateEventRequest = CreateEventRequest

type SetEventBeaconsRequest struct {
	Beacons []EventBeaconInput `json:"beacons" validate:"required,min=1,dive"`
}

type ActiveEventsResponse struct {
	Events []*Event `json:"events"`
}
