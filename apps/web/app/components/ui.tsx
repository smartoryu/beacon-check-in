import { X } from "lucide-react";
import * as React from "react";
import { Link } from "react-router";

export function cn(...classes: Array<string | false | null | undefined>): string {
	return classes.filter(Boolean).join(" ");
}

const buttonBase =
	"inline-flex items-center justify-center gap-2 rounded-lg text-sm font-semibold transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-blue-500 focus-visible:ring-offset-2 disabled:pointer-events-none disabled:opacity-50 dark:focus-visible:ring-offset-gray-900";

const buttonVariants = {
	primary: "bg-blue-600 text-white hover:bg-blue-700",
	secondary:
		"border border-gray-300 bg-white text-gray-800 hover:bg-gray-50 dark:border-gray-700 dark:bg-gray-800 dark:text-gray-100 dark:hover:bg-gray-700",
	danger: "bg-red-600 text-white hover:bg-red-700",
	ghost:
		"text-gray-700 hover:bg-gray-100 dark:text-gray-200 dark:hover:bg-gray-800",
};

const buttonSizes = {
	sm: "h-8 px-3 text-xs",
	md: "h-10 px-4",
	lg: "h-11 px-5",
};

export interface ButtonProps
	extends React.ButtonHTMLAttributes<HTMLButtonElement> {
	variant?: keyof typeof buttonVariants;
	size?: keyof typeof buttonSizes;
}

export const Button = React.forwardRef<HTMLButtonElement, ButtonProps>(
	({ className, variant = "primary", size = "md", type = "button", ...props }, ref) => (
		<button
			ref={ref}
			type={type}
			className={cn(buttonBase, buttonVariants[variant], buttonSizes[size], className)}
			{...props}
		/>
	),
);
Button.displayName = "Button";

export function ButtonLink({
	to,
	children,
	variant = "primary",
	size = "md",
}: {
	to: string;
	children: React.ReactNode;
	variant?: keyof typeof buttonVariants;
	size?: keyof typeof buttonSizes;
}) {
	return (
		<Link
			to={to}
			className={cn(buttonBase, buttonVariants[variant], buttonSizes[size])}
		>
			{children}
		</Link>
	);
}

export const Input = React.forwardRef<
	HTMLInputElement,
	React.InputHTMLAttributes<HTMLInputElement>
>(({ className, ...props }, ref) => (
	<input
		ref={ref}
		className={cn(
			"flex h-10 w-full rounded-lg border border-gray-300 bg-white px-3 py-2 text-sm text-gray-900 placeholder:text-gray-400 focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500 disabled:cursor-not-allowed disabled:opacity-60 dark:border-gray-700 dark:bg-gray-900 dark:text-gray-100",
			className,
		)}
		{...props}
	/>
));
Input.displayName = "Input";

export const Textarea = React.forwardRef<
	HTMLTextAreaElement,
	React.TextareaHTMLAttributes<HTMLTextAreaElement>
>(({ className, ...props }, ref) => (
	<textarea
		ref={ref}
		className={cn(
			"flex min-h-24 w-full rounded-lg border border-gray-300 bg-white px-3 py-2 text-sm text-gray-900 placeholder:text-gray-400 focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500 dark:border-gray-700 dark:bg-gray-900 dark:text-gray-100",
			className,
		)}
		{...props}
	/>
));
Textarea.displayName = "Textarea";

export const Select = React.forwardRef<
	HTMLSelectElement,
	React.SelectHTMLAttributes<HTMLSelectElement>
>(({ className, ...props }, ref) => (
	<select
		ref={ref}
		className={cn(
			"flex h-10 w-full rounded-lg border border-gray-300 bg-white px-3 py-2 text-sm text-gray-900 focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500 dark:border-gray-700 dark:bg-gray-900 dark:text-gray-100",
			className,
		)}
		{...props}
	/>
));
Select.displayName = "Select";

export function Label({
	className,
	...props
}: React.LabelHTMLAttributes<HTMLLabelElement>) {
	return (
		<label
			className={cn(
				"mb-1 block font-medium text-gray-700 text-sm dark:text-gray-300",
				className,
			)}
			{...props}
		/>
	);
}

export function Field({
	label,
	children,
	hint,
}: {
	label: string;
	children: React.ReactNode;
	hint?: string;
}) {
	return (
		<div>
			<Label>{label}</Label>
			{children}
			{hint ? (
				<p className="mt-1 text-gray-500 text-xs dark:text-gray-400">{hint}</p>
			) : null}
		</div>
	);
}

export function Card({
	className,
	...props
}: React.HTMLAttributes<HTMLDivElement>) {
	return (
		<div
			className={cn(
				"rounded-xl border border-gray-200 bg-white shadow-sm dark:border-gray-800 dark:bg-gray-900",
				className,
			)}
			{...props}
		/>
	);
}

export function CardHeader({
	className,
	...props
}: React.HTMLAttributes<HTMLDivElement>) {
	return <div className={cn("border-gray-100 border-b px-5 py-4 dark:border-gray-800", className)} {...props} />;
}

export function CardContent({
	className,
	...props
}: React.HTMLAttributes<HTMLDivElement>) {
	return <div className={cn("px-5 py-4", className)} {...props} />;
}

const badgeVariants = {
	gray: "bg-gray-100 text-gray-700 dark:bg-gray-800 dark:text-gray-300",
	green: "bg-green-100 text-green-800 dark:bg-green-950 dark:text-green-300",
	red: "bg-red-100 text-red-800 dark:bg-red-950 dark:text-red-300",
	amber: "bg-amber-100 text-amber-800 dark:bg-amber-950 dark:text-amber-300",
	blue: "bg-blue-100 text-blue-800 dark:bg-blue-950 dark:text-blue-300",
	purple: "bg-purple-100 text-purple-800 dark:bg-purple-950 dark:text-purple-300",
};

export function Badge({
	children,
	variant = "gray",
	className,
}: {
	children: React.ReactNode;
	variant?: keyof typeof badgeVariants;
	className?: string;
}) {
	return (
		<span
			className={cn(
				"inline-flex items-center rounded-full px-2.5 py-0.5 font-medium text-xs",
				badgeVariants[variant],
				className,
			)}
		>
			{children}
		</span>
	);
}

export function PageHeader({
	title,
	description,
	actions,
}: {
	title: string;
	description?: string;
	actions?: React.ReactNode;
}) {
	return (
		<div className="flex flex-wrap items-start justify-between gap-4">
			<div>
				<h1 className="font-bold text-2xl text-gray-900 dark:text-white">{title}</h1>
				{description ? (
					<p className="mt-1 text-gray-500 text-sm dark:text-gray-400">{description}</p>
				) : null}
			</div>
			{actions ? <div className="flex items-center gap-2">{actions}</div> : null}
		</div>
	);
}

export function StatCard({
	label,
	value,
	hint,
}: {
	label: string;
	value: React.ReactNode;
	hint?: string;
}) {
	return (
		<Card>
			<CardContent>
				<div className="text-gray-500 text-sm dark:text-gray-400">{label}</div>
				<div className="mt-1 font-bold text-2xl text-gray-900 dark:text-white">{value}</div>
				{hint ? <div className="mt-1 text-gray-500 text-xs">{hint}</div> : null}
			</CardContent>
		</Card>
	);
}

export function Spinner({ label = "Loading…" }: { label?: string }) {
	return (
		<div className="flex items-center gap-2 text-gray-500 text-sm dark:text-gray-400">
			<span className="h-4 w-4 animate-spin rounded-full border-2 border-gray-300 border-t-blue-600" />
			{label}
		</div>
	);
}

export function ErrorAlert({
	message,
	details,
}: {
	message: string;
	details?: unknown;
}) {
	return (
		<div className="rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-red-800 text-sm dark:border-red-900 dark:bg-red-950 dark:text-red-200">
			<div className="font-medium">{message}</div>
			{details ? (
				<pre className="mt-2 max-h-40 overflow-auto whitespace-pre-wrap text-xs opacity-80">
					{typeof details === "string" ? details : JSON.stringify(details, null, 2)}
				</pre>
			) : null}
		</div>
	);
}

export function EmptyState({
	title,
	description,
	action,
}: {
	title: string;
	description?: string;
	action?: React.ReactNode;
}) {
	return (
		<div className="rounded-xl border border-gray-200 border-dashed px-6 py-12 text-center dark:border-gray-800">
			<h3 className="font-semibold text-gray-900 dark:text-white">{title}</h3>
			{description ? (
				<p className="mx-auto mt-1 max-w-md text-gray-500 text-sm dark:text-gray-400">
					{description}
				</p>
			) : null}
			{action ? <div className="mt-4 flex justify-center">{action}</div> : null}
		</div>
	);
}

export function Modal({
	open,
	onClose,
	title,
	children,
	footer,
}: {
	open: boolean;
	onClose: () => void;
	title: string;
	children: React.ReactNode;
	footer?: React.ReactNode;
}) {
	React.useEffect(() => {
		if (!open) return;
		const handler = (event: KeyboardEvent) => {
			if (event.key === "Escape") onClose();
		};
		window.addEventListener("keydown", handler);
		return () => window.removeEventListener("keydown", handler);
	}, [open, onClose]);

	if (!open) return null;
	return (
		<div className="fixed inset-0 z-50 flex items-center justify-center p-4">
			<button
				type="button"
				aria-label="Close dialog"
				className="absolute inset-0 bg-black/40"
				onClick={onClose}
			/>
			<div className="relative z-10 max-h-[90vh] w-full max-w-lg overflow-auto rounded-xl bg-white shadow-xl dark:bg-gray-900">
				<div className="flex items-center justify-between border-gray-200 border-b px-5 py-4 dark:border-gray-800">
					<h2 className="font-semibold text-gray-900 text-lg dark:text-white">{title}</h2>
					<button
						type="button"
						onClick={onClose}
						className="rounded-md p-1 text-gray-500 hover:bg-gray-100 dark:hover:bg-gray-800"
					>
						<X className="h-5 w-5" />
					</button>
				</div>
				<div className="px-5 py-4">{children}</div>
				{footer ? (
					<div className="flex justify-end gap-2 border-gray-200 border-t px-5 py-3 dark:border-gray-800">
						{footer}
					</div>
				) : null}
			</div>
		</div>
	);
}
