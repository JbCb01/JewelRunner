import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from "react";
import { api, SESSION_EXPIRED_EVENT } from "../api/client";
import type { DailyReward, DailyRewardClaim, Me, Wallet } from "../api/types";
import { clearRankingCache } from "../lib/rankingCache";

const DAILY_DISMISS_PREFIX = "jr_daily_dismissed:";

function dismissKey(userId: string, today: string): string {
  return `${DAILY_DISMISS_PREFIX}${userId}:${today}`;
}

function isDismissed(userId: string, today: string): boolean {
  try {
    return sessionStorage.getItem(dismissKey(userId, today)) === "1";
  } catch {
    return false;
  }
}

function markDismissed(userId: string, today: string): void {
  try {
    sessionStorage.setItem(dismissKey(userId, today), "1");
  } catch {
    // Brak sessionStorage nie blokuje zamknięcia okna.
  }
}

function clearDismissed(): void {
  try {
    const keys: string[] = [];
    for (let i = 0; i < sessionStorage.length; i += 1) {
      const key = sessionStorage.key(i);
      if (key?.startsWith(DAILY_DISMISS_PREFIX)) keys.push(key);
    }
    keys.forEach((key) => sessionStorage.removeItem(key));
  } catch {
    // Ignorujemy brak dostępu do sessionStorage.
  }
}

interface AuthState {
  user: Me | null;
  loading: boolean;
  sessionExpired: boolean;
  gems: number | null;
  dailyReward: DailyReward | null;
  dailyRewardOpen: boolean;
  login: (email: string, password: string) => Promise<void>;
  register: (username: string, email: string, password: string) => Promise<void>;
  logout: () => Promise<void>;
  setUser: (user: Me) => void;
  setGems: (gems: number) => void;
  refreshWallet: () => Promise<void>;
  refreshMe: () => Promise<void>;
  openDailyReward: () => void;
  closeDailyReward: () => void;
  claimDailyReward: () => Promise<DailyRewardClaim>;
}

const AuthContext = createContext<AuthState | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUserState] = useState<Me | null>(null);
  const [loading, setLoading] = useState(true);
  const [sessionExpired, setSessionExpired] = useState(false);
  const [gems, setGems] = useState<number | null>(null);
  const [dailyReward, setDailyReward] = useState<DailyReward | null>(null);
  const [dailyRewardOpen, setDailyRewardOpen] = useState(false);

  const resetUserExtras = useCallback(() => {
    setGems(null);
    setDailyReward(null);
    setDailyRewardOpen(false);
    clearDismissed();
  }, []);

  const refreshWallet = useCallback(async () => {
    try {
      const wallet = await api<Wallet>("/me/wallet");
      setGems(wallet.gems);
    } catch {
      // Nie przerywamy pracy portalu przy chwilowym błędzie portfela.
    }
  }, []);

  const refreshMe = useCallback(async () => {
    const me = await api<Me>("/me");
    setUserState(me);
  }, []);

  useEffect(() => {
    api<Me>("/me", { allowAnonymous: true })
      .then(setUserState)
      .catch(() => setUserState(null))
      .finally(() => setLoading(false));

    const onExpired = () => {
      clearRankingCache();
      resetUserExtras();
      setUserState(null);
      setSessionExpired(true);
    };
    window.addEventListener(SESSION_EXPIRED_EVENT, onExpired);
    return () => window.removeEventListener(SESSION_EXPIRED_EVENT, onExpired);
  }, [resetUserExtras]);

  useEffect(() => {
    if (!user) return;
    let active = true;
    api<Wallet>("/me/wallet")
      .then((wallet) => {
        if (active) setGems(wallet.gems);
      })
      .catch(() => undefined);

    api<DailyReward>("/me/daily-reward")
      .then((reward) => {
        if (!active) return;
        setDailyReward(reward);
        if (reward.available && !isDismissed(user.id, reward.today)) {
          setDailyRewardOpen(true);
        }
      })
      .catch(() => undefined);

    return () => {
      active = false;
    };
  }, [user?.id]);

  const signIn = useCallback(
    (me: Me) => {
      clearRankingCache();
      resetUserExtras();
      setSessionExpired(false);
      setUserState(me);
    },
    [resetUserExtras],
  );

  const closeDailyReward = useCallback(() => {
    if (user && dailyReward) {
      markDismissed(user.id, dailyReward.today);
    }
    setDailyRewardOpen(false);
  }, [user, dailyReward]);

  const openDailyReward = useCallback(() => {
    setDailyRewardOpen(true);
  }, []);

  const claimDailyReward = useCallback(async (): Promise<DailyRewardClaim> => {
    const claimed = await api<DailyRewardClaim>("/me/daily-reward/claim", { method: "POST" });
    setDailyReward(claimed);
    setGems(claimed.balance);
    return claimed;
  }, []);

  const value = useMemo<AuthState>(
    () => ({
      user,
      loading,
      sessionExpired,
      gems,
      dailyReward,
      dailyRewardOpen,
      setUser: setUserState,
      setGems,
      refreshWallet,
      refreshMe,
      openDailyReward,
      closeDailyReward,
      claimDailyReward,
      login: async (email, password) =>
        signIn(await api<Me>("/auth/login", { method: "POST", body: { email, password }, allowAnonymous: true })),
      register: async (username, email, password) =>
        signIn(
          await api<Me>("/auth/register", { method: "POST", body: { username, email, password }, allowAnonymous: true }),
        ),
      logout: async () => {
        await api<void>("/auth/logout", { method: "POST", allowAnonymous: true });
        clearRankingCache();
        resetUserExtras();
        setSessionExpired(false);
        setUserState(null);
      },
    }),
    [
      user,
      loading,
      sessionExpired,
      gems,
      dailyReward,
      dailyRewardOpen,
      refreshWallet,
      refreshMe,
      openDailyReward,
      closeDailyReward,
      claimDailyReward,
      signIn,
      resetUserExtras,
    ],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth(): AuthState {
  const value = useContext(AuthContext);
  if (!value) throw new Error("useAuth wymaga AuthProvider");
  return value;
}
