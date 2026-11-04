export interface Me {
  id: string;
  username: string;
  email: string;
}

export interface Reward {
  type: "klejnoty" | "skórka" | "akcesorium" | "kolor" | "wzmocnienie";
  gems: number | null;
  element_name: string | null;
  booster_type: string | null;
}

export type Conditions = Record<string, unknown>;
export type ParticipationStatus = "Aktywne" | "Ukończone" | "Wygasłe";

export interface ChallengeListItem {
  id: number;
  name: string;
  difficulty: string;
  reward: Reward;
  ends_at: string;
  participation_status: ParticipationStatus | null;
}

export interface ChallengeDetails {
  id: number;
  name: string;
  description: string;
  difficulty: string;
  level: string;
  completion_conditions: Conditions;
  reward: Reward;
  starts_at: string;
  ends_at: string;
  participation: { status: ParticipationStatus; progress_percent: number } | null;
}

export interface AcceptedChallenge {
  status: ParticipationStatus;
  accepted_at: string;
  completion_conditions: Conditions;
}

export interface MyChallenge {
  challenge_id: number;
  name: string;
  status: ParticipationStatus;
  progress_percent: number;
  ends_at: string;
  best_score: number | null;
}

export interface Attempts {
  best_score: number | null;
  items: { score: number; attempted_at: string; passed: boolean }[];
}

export interface RankingEntry {
  position: number;
  player_id: string;
  username: string;
  score: number;
}

export interface Ranking {
  items: RankingEntry[];
  me: { position: number; score: number } | null;
  generated_at: string;
}

export interface Player {
  id: string;
  username: string;
  statistics: {
    play_time_seconds: number;
    levels_completed: number;
    enemies_defeated: number;
    defeats: number;
    longest_combo: number;
  };
}

export interface ItemList<T> {
  items: T[];
}
