import { Link } from "react-router";
import {
	Badge,
	Button,
	Card,
	CardContent,
	CardHeader,
	ErrorAlert,
	PageHeader,
	PageSkeleton,
	StatCard,
} from "#/components/ui";
import { api } from "#/lib/api";
import { formatDate, formatDateTime } from "#/lib/datetime";
import { useAsync } from "#/lib/use-async";

export function meta() {
	return [{ title: "Dashboard | Beacon Check-In" }];
}

export default function DashboardPage() {
	const { data, loading, error, refresh } = useAsync(
		() =>
			Promise.all([
				api.summary(),
				api.users({ include_deleted: true }),
			]),
		[],
	);

	if (loading) return <PageSkeleton cards={4} rows={6} />;

	if (error || !data) {
		return (
			<div className="space-y-6">
				<PageHeader
					title="Dashboard"
					description="A quick view of users, events, beacons and check-in activity."
				/>
				<ErrorAlert
					message="Unable to load the dashboard."
					details={error?.message}
				/>
				<Button onClick={refresh}>Retry</Button>
			</div>
		);
	}

	const [summary, users] = data;
	const pending = summary.pending_approvals;

	return (
		<div className="space-y-6">
			<PageHeader
				title="Dashboard"
				description="A quick view of users, events, beacons and check-in activity."
			/>

			<div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
				<StatCard
					label="Users"
					value={
						(summary.user_counts.super_admin ?? 0) +
						(summary.user_counts.admin ?? 0) +
						(summary.user_counts.user ?? 0)
					}
					hint={`${summary.user_counts.super_admin ?? 0} super admin · ${summary.user_counts.admin ?? 0} admin · ${summary.user_counts.user ?? 0} user`}
				/>
				<StatCard
					label="Events"
					value={
						(summary.event_counts.upcoming ?? 0) +
						(summary.event_counts.ongoing ?? 0) +
						(summary.event_counts.past ?? 0)
					}
					hint={`${summary.event_counts.ongoing ?? 0} ongoing · ${summary.event_counts.upcoming ?? 0} upcoming`}
				/>
				<StatCard
					label="Active beacons"
					value={summary.active_beacons}
					hint={`${summary.deleted_beacons} soft-deleted`}
				/>
				<StatCard
					label="Check-ins today"
					value={summary.checkins_today}
					hint={`${pending} pending approval${pending === 1 ? "" : "s"}`}
				/>
			</div>

			<div className="grid gap-6 lg:grid-cols-3">
				<Card className="lg:col-span-2">
					<CardHeader>
						<div className="flex items-center justify-between">
							<h2 className="font-semibold text-gray-900 dark:text-white">
								Recent check-ins
							</h2>
							<Link
								to="/events"
								className="font-medium text-blue-600 text-sm hover:text-blue-700"
							>
								View events
							</Link>
						</div>
					</CardHeader>
					<CardContent>
						{summary.recent_checkins.length === 0 ? (
							<p className="text-gray-500 text-sm dark:text-gray-400">
								No check-ins yet. Create an event and check in from the mobile app.
							</p>
						) : (
							<div className="overflow-x-auto">
								<table className="w-full text-left text-sm">
									<thead className="text-gray-500 text-xs uppercase dark:text-gray-400">
										<tr>
											<th className="pb-2">User</th>
											<th className="pb-2">Event</th>
											<th className="pb-2">Status</th>
											<th className="pb-2">Recorded</th>
										</tr>
									</thead>
									<tbody className="divide-y divide-gray-100 dark:divide-gray-800">
										{summary.recent_checkins.map((item) => (
											<tr key={item.id}>
												<td className="py-2 font-medium text-gray-900 dark:text-gray-100">
													{item.user_name || "Unknown"}
												</td>
												<td className="py-2 text-gray-600 dark:text-gray-300">
													<Link
														to={`/events/${item.event_id}`}
														className="hover:text-blue-600"
													>
														{item.event_title}
													</Link>
												</td>
												<td className="py-2">
													<Badge variant={item.status === "accepted" ? "green" : "red"}>
														{item.status}
													</Badge>
												</td>
												<td className="py-2 text-gray-500 dark:text-gray-400">
													{formatDateTime(item.recorded_at)}
												</td>
											</tr>
										))}
									</tbody>
								</table>
							</div>
						)}
					</CardContent>
				</Card>

				<Card>
					<CardHeader>
						<h2 className="font-semibold text-gray-900 dark:text-white">Quick actions</h2>
					</CardHeader>
					<CardContent className="space-y-2 text-sm">
						<Link className="block text-blue-600 hover:underline" to="/events/new">
							+ Create an event
						</Link>
						<Link className="block text-blue-600 hover:underline" to="/beacons">
							Manage beacons
						</Link>
						{pending > 0 ? (
							<Link className="block text-amber-600 hover:underline" to="/approvals">
								{pending} beacon request{pending === 1 ? "" : "s"} waiting for approval
							</Link>
						) : null}
					</CardContent>
				</Card>
			</div>

			<Card>
				<CardHeader>
					<div className="flex items-center justify-between">
						<h2 className="font-semibold text-gray-900 dark:text-white">
							Users ({users.length})
						</h2>
						<span className="text-gray-500 text-xs">
							Super admin and admin accounts can manage events and beacons.
						</span>
					</div>
				</CardHeader>
				<CardContent>
					{users.length === 0 ? (
						<p className="text-gray-500 text-sm dark:text-gray-400">No users yet.</p>
					) : (
						<div className="max-h-80 overflow-auto">
							<table className="w-full text-left text-sm">
								<thead className="sticky top-0 bg-white text-gray-500 text-xs uppercase dark:bg-gray-900 dark:text-gray-400">
									<tr>
										<th className="pb-2">Name</th>
										<th className="pb-2">Email</th>
										<th className="pb-2">Role</th>
										<th className="pb-2">Status</th>
										<th className="pb-2">Joined</th>
									</tr>
								</thead>
								<tbody className="divide-y divide-gray-100 dark:divide-gray-800">
									{users.map((user) => (
										<tr key={user.id}>
											<td className="py-2 font-medium text-gray-900 dark:text-gray-100">
												{user.display_name}
											</td>
											<td className="py-2 text-gray-600 dark:text-gray-300">{user.email}</td>
											<td className="py-2">
												<Badge
													variant={
														user.role === "super_admin"
															? "purple"
															: user.role === "admin"
																? "blue"
																: "gray"
													}
												>
													{user.role}
												</Badge>
											</td>
											<td className="py-2">
												<Badge variant={user.deleted_at ? "red" : "green"}>
													{user.deleted_at ? "Deleted" : "Active"}
												</Badge>
											</td>
											<td className="py-2 text-gray-500 dark:text-gray-400">
												{formatDate(user.created_at)}
											</td>
										</tr>
									))}
								</tbody>
							</table>
						</div>
					)}
				</CardContent>
			</Card>
		</div>
	);
}
