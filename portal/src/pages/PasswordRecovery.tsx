import { Link } from "react-router-dom";

export function PasswordRecovery() {
  return (
    <section className="panel form-panel">
      <h1>Odzyskiwanie hasła</h1>
      <p>Odzyskiwanie hasła będzie dostępne wkrótce.</p>
      <Link to="/logowanie">Wróć do logowania</Link>
    </section>
  );
}
