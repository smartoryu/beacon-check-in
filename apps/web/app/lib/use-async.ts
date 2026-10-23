import { useCallback, useEffect, useRef, useState } from "react";

export interface AsyncState<T> {
	data: T | null;
	loading: boolean;
	error: Error | null;
	refresh: () => void;
}

/**
 * Small client-side data hook for route components.
 *
 * Route navigation is never blocked: the page renders immediately with a
 * skeleton, then the request runs in the background.
 */
export function useAsync<T>(
	fetcher: () => Promise<T>,
	deps: unknown[] = [],
): AsyncState<T> {
	const [data, setData] = useState<T | null>(null);
	const [loading, setLoading] = useState(true);
	const [error, setError] = useState<Error | null>(null);
	const [tick, setTick] = useState(0);
	const fetcherRef = useRef(fetcher);
	fetcherRef.current = fetcher;

	useEffect(() => {
		let cancelled = false;
		setLoading(true);
		setError(null);

		fetcherRef
			.current()
			.then((value) => {
				if (cancelled) return;
				setData(value);
				setLoading(false);
			})
			.catch((cause: unknown) => {
				if (cancelled) return;
				setError(cause instanceof Error ? cause : new Error(String(cause)));
				setLoading(false);
			});

		return () => {
			cancelled = true;
		};
		// eslint-disable-next-line react-hooks/exhaustive-deps
	}, [...deps, tick]);

	const refresh = useCallback(() => setTick((value) => value + 1), []);

	return { data, loading, error, refresh };
}
