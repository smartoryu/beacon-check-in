import { useState } from "react";
import { Navigate } from "react-router";
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
	RefreshButton,
} from "#/components/ui";
import { api, ApiError } from "#/lib/api";
import { useAuthUser } from "#/lib/auth-context";
import { formatDateTime } from "#/lib/datetime";
import { useAsync } from "#/lib/use-async";
import type { TemporaryPasswordResponse, User } from "#/lib/types";

export function meta() {
	return [{ title: "Admins | Beacon Check-In" }];
}

type ModalState =
	| { type: "create" }
	| { type: "edit"; admin: User }
	| { type: "delete"; admin: User }
	| { type: "reset"; admin: User }
	| { type: "password"; result: TemporaryPasswordResponse | { temporary_password: string; user?: User } }
	| null;

export default function AdminsPage() {
	const me = useAuthUser();
	const { data, loading, error: loadError, refresh } = useAsync(
		() => api.listAdmins(true),
		[],
	);
	const admins = data ?? [];
	const [modal, setModal] = useState<ModalState>(null);
	const [name, setName] = useState("");
	const [email, setEmail] = useState("");
	const [submitting, setSubmitting] = useState(false);
	const [error, setError] = useState<string | null>(null);

	if (me.role !== "super_admin") return <Navigate to="/dashboard" replace />;

	if (loading) return <PageSkeleton cards={0} rows={6} />;

	if (loadError) {
		return (
			<div className="space-y-6">
				<PageHeader title="Admins" description="Manage admin accounts." />
				<ErrorAlert message="Unable to load admins." details={loadError.message} />
				<Button onClick={refresh}>Retry</Button>
			</div>
		);
	}

	function openCreate() {
		setName("");
		setEmail("");
		setError(null);
		setModal({ type: "create" });
	}

	function openEdit(admin: User) {
		setName(admin.display_name);
		setEmail(admin.email);
		setError(null);
		setModal({ type: "edit", admin });
	}

	async function submitForm() {
		if (!modal || (modal.type !== "create" && modal.type !== "edit")) return;
		setSubmitting(true);
		setError(null);
		try {
			if (modal.type === "create") {
				const result = await api.createAdmin(name, email);
				setModal({ type: "password", result });
			} else {
				await api.updateAdmin(modal.admin.id, name, email);
				setModal(null);
				refresh();
			}
		} catch (err) {
			setError(err instanceof ApiError ? err.message : "Request failed");
		} finally {
			setSubmitting(false);
		}
	}

	async function confirmDelete(admin: User) {
		setSubmitting(true);
		setError(null);
		try {
			await api.deleteAdmin(admin.id);
			setModal(null);
			refresh();
		} catch (err) {
			setError(err instanceof ApiError ? err.message : "Request failed");
		} finally {
			setSubmitting(false);
		}
	}

	async function confirmReset(admin: User) {
		setSubmitting(true);
		setError(null);
		try {
			const result = await api.resetAdminPassword(admin.id);
			setModal({ type: "password", result });
			refresh();
		} catch (err) {
			setError(err instanceof ApiError ? err.message : "Request failed");
		} finally {
			setSubmitting(false);
		}
	}

	return (
		<div className="space-y-6">
			<PageHeader
				title="Admins"
				description="Create and manage admin accounts. Only the super admin can use this page."
				actions={
					<>
						<RefreshButton onClick={refresh} />
						<Button onClick={openCreate}>Create admin</Button>
					</>
				}
			/>

			<Card>
				<CardHeader>
					<h2 className="font-semibold text-gray-900 dark:text-white">
						Admin accounts ({admins.length})
					</h2>
				</CardHeader>
				<CardContent>
					{admins.length === 0 ? (
						<EmptyState title="No admins yet" description="Create the first admin account." />
					) : (
						<div className="overflow-x-auto">
							<table className="w-full min-w-[720px] text-left text-sm">
								<thead className="text-gray-500 text-xs uppercase dark:text-gray-400">
									<tr>
										<th className="pb-2">Name</th>
										<th className="pb-2">Email</th>
										<th className="pb-2">Role</th>
										<th className="pb-2">Status</th>
										<th className="pb-2">Last login</th>
										<th className="pb-2 text-right">Actions</th>
									</tr>
								</thead>
								<tbody className="divide-y divide-gray-100 dark:divide-gray-800">
									{admins.map((admin) => {
										const isSuper = admin.role === "super_admin";
										const isSelf = admin.id === me.id;
										return (
											<tr key={admin.id}>
												<td className="py-2 font-medium text-gray-900 dark:text-gray-100">
													{admin.display_name}
												</td>
												<td className="py-2 text-gray-600 dark:text-gray-300">{admin.email}</td>
												<td className="py-2">
													<Badge variant={isSuper ? "purple" : "blue"}>
														{isSuper ? "Super admin" : "Admin"}
													</Badge>
												</td>
												<td className="py-2">
													<Badge variant={admin.deleted_at ? "red" : "green"}>
														{admin.deleted_at ? "Deleted" : "Active"}
													</Badge>
												</td>
												<td className="py-2 text-gray-500 dark:text-gray-400">
													{formatDateTime(admin.last_login_at)}
												</td>
												<td className="py-2">
													<div className="flex flex-wrap justify-end gap-1">
														<Button
															variant="ghost"
															size="sm"
															onClick={() => openEdit(admin)}
															disabled={isSuper}
														>
															Edit
														</Button>
														<Button
															variant="ghost"
															size="sm"
															onClick={() => {
																setError(null);
																setModal({ type: "reset", admin });
															}}
														>
															Reset password
														</Button>
														<Button
															variant="ghost"
															size="sm"
															className="text-red-600"
															onClick={() => {
																setError(null);
																setModal({ type: "delete", admin });
															}}
															disabled={isSuper || isSelf || Boolean(admin.deleted_at)}
														>
															Delete
														</Button>
													</div>
												</td>
											</tr>
										);
									})}
								</tbody>
							</table>
						</div>
					)}
				</CardContent>
			</Card>

			<Modal
				open={modal?.type === "create" || modal?.type === "edit"}
				onClose={() => setModal(null)}
				title={modal?.type === "edit" ? "Edit admin" : "Create admin"}
				footer={
					<>
						<Button variant="secondary" onClick={() => setModal(null)}>
							Cancel
						</Button>
						<Button onClick={submitForm} disabled={submitting}>
							{submitting ? "Saving…" : "Save"}
						</Button>
					</>
				}
			>
				<div className="space-y-4">
					{error ? <ErrorAlert message={error} /> : null}
					{modal?.type === "create" ? (
						<p className="rounded-lg bg-blue-50 px-3 py-2 text-blue-800 text-xs dark:bg-blue-950 dark:text-blue-200">
							A one-time temporary password will be shown after creation. The admin must change it
							on first sign-in.
						</p>
					) : null}
					<div>
						<label className="mb-1 block font-medium text-sm">Name</label>
						<Input value={name} onChange={(event) => setName(event.target.value)} />
					</div>
					<div>
						<label className="mb-1 block font-medium text-sm">Email</label>
						<Input
							type="email"
							value={email}
							onChange={(event) => setEmail(event.target.value)}
						/>
					</div>
				</div>
			</Modal>

			<Modal
				open={modal?.type === "delete"}
				onClose={() => setModal(null)}
				title="Delete admin"
				footer={
					<>
						<Button variant="secondary" onClick={() => setModal(null)}>
							Cancel
						</Button>
						<Button
							variant="danger"
							disabled={submitting}
							onClick={() => modal?.type === "delete" && confirmDelete(modal.admin)}
						>
							{submitting ? "Deleting…" : "Delete admin"}
						</Button>
					</>
				}
			>
				{error ? <ErrorAlert message={error} /> : null}
				<p className="text-sm">
					Soft-delete <strong>{modal?.type === "delete" ? modal.admin.display_name : ""}</strong>?
					Their sessions will be revoked. This action cannot be undone from the UI.
				</p>
			</Modal>

			<Modal
				open={modal?.type === "reset"}
				onClose={() => setModal(null)}
				title="Reset password"
				footer={
					<>
						<Button variant="secondary" onClick={() => setModal(null)}>
							Cancel
						</Button>
						<Button
							disabled={submitting}
							onClick={() => modal?.type === "reset" && confirmReset(modal.admin)}
						>
							{submitting ? "Resetting…" : "Generate new password"}
						</Button>
					</>
				}
			>
				{error ? <ErrorAlert message={error} /> : null}
				<p className="text-sm">
					Generate a new one-time password for{" "}
					<strong>{modal?.type === "reset" ? modal.admin.display_name : ""}</strong>? Existing
					sessions will be revoked.
				</p>
			</Modal>

			<Modal
				open={modal?.type === "password"}
				onClose={() => {
					setModal(null);
					refresh();
				}}
				title="Temporary password"
				footer={
					<Button
						onClick={() => {
							setModal(null);
							refresh();
						}}
					>
						Done
					</Button>
				}
			>
				{modal?.type === "password" ? (
					<div className="space-y-3">
						<p className="text-gray-600 text-sm dark:text-gray-300">
							Copy this password now. It will not be shown again.
						</p>
						<pre className="overflow-x-auto rounded-lg bg-gray-100 px-4 py-3 font-mono text-sm dark:bg-gray-800">
							{modal.result.temporary_password}
						</pre>
					</div>
				) : null}
			</Modal>
		</div>
	);
}
