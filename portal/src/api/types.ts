export interface Me {
  id: string;
  username: string;
  email: string;
  game_linked?: boolean;
  last_synced_at?: string | null;
}

export interface PairingCode {
  code: string;
  expires_at: string;
}

export interface Wallet {
  gems: number;
}

export interface DailyRewardDay {
  day: number;
  gems: number;
  special: boolean;
}

export interface DailyReward {
  today: string;
  available: boolean;
  streak_day: number;
  gems: number;
  special: boolean;
  last_claimed: string | null;
  rewards: DailyRewardDay[];
}

export interface DailyRewardClaim extends DailyReward {
  balance: number;
}

export interface Reward {
  type: "klejnoty" | "skórka" | "akcesorium" | "kolor" | "wzmocnienie";
  gems: number | null;
  element_name: string | null;
  booster_type: string | null;
}

export type Conditions = Record<string, unknown>;
export type ParticipationStatus = "Aktywne" | "Ukończone" | "Wygasłe";
export type RewardStatus = "Do odebrania" | "Odebrana" | null;

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
  reward_status?: RewardStatus;
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
  reward_status?: RewardStatus;
  reward?: Reward;
}

export interface ClaimRewardResponse {
  challenge_id: number;
  reward_status: "Odebrana";
  reward: Reward;
  gems_awarded: number;
  converted_to_gems: boolean;
  balance: number;
}

export interface Attempts {
  best_score: number | null;
  items: { score: number; attempted_at: string; passed: boolean }[];
}

export type RankingPeriod = "tydzień" | "miesiąc" | "ogółem" | "znajomi";
export type RankingEmptyReason = "no_results" | "no_friends" | null;

export interface RankingEntry {
  position: number;
  player_id: string;
  username: string;
  score: number;
}

export interface Ranking {
  period?: RankingPeriod;
  period_start?: string | null;
  items: RankingEntry[];
  me: { position: number; score: number } | null;
  empty_reason?: RankingEmptyReason;
  generated_at: string;
}

export interface Friend {
  player_id: string;
  username: string;
  added_at: string;
  score: number | null;
}

export interface PlayerSearchResult {
  player_id: string;
  username: string;
  is_friend: boolean;
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

export interface LevelStat {
  level: number;
  name: string;
  unlocked: boolean;
  unlock_condition: Conditions | null;
  best_score: number | null;
  best_time_s: number | null;
  attempts: number;
  completed: boolean;
}

export interface PlayerStats {
  has_played: boolean;
  last_synced_at: string | null;
  overall: {
    play_time_s: number;
    levels_completed: number;
    enemies_defeated: number;
    defeats: number;
    runs: number;
    gems_collected: number;
    gems_balance: number;
    tutorial_completed: boolean;
  };
  levels: LevelStat[];
}

export interface GameRun {
  id: number;
  level: number;
  level_name: string;
  completed: boolean;
  score: number;
  time_s: number;
  gems: number;
  enemies_defeated: number;
  played_at: string;
  session_id: string;
}

export interface GameRunPage {
  items: GameRun[];
  next_before_id: number | null;
}

export type AppearanceType = "skórka" | "kolor" | "akcesorium";

export interface UnlockCondition {
  type: "wynik w poziomie" | "liczba klejnotów" | "wyzwanie";
  value: number;
  challenge_name: string | null;
}

export interface AppearanceCatalogItem {
  id: number;
  type: AppearanceType;
  name: string;
  asset: string | null;
  color_hex: string | null;
  slot: string | null;
  owned: boolean;
  is_new: boolean;
  unlock_condition: UnlockCondition | null;
}

export interface EquippedAccessory {
  slot: string;
  accessory: { id: number; name: string };
  color: { id: number; name: string; hex: string } | null;
}

export interface AppearanceCurrent {
  skin: { id: number; name: string; asset: string | null };
  color: { id: number; name: string; hex: string };
  accessories: EquippedAccessory[];
  updated_at: string;
}

export interface AppearanceState {
  current: AppearanceCurrent | null;
  catalog: AppearanceCatalogItem[];
  new_count: number;
  newly_unlocked: { id: number; type: AppearanceType; name: string }[];
}

export interface ShopItem {
  booster_id: number;
  type: string;
  effect: string;
  duration_s: number | null;
  price: number;
  owned: number;
}

export interface ShopState {
  balance: number;
  items: ShopItem[];
}

export interface ShopPurchaseResponse {
  booster_id: number;
  type: string;
  price: number;
  balance: number;
  owned: number;
  duplicate: boolean;
}

export interface UserSession {
  id: string;
  device: "gra" | "przeglądarka";
  created_at: string;
  expires_at: string;
  is_current: boolean;
}

export interface ItemList<T> {
  items: T[];
}
