import { Navigate } from "react-router";
import { getAccessToken } from "#/lib/auth";

export default function HomePage() {
	return <Navigate to={getAccessToken() ? "/dashboard" : "/login"} replace />;
}
