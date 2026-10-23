export type Theme = "light" | "dark" | "system";

const STORAGE_KEY = "beacon-check-in.theme";

function systemPrefersDark(): boolean {
	if (typeof window === "undefined") return false;
	return window.matchMedia("(prefers-color-scheme: dark)").matches;
}

export function getStoredTheme(): Theme {
	if (typeof window === "undefined") return "system";
	const value = window.localStorage.getItem(STORAGE_KEY);
	if (value === "light" || value === "dark" || value === "system") {
		return value;
	}
	return "system";
}

export function applyTheme(theme: Theme): boolean {
	if (typeof document === "undefined") return false;
	const dark = theme === "dark" || (theme === "system" && systemPrefersDark());
	const root = document.documentElement;
	root.classList.toggle("dark", dark);
	root.dataset.theme = dark ? "dark" : "light";
	root.style.colorScheme = dark ? "dark" : "light";
	return dark;
}

export function setTheme(theme: Theme): boolean {
	if (typeof window !== "undefined") {
		window.localStorage.setItem(STORAGE_KEY, theme);
	}
	return applyTheme(theme);
}

/** Applies the saved theme and keeps "system" in sync with OS changes. */
export function initTheme(): () => void {
	applyTheme(getStoredTheme());
	if (typeof window === "undefined") return () => {};

	const media = window.matchMedia("(prefers-color-scheme: dark)");
	function onChange() {
		if (getStoredTheme() === "system") applyTheme("system");
	}
	media.addEventListener("change", onChange);
	return () => media.removeEventListener("change", onChange);
}

/** Flips between explicit light and dark, persisting the choice. */
export function toggleTheme(): "light" | "dark" {
	const isDark = document.documentElement.classList.contains("dark");
	return setTheme(isDark ? "light" : "dark") ? "dark" : "light";
}
