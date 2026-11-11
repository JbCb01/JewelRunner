import { useState, type FormEvent } from "react";
import { api, ApiError } from "../api/client";
import type { Me } from "../api/types";
import { useAuth } from "../auth/AuthContext";
import { validatePassword } from "../lib/format";

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
      </div>
    </section>
  );
}
