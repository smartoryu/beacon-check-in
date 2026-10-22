import {
	clearAuth,
	getAccessToken,
	getRefreshToken,
	updateAccessToken,
} from "./auth";
import type {
	AuthResponse,
	Beacon,
	ChangeRequest,
	Checkin,
	DashboardSummary,
	Event,
	EventInput,
	TemporaryPasswordResponse,
	User,
} from "./types";

const BASE_URL = (
	import.meta.env.VITE_API_BASE_URL ?? "http://localhost:8080/api/v1"
).replace(/\/$/, "");

export class ApiError extends Error {
	status: number;
	details?: unknown;

	constructor(status: number, message: string, details?: unknown) {
		super(message);
		this.name = "ApiError";
		this.status = status;
		this.details = details;
	}
}

interface RequestOptions extends RequestInit {
	skipAuth?: boolean;
}

let refreshInFlight: Promise<boolean> | null = null;

async function refreshAccessToken(): Promise<boolean> {
	const refreshToken = getRefreshToken();
	if (!refreshToken) return false;
	if (refreshInFlight) return refreshInFlight;

	refreshInFlight = (async () => {
		try {
			const response = await fetch(`${BASE_URL}/auth/refresh`, {
				method: "POST",
				headers: { "Content-Type": "application/json" },
				body: JSON.stringify({ refresh_token: refreshToken }),
			});
			if (!response.ok) {
				clearAuth();
				return false;
			}
			const data = (await response.json()) as AuthResponse;
			if (data.access_token && data.refresh_token) {
				updateAccessToken(data.access_token, data.refresh_token);
				return true;
			}
			clearAuth();
			return false;
		} catch {
			clearAuth();
			return false;
		} finally {
			refreshInFlight = null;
		}
	})();

	return refreshInFlight;
}

async function request<T>(
	path: string,
	options: RequestOptions = {},
	retry = true,
): Promise<T> {
	const headers = new Headers(options.headers);
	if (options.body && !headers.has("Content-Type")) {
		headers.set("Content-Type", "application/json");
	}
	if (!options.skipAuth) {
		const token = getAccessToken();
		if (token) headers.set("Authorization", `Bearer ${token}`);
	}

	let response: Response;
	try {
		response = await fetch(`${BASE_URL}${path}`, { ...options, headers });
	} catch (error) {
		throw new ApiError(0, "Network error — check that the API is running", error);
	}

	if (response.status === 401 && retry && !options.skipAuth) {
		const refreshed = await refreshAccessToken();
		if (refreshed) {
			return request<T>(path, options, false);
		}
		clearAuth();
	}

	if (response.status === 204) return null as T;

	const text = await response.text();
	let data: unknown = null;
	if (text) {
		try {
			data = JSON.parse(text);
		} catch {
			data = text;
		}
	}

	if (!response.ok) {
		const record = (data ?? {}) as Record<string, unknown>;
		const message =
			(typeof record.error === "string" && record.error) ||
			(typeof record.message === "string" && record.message) ||
			response.statusText ||
			"Request failed";
		throw new ApiError(response.status, message, record.details);
	}

	return data as T;
}

function json(body: unknown): RequestInit {
	return { method: "POST", body: JSON.stringify(body) };
}

function put(body: unknown): RequestInit {
	return { method: "PUT", body: JSON.stringify(body) };
}

function patch(body: unknown): RequestInit {
	return { method: "PATCH", body: JSON.stringify(body) };
}

export const api = {
	// Auth
	signIn(email: string, password: string) {
		return request<AuthResponse>(
			"/auth/signin/email",
			{ ...json({ email, password }), skipAuth: true },
			false,
		);
	},
	me() {
		return request<User>("/auth/me");
	},
	changePassword(
		currentPassword: string,
		newPassword: string,
		passwordConfirmation: string,
	) {
		return request<{ message: string }>("/auth/change-password", {
			...json({
				current_password: currentPassword,
				new_password: newPassword,
				password_confirmation: passwordConfirmation,
			}),
			skipAuth: false,
		});
	},

	// Dashboard
	summary() {
		return request<DashboardSummary>("/dashboard/summary");
	},

	// Users
	users(params: { role?: string; search?: string; include_deleted?: boolean } = {}) {
		const query = new URLSearchParams();
		if (params.role) query.set("role", params.role);
		if (params.search) query.set("search", params.search);
		if (params.include_deleted) query.set("include_deleted", "true");
		const suffix = query.toString() ? `?${query}` : "";
		return request<User[]>(`/users${suffix}`);
	},

	// Admins
	listAdmins(includeDeleted = true) {
		return request<User[]>(`/admins?include_deleted=${includeDeleted}`);
	},
	getAdmin(id: string) {
		return request<User>(`/admins/${id}`);
	},
	createAdmin(name: string, email: string) {
		return request<TemporaryPasswordResponse>("/admins", json({ name, email }));
	},
	updateAdmin(id: string, name: string, email: string) {
		return request<User>(`/admins/${id}`, put({ name, email }));
	},
	deleteAdmin(id: string) {
		return request<{ message: string }>(`/admins/${id}`, { method: "DELETE" });
	},
	resetAdminPassword(id: string) {
		return request<{ temporary_password: string }>(
			`/admins/${id}/reset-password`,
			{ method: "POST" },
		);
	},

	// Beacons
	listBeacons(
		params: {
			search?: string;
			status?: "active" | "deleted" | "all";
			include_deleted?: boolean;
		} = {},
	) {
		const query = new URLSearchParams();
		if (params.search) query.set("search", params.search);
		if (params.status) query.set("status", params.status);
		if (params.include_deleted) query.set("include_deleted", "true");
		const suffix = query.toString() ? `?${query}` : "";
		return request<Beacon[]>(`/beacons${suffix}`);
	},
	getBeacon(id: string) {
		return request<Beacon>(`/beacons/${id}`);
	},
	lookupBeacons(identities: string[]) {
		return request<{ items: Array<{ identity_key: string; status: string; beacon?: Beacon }> }>(
			"/beacons/lookup",
			json({ identities }),
		);
	},
	renameBeacon(id: string, label: string) {
		return request<Beacon>(`/beacons/${id}`, patch({ label }));
	},
	beaconUsage(id: string) {
		return request<
			Array<{
				event_id: string;
				title: string;
				starts_at: string;
				ends_at: string;
				x: number;
				y: number;
				deleted_at?: string | null;
			}>
		>(`/beacons/${id}/usage`);
	},
	deleteBeacon(id: string, reason: string) {
		return request<{ mode: string; message: string }>(`/beacons/${id}`, {
			method: "DELETE",
			body: JSON.stringify({ reason }),
		});
	},
	restoreBeacon(id: string, reason: string) {
		return request<{ mode: string; message: string }>(
			`/beacons/${id}/restore`,
			json({ reason }),
		);
	},

	// Beacon approvals
	listChangeRequests(status = "pending") {
		return request<ChangeRequest[]>(`/beacon-requests?status=${status}`);
	},
	createChangeRequest(beaconId: string, action: "delete" | "restore", reason: string) {
		return request<ChangeRequest>(
			"/beacon-requests",
			json({ beacon_id: beaconId, action, reason }),
		);
	},
	approveChangeRequest(id: string, note = "") {
		return request<ChangeRequest>(`/beacon-requests/${id}/approve`, json({ note }));
	},
	rejectChangeRequest(id: string, note = "") {
		return request<ChangeRequest>(`/beacon-requests/${id}/reject`, json({ note }));
	},

	// Events
	listEvents(
		params: { search?: string; status?: string; include_deleted?: boolean } = {},
	) {
		const query = new URLSearchParams();
		if (params.search) query.set("search", params.search);
		if (params.status) query.set("status", params.status);
		if (params.include_deleted) query.set("include_deleted", "true");
		const suffix = query.toString() ? `?${query}` : "";
		return request<Event[]>(`/events${suffix}`);
	},
	getEvent(id: string) {
		return request<Event>(`/events/${id}`);
	},
	createEvent(input: EventInput) {
		return request<Event>("/events", json(input));
	},
	updateEvent(id: string, input: EventInput) {
		return request<Event>(`/events/${id}`, put(input));
	},
	deleteEvent(id: string) {
		return request<{ message: string }>(`/events/${id}`, { method: "DELETE" });
	},
	setEventBeacons(id: string, beacons: EventInput["beacons"]) {
		return request<Event>(`/events/${id}/beacons`, put({ beacons }));
	},
	activeEvents() {
		return request<Event[]>("/events/active");
	},

	// Check-ins
	listEventCheckins(eventId: string, status = "all") {
		return request<Checkin[]>(`/events/${eventId}/checkins?status=${status}`);
	},
	myCheckins(status = "all") {
		return request<Checkin[]>(`/me/checkins?status=${status}`);
	},
};
