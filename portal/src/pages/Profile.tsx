import { useEffect, useState, type FormEvent } from "react";
import { api, ApiError } from "../api/client";
import type { Me, PairingCode } from "../api/types";
import { useAuth } from "../auth/AuthContext";
import { ProgressBar } from "../components/Status";
import {
  formatCountdown,
  formatDate,
  PAIRING_CODE_TTL_SECONDS,
  secondsLeft,
  validatePassword,
} from "../lib/format";

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
  const [pairing, setPairing] = useState<PairingCode | null>(null);
  const [left, setLeft] = useState(0);
  const [copied, setCopied] = useState(false);
  const [message, setMessage] = useState<Message>(null);
  const [busy, setBusy] = useState(false);

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
      </div>
    </section>
  );
}

export function Profile() {
  const { user } = useAuth();
  if (!user) return null;
  return (
    <section>
      <h1>Ustawienia profilu</h1>
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
    </section>
  );
}
