import { useEffect, useMemo, useState } from "react";
import { Link, useLoaderData, useNavigate, useRevalidator } from "react-router";
import { BeaconPlacementGrid } from "#/components/beacon-placement-grid";
import { TriangulationGraph } from "#/components/triangulation-graph";
import {
	Badge,
	Button,
	ButtonLink,
	Card,
	CardContent,
	CardHeader,
	EmptyState,
	ErrorAlert,
	Modal,
	PageHeader,
	Spinner,
} from "#/components/ui";
import { api, ApiError } from "#/lib/api";
import { eventStatus, formatDateTime } from "#/lib/datetime";

export function meta() {
	return [{ title: "Event detail | Beacon Check-In" }];
}

export async function clientLoader({ params }: { params: { id?: string } }) {
	if (!params.id) throw new Response("Missing event id", { status: 400 });
	const event = await api.getEvent(params.id);
	const checkins = await api.listEventCheckins(params.id, "all");
	return { event, checkins };
}

export default function EventDetailPage() {
	const { event, checkins } = useLoaderData<typeof clientLoader>();
	const navigate = useNavigate();
	const revalidator = useRevalidator();
	const [placements, setPlacements] = useState(event.beacons);
	const [savingLayout, setSavingLayout] = useState(false);
	const [error, setError] = useState<string | null>(null);
	const [tab, setTab] = useState<"accepted" | "rejected">("accepted");
	const [selectedCheckinId, setSelectedCheckinId] = useState<string | null>(null);
	const [deleteOpen, setDeleteOpen] = useState(false);

	useEffect(() => {
		setPlacements(event.beacons);
	}, [event.beacons]);

	const accepted = checkins.filter((item) => item.status === "accepted");
	const rejected = checkins.filter((item) => item.status === "rejected");
	const visible = tab === "accepted" ? accepted : rejected;
	const selectedCheckin =
		accepted.find((item) => item.id === selectedCheckinId) ?? accepted[0] ?? null;
	const state = eventStatus(event);

	const hasLayoutChanges = useMemo(() => {
		return placements.some((beacon) => {
			const original = event.beacons.find((item) => item.beacon_id === beacon.beacon_id);
			return !original || original.x !== beacon.x || original.y !== beacon.y;
		});
	}, [placements, event.beacons]);

	async function saveLayout() {
		setSavingLayout(true);
		setError(null);
		try {
			await api.setEventBeacons(
				event.id,
				placements.map((beacon) => ({
					beacon_id: beacon.beacon_id,
					x: beacon.x,
					y: beacon.y,
					tx_power_override: beacon.tx_power_override ?? null,
				})),
			);
			revalidator.revalidate();
		} catch (err) {
			setError(err instanceof ApiError ? err.message : "Unable to save layout");
		} finally {
			setSavingLayout(false);
		}
	}

	async function deleteEvent() {
		setError(null);
		try {
			await api.deleteEvent(event.id);
			navigate("/events", { replace: true });
		} catch (err) {
			setError(err instanceof ApiError ? err.message : "Unable to delete event");
		}
	}

	return (
		<div className="space-y-6">
			<PageHeader
				title={event.title}
				description={`${event.place_name}${event.address ? ` · ${event.address}` : ""}`}
				actions={
					<>
						<ButtonLink to={`/events/${event.id}/edit`} variant="secondary">
							Edit event
						</ButtonLink>
						<Button variant="danger" onClick={() => setDeleteOpen(true)}>
							Delete
						</Button>
					</>
				}
			/>

			{error ? <ErrorAlert message={error} /> : null}

			<div className="flex flex-wrap items-center gap-3 text-sm">
				<Badge
					variant={
						state === "ongoing"
							? "green"
							: state === "upcoming"
								? "blue"
								: state === "past"
									? "gray"
									: "red"
					}
				>
					{state}
				</Badge>
				<span className="text-gray-500 dark:text-gray-400">
					{formatDateTime(event.starts_at, event.timezone)} →{" "}
					{formatDateTime(event.ends_at, event.timezone)} ({event.timezone})
				</span>
				<span className="text-gray-500 dark:text-gray-400">
					RSSI ≥ {event.rssi_threshold_dbm} dBm · min {event.min_beacons} beacon(s)
				</span>
			</div>

			<div className="grid gap-6 lg:grid-cols-2">
				<Card>
					<CardHeader>
						<div className="flex items-center justify-between">
							<div>
								<h2 className="font-semibold text-gray-900 dark:text-white">
									Beacon placement
								</h2>
								<p className="text-gray-500 text-xs dark:text-gray-400">
									Drag beacons or use the arrow keys. Snap: 0.5 m, shift = 2 m.
								</p>
							</div>
							<Button
								size="sm"
								onClick={saveLayout}
								disabled={!hasLayoutChanges || savingLayout}
							>
								{savingLayout ? "Saving…" : "Save layout"}
							</Button>
						</div>
					</CardHeader>
					<CardContent>
						<BeaconPlacementGrid
							widthM={event.floor_width_m}
							heightM={event.floor_height_m}
							beacons={placements}
							onMove={(beaconId, x, y) =>
								setPlacements((current) =>
									current.map((beacon) =>
										beacon.beacon_id === beaconId ? { ...beacon, x, y } : beacon,
									),
								)
							}
						/>
					</CardContent>
				</Card>

				<Card>
					<CardHeader>
						<h2 className="font-semibold text-gray-900 dark:text-white">
							Triangulation
						</h2>
						<p className="text-gray-500 text-xs dark:text-gray-400">
							Select an accepted check-in to see the estimated position.
						</p>
					</CardHeader>
					<CardContent>
						{selectedCheckin ? (
							<TriangulationGraph event={event} checkin={selectedCheckin} />
						) : (
							<EmptyState
								title="No accepted check-ins yet"
								description="The graph appears after a user checks in with enough positioned beacons."
							/>
						)}
					</CardContent>
				</Card>
			</div>

			<Card>
				<CardHeader>
					<div className="flex flex-wrap items-center justify-between gap-3">
						<h2 className="font-semibold text-gray-900 dark:text-white">Check-ins</h2>
						<div className="flex gap-1 rounded-lg bg-gray-100 p-1 dark:bg-gray-800">
							<button
								type="button"
								onClick={() => setTab("accepted")}
								className={`rounded-md px-3 py-1 font-medium text-xs ${
									tab === "accepted"
										? "bg-white shadow-sm dark:bg-gray-900"
										: "text-gray-500"
								}`}
							>
								Accepted ({accepted.length})
							</button>
							<button
								type="button"
								onClick={() => setTab("rejected")}
								className={`rounded-md px-3 py-1 font-medium text-xs ${
									tab === "rejected"
										? "bg-white shadow-sm dark:bg-gray-900"
										: "text-gray-500"
								}`}
							>
								Rejected ({rejected.length})
							</button>
						</div>
					</div>
				</CardHeader>
				<CardContent>
					{visible.length === 0 ? (
						<EmptyState
							title={tab === "accepted" ? "No accepted check-ins" : "No rejected attempts"}
						/>
					) : (
						<div className="overflow-x-auto">
							<table className="w-full text-left text-sm">
								<thead className="text-gray-500 text-xs uppercase dark:text-gray-400">
									<tr>
										<th className="pb-2">User</th>
										<th className="pb-2">Status</th>
										<th className="pb-2">Recorded</th>
										<th className="pb-2">Offline</th>
										<th className="pb-2">Beacons</th>
										<th className="pb-2">Position</th>
										<th className="pb-2">Reason</th>
										<th className="pb-2" />
									</tr>
								</thead>
								<tbody className="divide-y divide-gray-100 dark:divide-gray-800">
									{visible.map((item) => (
										<tr key={item.id}>
											<td className="py-2">
												<div className="font-medium text-gray-900 dark:text-gray-100">
													{item.user_name || "Unknown"}
												</div>
												<div className="text-gray-500 text-xs">{item.user_email}</div>
											</td>
											<td className="py-2">
												<Badge variant={item.status === "accepted" ? "green" : "red"}>
													{item.status}
												</Badge>
											</td>
											<td className="py-2 text-gray-500 dark:text-gray-400">
												{formatDateTime(item.recorded_at, event.timezone)}
											</td>
											<td className="py-2 text-gray-500 dark:text-gray-400">
												{item.is_offline ? "Yes" : "No"}
											</td>
											<td className="py-2 text-gray-500 dark:text-gray-400">
												{item.used_beacon_count}
											</td>
											<td className="py-2 text-gray-500 dark:text-gray-400">
												{item.estimated_x != null && item.estimated_y != null
													? `${item.estimated_x.toFixed(1)}, ${item.estimated_y.toFixed(1)} m`
													: "—"}
											</td>
											<td className="py-2 text-gray-500 text-xs dark:text-gray-400">
												{item.reject_reason ?? "—"}
											</td>
											<td className="py-2 text-right">
												{item.status === "accepted" ? (
													<Button
														size="sm"
														variant="ghost"
														onClick={() => setSelectedCheckinId(item.id)}
													>
														View graph
													</Button>
												) : null}
											</td>
										</tr>
									))}
								</tbody>
							</table>
						</div>
					)}
				</CardContent>
			</Card>

			<Modal
				open={deleteOpen}
				onClose={() => setDeleteOpen(false)}
				title="Delete event"
				footer={
					<>
						<Button variant="secondary" onClick={() => setDeleteOpen(false)}>
							Cancel
						</Button>
						<Button variant="danger" onClick={deleteEvent}>
							Delete event
						</Button>
					</>
				}
			>
				<p className="text-sm">
					Soft-delete <strong>{event.title}</strong>? Past check-ins and beacon usage remain in
					the database.
				</p>
			</Modal>

			{savingLayout ? <Spinner label="Saving layout…" /> : null}

			<div>
				<Link to="/events" className="text-blue-600 text-sm hover:underline">
					← Back to events
				</Link>
			</div>
		</div>
	);
}
