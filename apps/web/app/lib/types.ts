export type Role = "super_admin" | "admin" | "user";

export interface User {
	id: string;
	display_name: string;
	email: string;
	username?: string | null;
	role: Role;
	must_change_password: boolean;
	email_verified_at?: string | null;
	last_login_at?: string | null;
	deleted_at?: string | null;
	created_at?: string;
}

export interface AuthResponse {
	user: User;
	access_token: string;
	refresh_token: string;
	session_id?: string;
	token_expiry?: string;
}

export interface BeaconMetadata {
	[key: string]: unknown;
}

export interface Beacon {
	id: string;
	identity_key: string;
	proximity_uuid: string;
	major: number;
	minor: number;
	label: string;
	local_name?: string | null;
	platform_device_id?: string | null;
	device_address_type?: string | null;
	tx_power?: number | null;
	metadata?: BeaconMetadata | null;
	gatt_info?: BeaconMetadata | null;
	gatt_read_at?: string | null;
	registered_by?: string | null;
	registered_at: string;
	last_seen_at?: string | null;
	deleted_at?: string | null;
	deleted_by?: string | null;
	created_at: string;
	updated_at?: string | null;
}

export interface EventBeacon {
	beacon_id: string;
	identity_key: string;
	label: string;
	local_name?: string | null;
	tx_power?: number | null;
	tx_power_override?: number | null;
	x: number;
	y: number;
	beacon_deleted_at?: string | null;
}

export interface Event {
	id: string;
	title: string;
	description?: string | null;
	place_name: string;
	address?: string | null;
	latitude?: number | null;
	longitude?: number | null;
	starts_at: string;
	ends_at: string;
	timezone: string;
	floor_width_m: number;
	floor_height_m: number;
	rssi_threshold_dbm: number;
	min_beacons: number;
	coverage_radius_m?: number | null;
	path_loss_exponent: number;
	created_by?: string | null;
	created_at: string;
	updated_at?: string | null;
	deleted_at?: string | null;
	beacons: EventBeacon[];
	checkin_count: number;
}

export interface CheckinReading {
	beacon_id?: string | null;
	identity_key: string;
	matched: boolean;
	median_rssi: number;
	tx_power?: number | null;
	distance_m?: number | null;
	rssi_samples: number[];
	platform_device_id?: string | null;
}

export interface Checkin {
	id: string;
	client_checkin_id: string;
	event_id: string;
	user_id: string;
	user_name: string;
	user_email: string;
	status: "accepted" | "rejected";
	reject_reason?: string | null;
	recorded_at: string;
	received_at: string;
	is_offline: boolean;
	estimated_x?: number | null;
	estimated_y?: number | null;
	accuracy_m?: number | null;
	used_beacon_count: number;
	readings: CheckinReading[];
	device_info?: Record<string, unknown> | null;
	created_at: string;
}

export interface ChangeRequest {
	id: string;
	beacon_id: string;
	action: "delete" | "restore";
	reason: string;
	status: "pending" | "approved" | "rejected";
	requested_by?: string | null;
	reviewed_by?: string | null;
	review_note?: string | null;
	reviewed_at?: string | null;
	created_at: string;
	updated_at?: string | null;
	beacon_label: string;
	beacon_identity: string;
	requester_name: string;
	reviewer_name?: string | null;
}

export interface DashboardSummary {
	user_counts: Record<string, number>;
	event_counts: Record<string, number>;
	active_beacons: number;
	deleted_beacons: number;
	checkins_today: number;
	pending_approvals: number;
	recent_checkins: Array<{
		id: string;
		event_id: string;
		event_title: string;
		user_name: string;
		status: string;
		recorded_at: string;
	}>;
}

export interface TemporaryPasswordResponse {
	user: User;
	temporary_password: string;
}

export interface EventInput {
	title: string;
	description?: string | null;
	place_name: string;
	address?: string | null;
	latitude?: number | null;
	longitude?: number | null;
	starts_at: string;
	ends_at: string;
	timezone: string;
	floor_width_m: number;
	floor_height_m: number;
	rssi_threshold_dbm: number;
	min_beacons: number;
	coverage_radius_m?: number | null;
	path_loss_exponent: number;
	beacons: Array<{
		beacon_id: string;
		x: number;
		y: number;
		tx_power_override?: number | null;
	}>;
}
