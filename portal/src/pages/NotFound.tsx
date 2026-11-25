import { Link } from "react-router-dom";
import { SPRITES } from "../lib/sprites";

export function NotFound() {
  return (
    <section className="panel form-panel not-found">
      <div className="not-found-art" aria-hidden="true">
        <img className="pixel" src={SPRITES.enemySlime} alt="" />
        <img className="pixel" src={SPRITES.enemyBat} alt="" />
        <img className="pixel" src={SPRITES.enemyCrab} alt="" />
      </div>
      <h1>Nie znaleziono strony</h1>
      <p className="muted-text">Wygląda na to, że ten poziom jeszcze nie istnieje.</p>
      <Link to="/" className="button primary">
        Wróć na stronę główną
      </Link>
    </section>
  );
}
