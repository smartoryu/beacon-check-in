import { useMemo, useState } from "react";
import type { FormEvent } from "react";
import { useNavigate, useParams } from "react-router";
import {
	Button,
	Card,
	CardContent,
	CardHeader,
	ErrorAlert,
	Field,
	FormSkeleton,
	Input,
	PageHeader,
	Select,
	Textarea,
} from "#/components/ui";
import { api, ApiError } from "#/lib/api";
import {
	toZonedInputValue,
	zonedInputToIso,
} from "#/lib/datetime";
import type { Beacon, Event, EventInput } from "#/lib/types";
import { useAsync } from "#/lib/use-async";

export function meta() {
	return [{ title: "Event form | Beacon Check-In" }];
}

type Placement = { x: number; y: number; tx_power_override?: number | null };

const TIMEZONES = [
	"Asia/Jakarta",
	"Asia/Singapore",
	"Asia/Tokyo",
	"Asia/Dubai",
	"Europe/London",
	"America/New_York",
	"UTC",
];

function defaultPlacement(index: number, width: number, height: number): Placement {
	const columns = Math.max(1, Math.min(4, Math.ceil(Math.sqrt(index + 1))));
	const x = 2 + (index % columns) * Math.max(2, (width - 4) / Math.max(1, columns - 1));
	const y = 2 + Math.floor(index / columns) * Math.max(2, (height - 4) / 3);
	return {
		x: Math.min(width, Math.max(0, Math.round(x * 2) / 2)),
		y: Math.min(height, Math.max(0, Math.round(y * 2) / 2)),
	};
}

export default function EventFormPage() {
	const { id } = useParams();
	const isEdit = Boolean(id);
	const { data, loading, error, refresh } = useAsync(async () => {
		const beacons = await api.listBeacons({ status: "active" });
		const event = id ? await api.getEvent(id) : null;
		return { event, beacons };
	}, [id]);

	if (loading) return <FormSkeleton />;

	if (error || !data) {
		return (
			<div className="space-y-6">
				<PageHeader title={isEdit ? "Edit event" : "Create event"} />
				<ErrorAlert message="Unable to load the event form." details={error?.message} />
				<Button onClick={refresh}>Retry</Button>
			</div>
		);
	}

	return (
		<EventForm
			key={data.event?.id ?? "new"}
			event={data.event}
			beacons={data.beacons}
			isEdit={isEdit}
		/>
	);
}

function EventForm({
	event,
	beacons,
	isEdit,
}: {
	event: Event | null;
	beacons: Beacon[];
	isEdit: boolean;
}) {
	const navigate = useNavigate();

	const [title, setTitle] = useState(event?.title ?? "");
	const [description, setDescription] = useState(event?.description ?? "");
	const [placeName, setPlaceName] = useState(event?.place_name ?? "");
	const [address, setAddress] = useState(event?.address ?? "");
	const [timezone, setTimezone] = useState(event?.timezone ?? "Asia/Jakarta");
	const [startsAt, setStartsAt] = useState(
		toZonedInputValue(event?.starts_at, event?.timezone ?? "Asia/Jakarta") ||
			toZonedInputValue(new Date(Date.now() + 60 * 60 * 1000).toISOString(), "Asia/Jakarta"),
	);
	const [endsAt, setEndsAt] = useState(
		toZonedInputValue(event?.ends_at, event?.timezone ?? "Asia/Jakarta") ||
			toZonedInputValue(new Date(Date.now() + 3 * 60 * 60 * 1000).toISOString(), "Asia/Jakarta"),
	);
	const [floorWidth, setFloorWidth] = useState(String(event?.floor_width_m ?? 20));
	const [floorHeight, setFloorHeight] = useState(String(event?.floor_height_m ?? 20));
	const [rssiThreshold, setRssiThreshold] = useState(
		String(event?.rssi_threshold_dbm ?? -75),
	);
	const [minBeacons, setMinBeacons] = useState(String(event?.min_beacons ?? 1));
	const [coverageRadius, setCoverageRadius] = useState(
		event?.coverage_radius_m == null ? "" : String(event.coverage_radius_m),
	);
	const [pathLoss, setPathLoss] = useState(String(event?.path_loss_exponent ?? 2));
	const [placements, setPlacements] = useState<Record<string, Placement>>(() => {
		const initial: Record<string, Placement> = {};
		for (const beacon of event?.beacons ?? []) {
			initial[beacon.beacon_id] = {
				x: beacon.x,
				y: beacon.y,
				tx_power_override: beacon.tx_power_override,
			};
		}
		return initial;
	});
	const [submitting, setSubmitting] = useState(false);
	const [error, setError] = useState<string | null>(null);

	const selectedBeacons = useMemo(
		() => beacons.filter((beacon) => placements[beacon.id]),
		[beacons, placements],
	);

	function toggleBeacon(beacon: Beacon) {
		setPlacements((current) => {
			const next = { ...current };
			if (next[beacon.id]) {
				delete next[beacon.id];
			} else {
				next[beacon.id] = defaultPlacement(
					Object.keys(current).length,
					Number(floorWidth) || 20,
					Number(floorHeight) || 20,
				);
			}
			return next;
		});
	}

	async function submit(event_: FormEvent) {
		event_.preventDefault();
		setError(null);
		if (!title.trim() || !placeName.trim()) {
			setError("Title and place are required.");
			return;
		}
		if (selectedBeacons.length === 0) {
			setError("Attach at least one beacon to the event.");
			return;
		}
		const width = Number(floorWidth) || 20;
		const height = Number(floorHeight) || 20;
		const input: EventInput = {
			title: title.trim(),
			description: description.trim() || null,
			place_name: placeName.trim(),
			address: address.trim() || null,
			latitude: null,
			longitude: null,
			starts_at: zonedInputToIso(startsAt, timezone),
			ends_at: zonedInputToIso(endsAt, timezone),
			timezone,
			floor_width_m: width,
			floor_height_m: height,
			rssi_threshold_dbm: Number(rssiThreshold) || -75,
			min_beacons: Number(minBeacons) || 1,
			coverage_radius_m: coverageRadius.trim() ? Number(coverageRadius) : null,
			path_loss_exponent: Number(pathLoss) || 2,
			beacons: selectedBeacons.map((beacon) => ({
				beacon_id: beacon.id,
				x: placements[beacon.id].x,
				y: placements[beacon.id].y,
				tx_power_override: placements[beacon.id].tx_power_override ?? null,
			})),
		};
		setSubmitting(true);
		try {
			const saved = isEdit && event
				? await api.updateEvent(event.id, input)
				: await api.createEvent(input);
			navigate(`/events/${saved.id}`);
		} catch (err) {
			setError(err instanceof ApiError ? err.message : "Unable to save event");
		} finally {
			setSubmitting(false);
		}
	}

	return (
		<div className="space-y-6">
			<PageHeader
				title={isEdit ? "Edit event" : "Create event"}
				description="An event must have at least one registered beacon. Positions can be fine-tuned on the event detail page."
			/>

			{error ? <ErrorAlert message={error} /> : null}

			<form onSubmit={submit} className="space-y-6">
				<Card>
					<CardHeader>
						<h2 className="font-semibold text-gray-900 dark:text-white">Event details</h2>
					</CardHeader>
					<CardContent className="grid gap-4 md:grid-cols-2">
						<Field label="Title">
							<Input value={title} onChange={(e) => setTitle(e.target.value)} required />
						</Field>
						<Field label="Place name">
							<Input value={placeName} onChange={(e) => setPlaceName(e.target.value)} required />
						</Field>
						<Field label="Address">
							<Input value={address} onChange={(e) => setAddress(e.target.value)} />
						</Field>
						<Field label="Timezone" hint="Display and input timezone for this event.">
							<Select value={timezone} onChange={(e) => setTimezone(e.target.value)}>
								{TIMEZONES.map((zone) => (
									<option key={zone} value={zone}>
										{zone}
									</option>
								))}
							</Select>
						</Field>
						<Field label="Starts at">
							<Input
								type="datetime-local"
								value={startsAt}
								onChange={(e) => setStartsAt(e.target.value)}
								required
							/>
						</Field>
						<Field label="Ends at">
							<Input
								type="datetime-local"
								value={endsAt}
								onChange={(e) => setEndsAt(e.target.value)}
								required
							/>
						</Field>
						<div className="md:col-span-2">
							<Field label="Description">
								<Textarea
									value={description ?? ""}
									onChange={(e) => setDescription(e.target.value)}
								/>
							</Field>
						</div>
					</CardContent>
				</Card>

				<Card>
					<CardHeader>
						<h2 className="font-semibold text-gray-900 dark:text-white">Coverage & floor</h2>
					</CardHeader>
					<CardContent className="grid gap-4 md:grid-cols-3">
						<Field label="Floor width (m)">
							<Input
								type="number"
								min="1"
								step="0.5"
								value={floorWidth}
								onChange={(e) => setFloorWidth(e.target.value)}
							/>
						</Field>
						<Field label="Floor height (m)">
							<Input
								type="number"
								min="1"
								step="0.5"
								value={floorHeight}
								onChange={(e) => setFloorHeight(e.target.value)}
							/>
						</Field>
						<Field
							label="RSSI threshold (dBm)"
							hint="Minimum signal strength a beacon must reach to count. -75 is a good starting point; higher values (closer to 0) require the phone to be nearer."
						>
							<Input
								type="number"
								min="-120"
								max="0"
								value={rssiThreshold}
								onChange={(e) => setRssiThreshold(e.target.value)}
							/>
						</Field>
						<Field label="Minimum beacons">
							<Input
								type="number"
								min="1"
								value={minBeacons}
								onChange={(e) => setMinBeacons(e.target.value)}
							/>
						</Field>
						<Field
							label="Coverage radius (m)"
							hint="Optional. When set and 3+ beacons are positioned, the trilaterated point must be inside this radius."
						>
							<Input
								type="number"
								min="1"
								step="0.5"
								value={coverageRadius}
								onChange={(e) => setCoverageRadius(e.target.value)}
							/>
						</Field>
						<Field
							label="Path-loss exponent"
							hint="How quickly signal strength fades with distance. 2 is open space; 2.5–3.5 suits indoor areas with walls and furniture. This affects position estimates, not the RSSI pass/fail check."
						>
							<Input
								type="number"
								min="0.1"
								step="0.1"
								value={pathLoss}
								onChange={(e) => setPathLoss(e.target.value)}
							/>
						</Field>
					</CardContent>
				</Card>

				<Card>
					<CardHeader>
						<div className="flex items-center justify-between">
							<h2 className="font-semibold text-gray-900 dark:text-white">Beacons</h2>
							<span className="text-gray-500 text-sm dark:text-gray-400">
								{selectedBeacons.length} selected
							</span>
						</div>
					</CardHeader>
					<CardContent>
						{beacons.length === 0 ? (
							<p className="text-gray-500 text-sm dark:text-gray-400">
								No active beacons. Register a beacon from the mobile admin scanner first.
							</p>
						) : (
							<div className="space-y-2">
								<p className="text-gray-500 text-xs">
									Click anywhere on a beacon card to attach or remove it. Positions are assigned
									automatically; fine-tune them on the event detail page.
								</p>
								{beacons.map((beacon) => {
									const selected = Boolean(placements[beacon.id]);
									return (
										<label
											key={beacon.id}
											className={`flex cursor-pointer items-center gap-3 rounded-lg border px-3 py-3 transition-colors ${
												selected
													? "border-blue-300 bg-blue-50"
													: "border-gray-200 hover:bg-gray-50"
											}`}
										>
											<input
												type="checkbox"
												checked={selected}
												onChange={() => toggleBeacon(beacon)}
												className="h-4 w-4 shrink-0 rounded border-gray-300 text-blue-600"
											/>
											<div className="min-w-0 flex-1">
												<div className="font-medium text-gray-900 text-sm">{beacon.label}</div>
												<div className="font-mono text-gray-500 text-xs">
													{beacon.identity_key}
												</div>
											</div>
											{selected ? (
												<span className="rounded-full bg-blue-100 px-2 py-0.5 font-medium text-blue-700 text-xs">
													Selected
												</span>
											) : null}
										</label>
									);
								})}
							</div>
						)}
					</CardContent>
				</Card>

				<div className="flex justify-end gap-2">
					<Button variant="secondary" onClick={() => navigate(-1)}>
						Cancel
					</Button>
					<Button type="submit" disabled={submitting}>
						{submitting ? "Saving…" : isEdit ? "Save changes" : "Create event"}
					</Button>
				</div>
			</form>
		</div>
	);
}
