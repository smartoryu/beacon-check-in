import { Navigate, Outlet } from "react-router";
import { AppShell, AppShellSkeleton } from "#/components/app-shell";
import { Button, ErrorAlert } from "#/components/ui";
import { api, ApiError } from "#/lib/api";
import { clearAuth, getAccessToken } from "#/lib/auth";
import { AuthProvider } from "#/lib/auth-context";
import { useAsync } from "#/lib/use-async";

export default function ProtectedLayout() {
	const hasToken = Boolean(getAccessToken());
	const { data: me, loading, error, refresh } = useAsync(
		async () => (hasToken ? api.me() : null),
		[hasToken],
	);

	if (!hasToken) {
		return <Navigate to="/login" replace />;
	}

	if (loading) {
		return <AppShellSkeleton />;
	}

	if (error) {
		if (error instanceof ApiError && error.status === 401) {
			clearAuth();
			return <Navigate to="/login" replace />;
		}
		return (
			<div className="flex min-h-screen items-center justify-center bg-gray-50 px-4 dark:bg-gray-950">
				<div className="w-full max-w-md space-y-4">
					<ErrorAlert message="Unable to load your session." details={error.message} />
					<Button className="w-full" onClick={refresh}>
						Retry
					</Button>
				</div>
			</div>
		);
	}

	if (!me) {
		clearAuth();
		return <Navigate to="/login" replace />;
	}

	if (me.must_change_password) {
		return <Navigate to="/change-password" replace />;
	}

	return (
		<AuthProvider value={me}>
			<AppShell me={me}>
				<Outlet />
			</AppShell>
		</AuthProvider>
	);
}
