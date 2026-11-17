import { useState, type FormEvent } from "react";
import { Link } from "react-router-dom";
import { api, ApiError } from "../api/client";

export function PasswordRecovery() {
  const [email, setEmail] = useState("");
  const [busy, setBusy] = useState(false);
  const [sentMessage, setSentMessage] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  async function submit(event: FormEvent) {
    event.preventDefault();
    setBusy(true);
    setError(null);
    setSentMessage(null);
    try {
      const response = await api<{ status: string; message: string }>("/auth/forgot", {
        method: "POST",
        body: { email },
        allowAnonymous: true,
      });
      setSentMessage(response.message || "Jeśli konto istnieje, wysłaliśmy link do ustawienia nowego hasła.");
    } catch (caught) {
      const err = caught as ApiError;
      setError(
        err.code === "validation_error"
          ? "Podaj poprawny adres e-mail."
          : "Nie udało się wysłać żądania. Spróbuj ponownie.",
      );
    } finally {
      setBusy(false);
    }
  }

  return (
    <section className="panel form-panel">
      <h1>Odzyskiwanie hasła</h1>
      <p className="muted-text">Podaj adres e-mail konta, a wyślemy link do ustawienia nowego hasła.</p>
      <form onSubmit={submit}>
        <label>
          E-mail
          <input
            type="email"
            required
            autoComplete="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
          />
        </label>
        {sentMessage && (
          <p className="notice success" role="status">
            {sentMessage}
          </p>
        )}
        {error && (
          <p className="field-error" role="alert">
            {error}
          </p>
        )}
        <button className="button primary" disabled={busy}>
          {busy ? "Wysyłanie..." : "Wyślij link"}
        </button>
      </form>
      <p>
        <Link to="/logowanie">Wróć do logowania</Link>
      </p>
    </section>
  );
}
