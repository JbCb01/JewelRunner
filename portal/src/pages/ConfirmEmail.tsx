import { useEffect, useRef, useState } from "react";
import { Link, useSearchParams } from "react-router-dom";
import { api, ApiError } from "../api/client";
import type { Me } from "../api/types";
import { useAuth } from "../auth/AuthContext";
import { ErrorBox, Loading } from "../components/Status";

export function ConfirmEmail() {
  const [params] = useSearchParams();
  const { setUser } = useAuth();
  const token = params.get("token");
  const [state, setState] = useState<"pending" | "done" | "failed">(token ? "pending" : "failed");
  const [message, setMessage] = useState("Link jest nieprawidłowy lub wygasł.");
  // Token jest jednorazowy, a React w trybie deweloperskim uruchamia efekt dwa razy.
  const sent = useRef(false);

  useEffect(() => {
    if (!token || sent.current) return;
    sent.current = true;
    api<Me>("/me/email/confirm", { method: "POST", body: { token } })
      .then((me) => {
        setUser(me);
        setState("done");
      })
      .catch((caught: ApiError) => {
        if (caught.code === "email_taken") setMessage("Ten adres e-mail jest już zarejestrowany.");
        else if (caught.code !== "invalid_token") setMessage("Nie udało się potwierdzić adresu. Spróbuj ponownie.");
        setState("failed");
      });
  }, [token, setUser]);

  return (
    <section className="panel form-panel">
      <h1>Potwierdzenie adresu e-mail</h1>
      {state === "pending" && <Loading />}
      {state === "done" && (
        <p className="notice success" role="status">
          Adres e-mail został zmieniony.
        </p>
      )}
      {state === "failed" && <ErrorBox message={message} />}
      <Link to="/profil">Przejdź do profilu</Link>
    </section>
  );
}
