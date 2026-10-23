import { Moon, Sun } from "lucide-react";
import * as React from "react";
import { toggleTheme } from "#/lib/theme";
import { Button } from "#/components/ui";

export function ThemeToggle({ className }: { className?: string }) {
	const [dark, setDark] = React.useState(false);

	React.useEffect(() => {
		setDark(document.documentElement.classList.contains("dark"));
	}, []);

	function handleToggle() {
		const next = toggleTheme();
		setDark(next === "dark");
	}

	return (
		<Button
			variant="ghost"
			size="sm"
			className={className}
			onClick={handleToggle}
			aria-label={dark ? "Switch to light theme" : "Switch to dark theme"}
			title={dark ? "Switch to light theme" : "Switch to dark theme"}
		>
			{dark ? <Sun className="h-4 w-4" /> : <Moon className="h-4 w-4" />}
		</Button>
	);
}
