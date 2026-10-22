import { describe, expect, it } from "vitest";
import { render, screen } from "@testing-library/react";
import { createRoutesStub } from "react-router";
import { AppShell } from "#/components/app-shell";
import type { User } from "#/lib/types";

function makeUser(role: User["role"]): User {
	return {
		id: "u1",
		display_name: "Test User",
		email: "test@example.com",
		role,
		must_change_password: false,
	};
}

describe("AppShell role navigation", () => {
	it("shows super admin navigation only for super admins", () => {
		const admin = makeUser("admin");
		const RouteStub = createRoutesStub([
			{
				path: "/",
				Component: () => (
					<AppShell me={admin}>
						<div>content</div>
					</AppShell>
				),
			},
		]);
		render(<RouteStub initialEntries={["/"]} />);
		expect(screen.getAllByText("Dashboard").length).toBeGreaterThan(0);
		expect(screen.queryByText("Approvals")).not.toBeInTheDocument();
		expect(screen.queryByText("Admins")).not.toBeInTheDocument();
	});

	it("shows approvals and admins for super admins", () => {
		const superAdmin = makeUser("super_admin");
		const RouteStub = createRoutesStub([
			{
				path: "/",
				Component: () => (
					<AppShell me={superAdmin}>
						<div>content</div>
					</AppShell>
				),
			},
		]);
		render(<RouteStub initialEntries={["/"]} />);
		expect(screen.getAllByText("Approvals").length).toBeGreaterThan(0);
		expect(screen.getAllByText("Admins").length).toBeGreaterThan(0);
	});
});
