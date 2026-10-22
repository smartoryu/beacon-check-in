import { useRef, useState } from "react";
import type { EventBeacon } from "#/lib/types";
import { cn } from "./ui";

interface Props {
	widthM: number;
	heightM: number;
	beacons: EventBeacon[];
	onMove?: (beaconId: string, x: number, y: number) => void;
	className?: string;
}

function clamp(value: number, min: number, max: number): number {
	return Math.min(max, Math.max(min, value));
}

function snap(value: number): number {
	return Math.round(value * 2) / 2;
}

export function BeaconPlacementGrid({
	widthM,
	heightM,
	beacons,
	onMove,
	className,
}: Props) {
	const containerRef = useRef<HTMLDivElement>(null);
	const [dragging, setDragging] = useState<string | null>(null);

	function coordinatesFromEvent(clientX: number, clientY: number) {
		const rect = containerRef.current?.getBoundingClientRect();
		if (!rect) return null;
		const rawX = ((clientX - rect.left) / rect.width) * widthM;
		const rawY = ((clientY - rect.top) / rect.height) * heightM;
		return {
			x: snap(clamp(rawX, 0, widthM)),
			y: snap(clamp(rawY, 0, heightM)),
		};
	}

	function moveTo(beaconId: string, clientX: number, clientY: number) {
		const coords = coordinatesFromEvent(clientX, clientY);
		if (coords) onMove?.(beaconId, coords.x, coords.y);
	}

	const gridBackground = {
		backgroundImage:
			"linear-gradient(to right, rgba(148,163,184,0.18) 1px, transparent 1px), linear-gradient(to bottom, rgba(148,163,184,0.18) 1px, transparent 1px), linear-gradient(to right, rgba(100,116,139,0.35) 1px, transparent 1px), linear-gradient(to bottom, rgba(100,116,139,0.35) 1px, transparent 1px)",
		backgroundSize: `${100 / widthM}% ${100 / heightM}%, ${100 / widthM}% ${100 / heightM}%, ${500 / widthM}% ${500 / heightM}%, ${500 / widthM}% ${500 / heightM}%`,
	};

	return (
		<div className={cn("select-none", className)}>
			<div className="mb-2 flex justify-between text-gray-400 text-xs">
				<span>0 m</span>
				<span>{widthM / 2} m</span>
				<span>{widthM} m</span>
			</div>
			<div
				ref={containerRef}
				className="relative w-full overflow-hidden rounded-xl border border-gray-300 bg-gray-50 dark:border-gray-700 dark:bg-gray-950"
				style={{ ...gridBackground, aspectRatio: `${widthM} / ${heightM}` }}
				onPointerMove={(event) => {
					if (!dragging) return;
					moveTo(dragging, event.clientX, event.clientY);
				}}
				onPointerUp={() => setDragging(null)}
				onPointerLeave={() => setDragging(null)}
			>
				{beacons.map((beacon) => {
					const left = `${(beacon.x / widthM) * 100}%`;
					const top = `${(beacon.y / heightM) * 100}%`;
					return (
						<div
							key={beacon.beacon_id}
							className="absolute -translate-x-1/2 -translate-y-1/2"
							style={{ left, top }}
						>
							<button
								type="button"
								tabIndex={0}
								onPointerDown={(event) => {
									event.preventDefault();
									setDragging(beacon.beacon_id);
								}}
								onKeyDown={(event) => {
									if (!onMove) return;
									const step = event.shiftKey ? 2 : 0.5;
									let dx = 0;
									let dy = 0;
									if (event.key === "ArrowLeft") dx = -step;
									if (event.key === "ArrowRight") dx = step;
									if (event.key === "ArrowUp") dy = -step;
									if (event.key === "ArrowDown") dy = step;
									if (dx || dy) {
										event.preventDefault();
										onMove(
											beacon.beacon_id,
											clamp(beacon.x + dx, 0, widthM),
											clamp(beacon.y + dy, 0, heightM),
										);
									}
								}}
								className={cn(
									"group flex cursor-grab flex-col items-center focus:outline-none",
									dragging === beacon.beacon_id && "cursor-grabbing",
								)}
							>
								<span className="flex h-7 w-7 items-center justify-center rounded-full bg-blue-600 font-bold text-white text-xs shadow-lg ring-2 ring-white dark:ring-gray-900">
									B
								</span>
								<span className="mt-1 max-w-28 truncate rounded bg-white/90 px-1.5 py-0.5 font-medium text-[10px] text-gray-700 shadow-sm dark:bg-gray-900/90 dark:text-gray-200">
									{beacon.label}
								</span>
								<span className="text-[9px] text-gray-500">
									{beacon.x.toFixed(1)}, {beacon.y.toFixed(1)} m
								</span>
							</button>
						</div>
					);
				})}
			</div>
			<div className="mt-2 flex justify-between text-gray-400 text-xs">
				<span>0 m</span>
				<span>{heightM} m</span>
			</div>
		</div>
	);
}
