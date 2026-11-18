import { useEffect, useState, type FormEvent } from "react";
import { Link } from "react-router-dom";
import { api, ApiError } from "../api/client";
import type {
  AppearanceState,
  GameRun,
  GameRunPage,
  ItemList,
  Me,
  PairingCode,
  PlayerStats,
  UserSession,
} from "../api/types";
import { useAuth } from "../auth/AuthContext";
import { ErrorBox, Loading, ProgressBar } from "../components/Status";
import {
  formatCountdown,
  formatDate,
  formatDuration,
  formatRunTime,
  PAIRING_CODE_TTL_SECONDS,
  secondsLeft,
  validatePassword,
} from "../lib/format";
import { useApi } from "../lib/useApi";
import jewel from "../assets/jewel.png";

type Message = { kind: "success" | "error"; text: string } | null;

function MessageLine({ message }: { message: Message }) {
  if (!message) return null;
  return message.kind === "success" ? (
    <p className="notice success" role="status">
      {message.text}
    </p>
  ) : (
    <p className="field-error" role="alert">
      {message.text}
    </p>
  );
}

function accountError(error: ApiError): string {
  switch (error.code) {
    case "username_taken":
      return "Nazwa jest zajęta.";
    case "email_taken":
      return "Ten adres e-mail jest już zarejestrowany.";
    case "invalid_password":
      return "Aktualne hasło jest nieprawidłowe.";
    case "weak_password":
      return "Hasło musi mieć co najmniej 8 znaków, literę i cyfrę.";
    case "login_locked":
      return "Zbyt wiele nieudanych prób. Spróbuj ponownie za 15 minut.";
    case "email_unavailable":
      return "Nie udało się wysłać wiadomości. Spróbuj ponownie później.";
    case "validation_error":
      return "Sprawdź wpisane dane.";
    default:
      return "Nie udało się zapisać zmian.";
  }
}

function ProfileOverview() {
  const { gems } = useAuth();
  const appearance = useApi<AppearanceState>("/me/appearance");
  const current = appearance.data?.current;

  return (
    <div className="panel profile-overview" data-testid="profile-overview">
      <div className="overview-block">
        <h2>Portfel</h2>
        <p className="overview-gems" data-testid="profile-gems">
          <img src={jewel} alt="" width={24} height={24} />
          <strong>{gems ?? "–"} klejnotów</strong>
        </p>
        <Link to="/sklep">Przejdź do sklepu</Link>
      </div>

      <div className="overview-block" data-testid="profile-appearance">
        <h2>Aktualny wygląd postaci</h2>
        {appearance.loading && !current && <Loading />}
        {current ? (
          <div className="appearance-inline">
            <span
              className="color-dot lg"
              style={{ backgroundColor: current.color.hex }}
              title={current.color.name}
              aria-hidden="true"
            />
            <div>
              <p>
                <strong>Skórka:</strong> {current.skin.name} · <strong>Kolor:</strong> {current.color.name}
              </p>
              <p className="muted-text small-note">
                Akcesoria:{" "}
                {current.accessories.length > 0
                  ? current.accessories.map((acc) => `${acc.accessory.name} (${acc.slot})`).join(", ")
                  : "Brak"}
              </p>
            </div>
          </div>
        ) : (
          !appearance.loading && <p className="muted-text">Brak danych o wyglądzie.</p>
        )}
        <Link to="/kolekcja">Zmień w Kolekcji</Link>
      </div>
    </div>
  );
}

function UsernameForm({ user }: { user: Me }) {
  const { setUser } = useAuth();
  const [username, setUsername] = useState(user.username);
  const [message, setMessage] = useState<Message>(null);

  async function submit(event: FormEvent) {
    event.preventDefault();
    const trimmed = username.trim();
    if (trimmed.length < 3 || trimmed.length > 32) {
      setMessage({ kind: "error", text: "Nazwa użytkownika musi mieć od 3 do 32 znaków." });
      return;
    }
    try {
      setUser(await api<Me>("/me", { method: "PATCH", body: { username: trimmed } }));
      setMessage({ kind: "success", text: "Nazwa została zmieniona." });
    } catch (caught) {
      setMessage({ kind: "error", text: accountError(caught as ApiError) });
    }
  }

  return (
    <form onSubmit={submit} aria-label="Zmiana nazwy">
      <h2>Nazwa użytkownika</h2>
      <label>
        Nowa nazwa
        <input required value={username} onChange={(e) => setUsername(e.target.value)} />
      </label>
      <MessageLine message={message} />
      <div className="actions">
        <button className="button primary">Zapisz nazwę</button>
        <button
          type="button"
          className="button ghost"
          onClick={() => {
            setUsername(user.username);
            setMessage(null);
          }}
        >
          Anuluj
        </button>
      </div>
    </form>
  );
}

function EmailForm({ user }: { user: Me }) {
  const [newEmail, setNewEmail] = useState("");
  const [password, setPassword] = useState("");
  const [message, setMessage] = useState<Message>(null);

  async function submit(event: FormEvent) {
    event.preventDefault();
    try {
      await api("/me/email", { method: "POST", body: { new_email: newEmail, current_password: password } });
      setMessage({ kind: "success", text: `Wysłaliśmy link potwierdzający na adres ${newEmail}.` });
      setNewEmail("");
      setPassword("");
    } catch (caught) {
      setMessage({ kind: "error", text: accountError(caught as ApiError) });
    }
  }

  return (
    <form onSubmit={submit} aria-label="Zmiana e-maila">
      <h2>Adres e-mail</h2>
      <p>Obecny adres: {user.email}</p>
      <label>
        Nowy adres e-mail
        <input type="email" required value={newEmail} onChange={(e) => setNewEmail(e.target.value)} />
      </label>
      <label>
        Aktualne hasło
        <input
          type="password"
          required
          autoComplete="current-password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
        />
      </label>
      <MessageLine message={message} />
      <button className="button primary">Zmień e-mail</button>
    </form>
  );
}

function PasswordForm() {
  const [current, setCurrent] = useState("");
  const [next, setNext] = useState("");
  const [repeat, setRepeat] = useState("");
  const [message, setMessage] = useState<Message>(null);

  async function submit(event: FormEvent) {
    event.preventDefault();
    const invalid = validatePassword(next);
    if (invalid) {
      setMessage({ kind: "error", text: invalid });
      return;
    }
    if (next !== repeat) {
      setMessage({ kind: "error", text: "Hasła nie są takie same." });
      return;
    }
    try {
      await api("/me/password", { method: "POST", body: { current_password: current, new_password: next } });
      setMessage({ kind: "success", text: "Hasło zostało zmienione." });
      setCurrent("");
      setNext("");
      setRepeat("");
    } catch (caught) {
      setMessage({ kind: "error", text: accountError(caught as ApiError) });
    }
  }

  return (
    <form onSubmit={submit} aria-label="Zmiana hasła">
      <h2>Hasło</h2>
      <label>
        Aktualne hasło
        <input
          type="password"
          required
          autoComplete="current-password"
          value={current}
          onChange={(e) => setCurrent(e.target.value)}
        />
      </label>
      <label>
        Nowe hasło
        <input type="password" required autoComplete="new-password" value={next} onChange={(e) => setNext(e.target.value)} />
      </label>
      <label>
        Powtórz nowe hasło
        <input
          type="password"
          required
          autoComplete="new-password"
          value={repeat}
          onChange={(e) => setRepeat(e.target.value)}
        />
      </label>
      <MessageLine message={message} />
      <button className="button primary">Zmień hasło</button>
    </form>
  );
}

function GamePairing({ user }: { user: Me }) {
  const { refreshMe } = useAuth();
  const [pairing, setPairing] = useState<PairingCode | null>(null);
  const [left, setLeft] = useState(0);
  const [copied, setCopied] = useState(false);
  const [message, setMessage] = useState<Message>(null);
  const [busy, setBusy] = useState(false);
  const [disconnecting, setDisconnecting] = useState(false);

  useEffect(() => {
    if (!pairing) return;
    setLeft(secondsLeft(pairing.expires_at));
    const timer = window.setInterval(() => setLeft(secondsLeft(pairing.expires_at)), 1000);
    return () => window.clearInterval(timer);
  }, [pairing]);

  async function generate() {
    setBusy(true);
    setCopied(false);
    setMessage(null);
    try {
      setPairing(await api<PairingCode>("/me/pairing-code", { method: "POST" }));
    } catch (caught) {
      const error = caught as ApiError;
      setMessage({
        kind: "error",
        text: error.isUnavailable ? "Brak połączenia z serwerem. Spróbuj ponownie." : "Nie udało się wygenerować kodu.",
      });
    } finally {
      setBusy(false);
    }
  }

  async function disconnectGame() {
    setDisconnecting(true);
    setMessage(null);
    try {
      const response = await api<ItemList<UserSession>>("/me/sessions");
      const gameSessions = response.items.filter((session) => session.device === "gra");
      for (const session of gameSessions) {
        await api(`/me/sessions/${session.id}`, { method: "DELETE" });
      }
      await refreshMe();
      setPairing(null);
      setMessage({ kind: "success", text: "Gra została odłączona od konta." });
    } catch {
      setMessage({ kind: "error", text: "Nie udało się odłączyć gry. Spróbuj ponownie." });
    } finally {
      setDisconnecting(false);
    }
  }

  async function copyCode() {
    if (!pairing || !navigator.clipboard) return;
    try {
      await navigator.clipboard.writeText(pairing.code);
      setCopied(true);
    } catch {
      setCopied(false);
    }
  }

  const active = pairing !== null && left > 0;
  const linked = Boolean(user.game_linked);
  const statusLabel = linked ? "Połączone" : active ? "Oczekuje na wpisanie kodu" : "Niepołączone";
  const progressPercent = active
    ? Math.min(100, Math.max(0, Math.round((left / PAIRING_CODE_TTL_SECONDS) * 100)))
    : 0;

  return (
    <section className="game-link" aria-label="Połącz grę">
      <h2>Połącz z grą</h2>
      <div className="game-link-status-row">
        <span>Status powiązania:</span>
        <span
          className={`badge ${linked ? "badge-linked" : active ? "badge-pending" : "badge-unlinked"}`}
          data-testid="game-link-status"
        >
          {statusLabel}
        </span>
      </div>
      <p className="game-link-description">
        Wygeneruj 6-znakowy kod i wpisz go w grze na ekranie logowania, w polu „Kod z portalu”. Nie musisz podawać hasła w grze.
      </p>
      {user.last_synced_at && (
        <p className="game-link-sync">Ostatnia synchronizacja: {formatDate(user.last_synced_at)}</p>
      )}
      {active ? (
        <div className="pairing-code-box" aria-live="polite">
          <p className="pairing-code" aria-label="Kod parowania" data-testid="pairing-code">
            {pairing.code}
          </p>
          <div className="pairing-countdown">
            <p role="timer" data-testid="pairing-countdown">
              Kod wygaśnie za {formatCountdown(left)}. Działa tylko raz.
            </p>
            <ProgressBar value={progressPercent} />
          </div>
        </div>
      ) : (
        pairing && (
          <p className="field-error" role="status" data-testid="pairing-countdown">
            Kod wygasł. Wygeneruj nowy.
          </p>
        )
      )}
      <MessageLine message={message} />
      <div className="actions">
        <button type="button" className="button primary" onClick={generate} disabled={busy}>
          {active ? "Wygeneruj nowy kod" : "Wygeneruj kod"}
        </button>
        {active && (
          <button type="button" className="button ghost" onClick={copyCode}>
            {copied ? "Skopiowano" : "Kopiuj kod"}
          </button>
        )}
        {linked && (
          <button type="button" className="button ghost" onClick={disconnectGame} disabled={disconnecting}>
            {disconnecting ? "Odłączanie..." : "Odłącz grę"}
          </button>
        )}
      </div>
    </section>
  );
}

function StatsAndHistory() {
  const stats = useApi<PlayerStats>("/me/stats");
  const [runs, setRuns] = useState<GameRun[]>([]);
  const [nextBeforeId, setNextBeforeId] = useState<number | null>(null);
  const [runsLoading, setRunsLoading] = useState(true);
  const [runsLoadingMore, setRunsLoadingMore] = useState(false);
  const [runsError, setRunsError] = useState(false);

  useEffect(() => {
    let active = true;
    setRunsLoading(true);
    setRunsError(false);
    api<GameRunPage>("/me/runs?limit=10")
      .then((page) => {
        if (!active) return;
        setRuns(page.items);
        setNextBeforeId(page.next_before_id);
      })
      .catch(() => {
        if (active) setRunsError(true);
      })
      .finally(() => {
        if (active) setRunsLoading(false);
      });
    return () => {
      active = false;
    };
  }, []);

  async function loadMoreRuns() {
    if (nextBeforeId === null || runsLoadingMore) return;
    setRunsLoadingMore(true);
    try {
      const page = await api<GameRunPage>(`/me/runs?limit=10&before_id=${nextBeforeId}`);
      setRuns((prev) => [...prev, ...page.items]);
      setNextBeforeId(page.next_before_id);
    } catch {
      setRunsError(true);
    } finally {
      setRunsLoadingMore(false);
    }
  }

  return (
    <div className="stack-lg">
      <div className="panel" data-testid="profile-stats">
        <div className="page-header-row">
          <h2>Statystyki</h2>
          <Link to="/rankingi" className="button ghost">
            Zobacz ranking
          </Link>
        </div>

        {stats.loading && !stats.data && <Loading />}
        {stats.error && <ErrorBox message="Nie można pobrać statystyk." onRetry={stats.reload} />}

        {stats.data && (
          <>
            {!stats.data.has_played && (
              <p className="notice info" data-testid="stats-zero-notice">
                Nie rozegrałeś jeszcze żadnego poziomu. Uruchom grę, aby zdobyć pierwsze wyniki i pojawić się w rankingu!
              </p>
            )}

            <div className="stats-summary-grid">
              <div className="stat-box">
                <span className="stat-label">Łączny czas gry</span>
                <strong>{formatDuration(stats.data.overall.play_time_s)}</strong>
              </div>
              <div className="stat-box">
                <span className="stat-label">Rozgrywki</span>
                <strong>{stats.data.overall.runs}</strong>
              </div>
              <div className="stat-box">
                <span className="stat-label">Ukończone poziomy</span>
                <strong>{stats.data.overall.levels_completed}</strong>
              </div>
              <div className="stat-box">
                <span className="stat-label">Pokonani wrogowie</span>
                <strong>{stats.data.overall.enemies_defeated}</strong>
              </div>
              <div className="stat-box">
                <span className="stat-label">Porażki</span>
                <strong>{stats.data.overall.defeats}</strong>
              </div>
              <div className="stat-box">
                <span className="stat-label">Zebrane klejnoty</span>
                <strong>{stats.data.overall.gems_collected}</strong>
              </div>
            </div>

            <h3 className="subsection-title">Poziomy</h3>
            <table data-testid="stats-levels-table">
              <thead>
                <tr>
                  <th>Poziom</th>
                  <th>Status</th>
                  <th>Najlepszy wynik</th>
                  <th>Najlepszy czas</th>
                  <th>Próby</th>
                  <th>Ranking</th>
                </tr>
              </thead>
              <tbody>
                {stats.data.levels.map((level) => (
                  <tr key={level.level}>
                    <td>{level.name}</td>
                    <td>{level.unlocked ? (level.completed ? "Ukończony" : "Odblokowany") : "Zablokowany"}</td>
                    <td>{level.best_score ?? "–"}</td>
                    <td>{level.best_time_s !== null ? formatRunTime(level.best_time_s) : "–"}</td>
                    <td>{level.attempts}</td>
                    <td>
                      <Link to="/rankingi">Ranking</Link>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </>
        )}
      </div>

      <div className="panel" data-testid="profile-runs">
        <h2>Historia gier</h2>
        {runsLoading && <Loading />}
        {runsError && <p className="notice error">Nie udało się pobrać historii gier.</p>}
        {!runsLoading && runs.length === 0 && !runsError && (
          <p className="notice info">Brak zapisanych rozgrywek.</p>
        )}
        {runs.length > 0 && (
          <>
            <table data-testid="runs-table">
              <thead>
                <tr>
                  <th>Data</th>
                  <th>Poziom</th>
                  <th>Wynik przejścia</th>
                  <th>Punkty</th>
                  <th>Czas</th>
                  <th>Klejnoty</th>
                  <th>Wrogowie</th>
                </tr>
              </thead>
              <tbody>
                {runs.map((run) => (
                  <tr key={run.id}>
                    <td>{formatDate(run.played_at)}</td>
                    <td>{run.level_name}</td>
                    <td>{run.completed ? "Ukończony" : "Porażka"}</td>
                    <td>{run.score}</td>
                    <td>{formatRunTime(run.time_s)}</td>
                    <td>{run.gems}</td>
                    <td>{run.enemies_defeated}</td>
                  </tr>
                ))}
              </tbody>
            </table>
            {nextBeforeId !== null && (
              <div className="actions top-gap">
                <button type="button" className="button ghost" onClick={loadMoreRuns} disabled={runsLoadingMore}>
                  {runsLoadingMore ? "Ładowanie..." : "Załaduj więcej"}
                </button>
              </div>
            )}
          </>
        )}
      </div>
    </div>
  );
}

export function Profile() {
  const { user } = useAuth();
  if (!user) return null;
  return (
    <section className="stack-lg">
      <h1>Ustawienia profilu</h1>
      <ProfileOverview />
      <div className="profile-grid">
        <div className="panel">
          <UsernameForm key={user.username} user={user} />
        </div>
        <div className="panel">
          <EmailForm user={user} />
        </div>
        <div className="panel">
          <PasswordForm />
        </div>
        <div className="panel">
          <GamePairing user={user} />
        </div>
      </div>
      <StatsAndHistory />
    </section>
  );
}
