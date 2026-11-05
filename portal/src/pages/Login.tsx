import { useState, type FormEvent } from "react";
import { Link, Navigate, useLocation } from "react-router-dom";
import { ApiError } from "../api/client";
import { useAuth } from "../auth/AuthContext";

function loginError(error: ApiError): string {
  if (error.code === "invalid_credentials") return "Nieprawidłowy login lub hasło.";
  if (error.code === "login_locked") return "Zbyt wiele nieudanych prób. Spróbuj ponownie za 15 minut.";
  if (error.code === "account_blocked") return "Konto zostało zablokowane.";
  if (error.code === "validation_error") return "Podaj poprawny adres e-mail.";
  return "Nie udało się zalogować. Spróbuj ponownie.";
}

export function Login() {
  const { user, login, sessionExpired } = useAuth();
  const location = useLocation();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  if (user) return <Navigate to={(location.state as { from?: string } | null)?.from ?? "/wyzwania"} replace />;

  async function submit(event: FormEvent) {
    event.preventDefault();
    setBusy(true);
    setError(null);
    try {
      await login(email, password);
    } catch (caught) {
      setError(loginError(caught as ApiError));
    } finally {
      setBusy(false);
    }
  }

  return (
    <section className="panel form-panel">
      <h1>Logowanie</h1>
      {sessionExpired && <p className="notice info">Sesja wygasła. Zaloguj się ponownie.</p>}
      <form onSubmit={submit}>
        <label>
          E-mail
          <input type="email" required autoComplete="email" value={email} onChange={(e) => setEmail(e.target.value)} />
        </label>
        <label>
          Hasło
          <input
            type="password"
            required
            autoComplete="current-password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
          />
        </label>
        {error && (
          <p className="field-error" role="alert">
            {error}
          </p>
        )}
        <button className="button primary" disabled={busy}>
          Zaloguj się
        </button>
      </form>
      <p>
        Nie masz konta? <Link to="/rejestracja">Utwórz konto</Link>
      </p>
    </section>
  );
}
