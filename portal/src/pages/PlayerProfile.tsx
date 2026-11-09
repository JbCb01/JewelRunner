import { Link, useParams } from "react-router-dom";
import type { Player } from "../api/types";
import { ErrorBox, Loading } from "../components/Status";
import { formatDuration } from "../lib/format";
import { useApi } from "../lib/useApi";

export function PlayerProfile() {
  const { id } = useParams();
  const { data, error, loading, reload } = useApi<Player>(`/players/${id}`);
  const back = <Link to="/rankingi">Powrót do rankingu</Link>;

  if (error?.code === "not_found" || error?.code === "validation_error") {
    return <ErrorBox message="Nie znaleziono gracza.">{back}</ErrorBox>;
  }

  return (
    <section className="panel">
      {loading && <Loading />}
      {error && <ErrorBox message="Nie można pobrać profilu gracza." onRetry={reload} />}
      {data && (
        <>
          <h1>{data.username}</h1>
          <dl>
            <dt>Czas gry</dt>
            <dd>{formatDuration(data.statistics.play_time_seconds)}</dd>
            <dt>Ukończone poziomy</dt>
            <dd>{data.statistics.levels_completed}</dd>
            <dt>Pokonani wrogowie</dt>
            <dd>{data.statistics.enemies_defeated}</dd>
            <dt>Porażki</dt>
            <dd>{data.statistics.defeats}</dd>
            <dt>Najdłuższe combo</dt>
            <dd>{data.statistics.longest_combo}</dd>
          </dl>
        </>
      )}
      <p>{back}</p>
    </section>
  );
}
