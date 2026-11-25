import { useEffect, useRef, useState } from "react";
import { Link } from "react-router-dom";
import { api, ApiError } from "../api/client";
import type { Ranking as RankingData, RankingPeriod } from "../api/types";
import { useAuth } from "../auth/AuthContext";
import { ErrorBox, Loading } from "../components/Status";
import { formatDate } from "../lib/format";
import { loadRanking, saveRanking } from "../lib/rankingCache";

const PERIODS: { value: RankingPeriod; label: string }[] = [
  { value: "tydzień", label: "Tydzień" },
  { value: "miesiąc", label: "Miesiąc" },
  { value: "ogółem", label: "Ogółem" },
  { value: "znajomi", label: "Znajomi" },
];

export function Ranking() {
  const { user } = useAuth();
  const [selectedPeriod, setSelectedPeriod] = useState<RankingPeriod | null>(null);
  const [data, setData] = useState<RankingData | null>(null);
  const [stale, setStale] = useState(false);
  const [switchError, setSwitchError] = useState(false);
  const [failed, setFailed] = useState(false);
  const [loading, setLoading] = useState(true);
  const [attempt, setAttempt] = useState(0);
  const dataRef = useRef<RankingData | null>(null);
  dataRef.current = data;

  useEffect(() => {
    let active = true;
    setLoading(true);
    setFailed(false);
    setSwitchError(false);

    const path = selectedPeriod ? `/ranking?period=${encodeURIComponent(selectedPeriod)}` : "/ranking";
    api<RankingData>(path)
      .then((ranking) => {
        if (!active) return;
        saveRanking(ranking);
        setData(ranking);
        setStale(false);
        setSwitchError(false);
      })
      .catch((caught: ApiError) => {
        if (!active || !caught.isUnavailable) return;
        if (dataRef.current !== null) {
          // Przy błędzie sieci podczas zmiany filtra zostaje poprzednia lista.
          setSwitchError(true);
          return;
        }
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
  }, [selectedPeriod, attempt]);

  const activePeriod: RankingPeriod = data?.period ?? selectedPeriod ?? "ogółem";
  const meOutside = data?.me && !data.items.some((item) => item.player_id === user?.id);

  function selectPeriod(period: RankingPeriod) {
    if (period === selectedPeriod) {
      setAttempt((value) => value + 1);
    } else {
      setSelectedPeriod(period);
    }
  }

  return (
    <section className="panel">
      <div className="page-header-row">
        <h1>Ranking globalny</h1>
        <Link to="/znajomi" className="button ghost">
          Zarządzaj znajomymi
        </Link>
      </div>

      <div className="filter-bar" role="group" aria-label="Okres rankingu">
        {PERIODS.map((period) => (
          <button
            key={period.value}
            type="button"
            className={`button filter-btn${activePeriod === period.value ? " active" : ""}`}
            aria-pressed={activePeriod === period.value}
            onClick={() => selectPeriod(period.value)}
          >
            {period.label}
          </button>
        ))}
      </div>

      {loading && <Loading />}
      {failed && <ErrorBox message="Nie można pobrać rankingu." onRetry={() => setAttempt((value) => value + 1)} />}
      {switchError && data && (
        <p className="notice error" role="alert">
          Nie udało się pobrać rankingu dla wybranego filtra. Pokazano poprzednią listę.{" "}
          <button className="link-button" onClick={() => setAttempt((value) => value + 1)}>
            Spróbuj ponownie
          </button>
        </p>
      )}
      {stale && data && (
        <p className="notice info">
          Serwer jest niedostępny. Dane z: {formatDate(data.generated_at)}.{" "}
          <button className="link-button" onClick={() => setAttempt((value) => value + 1)}>
            Odśwież
          </button>
        </p>
      )}

      {data?.empty_reason === "no_friends" && (
        <p className="notice info" data-testid="ranking-empty">
          Nie masz jeszcze znajomych. <Link to="/znajomi">Dodaj znajomych</Link>, aby porównać wyniki.
        </p>
      )}
      {data?.empty_reason === "no_results" && (
        <p className="notice info" data-testid="ranking-empty">
          Brak wyników w tym okresie.
        </p>
      )}
      {data && !data.empty_reason && data.me === null && (
        <p className="notice info">Ukończ poziom, aby pojawić się w rankingu.</p>
      )}

      {data && !data.empty_reason && data.items.length > 0 && (
        <table className="ranking-table">
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
