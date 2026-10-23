import { useMemo, useState } from "react";

import {
	Badge,
	Button,
	Card,
	CardContent,
	CardHeader,
	EmptyState,
	ErrorAlert,
	Input,
	Modal,
	PageHeader,
	PageSkeleton,
	Select,
	Textarea,
} from "#/components/ui";
import { api, ApiError } from "#/lib/api";
import { useAuthUser } from "#/lib/auth-context";
import { formatDateTime } from "#/lib/datetime";
import { useAsync } from "#/lib/use-async";
import type { Beacon } from "#/lib/types";

export function meta() {
	return [{ title: "Beacons | Beacon Check-In" }];
}

type ModalState =
	| { type: "rename"; beacon: Beacon }
	| { type: "delete"; beacon: Beacon }
	| { type: "restore"; beacon: Beacon }
	| { type: "detail"; beacon: Beacon }
	| null;

export default function BeaconsPage() {
	const me = useAuthUser();
	const { data, loading, error: loadError, refresh } = useAsync(
		() => api.listBeacons({ status: "all", include_deleted: true }),
		[],
	);
	const beacons = useMemo(() => data ?? [], [data]);
	const [modal, setModal] = useState<ModalState>(null);
	const [label, setLabel] = useState("");
	const [reason, setReason] = useState("");
	const [confirmText, setConfirmText] = useState("");
	const [submitting, setSubmitting] = useState(false);
	const [error, setError] = useState<string | null>(null);
	const [message, setMessage] = useState<string | null>(null);
	const [usage, setUsage] = useState<
		Array<{ event_id: string; title: string; starts_at: string; ends_at: string; x: number; y: number }>
	>([]);
	const [search, setSearch] = useState("");
	const [status, setStatus] = useState("all");

	const filtered = useMemo(() => {
		return beacons.filter((beacon) => {
			if (status === "active" && beacon.deleted_at) return false;
			if (status === "deleted" && !beacon.deleted_at) return false;
			if (!search) return true;
			const haystack = `${beacon.label} ${beacon.identity_key} ${beacon.local_name ?? ""}`.toLowerCase();
			return haystack.includes(search.toLowerCase());
		});
	}, [beacons, search, status]);

	function openRename(beacon: Beacon) {
		setLabel(beacon.label);
		setError(null);
		setModal({ type: "rename", beacon });
	}

	function openDelete(beacon: Beacon) {
		setReason("");
		setConfirmText("");
		setError(null);
		setModal({ type: "delete", beacon });
	}

	function openRestore(beacon: Beacon) {
		setReason("");
		setError(null);
		setModal({ type: "restore", beacon });
	}

	async function openDetail(beacon: Beacon) {
		setError(null);
		setModal({ type: "detail", beacon });
		setUsage([]);
		try {
			const result = await api.beaconUsage(beacon.id);
			setUsage(result);
		} catch {
			setUsage([]);
		}
	}

	async function submitRename() {
		if (modal?.type !== "rename") return;
		setSubmitting(true);
		setError(null);
		try {
			await api.renameBeacon(modal.beacon.id, label);
			setModal(null);
			refresh();
		} catch (err) {
			setError(err instanceof ApiError ? err.message : "Request failed");
		} finally {
			setSubmitting(false);
		}
	}

	async function submitDelete() {
		if (modal?.type !== "delete") return;
		if (confirmText !== modal.beacon.label) {
			setError("Type the beacon label exactly to confirm.");
			return;
		}
		setSubmitting(true);
		setError(null);
		try {
			const result = await api.deleteBeacon(modal.beacon.id, reason);
			setMessage(result.message);
			setModal(null);
			refresh();
		} catch (err) {
			setError(err instanceof ApiError ? err.message : "Request failed");
		} finally {
			setSubmitting(false);
		}
	}

	async function submitRestore() {
		if (modal?.type !== "restore") return;
		setSubmitting(true);
		setError(null);
		try {
			const result = await api.restoreBeacon(modal.beacon.id, reason);
			setMessage(result.message);
			setModal(null);
			refresh();
		} catch (err) {
			setError(err instanceof ApiError ? err.message : "Request failed");
		} finally {
			setSubmitting(false);
		}
	}

	const isSuper = me.role === "super_admin";

	if (loading) return <PageSkeleton cards={4} rows={6} />;

	if (loadError) {
		return (
			<div className="space-y-6">
				<PageHeader title="Beacons" description="Manage registered beacons." />
				<ErrorAlert message="Unable to load beacons." details={loadError.message} />
				<Button onClick={refresh}>Retry</Button>
			</div>
		);
	}

	return (
		<div className="space-y-6">
			<PageHeader
				title="Beacons"
				description="Beacons are registered from the mobile app. Here you can rename them, inspect metadata and request deletion."
			/>

			{message ? (
				<div className="rounded-lg border border-green-200 bg-green-50 px-4 py-3 text-green-800 text-sm dark:border-green-900 dark:bg-green-950 dark:text-green-200">
					{message}
				</div>
			) : null}
			{error && !modal ? <ErrorAlert message={error} /> : null}

			<Card>
				<CardContent className="flex flex-wrap items-end gap-3">
					<div className="min-w-56 flex-1">
						<label className="mb-1 block font-medium text-sm">Search</label>
						<Input
							value={search}
							onChange={(event) => setSearch(event.target.value)}
							placeholder="Label, identity or local name"
						/>
					</div>
					<div className="w-44">
						<label className="mb-1 block font-medium text-sm">Status</label>
						<Select value={status} onChange={(event) => setStatus(event.target.value)}>
							<option value="all">All</option>
							<option value="active">Active</option>
							<option value="deleted">Deleted</option>
						</Select>
					</div>
				</CardContent>
			</Card>

			<Card>
				<CardHeader>
					<div className="flex items-center justify-between">
						<h2 className="font-semibold text-gray-900 dark:text-white">
							Registered beacons ({filtered.length})
						</h2>
						<Badge variant="gray">{isSuper ? "Super admin can delete directly" : "Deletion needs approval"}</Badge>
					</div>
				</CardHeader>
				<CardContent>
					{filtered.length === 0 ? (
						<EmptyState
							title="No beacons found"
							description="Register a beacon from the mobile admin scanner."
						/>
					) : (
						<div className="overflow-x-auto">
							<table className="w-full text-left text-sm">
								<thead className="text-gray-500 text-xs uppercase dark:text-gray-400">
									<tr>
										<th className="pb-2">Label</th>
										<th className="pb-2">Identity</th>
										<th className="pb-2">Local name</th>
										<th className="pb-2">TX power</th>
										<th className="pb-2">Last seen</th>
										<th className="pb-2">Status</th>
										<th className="pb-2 text-right">Actions</th>
									</tr>
								</thead>
								<tbody className="divide-y divide-gray-100 dark:divide-gray-800">
									{filtered.map((beacon) => (
										<tr key={beacon.id}>
											<td className="py-2 font-medium text-gray-900 dark:text-gray-100">
												{beacon.label}
											</td>
											<td className="py-2 font-mono text-gray-600 text-xs dark:text-gray-300">
												{beacon.identity_key}
											</td>
											<td className="py-2 text-gray-600 dark:text-gray-300">
												{beacon.local_name || "—"}
											</td>
											<td className="py-2 text-gray-600 dark:text-gray-300">
												{beacon.tx_power ?? "—"}
											</td>
											<td className="py-2 text-gray-500 dark:text-gray-400">
												{formatDateTime(beacon.last_seen_at)}
											</td>
											<td className="py-2">
												<Badge variant={beacon.deleted_at ? "red" : "green"}>
													{beacon.deleted_at ? "Deleted" : "Active"}
												</Badge>
											</td>
											<td className="py-2">
												<div className="flex justify-end gap-1">
													<Button variant="ghost" size="sm" onClick={() => openDetail(beacon)}>
														Details
													</Button>
													<Button
														variant="ghost"
														size="sm"
														onClick={() => openRename(beacon)}
													>
														Rename
													</Button>
													{beacon.deleted_at ? (
														<Button
															variant="ghost"
															size="sm"
															className="text-green-700"
															onClick={() => openRestore(beacon)}
														>
															Restore
														</Button>
													) : (
														<Button
															variant="ghost"
															size="sm"
															className="text-red-600"
															onClick={() => openDelete(beacon)}
														>
															Delete
														</Button>
													)}
												</div>
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
				open={modal?.type === "rename"}
				onClose={() => setModal(null)}
				title="Rename beacon"
				footer={
					<>
						<Button variant="secondary" onClick={() => setModal(null)}>
							Cancel
						</Button>
						<Button onClick={submitRename} disabled={submitting}>
							{submitting ? "Saving…" : "Save"}
						</Button>
					</>
				}
			>
				<div className="space-y-3">
					{error ? <ErrorAlert message={error} /> : null}
					<Input value={label} onChange={(event) => setLabel(event.target.value)} />
				</div>
			</Modal>

			<Modal
				open={modal?.type === "delete"}
				onClose={() => setModal(null)}
				title="Delete beacon"
				footer={
					<>
						<Button variant="secondary" onClick={() => setModal(null)}>
							Cancel
						</Button>
						<Button variant="danger" onClick={submitDelete} disabled={submitting}>
							{submitting ? "Submitting…" : isSuper ? "Delete beacon" : "Request deletion"}
						</Button>
					</>
				}
			>
				<div className="space-y-3">
					{error ? <ErrorAlert message={error} /> : null}
					<p className="text-sm">
						{isSuper
							? "The beacon will be soft-deleted. Past events keep their snapshot."
							: "A delete request will be sent to the super admin. The beacon stays active until approved."}
					</p>
					<div>
						<label className="mb-1 block font-medium text-sm">Reason</label>
						<Textarea
							value={reason}
							onChange={(event) => setReason(event.target.value)}
							placeholder="Why should this beacon be deleted?"
						/>
					</div>
					<div>
						<label className="mb-1 block font-medium text-sm">
							Type <strong>{modal?.type === "delete" ? modal.beacon.label : ""}</strong> to
							confirm
						</label>
						<Input value={confirmText} onChange={(event) => setConfirmText(event.target.value)} />
					</div>
				</div>
			</Modal>

			<Modal
				open={modal?.type === "restore"}
				onClose={() => setModal(null)}
				title="Restore beacon"
				footer={
					<>
						<Button variant="secondary" onClick={() => setModal(null)}>
							Cancel
						</Button>
						<Button onClick={submitRestore} disabled={submitting}>
							{submitting ? "Submitting…" : isSuper ? "Restore beacon" : "Request restore"}
						</Button>
					</>
				}
			>
				<div className="space-y-3">
					{error ? <ErrorAlert message={error} /> : null}
					<p className="text-sm">
						{isSuper
							? "The beacon becomes active again."
							: "A restore request will be sent to the super admin."}
					</p>
					<div>
						<label className="mb-1 block font-medium text-sm">Reason</label>
						<Textarea value={reason} onChange={(event) => setReason(event.target.value)} />
					</div>
				</div>
			</Modal>

			<Modal
				open={modal?.type === "detail"}
				onClose={() => setModal(null)}
				title={modal?.type === "detail" ? modal.beacon.label : "Beacon"}
			>
				{modal?.type === "detail" ? (
					<div className="space-y-4">
						<div className="grid grid-cols-2 gap-2 text-sm">
							<div className="text-gray-500">Identity</div>
							<div className="font-mono text-xs">{modal.beacon.identity_key}</div>
							<div className="text-gray-500">Local name</div>
							<div>{modal.beacon.local_name || "—"}</div>
							<div className="text-gray-500">Device id</div>
							<div className="font-mono text-xs">{modal.beacon.platform_device_id || "—"}</div>
							<div className="text-gray-500">TX power</div>
							<div>{modal.beacon.tx_power ?? "—"}</div>
							<div className="text-gray-500">Registered</div>
							<div>{formatDateTime(modal.beacon.registered_at)}</div>
							<div className="text-gray-500">Last seen</div>
							<div>{formatDateTime(modal.beacon.last_seen_at)}</div>
						</div>
						<div>
							<div className="mb-1 font-medium text-sm">Advertisement metadata</div>
							<pre className="max-h-56 overflow-auto rounded-lg bg-gray-100 p-3 text-xs dark:bg-gray-800">
								{JSON.stringify(modal.beacon.metadata ?? {}, null, 2)}
							</pre>
						</div>
						<div>
							<div className="mb-1 font-medium text-sm">GATT details</div>
							<pre className="max-h-40 overflow-auto rounded-lg bg-gray-100 p-3 text-xs dark:bg-gray-800">
								{JSON.stringify(modal.beacon.gatt_info ?? {}, null, 2)}
							</pre>
						</div>
						<div>
							<div className="mb-1 font-medium text-sm">Event usage</div>
							{usage.length === 0 ? (
								<p className="text-gray-500 text-sm">Not attached to any event.</p>
							) : (
								<ul className="space-y-1 text-sm">
									{usage.map((item) => (
										<li key={item.event_id}>
											{item.title} · {formatDateTime(item.starts_at)} · ({item.x},{" "}
											{item.y}) m
										</li>
									))}
								</ul>
							)}
						</div>
					</div>
				) : null}
			</Modal>
		</div>
	);
}
