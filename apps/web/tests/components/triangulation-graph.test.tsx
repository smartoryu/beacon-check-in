import { describe, expect, it } from "vitest";
import { render, screen } from "@testing-library/react";
import { TriangulationGraph } from "#/components/triangulation-graph";
import type { Checkin, Event } from "#/lib/types";

const event: Event = {
	id: "e1",
	title: "Demo",
	place_name: "Hall",
	starts_at: "2026-01-01T00:00:00Z",
	ends_at: "2026-01-01T10:00:00Z",
	timezone: "Asia/Jakarta",
	floor_width_m: 20,
	floor_height_m: 20,
	rssi_threshold_dbm: -75,
	min_beacons: 1,
	path_loss_exponent: 2,
	created_at: "2026-01-01T00:00:00Z",
	beacons: [
		{ beacon_id: "b1", identity_key: "u:1:1", label: "B1", x: 2, y: 2 },
		{ beacon_id: "b2", identity_key: "u:1:2", label: "B2", x: 17, y: 4 },
		{ beacon_id: "b3", identity_key: "u:1:3", label: "B3", x: 10, y: 17 },
	],
	checkin_count: 1,
};

const checkin: Checkin = {
	id: "c1",
	client_checkin_id: "d1",
	event_id: "e1",
	user_id: "u1",
	user_name: "User One",
	user_email: "user1@example.com",
	status: "accepted",
	recorded_at: "2026-01-01T02:00:00Z",
	received_at: "2026-01-01T02:00:05Z",
	is_offline: false,
	estimated_x: 9,
	estimated_y: 8,
	accuracy_m: 1.2,
	used_beacon_count: 3,
	readings: [
		{
			beacon_id: "b1",
			identity_key: "u:1:1",
			matched: true,
			median_rssi: -60,
			distance_m: 8.1,
			rssi_samples: [-60],
		},
		{
			beacon_id: "b2",
			identity_key: "u:1:2",
			matched: true,
			median_rssi: -62,
			distance_m: 8.9,
			rssi_samples: [-62],
		},
		{
			beacon_id: "b3",
			identity_key: "u:1:3",
			matched: true,
			median_rssi: -61,
			distance_m: 9.1,
			rssi_samples: [-61],
		},
	],
	created_at: "2026-01-01T02:00:05Z",
};

describe("TriangulationGraph", () => {
	it("renders the user position and accuracy", () => {
		render(<TriangulationGraph event={event} checkin={checkin} />);
		expect(screen.getByText("User position")).toBeInTheDocument();
		expect(screen.getByText("Accuracy ≈ 1.2 m")).toBeInTheDocument();
		expect(screen.getByText("3 beacon(s) used")).toBeInTheDocument();
	});

	it("explains when a position is unavailable", () => {
		render(
			<TriangulationGraph
				event={event}
				checkin={{ ...checkin, estimated_x: null, estimated_y: null }}
			/>,
		);
		expect(screen.getByText(/Position unavailable/)).toBeInTheDocument();
	});
});
