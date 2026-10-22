package models

type RegisterBeaconRequest struct {
	ProximityUUID     string         `json:"proximity_uuid" validate:"required,uuid" example:"f7826da6-4fa2-4e98-8024-bc5b71e0893e"`
	Major             int            `json:"major" validate:"gte=0,lte=65535" example:"1"`
	Minor             int            `json:"minor" validate:"gte=0,lte=65535" example:"1"`
	Label             string         `json:"label" validate:"required,min=1,max=120" example:"Lobby North"`
	LocalName         *string        `json:"local_name,omitempty"`
	PlatformDeviceID  *string        `json:"platform_device_id,omitempty"`
	DeviceAddressType *string        `json:"device_address_type,omitempty"`
	TxPower           *int           `json:"tx_power,omitempty" example:"-59"`
	Metadata          map[string]any `json:"metadata,omitempty"`
	GattInfo          map[string]any `json:"gatt_info,omitempty"`
	RSSISamples       []int          `json:"rssi_samples,omitempty"`
}

type LookupRequest struct {
	Identities []string `json:"identities" validate:"required,min=1,max=200"`
}

type LookupItem struct {
	IdentityKey string  `json:"identity_key"`
	Status      string  `json:"status"` // registered|deleted|unknown
	Beacon      *Beacon `json:"beacon,omitempty"`
}

type LookupResponse struct {
	Items []LookupItem `json:"items"`
}

type UpdateBeaconRequest struct {
	Label string `json:"label" validate:"required,min=1,max=120" example:"Lobby North"`
}

type ChangeActionRequest struct {
	Reason string `json:"reason" validate:"required,min=4,max=500"`
}

type CreateChangeRequest struct {
	BeaconID string `json:"beacon_id" validate:"required,uuid"`
	Action   string `json:"action" validate:"required,oneof=delete restore"`
	Reason   string `json:"reason" validate:"required,min=4,max=500"`
}

type ReviewChangeRequest struct {
	Note string `json:"note,omitempty"`
}

type ChangeActionResult struct {
	Mode    string         `json:"mode"` // deleted|restored|requested
	Request *ChangeRequest `json:"request,omitempty"`
	Beacon  *Beacon        `json:"beacon,omitempty"`
	Message string         `json:"message"`
}
