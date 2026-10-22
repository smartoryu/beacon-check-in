import type { Checkin, Event } from "#/lib/types";

function gridLines(size: number, step: number): number[] {
	const values: number[] = [];
	for (let value = 0; value <= size + 0.001; value += step) {
		values.push(Number(value.toFixed(2)));
	}
	return values;
}

export function TriangulationGraph({
	event,
	checkin,
}: {
	event: Event;
	checkin: Checkin;
}) {
	const width = event.floor_width_m;
	const height = event.floor_height_m;
	const hasPosition =
		checkin.estimated_x != null && checkin.estimated_y != null;
	const positions = new Map(
		event.beacons.map((beacon) => [beacon.beacon_id, beacon]),
	);

	if (!hasPosition) {
		return (
			<div className="rounded-xl border border-amber-200 bg-amber-50 px-4 py-6 text-center text-amber-800 text-sm dark:border-amber-900 dark:bg-amber-950 dark:text-amber-200">
				Position unavailable — at least 3 positioned beacons with valid TX power are needed
				for trilateration.
			</div>
		);
	}

	const userX = checkin.estimated_x ?? 0;
	const userY = checkin.estimated_y ?? 0;
	const accuracy = checkin.accuracy_m ?? 0;

	return (
		<div className="space-y-2">
			<svg
				viewBox={`0 0 ${width} ${height}`}
				className="w-full rounded-xl border border-gray-300 bg-gray-50 dark:border-gray-700 dark:bg-gray-950"
				style={{ aspectRatio: `${width} / ${height}` }}
				role="img"
				aria-label="Triangulation graph"
			>
				{gridLines(width, 1).map((x) => (
					<line
						key={`x-${x}`}
						x1={x}
						y1={0}
						x2={x}
						y2={height}
						stroke={x % 5 === 0 ? "rgba(100,116,139,0.35)" : "rgba(148,163,184,0.18)"}
						strokeWidth={0.03}
					/>
				))}
				{gridLines(height, 1).map((y) => (
					<line
						key={`y-${y}`}
						x1={0}
						y1={y}
						x2={width}
						y2={y}
						stroke={y % 5 === 0 ? "rgba(100,116,139,0.35)" : "rgba(148,163,184,0.18)"}
						strokeWidth={0.03}
					/>
				))}

				{checkin.readings.map((reading) => {
					if (!reading.beacon_id || reading.distance_m == null) return null;
					const beacon = positions.get(reading.beacon_id);
					if (!beacon) return null;
					return (
						<g key={`range-${reading.beacon_id}`}>
							<circle
								cx={beacon.x}
								cy={beacon.y}
								r={reading.distance_m}
								fill="rgba(37,99,235,0.05)"
								stroke="rgba(37,99,235,0.35)"
								strokeWidth={0.05}
								strokeDasharray="0.3 0.2"
							/>
							<line
								x1={beacon.x}
								y1={beacon.y}
								x2={userX}
								y2={userY}
								stroke="rgba(37,99,235,0.35)"
								strokeWidth={0.05}
								strokeDasharray="0.25 0.2"
							/>
						</g>
					);
				})}

				{event.beacons.map((beacon) => (
					<g key={beacon.beacon_id}>
						<circle
							cx={beacon.x}
							cy={beacon.y}
							r={0.35}
							fill="#2563eb"
							stroke="white"
							strokeWidth={0.08}
						/>
						<text
							x={beacon.x + 0.5}
							y={beacon.y - 0.45}
							fontSize={Math.max(0.7, width * 0.035)}
							fill="#1e40af"
						>
							{beacon.label}
						</text>
						<text
							x={beacon.x + 0.5}
							y={beacon.y + 0.05}
							fontSize={Math.max(0.55, width * 0.025)}
							fill="#64748b"
						>
							{beacon.x.toFixed(1)}, {beacon.y.toFixed(1)} m
						</text>
					</g>
				))}

				{accuracy > 0 ? (
					<circle
						cx={userX}
						cy={userY}
						r={Math.max(accuracy, 0.4)}
						fill="rgba(220,38,38,0.08)"
						stroke="rgba(220,38,38,0.45)"
						strokeWidth={0.05}
					/>
				) : null}
				<circle cx={userX} cy={userY} r={0.45} fill="#dc2626" stroke="white" strokeWidth={0.1} />
				<text
					x={userX + 0.65}
					y={userY + 0.15}
					fontSize={Math.max(0.7, width * 0.035)}
					fill="#991b1b"
				>
					{checkin.user_name || "User"}
				</text>
			</svg>
			<div className="flex flex-wrap gap-4 text-gray-500 text-xs dark:text-gray-400">
				<span className="flex items-center gap-1">
					<span className="h-2.5 w-2.5 rounded-full bg-blue-600" /> Beacon
				</span>
				<span className="flex items-center gap-1">
					<span className="h-2.5 w-2.5 rounded-full bg-red-600" /> User position
				</span>
				<span>Accuracy ≈ {accuracy.toFixed(1)} m</span>
				<span>{checkin.used_beacon_count} beacon(s) used</span>
			</div>
		</div>
	);
}
