import type { Ranking } from "../api/types";

const KEY = "jr_ranking";

export function saveRanking(ranking: Ranking): void {
  try {
    localStorage.setItem(KEY, JSON.stringify(ranking));
  } catch {
    // Brak zapisu nie blokuje wyświetlenia rankingu.
  }
}

export function loadRanking(): Ranking | null {
  try {
    const value = localStorage.getItem(KEY);
    return value ? (JSON.parse(value) as Ranking) : null;
  } catch {
    return null;
  }
}

export function clearRankingCache(): void {
  try {
    localStorage.removeItem(KEY);
  } catch {
    // Pamięć przeglądarki może być niedostępna.
  }
}
