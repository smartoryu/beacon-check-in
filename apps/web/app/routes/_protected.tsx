import { Outlet, redirect, useLoaderData } from "react-router";
import { AppShell } from "#/components/app-shell";
import { api } from "#/lib/api";
import { clearAuth, getAccessToken } from "#/lib/auth";

export async function clientLoader() {
	if (!getAccessToken()) {
		throw redirect("/login");
	}
	try {
		const me = await api.me();
		if (me.must_change_password) {
			throw redirect("/change-password");
		}
		return { me };
	} catch (error) {
		if (error instanceof Response) throw error;
		clearAuth();
		throw redirect("/login");
	}
}

export default function ProtectedLayout() {
	const { me } = useLoaderData<typeof clientLoader>();
	return (
		<AppShell me={me}>
			<Outlet />
		</AppShell>
	);
}
