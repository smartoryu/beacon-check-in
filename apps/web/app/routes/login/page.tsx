import { Form, redirect, useActionData, useNavigation } from "react-router";
import { Button, ErrorAlert, Input } from "#/components/ui";
import { api, ApiError } from "#/lib/api";
import { setAuth } from "#/lib/auth";

export function meta() {
	return [{ title: "Sign in | Beacon Check-In" }];
}

export async function clientAction({ request }: { request: Request }) {
	const formData = await request.formData();
	const email = String(formData.get("email") ?? "").trim();
	const password = String(formData.get("password") ?? "");
	if (!email || !password) {
		return { error: "Email and password are required." };
	}
	try {
		const auth = await api.signIn(email, password);
		setAuth(auth);
		if (auth.user.must_change_password) {
			return redirect("/change-password");
		}
		return redirect("/dashboard");
	} catch (error) {
		if (error instanceof ApiError) {
			return { error: error.message };
		}
		return { error: "Unable to sign in. Is the API running?" };
	}
}

export default function LoginPage() {
	const actionData = useActionData<typeof clientAction>();
	const navigation = useNavigation();
	const pending = navigation.state === "submitting";

	return (
		<div className="flex min-h-screen items-center justify-center bg-gray-50 px-4 py-12 dark:bg-gray-950">
			<div className="w-full max-w-md space-y-6">
				<div className="text-center">
					<div className="mx-auto flex h-14 w-14 items-center justify-center rounded-2xl bg-blue-600 font-bold text-2xl text-white">
						B
					</div>
					<h1 className="mt-4 font-bold text-3xl text-gray-900 dark:text-white">
						Beacon Check-In
					</h1>
					<p className="mt-2 text-gray-500 text-sm dark:text-gray-400">
						Admin console — sign in to manage events, beacons and approvals.
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
							<label
								htmlFor="email"
								className="mb-1 block font-medium text-gray-700 text-sm dark:text-gray-300"
							>
								Email
							</label>
							<Input
								id="email"
								name="email"
								type="email"
								autoComplete="email"
								required
								placeholder="superadmin@beacon.local"
							/>
						</div>
						<div>
							<label
								htmlFor="password"
								className="mb-1 block font-medium text-gray-700 text-sm dark:text-gray-300"
							>
								Password
							</label>
							<Input
								id="password"
								name="password"
								type="password"
								autoComplete="current-password"
								required
								placeholder="••••••••"
							/>
						</div>
						<Button type="submit" className="w-full" disabled={pending}>
							{pending ? "Signing in…" : "Sign in"}
						</Button>
					</Form>
				</div>

				<p className="text-center text-gray-500 text-xs dark:text-gray-400">
					Seeded super admin: <code>superadmin@beacon.local</code> / <code>SuperAdmin123!</code>
				</p>
			</div>
		</div>
	);
}
