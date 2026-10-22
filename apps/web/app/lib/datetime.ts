export function formatDateTime(
	iso: string | null | undefined,
	timezone = "Asia/Jakarta",
): string {
	if (!iso) return "—";
	const date = new Date(iso);
	if (Number.isNaN(date.getTime())) return "—";
	try {
		return new Intl.DateTimeFormat("en-GB", {
			timeZone: timezone,
			dateStyle: "medium",
			timeStyle: "short",
		}).format(date);
	} catch {
		return date.toLocaleString();
	}
}

export function formatDate(
	iso: string | null | undefined,
	timezone = "Asia/Jakarta",
): string {
	if (!iso) return "—";
	const date = new Date(iso);
	if (Number.isNaN(date.getTime())) return "—";
	try {
		return new Intl.DateTimeFormat("en-GB", {
			timeZone: timezone,
			dateStyle: "medium",
		}).format(date);
	} catch {
		return date.toLocaleDateString();
	}
}

export function eventStatus(
	event: { starts_at: string; ends_at: string; deleted_at?: string | null },
	now = new Date(),
): "upcoming" | "ongoing" | "past" | "deleted" {
	if (event.deleted_at) return "deleted";
	const start = new Date(event.starts_at).getTime();
	const end = new Date(event.ends_at).getTime();
	if (now.getTime() < start) return "upcoming";
	if (now.getTime() > end) return "past";
	return "ongoing";
}

function partsToMap(parts: Intl.DateTimeFormatPart[]): Record<string, string> {
	return Object.fromEntries(parts.map((part) => [part.type, part.value]));
}

function offsetMs(date: Date, timeZone: string): number {
	const formatter = new Intl.DateTimeFormat("en-US", {
		timeZone,
		hour12: false,
		year: "numeric",
		month: "2-digit",
		day: "2-digit",
		hour: "2-digit",
		minute: "2-digit",
		second: "2-digit",
	});
	const parts = partsToMap(formatter.formatToParts(date));
	const asUtc = Date.UTC(
		Number(parts.year),
		Number(parts.month) - 1,
		Number(parts.day),
		Number(parts.hour) % 24,
		Number(parts.minute),
		Number(parts.second),
	);
	return asUtc - date.getTime();
}

export function toZonedInputValue(
	iso: string | null | undefined,
	timeZone: string,
): string {
	if (!iso) return "";
	const date = new Date(iso);
	if (Number.isNaN(date.getTime())) return "";
	const formatter = new Intl.DateTimeFormat("en-CA", {
		timeZone,
		hour12: false,
		year: "numeric",
		month: "2-digit",
		day: "2-digit",
		hour: "2-digit",
		minute: "2-digit",
	});
	const parts = partsToMap(formatter.formatToParts(date));
	return `${parts.year}-${parts.month}-${parts.day}T${parts.hour === "24" ? "00" : parts.hour}:${parts.minute}`;
}

export function zonedInputToIso(value: string, timeZone: string): string {
	if (!value) return "";
	const [datePart, timePart] = value.split("T");
	if (!datePart || !timePart) return "";
	const [year, month, day] = datePart.split("-").map(Number);
	const [hour, minute] = timePart.split(":").map(Number);
	const utcGuess = Date.UTC(year, month - 1, day, hour, minute);
	const offset = offsetMs(new Date(utcGuess), timeZone);
	return new Date(utcGuess - offset).toISOString();
}
