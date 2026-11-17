import { useState, type FormEvent } from "react";
import { Link, useSearchParams } from "react-router-dom";
import { api, ApiError } from "../api/client";
import { validatePassword } from "../lib/format";

export function ResetPassword() {
  const [params] = useSearchParams();
  const token = params.get("token") ?? "";
  const [password, setPassword] = useState("");
  const [repeat, setRepeat] = useState("");
  const [busy, setBusy] = useState(false);
  const [done, setDone] = useState(false);
  const [expired, setExpired] = useState(!token);
  const [error, setError] = useState<string | null>(null);

  async function submit(event: FormEvent) {
    event.preventDefault();
    setError(null);
    const invalid = validatePassword(password);
    if (invalid) {
      setError(invalid);
      return;
    }
    if (password !== repeat) {
      setError("Hasła nie są takie same.");
      return;
    }
    setBusy(true);
    try {
      await api("/auth/reset", {
        method: "POST",
        body: { token, new_password: password },
        allowAnonymous: true,
      });
      setDone(true);
    } catch (caught) {
      const err = caught as ApiError;
      if (err.code === "invalid_token") {
        setExpired(true);
      } else if (err.code === "weak_password") {
        setError("Hasło musi mieć co najmniej 8 znaków, literę i cyfrę.");
      } else {
        setError("Nie udało się zmienić hasła. Spróbuj ponownie.");
      }
    } finally {
      setBusy(false);
    }
  }

  return (
    <section className="panel form-panel">
      <h1>Ustaw nowe hasło</h1>
      {done ? (
        <div className="notice success" role="status">
          <p>Hasło zostało zmienione. Możesz się teraz zalogować nowym hasłem.</p>
          <p>
            <Link to="/logowanie">Przejdź do logowania</Link>
          </p>
        </div>
      ) : expired ? (
        <div className="notice error" role="alert">
          <p>Link wygasł lub został już wykorzystany.</p>
          <p>
            <Link to="/odzyskiwanie-hasla">Wyślij nowy link</Link>
          </p>
        </div>
      ) : (
        <form onSubmit={submit}>
          <label>
            Nowe hasło
            <input
              type="password"
              required
              autoComplete="new-password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
            />
          </label>
          <small>Minimum 8 znaków, w tym litera i cyfra.</small>
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
          {error && (
            <p className="field-error" role="alert">
              {error}
            </p>
          )}
          <button className="button primary" disabled={busy}>
            {busy ? "Zapisywanie..." : "Zapisz nowe hasło"}
          </button>
        </form>
      )}
    </section>
  );
}
