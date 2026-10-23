import type { ReactNode } from "react";
import {
	CalendarDays,
	CheckSquare,
	LayoutDashboard,
	LogOut,
	Radio,
	ShieldCheck,
} from "lucide-react";
import { Link, NavLink, useNavigate } from "react-router";
import { ThemeToggle } from "#/components/theme-toggle";
import { clearAuth } from "#/lib/auth";
import type { User } from "#/lib/types";
import { Badge, Button, Skeleton, cn } from "./ui";

const navItems = [
	{ to: "/dashboard", label: "Dashboard", icon: LayoutDashboard },
	{ to: "/events", label: "Events", icon: CalendarDays },
	{ to: "/beacons", label: "Beacons", icon: Radio },
];

const superAdminItems = [
	{ to: "/approvals", label: "Approvals", icon: CheckSquare },
	{ to: "/admins", label: "Admins", icon: ShieldCheck },
];

function roleLabel(role: User["role"]): string {
	if (role === "super_admin") return "Super admin";
	if (role === "admin") return "Admin";
	return "User";
}

export function AppShell({
	me,
	children,
}: {
	me: User;
	children: ReactNode;
}) {
	const navigate = useNavigate();

	function logout() {
		clearAuth();
		navigate("/login", { replace: true });
	}

	const isSuper = me.role === "super_admin";

	return (
		<div className="min-h-screen bg-gray-50 dark:bg-gray-950">
			<aside className="fixed inset-y-0 left-0 hidden w-64 border-gray-200 border-r bg-white lg:block dark:border-gray-800 dark:bg-gray-900">
				<div className="flex h-full flex-col">
					<Link to="/dashboard" className="flex items-center gap-2 px-5 py-5">
						<span className="flex h-9 w-9 items-center justify-center rounded-lg bg-blue-600 text-white">
							<Radio className="h-5 w-5" />
						</span>
						<div>
							<div className="font-bold text-gray-900 text-sm dark:text-white">
								Beacon Check-In
							</div>
							<div className="text-gray-500 text-xs dark:text-gray-400">Admin console</div>
						</div>
					</Link>
					<nav className="flex-1 space-y-1 px-3 py-2">
						{navItems.map((item) => (
							<NavLink
								key={item.to}
								to={item.to}
								className={({ isActive }) =>
									cn(
										"flex items-center gap-3 rounded-lg px-3 py-2 font-medium text-sm",
										isActive
											? "bg-blue-50 text-blue-700 dark:bg-blue-950 dark:text-blue-300"
											: "text-gray-700 hover:bg-gray-100 dark:text-gray-300 dark:hover:bg-gray-800",
									)
								}
							>
								<item.icon className="h-4 w-4" />
								{item.label}
							</NavLink>
						))}
						{isSuper ? (
							<>
								<div className="px-3 pt-5 pb-1 font-semibold text-gray-400 text-xs uppercase tracking-wide">
									Super admin
								</div>
								{superAdminItems.map((item) => (
									<NavLink
										key={item.to}
										to={item.to}
										className={({ isActive }) =>
											cn(
												"flex items-center gap-3 rounded-lg px-3 py-2 font-medium text-sm",
												isActive
													? "bg-blue-50 text-blue-700 dark:bg-blue-950 dark:text-blue-300"
													: "text-gray-700 hover:bg-gray-100 dark:text-gray-300 dark:hover:bg-gray-800",
											)
										}
									>
										<item.icon className="h-4 w-4" />
										{item.label}
									</NavLink>
								))}
							</>
						) : null}
					</nav>
					<div className="border-gray-200 border-t p-4 dark:border-gray-800">
						<div className="mb-3">
							<div className="truncate font-medium text-gray-900 text-sm dark:text-white">
								{me.display_name}
							</div>
							<div className="truncate text-gray-500 text-xs dark:text-gray-400">{me.email}</div>
							<Badge variant={isSuper ? "purple" : "blue"} className="mt-2">
								{roleLabel(me.role)}
							</Badge>
						</div>
						<div className="flex gap-2">
							<ThemeToggle className="shrink-0" />
							<Button variant="secondary" size="sm" className="flex-1" onClick={logout}>
								<LogOut className="h-4 w-4" /> Sign out
							</Button>
						</div>
					</div>
				</div>
			</aside>

			<div className="min-w-0 lg:pl-64">
				<header className="sticky top-0 z-20 flex items-center justify-between border-gray-200 border-b bg-white/90 px-4 py-3 backdrop-blur lg:hidden dark:border-gray-800 dark:bg-gray-900/90">
					<Link to="/dashboard" className="flex items-center gap-2">
						<span className="flex h-8 w-8 items-center justify-center rounded-lg bg-blue-600 text-white">
							<Radio className="h-4 w-4" />
						</span>
						<span className="font-bold text-gray-900 text-sm dark:text-white">
							Beacon Check-In
						</span>
					</Link>
					<div className="flex items-center gap-1.5">
						<ThemeToggle />
						<span className="hidden sm:inline-flex">
							<Badge variant={isSuper ? "purple" : "blue"}>{roleLabel(me.role)}</Badge>
						</span>
						<Button variant="ghost" size="sm" onClick={logout} aria-label="Sign out">
							<LogOut className="h-4 w-4" />
						</Button>
					</div>
				</header>
				<nav
					aria-label="Main navigation"
					className="grid grid-cols-3 gap-1 border-gray-200 border-b bg-white px-2 py-2 lg:hidden dark:border-gray-800 dark:bg-gray-900"
				>
					{[...navItems, ...(isSuper ? superAdminItems : [])].map((item) => (
						<NavLink
							key={item.to}
							to={item.to}
							className={({ isActive }) =>
								cn(
									"flex min-w-0 flex-col items-center justify-center gap-1 rounded-lg px-2 py-2 font-medium text-[11px]",
									isActive
										? "bg-blue-50 text-blue-700 dark:bg-blue-950 dark:text-blue-300"
										: "text-gray-600 hover:bg-gray-100 dark:text-gray-300 dark:hover:bg-gray-800",
								)
							}
						>
							<item.icon className="h-4 w-4" />
							{item.label}
						</NavLink>
					))}
				</nav>
				<main className="mx-auto min-w-0 max-w-7xl px-3 py-5 sm:px-6 sm:py-6 lg:px-8">{children}</main>
			</div>
		</div>
	);
}

export function AppShellSkeleton() {
	return (
		<div className="min-h-screen bg-gray-50 dark:bg-gray-950">
			<aside className="fixed inset-y-0 left-0 hidden w-64 border-gray-200 border-r bg-white p-5 lg:block dark:border-gray-800 dark:bg-gray-900">
				<div className="flex items-center gap-2">
					<Skeleton className="h-9 w-9 rounded-lg" />
					<div className="space-y-2">
						<Skeleton className="h-3 w-28" />
						<Skeleton className="h-3 w-20" />
					</div>
				</div>
				<div className="mt-8 space-y-3">
					{Array.from({ length: 6 }).map((_, index) => (
						<Skeleton key={index} className="h-9 w-full" />
					))}
				</div>
			</aside>
			<div className="min-w-0 lg:pl-64">
				<div className="border-gray-200 border-b bg-white px-6 py-4 dark:border-gray-800 dark:bg-gray-900">
					<Skeleton className="h-6 w-40" />
				</div>
				<main className="mx-auto max-w-7xl space-y-6 px-4 py-6 sm:px-6 lg:px-8">
					<div className="space-y-2">
						<Skeleton className="h-8 w-56" />
						<Skeleton className="h-4 w-80" />
					</div>
					<div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
						{Array.from({ length: 4 }).map((_, index) => (
							<div
								key={index}
								className="rounded-xl border border-gray-200 bg-white p-5 dark:border-gray-800 dark:bg-gray-900"
							>
								<Skeleton className="h-4 w-24" />
								<Skeleton className="mt-3 h-8 w-16" />
							</div>
						))}
					</div>
					<div className="rounded-xl border border-gray-200 bg-white p-5 dark:border-gray-800 dark:bg-gray-900">
						<Skeleton className="h-4 w-40" />
						<div className="mt-5 space-y-4">
							{Array.from({ length: 5 }).map((_, index) => (
								<Skeleton key={index} className="h-5 w-full" />
							))}
						</div>
					</div>
				</main>
			</div>
		</div>
	);
}
