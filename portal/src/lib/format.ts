import type { ClaimRewardResponse, Conditions, Reward, UnlockCondition } from "../api/types";

const dateFormat = new Intl.DateTimeFormat("pl-PL", { dateStyle: "medium", timeStyle: "short" });

export function formatDate(value: string): string {
  return dateFormat.format(new Date(value));
}

export function formatReward(reward: Reward): string {
  switch (reward.type) {
    case "klejnoty":
      return `${reward.gems} klejnotów`;
    case "skórka":
      return `Skórka: ${reward.element_name}`;
    case "akcesorium":
      return `Akcesorium: ${reward.element_name}`;
    case "kolor":
      return `Kolor: ${reward.element_name}`;
    case "wzmocnienie":
      return `Wzmocnienie: ${reward.booster_type}`;
  }
}

/** Zamienia warunki z bazy na tekst dla gracza. Nieznany warunek pokazuje bez zmian, żeby go nie ukryć. */
export function formatConditions(conditions: Conditions): string[] {
  return Object.entries(conditions).map(([key, value]) => {
    switch (key) {
      case "ukoncz_poziom":
        return "Ukończ poziom";
      case "min_klejnotow":
        return `Zbierz co najmniej ${value} klejnotów`;
      case "min_wynik":
        return `Zdobądź co najmniej ${value} punktów`;
      case "max_czas_s":
        return `Ukończ poziom w maksymalnie ${value} s`;
      case "poziom_odblokowany":
        return `Odblokuj poziom ${value}`;
      default:
        return `${key}: ${String(value)}`;
    }
  });
}

export function formatRemaining(endsAt: string, now: Date = new Date()): string {
  const minutes = Math.floor((new Date(endsAt).getTime() - now.getTime()) / 60000);
  if (minutes <= 0) return "Czas minął";
  const days = Math.floor(minutes / 1440);
  if (days > 0) return `Pozostało: ${days} d`;
  const hours = Math.floor(minutes / 60);
  if (hours > 0) return `Pozostało: ${hours} godz.`;
  return `Pozostało: ${minutes} min`;
}

export function formatDuration(totalSeconds: number): string {
  const hours = Math.floor(totalSeconds / 3600);
  const minutes = Math.floor((totalSeconds % 3600) / 60);
  return `${hours} godz. ${minutes} min`;
}

export function validatePassword(password: string): string | null {
  const strong = password.length >= 8 && /\p{L}/u.test(password) && /\p{N}/u.test(password);
  return strong ? null : "Hasło musi mieć co najmniej 8 znaków, literę i cyfrę.";
}

export const PAIRING_CODE_TTL_SECONDS = 300;

export function secondsLeft(expiresAt: string, nowMs: number = Date.now()): number {
  return Math.max(0, Math.round((new Date(expiresAt).getTime() - nowMs) / 1000));
}

export function formatCountdown(seconds: number): string {
  const clamped = Math.max(0, Math.floor(seconds));
  return `${Math.floor(clamped / 60)}:${String(clamped % 60).padStart(2, "0")}`;
}

export function formatRunTime(seconds: number): string {
  if (seconds < 60) return `${seconds.toFixed(1)} s`;
  const mins = Math.floor(seconds / 60);
  const rem = (seconds % 60).toFixed(1).padStart(4, "0");
  return `${mins}:${rem}`;
}

export function formatUnlockCondition(condition: UnlockCondition | null): string {
  if (!condition) return "Do zdobycia jako nagroda w wyzwaniu";
  switch (condition.type) {
    case "wynik w poziomie":
      return `Zdobądź co najmniej ${condition.value} pkt w poziomie`;
    case "liczba klejnotów":
      return `Zbierz łącznie ${condition.value} klejnotów`;
    case "wyzwanie":
      return condition.challenge_name
        ? `Ukończ wyzwanie: ${condition.challenge_name}`
        : `Ukończ wyzwanie #${condition.value}`;
  }
}

export function formatBoosterName(type: string): string {
  if (!type) return type;
  return type.charAt(0).toUpperCase() + type.slice(1);
}

export function formatClaimResult(result: ClaimRewardResponse): string {
  if (result.converted_to_gems) {
    return `Masz już ten element — otrzymano równowartość ${result.gems_awarded} klejnotów. Nowe saldo: ${result.balance} klejnotów.`;
  }
  if (result.reward.type === "klejnoty") {
    return `Odebrano ${result.gems_awarded} klejnotów. Nowe saldo: ${result.balance} klejnotów.`;
  }
  return `Odebrano nagrodę: ${formatReward(result.reward)}.`;
}
