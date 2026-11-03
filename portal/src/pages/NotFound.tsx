import { Link } from "react-router-dom";

export function NotFound() {
  return (
    <section className="panel form-panel">
      <h1>Nie znaleziono strony</h1>
      <Link to="/">Wróć na stronę główną</Link>
    </section>
  );
}
