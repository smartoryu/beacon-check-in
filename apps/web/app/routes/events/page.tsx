import { useMemo, useState } from "react";
import { Link } from "react-router";
import {
	Badge,
	Button,
	ButtonLink,
	Card,
	CardContent,
	EmptyState,
	ErrorAlert,
	Input,
	PageHeader,
	Skeleton,
	Select,
} from "#/components/ui";
import { api } from "#/lib/api";
import { eventStatus, formatDateTime } from "#/lib/datetime";
import { useAsync } from "#/lib/use-async";

export function meta() {
	return [{ title: "Events | Beacon Check-In" }];
}

export default function EventsPage() {
	const { data, loading, error, refresh } = useAsync(
		() => api.listEvents({ include_deleted: false }),
		[],
	);
	const [search, setSearch] = useState("");
	const [status, setStatus] = useState("all");
	const events = useMemo(() => data ?? [], [data]);

	const filtered = useMemo(() => {
		return events.filter((event) => {
			const eventState = eventStatus(event);
			if (status !== "all" && eventState !== status) return false;
			if (!search) return true;
			const haystack = `${event.title} ${event.place_name} ${event.address ?? ""}`.toLowerCase();
			return haystack.includes(search.toLowerCase());
		});
	}, [events, search, status]);

	if (loading) {
		return (
			<div className="space-y-6">
				<PageHeader
					title="Events"
					description="Create events, attach at least one beacon and place beacons on the floor grid."
				/>
				<div className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
					{Array.from({ length: 6 }).map((_, index) => (
						<Card key={index}>
							<CardContent className="space-y-4">
								<Skeleton className="h-5 w-40" />
								<Skeleton className="h-4 w-56" />
								<Skeleton className="h-4 w-48" />
								<Skeleton className="h-4 w-32" />
							</CardContent>
						</Card>
					))}
				</div>
			</div>
		);
	}

	if (error) {
		return (
			<div className="space-y-6">
				<PageHeader title="Events" description="Create and manage events." />
				<ErrorAlert message="Unable to load events." details={error.message} />
				<Button onClick={refresh}>Retry</Button>
			</div>
		);
	}

	return (
		<div className="space-y-6">
			<PageHeader
				title="Events"
				description="Create events, attach at least one beacon and place beacons on the floor grid."
				actions={
					<>
						<Button variant="secondary" onClick={refresh}>
							Refresh
						</Button>
						<ButtonLink to="/events/new">Create event</ButtonLink>
					</>
				}
			/>

			<Card>
				<CardContent className="flex flex-wrap items-end gap-3">
					<div className="min-w-56 flex-1">
						<label className="mb-1 block font-medium text-sm">Search</label>
						<Input
							value={search}
							onChange={(event) => setSearch(event.target.value)}
							placeholder="Title, place or address"
						/>
					</div>
					<div className="w-44">
						<label className="mb-1 block font-medium text-sm">Status</label>
						<Select value={status} onChange={(event) => setStatus(event.target.value)}>
							<option value="all">All</option>
							<option value="ongoing">Ongoing</option>
							<option value="upcoming">Upcoming</option>
							<option value="past">Past</option>
						</Select>
					</div>
				</CardContent>
			</Card>

			{filtered.length === 0 ? (
				<EmptyState
					title="No events found"
					description="Create an event and attach at least one registered beacon."
					action={<Link to="/events/new">Create event</Link>}
				/>
			) : (
				<div className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
					{filtered.map((event) => {
						const state = eventStatus(event);
						return (
							<Card key={event.id} className="flex flex-col">
								<CardContent className="flex-1">
									<div className="flex items-start justify-between gap-2">
										<Link
											to={`/events/${event.id}`}
											className="font-semibold text-gray-900 hover:text-blue-600 dark:text-white"
										>
											{event.title}
										</Link>
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
									</div>
									<p className="mt-1 text-gray-500 text-sm dark:text-gray-400">
										{event.place_name}
										{event.address ? ` · ${event.address}` : ""}
									</p>
									<p className="mt-3 text-gray-600 text-sm dark:text-gray-300">
										{formatDateTime(event.starts_at, event.timezone)} →{" "}
										{formatDateTime(event.ends_at, event.timezone)}
									</p>
									<div className="mt-3 flex flex-wrap gap-2 text-gray-500 text-xs dark:text-gray-400">
										<span>{event.beacons.length} beacon(s)</span>
										<span>·</span>
										<span>{event.checkin_count} check-in(s)</span>
										<span>·</span>
										<span>
											{event.floor_width_m}×{event.floor_height_m} m
										</span>
									</div>
								</CardContent>
								<div className="flex gap-2 border-gray-100 border-t px-5 py-3 dark:border-gray-800">
									<Link
										to={`/events/${event.id}`}
										className="font-medium text-blue-600 text-sm hover:underline"
									>
										Open
									</Link>
									<Link
										to={`/events/${event.id}/edit`}
										className="font-medium text-gray-600 text-sm hover:underline dark:text-gray-300"
									>
										Edit
									</Link>
								</div>
							</Card>
						);
					})}
				</div>
			)}
		</div>
	);
}
