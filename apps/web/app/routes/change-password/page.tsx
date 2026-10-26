import { Form, Navigate, redirect, useActionData, useNavigation } from "react-router";
import { Button, ErrorAlert, Input } from "#/components/ui";
import { api, ApiError } from "#/lib/api";
import { clearAuth, getAccessToken } from "#/lib/auth";

export function meta() {
	return [{ title: "Change password | Beacon Check-In" }];
}

export async function clientAction({ request }: { request: Request }) {
	const formData = await request.formData();
	const currentPassword = String(formData.get("current_password") ?? "");
	const newPassword = String(formData.get("new_password") ?? "");
	const confirmation = String(formData.get("password_confirmation") ?? "");

	if (newPassword.length < 8) {
		return { error: "New password must be at least 8 characters." };
	}
	if (newPassword !== confirmation) {
		return { error: "Password confirmation does not match." };
	}
	try {
		await api.changePassword(currentPassword, newPassword, confirmation);
		clearAuth();
		return redirect("/login?changed=1");
	} catch (error) {
		if (error instanceof ApiError) return { error: error.message };
		return { error: "Unable to change password." };
	}
}

export default function ChangePasswordPage() {
	const actionData = useActionData<typeof clientAction>();
	const navigation = useNavigation();
	const pending = navigation.state === "submitting";

	if (!getAccessToken()) {
		return <Navigate to="/login" replace />;
	}

	return (
		<div className="flex min-h-screen items-center justify-center bg-gray-50 px-4 py-12 dark:bg-gray-950">
			<div className="w-full max-w-md space-y-6">
				<div className="text-center">
					<h1 className="font-bold text-3xl text-gray-900 dark:text-white">
						Change your password
					</h1>
					<p className="mt-2 text-gray-500 text-sm dark:text-gray-400">
						You are using a temporary password. Set a new password to continue.
					</p>
				</div>
				<div className="rounded-xl border border-gray-200 bg-white p-6 shadow-sm dark:border-gray-800 dark:bg-gray-900">
					{actionData?.error ? (
						<div className="mb-4">
							<ErrorAlert message={actionData.error} />
						</div>
					) : null}
					<Form method="post" className="space-y-4">
						<div>
							<label htmlFor="current_password" className="mb-1 block font-medium text-sm">
								Temporary password
							</label>
							<Input
								id="current_password"
								name="current_password"
								type="password"
								autoComplete="current-password"
								required
							/>
						</div>
						<div>
							<label htmlFor="new_password" className="mb-1 block font-medium text-sm">
								New password
							</label>
							<Input
								id="new_password"
								name="new_password"
								type="password"
								autoComplete="new-password"
								required
							/>
						</div>
						<div>
							<label
								htmlFor="password_confirmation"
								className="mb-1 block font-medium text-sm"
							>
								Confirm new password
							</label>
							<Input
								id="password_confirmation"
								name="password_confirmation"
								type="password"
								autoComplete="new-password"
								required
							/>
						</div>
						<Button type="submit" className="w-full" disabled={pending}>
							{pending ? "Saving…" : "Set new password"}
						</Button>
					</Form>
				</div>
			</div>
		</div>
	);
}
