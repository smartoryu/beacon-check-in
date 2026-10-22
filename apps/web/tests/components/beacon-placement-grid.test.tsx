import { describe, expect, it, vi } from "vitest";
import { fireEvent, render, screen } from "@testing-library/react";
import { BeaconPlacementGrid } from "#/components/beacon-placement-grid";
import type { EventBeacon } from "#/lib/types";

const beacons: EventBeacon[] = [
	{
		beacon_id: "b1",
		identity_key: "uuid:1:1",
		label: "Lobby",
		x: 3,
		y: 2,
	},
];

describe("BeaconPlacementGrid", () => {
	it("renders beacon labels and coordinates", () => {
		render(<BeaconPlacementGrid widthM={20} heightM={20} beacons={beacons} />);
		expect(screen.getByText("Lobby")).toBeInTheDocument();
		expect(screen.getByText("3.0, 2.0 m")).toBeInTheDocument();
	});

	it("nudges a beacon with the keyboard", () => {
		const onMove = vi.fn();
		render(
			<BeaconPlacementGrid
				widthM={20}
				heightM={20}
				beacons={beacons}
				onMove={onMove}
			/>,
		);
		const marker = screen.getByText("Lobby").closest("button");
		expect(marker).not.toBeNull();
		fireEvent.keyDown(marker as HTMLButtonElement, { key: "ArrowRight" });
		expect(onMove).toHaveBeenCalledWith("b1", 3.5, 2);
	});
});
