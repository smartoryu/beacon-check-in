import { redirect } from "react-router";
import { getAccessToken } from "#/lib/auth";

export function clientLoader() {
	throw redirect(getAccessToken() ? "/dashboard" : "/login");
}

export default function HomePage() {
	return null;
}
