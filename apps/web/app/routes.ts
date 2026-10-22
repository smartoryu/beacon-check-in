import {
	index,
	layout,
	type RouteConfig,
	route,
} from "@react-router/dev/routes";

export default [
	index("routes/home/page.tsx"),
	route("login", "routes/login/page.tsx"),
	route("change-password", "routes/change-password/page.tsx"),
	layout("routes/_protected.tsx", [
		route("dashboard", "routes/dashboard/page.tsx"),
		route("admins", "routes/admins/page.tsx"),
		route("approvals", "routes/approvals/page.tsx"),
		route("events", "routes/events/page.tsx"),
		route("events/new", "routes/events/form/page.tsx", { id: "event-new" }),
		route("events/:id", "routes/events/detail/page.tsx"),
		route("events/:id/edit", "routes/events/form/page.tsx", { id: "event-edit" }),
		route("beacons", "routes/beacons/page.tsx"),
	]),
] satisfies RouteConfig;
