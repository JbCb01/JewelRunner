import { useState } from "react";
import { Link, useParams } from "react-router-dom";
import { api, ApiError } from "../api/client";
import type { AcceptedChallenge, ChallengeDetails as Details } from "../api/types";
import { ErrorBox, Loading, ProgressBar } from "../components/Status";
import { formatConditions, formatDate, formatReward } from "../lib/format";
import { useApi } from "../lib/useApi";

const BACK = <Link to="/wyzwania">Powrót do listy</Link>;

function acceptError(error: ApiError): string {
  if (error.code === "challenge_unavailable") return "Wyzwanie jest niedostępne.";
  if (error.code === "participation_requirements_not_met") {
    const missing = formatConditions((error.details ?? {}) as Record<string, unknown>).join(", ");
    return `Nie spełniasz warunków udziału. Brakujący warunek: ${missing}.`;
  }
  return "Nie udało się przyjąć wyzwania.";
}

export function ChallengeDetails() {
  const { id } = useParams();
  const { data, error, loading, reload } = useApi<Details>(`/challenges/${id}`);
  const [accepted, setAccepted] = useState<AcceptedChallenge | null>(null);
  const [acceptMessage, setAcceptMessage] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);


  if (error?.code === "challenge_unavailable" || error?.code === "validation_error") {
    return <ErrorBox message="Wyzwanie jest niedostępne.">{BACK}</ErrorBox>;
  }
  if (error) {
    return (
      <ErrorBox message="Nie można pobrać szczegółów wyzwania." onRetry={reload}>
        {BACK}
      </ErrorBox>
    );
  }
  if (loading && !data) return <Loading />;
  if (!data) return null;

  return (
    <section className="panel">
      <h1>{data.name}</h1>
      <p>{data.description}</p>
      <dl>
        <dt>Poziom trudności</dt>
        <dd>{data.difficulty}</dd>
        <dt>Poziom gry</dt>
        <dd>{data.level}</dd>
        <dt>Warunki ukończenia</dt>
        <dd>{formatConditions(data.completion_conditions).join(", ")}</dd>
        <dt>Nagroda</dt>
        <dd>{formatReward(data.reward)}</dd>
        <dt>Czas trwania</dt>
        <dd>
          {formatDate(data.starts_at)} – {formatDate(data.ends_at)}
        </dd>
      </dl>


      {data.participation ? (
        <div className="participation">
          <p>
            Twój postęp: {data.participation.progress_percent}% ({data.participation.status})
          </p>
          <ProgressBar value={data.participation.progress_percent} />
        </div>
      ) : (

      <p>{BACK}</p>
    </section>
  );
}
