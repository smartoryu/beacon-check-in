import { describe, expect, it } from "vitest";
import {
	eventStatus,
	toZonedInputValue,
	zonedInputToIso,
} from "#/lib/datetime";

describe("datetime helpers", () => {
	it("converts a zoned datetime-local value to UTC", () => {
		expect(zonedInputToIso("2026-01-01T10:00", "Asia/Jakarta")).toBe(
			"2026-01-01T03:00:00.000Z",
		);
	});

	it("converts a UTC instant back to the event timezone input value", () => {
		expect(toZonedInputValue("2026-01-01T03:00:00.000Z", "Asia/Jakarta")).toBe(
			"2026-01-01T10:00",
		);
	});

	it("classifies events by their time window", () => {
		const now = new Date("2026-01-01T12:00:00.000Z");
		expect(
			eventStatus(
				{ starts_at: "2026-01-01T13:00:00.000Z", ends_at: "2026-01-01T14:00:00.000Z" },
				now,
			),
		).toBe("upcoming");
		expect(
			eventStatus(
				{ starts_at: "2026-01-01T11:00:00.000Z", ends_at: "2026-01-01T13:00:00.000Z" },
				now,
			),
		).toBe("ongoing");
		expect(
			eventStatus(
				{ starts_at: "2026-01-01T09:00:00.000Z", ends_at: "2026-01-01T10:00:00.000Z" },
				now,
			),
		).toBe("past");
		expect(
			eventStatus(
				{
					starts_at: "2026-01-01T09:00:00.000Z",
					ends_at: "2026-01-01T10:00:00.000Z",
					deleted_at: "2026-01-01T11:00:00.000Z",
				},
				now,
			),
		).toBe("deleted");
	});
});
