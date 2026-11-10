import { Link, useParams } from "react-router-dom";
import type { Attempts as AttemptsData, ItemList, MyChallenge } from "../api/types";
import { ErrorBox, Loading } from "../components/Status";
import { formatDate } from "../lib/format";
import { useApi } from "../lib/useApi";

export function Attempts() {
  const { id } = useParams();
  const attempts = useApi<AttemptsData>(`/me/challenges/${id}/attempts`);
  const mine = useApi<ItemList<MyChallenge>>("/me/challenges");
  const challenge = mine.data?.items.find((item) => String(item.challenge_id) === id);
  const back = <Link to="/moje-wyzwania">Powrót do moich wyzwań</Link>;

  if (attempts.error?.code === "not_found" || attempts.error?.code === "validation_error") {
    return <ErrorBox message="Nie znaleziono tego wyzwania na Twojej liście.">{back}</ErrorBox>;
  }

  return (
    <section className="panel">
      <h1>{challenge?.name ?? "Historia prób"}</h1>
      {attempts.loading && <Loading />}
      {attempts.error && <ErrorBox message="Nie można pobrać historii prób." onRetry={attempts.reload} />}
      {attempts.data && (
        <>
          <p>Najlepszy wynik: {attempts.data.best_score ?? "–"}</p>
          {attempts.data.items.length === 0 ? (
            <p className="notice info">Brak prób.</p>
          ) : (
            <table>
              <thead>
                <tr>
                  <th>Data</th>
                  <th>Wynik</th>
                  <th>Zaliczona</th>
                </tr>
              </thead>
              <tbody>
                {attempts.data.items.map((attempt) => (
                  <tr key={`${attempt.attempted_at}-${attempt.score}`}>
                    <td>{formatDate(attempt.attempted_at)}</td>
                    <td>{attempt.score}</td>
                    <td>{attempt.passed ? "Tak" : "Nie"}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </>
      )}
      <p>{back}</p>
    </section>
  );
}
