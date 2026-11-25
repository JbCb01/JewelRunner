import { useEffect, useState } from "react";
import { ApiError } from "../api/client";
import type { DailyRewardClaim } from "../api/types";
import { useAuth } from "../auth/AuthContext";
import { SPRITES } from "../lib/sprites";

export function DailyRewardModal() {
  const { dailyReward, dailyRewardOpen, closeDailyReward, claimDailyReward } = useAuth();
  const [busy, setBusy] = useState(false);
  const [claimed, setClaimed] = useState<DailyRewardClaim | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!dailyRewardOpen) {
      setClaimed(null);
      setError(null);
    }
  }, [dailyRewardOpen]);

  if (!dailyRewardOpen || !dailyReward) return null;

  async function handleClaim() {
    setBusy(true);
    setError(null);
    try {
      const result = await claimDailyReward();
      setClaimed(result);
    } catch (caught) {
      const err = caught as ApiError;
      if (err.code === "daily_reward_claimed") {
        setError("Nagroda dzienna została już dziś odebrana.");
      } else {
        setError("Nie udało się odebrać nagrody dziennej. Spróbuj ponownie.");
      }
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="modal-backdrop" role="presentation">
      <div
        className="modal-panel"
        role="dialog"
        aria-modal="true"
        aria-labelledby="daily-reward-title"
        data-testid="daily-reward-modal"
      >
        <div className="card-title">
          <h2 id="daily-reward-title">Nagroda dzienna</h2>
          {dailyReward.special && (
            <span className="badge badge-special" data-testid="daily-reward-special">
              Nagroda specjalna
            </span>
          )}
        </div>

        <p className="daily-reward-hero">
          <img className="pixel" src={SPRITES.jewel} alt="" width={28} height={28} />
          <strong>+{dailyReward.gems} klejnotów</strong>
          <span className="muted-text">· Dzień serii: {dailyReward.streak_day} z 7</span>
        </p>

        <div className="daily-track" aria-label="Seria 7 dni">
          {dailyReward.rewards.map((day) => {
            const isCurrent = day.day === dailyReward.streak_day;
            const isDone =
              day.day < dailyReward.streak_day || (isCurrent && (!dailyReward.available || claimed !== null));
            return (
              <div
                key={day.day}
                className={`daily-day${isCurrent ? " current" : ""}${isDone ? " done" : ""}${day.special ? " special" : ""}`}
              >
                <span className="daily-day-num">Dzień {day.day}</span>
                <img className="pixel daily-day-icon" src={day.special ? SPRITES.star : SPRITES.jewel} alt="" />
                <strong>{day.gems}</strong>
                {day.special && <span className="daily-day-tag">Specjalna</span>}
              </div>
            );
          })}
        </div>

        {claimed && (
          <p className="notice success" role="status">
            Odebrano {claimed.gems} klejnotów! Nowe saldo: {claimed.balance} klejnotów.
          </p>
        )}
        {error && (
          <p className="field-error" role="alert">
            {error}
          </p>
        )}
        {!claimed && dailyReward.available && (
          <p className="muted-text small-note">Jeśli zamkniesz okno teraz, nagroda będzie czekać do końca dnia.</p>
        )}

        <div className="actions">
          {dailyReward.available && !claimed && (
            <button type="button" className="button primary" onClick={handleClaim} disabled={busy}>
              {busy ? "Odbieranie..." : "Odbierz"}
            </button>
          )}
          <button type="button" className="button ghost" onClick={closeDailyReward}>
            Zamknij
          </button>
        </div>
      </div>
    </div>
  );
}
