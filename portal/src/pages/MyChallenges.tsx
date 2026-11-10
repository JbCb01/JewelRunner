import { Link } from "react-router-dom";
import type { ItemList, MyChallenge, ParticipationStatus } from "../api/types";
import { ErrorBox, Loading, ProgressBar } from "../components/Status";
import { formatDate, formatRemaining } from "../lib/format";
import { useApi } from "../lib/useApi";

const STATUS_LABEL: Record<ParticipationStatus, string> = {
  Aktywne: "Aktywne",
  Ukończone: "Ukończone",
  Wygasłe: "Zakończone – nieukończone",
};

export function MyChallenges() {
  const { data, error, loading, reload } = useApi<ItemList<MyChallenge>>("/me/challenges");
  const active = data?.items.filter((item) => item.status === "Aktywne") ?? [];
  const history = data?.items.filter((item) => item.status !== "Aktywne") ?? [];

  return (
    <section>
      <h1>Moje wyzwania</h1>
      {loading && <Loading />}
      {error && <ErrorBox message="Nie można pobrać Twoich wyzwań." onRetry={reload} />}
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
              <Link key={item.challenge_id} to={`/moje-wyzwania/${item.challenge_id}`} className="card muted">
                <div className="card-title">
                  <h2>{item.name}</h2>
                  <span className="badge">{STATUS_LABEL[item.status]}</span>
                </div>
                <p>
                  Postęp: {item.progress_percent}% · Koniec: {formatDate(item.ends_at)}
                </p>
              </Link>
            ))}
          </div>
        </>
      )}
    </section>
  );
}
