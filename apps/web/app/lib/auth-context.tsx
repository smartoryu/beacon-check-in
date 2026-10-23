import { createContext, useContext } from "react";
import type { User } from "./types";

const AuthContext = createContext<User | null>(null);

export const AuthProvider = AuthContext.Provider;

export function useAuthUser(): User {
	const user = useContext(AuthContext);
	if (!user) {
		throw new Error("useAuthUser must be used inside the protected layout");
	}
	return user;
}
