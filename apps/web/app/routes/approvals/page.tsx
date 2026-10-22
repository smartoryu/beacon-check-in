import { useState } from "react";
import { Navigate, redirect, useLoaderData, useRevalidator } from "react-router";
import {
	Badge,
	Button,
	Card,
	CardContent,
	CardHeader,
	EmptyState,
	ErrorAlert,
	Modal,
	PageHeader,
	Textarea,
} from "#/components/ui";
import { api, ApiError } from "#/lib/api";
import { formatDateTime } from "#/lib/datetime";
import type { ChangeRequest } from "#/lib/types";

export function meta() {
	return [{ title: "Approvals | Beacon Check-In" }];
}

export async function clientLoader() {
	const me = await api.me();
	if (me.role !== "super_admin") throw redirect("/dashboard");
	const requests = await api.listChangeRequests("");
	return { me, requests };
}

type ReviewState = { request: ChangeRequest; action: "approve" | "reject" } | null;

export default function ApprovalsPage() {
	const { me, requests } = useLoaderData<typeof clientLoader>();
	const revalidator = useRevalidator();
	const [review, setReview] = useState<ReviewState>(null);
	const [note, setNote] = useState("");
	const [submitting, setSubmitting] = useState(false);
	const [error, setError] = useState<string | null>(null);

	if (me.role !== "super_admin") return <Navigate to="/dashboard" replace />;

	const pending = requests.filter((request) => request.status === "pending");
	const history = requests.filter((request) => request.status !== "pending");

	async function submitReview() {
		if (!review) return;
		setSubmitting(true);
		setError(null);
		try {
			if (review.action === "approve") {
				await api.approveChangeRequest(review.request.id, note);
			} else {
				await api.rejectChangeRequest(review.request.id, note);
			}
			setReview(null);
			setNote("");
			revalidator.revalidate();
		} catch (err) {
			setError(err instanceof ApiError ? err.message : "Request failed");
		} finally {
			setSubmitting(false);
		}
	}

	return (
		<div className="space-y-6">
			<PageHeader
				title="Approvals"
				description="Admins cannot delete or restore beacons directly. Approve or reject their requests here."
			/>

			<Card>
				<CardHeader>
					<div className="flex items-center justify-between">
						<h2 className="font-semibold text-gray-900 dark:text-white">Pending requests</h2>
						<Badge variant={pending.length ? "amber" : "gray"}>{pending.length} pending</Badge>
					</div>
				</CardHeader>
				<CardContent>
					{pending.length === 0 ? (
						<EmptyState
							title="No pending requests"
							description="Beacon delete and restore requests from admins will appear here."
						/>
					) : (
						<div className="space-y-3">
							{pending.map((request) => (
								<div
									key={request.id}
									className="flex flex-wrap items-center justify-between gap-3 rounded-lg border border-gray-200 px-4 py-3 dark:border-gray-800"
								>
									<div>
										<div className="flex items-center gap-2">
											<Badge variant={request.action === "delete" ? "red" : "green"}>
												{request.action}
											</Badge>
											<span className="font-medium text-gray-900 dark:text-white">
												{request.beacon_label}
											</span>
										</div>
										<div className="mt-1 text-gray-500 text-xs dark:text-gray-400">
											{request.requester_name} · {formatDateTime(request.created_at)}
										</div>
										<p className="mt-1 text-gray-600 text-sm dark:text-gray-300">
											“{request.reason}”
										</p>
									</div>
									<div className="flex gap-2">
										<Button
											size="sm"
											onClick={() => {
												setError(null);
												setNote("");
												setReview({ request, action: "approve" });
											}}
										>
											Approve
										</Button>
										<Button
											size="sm"
											variant="secondary"
											onClick={() => {
												setError(null);
												setNote("");
												setReview({ request, action: "reject" });
											}}
										>
											Reject
										</Button>
									</div>
								</div>
							))}
						</div>
					)}
				</CardContent>
			</Card>

			<Card>
				<CardHeader>
					<h2 className="font-semibold text-gray-900 dark:text-white">History</h2>
				</CardHeader>
				<CardContent>
					{history.length === 0 ? (
						<p className="text-gray-500 text-sm dark:text-gray-400">No reviewed requests yet.</p>
					) : (
						<div className="overflow-x-auto">
							<table className="w-full text-left text-sm">
								<thead className="text-gray-500 text-xs uppercase dark:text-gray-400">
									<tr>
										<th className="pb-2">Beacon</th>
										<th className="pb-2">Action</th>
										<th className="pb-2">Status</th>
										<th className="pb-2">Requested by</th>
										<th className="pb-2">Reviewed by</th>
										<th className="pb-2">Reviewed at</th>
									</tr>
								</thead>
								<tbody className="divide-y divide-gray-100 dark:divide-gray-800">
									{history.map((request) => (
										<tr key={request.id}>
											<td className="py-2">{request.beacon_label}</td>
											<td className="py-2">
												<Badge variant={request.action === "delete" ? "red" : "green"}>
													{request.action}
												</Badge>
											</td>
											<td className="py-2">
												<Badge
													variant={request.status === "approved" ? "green" : "red"}
												>
													{request.status}
												</Badge>
											</td>
											<td className="py-2">{request.requester_name}</td>
											<td className="py-2">{request.reviewer_name ?? "—"}</td>
											<td className="py-2 text-gray-500 dark:text-gray-400">
												{formatDateTime(request.reviewed_at)}
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
				open={Boolean(review)}
				onClose={() => setReview(null)}
				title={review?.action === "approve" ? "Approve request" : "Reject request"}
				footer={
					<>
						<Button variant="secondary" onClick={() => setReview(null)}>
							Cancel
						</Button>
						<Button
							variant={review?.action === "approve" ? "primary" : "danger"}
							disabled={submitting}
							onClick={submitReview}
						>
							{submitting ? "Saving…" : review?.action === "approve" ? "Approve" : "Reject"}
						</Button>
					</>
				}
			>
				<div className="space-y-3">
					{error ? <ErrorAlert message={error} /> : null}
					<p className="text-sm">
						{review?.action === "approve"
							? "This will apply the requested action immediately."
							: "The beacon will stay unchanged and the requester will see the rejection."}
					</p>
					<div>
						<label className="mb-1 block font-medium text-sm">Review note (optional)</label>
						<Textarea value={note} onChange={(event) => setNote(event.target.value)} />
					</div>
				</div>
			</Modal>
		</div>
	);
}
