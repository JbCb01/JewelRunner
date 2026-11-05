import { useState, type FormEvent, type ReactNode } from "react";
import { Link, Navigate } from "react-router-dom";
import { ApiError } from "../api/client";
import { useAuth } from "../auth/AuthContext";
import { validatePassword } from "../lib/format";

export function Register() {
  const { user, register } = useAuth();
  const [username, setUsername] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<ReactNode>(null);
  const [busy, setBusy] = useState(false);

  if (user) return <Navigate to="/wyzwania" replace />;

  async function submit(event: FormEvent) {
    event.preventDefault();
    const trimmed = username.trim();
    if (trimmed.length < 3 || trimmed.length > 32) {
      setError("Nazwa użytkownika musi mieć od 3 do 32 znaków.");
      return;
    }
    const passwordError = validatePassword(password);
    if (passwordError) {
      setError(passwordError);
      return;
    }
    setBusy(true);
    setError(null);
    try {
      await register(trimmed, email, password);
    } catch (caught) {
      const apiError = caught as ApiError;
      if (apiError.code === "username_taken") setError("Nazwa jest zajęta.");
      else if (apiError.code === "email_taken")
        setError(
          <>
            Ten adres e-mail jest już zarejestrowany. <Link to="/logowanie">Zaloguj się</Link> lub{" "}
            <Link to="/odzyskiwanie-hasla">odzyskaj hasło</Link>.
          </>,
        );
      else if (apiError.code === "weak_password") setError("Hasło musi mieć co najmniej 8 znaków, literę i cyfrę.");
      else if (apiError.code === "validation_error") setError("Sprawdź poprawność nazwy i adresu e-mail.");
      else setError("Nie udało się utworzyć konta. Spróbuj ponownie.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <section className="panel form-panel">
      <h1>Utwórz konto</h1>
      <form onSubmit={submit}>
        <label>
          Nazwa użytkownika
          <input required autoComplete="username" value={username} onChange={(e) => setUsername(e.target.value)} />
        </label>
        <label>
          E-mail
          <input type="email" required autoComplete="email" value={email} onChange={(e) => setEmail(e.target.value)} />
        </label>
        <label>
          Hasło
          <input
            type="password"
            required
            autoComplete="new-password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
          />
          <small>Co najmniej 8 znaków, litera i cyfra.</small>
        </label>
        {error && (
          <p className="field-error" role="alert">
            {error}
          </p>
        )}
        <button className="button primary" disabled={busy}>
          Utwórz konto
        </button>
      </form>
      <p>
        Masz już konto? <Link to="/logowanie">Zaloguj się</Link>
      </p>
    </section>
  );
}
