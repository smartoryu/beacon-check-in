import type { AuthResponse, User } from "./types";

const ACCESS_KEY = "bci.access_token";
const REFRESH_KEY = "bci.refresh_token";
const USER_KEY = "bci.user";

function storage(): Storage | null {
	return typeof window === "undefined" ? null : window.localStorage;
}

export function getAccessToken(): string | null {
	return storage()?.getItem(ACCESS_KEY) ?? null;
}

export function getRefreshToken(): string | null {
	return storage()?.getItem(REFRESH_KEY) ?? null;
}

export function getStoredUser(): User | null {
	const raw = storage()?.getItem(USER_KEY);
	if (!raw) return null;
	try {
		return JSON.parse(raw) as User;
	} catch {
		return null;
	}
}

export function setAuth(auth: AuthResponse): void {
	const store = storage();
	if (!store) return;
	store.setItem(ACCESS_KEY, auth.access_token);
	store.setItem(REFRESH_KEY, auth.refresh_token);
	store.setItem(USER_KEY, JSON.stringify(auth.user));
}

export function updateAccessToken(accessToken: string, refreshToken: string): void {
	const store = storage();
	if (!store) return;
	store.setItem(ACCESS_KEY, accessToken);
	store.setItem(REFRESH_KEY, refreshToken);
}

export function clearAuth(): void {
	const store = storage();
	if (!store) return;
	store.removeItem(ACCESS_KEY);
	store.removeItem(REFRESH_KEY);
	store.removeItem(USER_KEY);
}
