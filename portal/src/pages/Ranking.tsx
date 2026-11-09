import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { api, ApiError } from "../api/client";
import type { Ranking as RankingData } from "../api/types";
import { useAuth } from "../auth/AuthContext";
import { ErrorBox, Loading } from "../components/Status";
import { formatDate } from "../lib/format";
import { loadRanking, saveRanking } from "../lib/rankingCache";

export function Ranking() {
  const { user } = useAuth();
  const [data, setData] = useState<RankingData | null>(null);
  const [stale, setStale] = useState(false);
  const [failed, setFailed] = useState(false);
  const [loading, setLoading] = useState(true);
  const [attempt, setAttempt] = useState(0);

  useEffect(() => {
    let active = true;
    setLoading(true);
    setFailed(false);
    api<RankingData>("/ranking")
      .then((ranking) => {
        if (!active) return;
        saveRanking(ranking);
        setData(ranking);
        setStale(false);
      })
      .catch((caught: ApiError) => {
        if (!active || !caught.isUnavailable) return;
        const cached = loadRanking();
        setData(cached);
        setStale(cached !== null);
        setFailed(cached === null);
      })
      .finally(() => {
        if (active) setLoading(false);
      });
    return () => {
      active = false;
    };
  }, [attempt]);

  const meOutside = data?.me && !data.items.some((item) => item.player_id === user?.id);

  return (
    <section className="panel">
      <h1>Ranking globalny</h1>
      {loading && <Loading />}
      {failed && <ErrorBox message="Nie można pobrać rankingu." onRetry={() => setAttempt((value) => value + 1)} />}
      {stale && data && (
        <p className="notice info">
          Serwer jest niedostępny. Dane z: {formatDate(data.generated_at)}.{" "}
          <button className="link-button" onClick={() => setAttempt((value) => value + 1)}>
            Odśwież
          </button>
        </p>
      )}
      {data && data.me === null && <p className="notice info">Ukończ poziom, aby pojawić się w rankingu.</p>}
      {data && data.items.length > 0 && (
        <table>
          <thead>
            <tr>
              <th>Pozycja</th>
              <th>Gracz</th>
              <th>Wynik</th>
            </tr>
          </thead>
          <tbody>
            {data.items.map((item) => (
              <tr key={item.player_id} className={item.player_id === user?.id ? "highlight" : undefined}>
                <td>{item.position}</td>
                <td>
                  <Link to={`/gracze/${item.player_id}`}>{item.username}</Link>
                </td>
                <td>{item.score}</td>
              </tr>
            ))}
          </tbody>
          {meOutside && data.me && (
            <tfoot>
              <tr className="highlight" data-testid="my-position">
                <td>{data.me.position}</td>
                <td>{user?.username} (Ty)</td>
                <td>{data.me.score}</td>
              </tr>
            </tfoot>
          )}
        </table>
      )}
    </section>
  );
}
