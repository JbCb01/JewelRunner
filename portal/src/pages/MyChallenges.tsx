import { useState } from "react";
import { Link } from "react-router-dom";
import { api, ApiError } from "../api/client";
import type { ClaimRewardResponse, ItemList, MyChallenge, ParticipationStatus } from "../api/types";
import { useAuth } from "../auth/AuthContext";
import { ErrorBox, Loading, ProgressBar } from "../components/Status";
import { formatClaimResult, formatDate, formatRemaining, formatReward } from "../lib/format";
import { useApi } from "../lib/useApi";

const STATUS_LABEL: Record<ParticipationStatus, string> = {
  Aktywne: "Aktywne",
  Ukończone: "Ukończone",
  Wygasłe: "Zakończone – nieukończone",
};

export function MyChallenges() {
  const { setGems } = useAuth();
  const { data, error, loading, reload } = useApi<ItemList<MyChallenge>>("/me/challenges");
  const [claimingId, setClaimingId] = useState<number | null>(null);
  const [claimMessage, setClaimMessage] = useState<{ kind: "success" | "error"; text: string } | null>(null);

  const active = data?.items.filter((item) => item.status === "Aktywne") ?? [];
  const history = data?.items.filter((item) => item.status !== "Aktywne") ?? [];

  async function handleClaim(challengeId: number) {
    setClaimingId(challengeId);
    setClaimMessage(null);
    try {
      const result = await api<ClaimRewardResponse>(`/me/challenges/${challengeId}/claim`, { method: "POST" });
      setGems(result.balance);
      setClaimMessage({ kind: "success", text: formatClaimResult(result) });
      reload();
    } catch (caught) {
      const err = caught as ApiError;
      if (err.code === "reward_already_claimed") {
        setClaimMessage({ kind: "error", text: "Nagroda za to wyzwanie została już odebrana." });
        reload();
      } else {
        setClaimMessage({ kind: "error", text: "Nie udało się odebrać nagrody. Spróbuj ponownie." });
      }
    } finally {
      setClaimingId(null);
    }
  }

  return (
    <section>
      <h1>Moje wyzwania</h1>
      {loading && <Loading />}
      {error && <ErrorBox message="Nie można pobrać Twoich wyzwań." onRetry={reload} />}
      {claimMessage && (
        <p
          className={claimMessage.kind === "success" ? "notice success" : "notice error"}
          role={claimMessage.kind === "success" ? "status" : "alert"}
        >
          {claimMessage.text}
        </p>
      )}
      {data && active.length === 0 && (
        <p className="notice info">
          Nie masz aktywnych wyzwań. <Link to="/wyzwania">Zobacz listę wyzwań</Link>
        </p>
      )}
      <div className="card-grid">
        {active.map((item) => (
          <Link key={item.challenge_id} to={`/moje-wyzwania/${item.challenge_id}`} className="card">
            <h2>{item.name}</h2>
            <ProgressBar value={item.progress_percent} />
            <p>
              {item.progress_percent}% · {formatRemaining(item.ends_at)}
            </p>
          </Link>
        ))}
      </div>
      {history.length > 0 && (
        <>
          <h2 className="section-title">Historia</h2>
          <div className="card-grid">
            {history.map((item) => (
              <article key={item.challenge_id} className="card muted history-card">
                <div className="card-title">
                  <h2>
                    <Link to={`/moje-wyzwania/${item.challenge_id}`}>{item.name}</Link>
                  </h2>
                  <span className="badge">{STATUS_LABEL[item.status]}</span>
                </div>
                <p>
                  Postęp: {item.progress_percent}% · Koniec: {formatDate(item.ends_at)}
                </p>
                {item.reward && <p className="muted-text small-note">Nagroda: {formatReward(item.reward)}</p>}
                {item.reward_status === "Do odebrania" && (
                  <button
                    type="button"
                    className="button primary"
                    disabled={claimingId === item.challenge_id}
                    onClick={() => handleClaim(item.challenge_id)}
                  >
                    {claimingId === item.challenge_id ? "Odbieranie..." : "Odbierz nagrodę"}
                  </button>
                )}
                {item.reward_status === "Odebrana" && <span className="badge badge-linked">Nagroda odebrana</span>}
              </article>
            ))}
          </div>
        </>
      )}
    </section>
  );
}
