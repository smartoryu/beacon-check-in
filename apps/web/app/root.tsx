import "./styles/global.css";
import { useEffect } from "react";
import {
	isRouteErrorResponse,
	Links,
	Meta,
	Outlet,
	Scripts,
	ScrollRestoration,
} from "react-router";
import NotFound from "#/components/errors/404";
import InternalError from "#/components/errors/500";
import { initTheme } from "#/lib/theme";
import type { Route } from "./+types/root";

export const links: Route.LinksFunction = () => [
	{
		rel: "preconnect",
		href: "https://cdn.jsdelivr.net",
		crossOrigin: "anonymous",
	},
];

const themeBootstrap = `(function(){try{var t=localStorage.getItem("beacon-check-in.theme")||"system";var d=t==="dark"||(t==="system"&&matchMedia("(prefers-color-scheme: dark)").matches);var r=document.documentElement;r.classList.toggle("dark",d);r.dataset.theme=d?"dark":"light";r.style.colorScheme=d?"dark":"light";}catch(e){}})();`;

export function Layout({ children }: { children: React.ReactNode }) {
	useEffect(() => initTheme(), []);

	return (
		<html lang="en" suppressHydrationWarning>
			<head>
				<meta charSet="utf-8" />
				<meta name="viewport" content="width=device-width, initial-scale=1" />
				<Meta />
				<Links />
				<script dangerouslySetInnerHTML={{ __html: themeBootstrap }} />
			</head>
			<body suppressHydrationWarning={true}>
				{children}
				<ScrollRestoration />
				<Scripts />
			</body>
		</html>
	);
}

export default function App() {
	return <Outlet />;
}

export function ErrorBoundary({ error }: Route.ErrorBoundaryProps) {
	const isError = isRouteErrorResponse(error);

	let message = "Oops!";
	let details = "An unexpected error occurred.";
	let stack: string | undefined;

	if (isError && error.status === 404) {
		return <NotFound />;
	}

	if (isError) {
		message = "Error";
		details = error.statusText || details;
	} else if (import.meta.env.DEV && error && error instanceof Error) {
		details = error.message;
		stack = error.stack;
	}

	return <InternalError message={message} details={details} stack={stack} />;
}
