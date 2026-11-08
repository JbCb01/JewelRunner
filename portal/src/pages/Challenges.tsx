import { Link } from "react-router-dom";
import type { ChallengeListItem, ItemList } from "../api/types";
import { ErrorBox, Loading } from "../components/Status";
import { formatDate, formatReward } from "../lib/format";
import { useApi } from "../lib/useApi";

export function Challenges() {
  const { data, error, loading, reload } = useApi<ItemList<ChallengeListItem>>("/challenges");

  return (
    <section>
      <h1>Wyzwania</h1>
      {loading && <Loading />}
      {error && <ErrorBox message="Nie można pobrać wyzwań." onRetry={reload} />}
      {data?.items.length === 0 && <p className="notice info">Brak dostępnych wyzwań.</p>}
      <div className="card-grid">
        {data?.items.map((challenge) => (
          <Link key={challenge.id} to={`/wyzwania/${challenge.id}`} className="card">
            <div className="card-title">
              <h2>{challenge.name}</h2>
              {challenge.participation_status && <span className="badge">Przyjęte</span>}
            </div>
            <dl>
              <dt>Poziom trudności</dt>
              <dd>{challenge.difficulty}</dd>
              <dt>Nagroda</dt>
              <dd>{formatReward(challenge.reward)}</dd>
              <dt>Koniec</dt>
              <dd>{formatDate(challenge.ends_at)}</dd>
            </dl>
          </Link>
        ))}
      </div>
    </section>
  );
}
