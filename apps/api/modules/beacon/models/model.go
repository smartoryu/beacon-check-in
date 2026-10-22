package models

import (
	"time"

	"github.com/gofrs/uuid/v5"
)

const BeaconTable = "public.beacons"
const ChangeRequestTable = "public.beacon_change_requests"

type Beacon struct {
	ID                uuid.UUID      `json:"id" db:"id"`
	IdentityKey       string         `json:"identity_key" db:"identity_key"`
	ProximityUUID     uuid.UUID      `json:"proximity_uuid" db:"proximity_uuid"`
	Major             int            `json:"major" db:"major"`
	Minor             int            `json:"minor" db:"minor"`
	Label             string         `json:"label" db:"label"`
	LocalName         *string        `json:"local_name" db:"local_name"`
	PlatformDeviceID  *string        `json:"platform_device_id" db:"platform_device_id"`
	DeviceAddressType *string        `json:"device_address_type" db:"device_address_type"`
	TxPower           *int           `json:"tx_power" db:"tx_power"`
	Metadata          map[string]any `json:"metadata" db:"metadata"`
	GattInfo          map[string]any `json:"gatt_info" db:"gatt_info"`
	GattReadAt        *time.Time     `json:"gatt_read_at" db:"gatt_read_at"`
	RegisteredBy      *uuid.UUID     `json:"registered_by" db:"registered_by"`
	RegisteredAt      time.Time      `json:"registered_at" db:"registered_at"`
	LastSeenAt        *time.Time     `json:"last_seen_at" db:"last_seen_at"`
	DeletedAt         *time.Time     `json:"deleted_at" db:"deleted_at"`
	DeletedBy         *uuid.UUID     `json:"deleted_by" db:"deleted_by"`
	CreatedAt         time.Time      `json:"created_at" db:"created_at"`
	UpdatedAt         *time.Time     `json:"updated_at" db:"updated_at"`
}

type BeaconFilter struct {
	Search         string `json:"search,omitempty" query:"search"`
	Status         string `json:"status,omitempty" query:"status"` // active|deleted|all
	IncludeDeleted bool   `json:"include_deleted,omitempty" query:"include_deleted"`
	Limit          int    `json:"limit,omitempty" query:"limit"`
	Offset         int    `json:"offset,omitempty" query:"offset"`
}

type BeaconUsage struct {
	EventID   uuid.UUID  `json:"event_id"`
	Title     string     `json:"title"`
	StartsAt  time.Time  `json:"starts_at"`
	EndsAt    time.Time  `json:"ends_at"`
	X         float64    `json:"x"`
	Y         float64    `json:"y"`
	DeletedAt *time.Time `json:"deleted_at"`
}

type ChangeRequest struct {
	ID             uuid.UUID  `json:"id"`
	BeaconID       uuid.UUID  `json:"beacon_id"`
	Action         string     `json:"action"`
	Reason         string     `json:"reason"`
	Status         string     `json:"status"`
	RequestedBy    *uuid.UUID `json:"requested_by"`
	ReviewedBy     *uuid.UUID `json:"reviewed_by"`
	ReviewNote     *string    `json:"review_note"`
	ReviewedAt     *time.Time `json:"reviewed_at"`
	CreatedAt      time.Time  `json:"created_at"`
	UpdatedAt      *time.Time `json:"updated_at"`
	BeaconLabel    string     `json:"beacon_label"`
	BeaconIdentity string     `json:"beacon_identity"`
	RequesterName  string     `json:"requester_name"`
	ReviewerName   *string    `json:"reviewer_name"`
}
