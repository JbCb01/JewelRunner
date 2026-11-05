import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from "react";
import { api, SESSION_EXPIRED_EVENT } from "../api/client";
import type { Me } from "../api/types";
import { clearRankingCache } from "../lib/rankingCache";

interface AuthState {
  user: Me | null;
  loading: boolean;
  sessionExpired: boolean;
  login: (email: string, password: string) => Promise<void>;
  register: (username: string, email: string, password: string) => Promise<void>;
  logout: () => Promise<void>;
  setUser: (user: Me) => void;
}

const AuthContext = createContext<AuthState | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUserState] = useState<Me | null>(null);
  const [loading, setLoading] = useState(true);
  const [sessionExpired, setSessionExpired] = useState(false);

  useEffect(() => {
    api<Me>("/me", { allowAnonymous: true })
      .then(setUserState)
      .catch(() => setUserState(null))
      .finally(() => setLoading(false));

    const onExpired = () => {
      clearRankingCache();
      setUserState(null);
      setSessionExpired(true);
    };
    window.addEventListener(SESSION_EXPIRED_EVENT, onExpired);
    return () => window.removeEventListener(SESSION_EXPIRED_EVENT, onExpired);
  }, []);

  const signIn = useCallback((me: Me) => {
    clearRankingCache();
    setSessionExpired(false);
    setUserState(me);
  }, []);

  const value = useMemo<AuthState>(
    () => ({
      user,
      loading,
      sessionExpired,
      setUser: setUserState,
      login: async (email, password) =>
        signIn(await api<Me>("/auth/login", { method: "POST", body: { email, password }, allowAnonymous: true })),
      register: async (username, email, password) =>
        signIn(
          await api<Me>("/auth/register", { method: "POST", body: { username, email, password }, allowAnonymous: true }),
        ),
      logout: async () => {
        await api<void>("/auth/logout", { method: "POST", allowAnonymous: true });
        clearRankingCache();
        setSessionExpired(false);
        setUserState(null);
      },
    }),
    [user, loading, sessionExpired, signIn],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth(): AuthState {
  const value = useContext(AuthContext);
  if (!value) throw new Error("useAuth wymaga AuthProvider");
  return value;
}
