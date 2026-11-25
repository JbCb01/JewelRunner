import { Link } from "react-router-dom";
import type { AppearanceState, ItemList, MyChallenge, PlayerStats, Ranking } from "../api/types";
import { useAuth } from "../auth/AuthContext";
import { ProgressBar } from "../components/Status";
import { formatDuration, formatRemaining } from "../lib/format";
import { skinFilterClass, skinSprite, SPRITES } from "../lib/sprites";
import { useApi } from "../lib/useApi";

const PERIOD_LABEL: Record<string, string> = {
  tydzień: "w tym tygodniu",
  miesiąc: "w tym miesiącu",
  ogółem: "ogółem",
  znajomi: "wśród znajomych",
};

/** Strona startowa: najważniejsze informacje o graczu w jednym miejscu. */
export function Dashboard() {
  const { user, gems, dailyReward, openDailyReward } = useAuth();
  const appearance = useApi<AppearanceState>("/me/appearance");
  const stats = useApi<PlayerStats>("/me/stats");
  const challenges = useApi<ItemList<MyChallenge>>("/me/challenges");
  const ranking = useApi<Ranking>("/ranking");

  if (!user) return null;
  const skinName = appearance.data?.current?.skin.name;
  const active = (challenges.data?.items ?? []).filter((item) => item.status === "Aktywne").slice(0, 3);
  const toClaim = (challenges.data?.items ?? []).filter((item) => item.reward_status === "Do odebrania").length;
  const overall = stats.data?.overall;
  const newItems = appearance.data?.new_count ?? 0;

  return (
    <section className="dashboard">
      <div className="hero-banner">
        <div className="sprite-stage hero-stage" aria-hidden="true">
          <img className={`pixel ${skinFilterClass(skinName)}`} src={skinSprite(skinName)} alt="" />
          <img className="pixel hero-gem hg-1" src={SPRITES.jewel} alt="" />
          <img className="pixel hero-gem hg-2" src={SPRITES.jewelTeal} alt="" />
          <img className="pixel hero-gem hg-3" src={SPRITES.star} alt="" />
        </div>
        <div className="hero-text">
          <p className="hero-kicker">Witaj z powrotem,</p>
          <h1>{user.username}!</h1>
          <div className="hero-chips">
            <span className="hero-chip">
              <img className="pixel" src={SPRITES.jewel} alt="" /> {gems ?? "–"} klejnotów
            </span>
            {ranking.data?.me && (
              <span className="hero-chip">
                <img className="pixel" src={SPRITES.star} alt="" /> #{ranking.data.me.position}{" "}
                {PERIOD_LABEL[ranking.data.period ?? "ogółem"] ?? ""}
              </span>
            )}
            <span className={`hero-chip ${user.game_linked ? "ok" : "warn"}`}>
              {user.game_linked ? "Gra połączona" : "Gra niepołączona"}
            </span>
          </div>
          <div className="actions">
            {dailyReward?.available && (
              <button type="button" className="button accent-small big" onClick={openDailyReward}>
                Odbierz nagrodę dnia (+{dailyReward.gems})
              </button>
            )}
            <Link to="/wyzwania" className="button primary">
              Wybierz wyzwanie
            </Link>
            {!user.game_linked && (
              <Link to="/profil" className="button ghost">
                Połącz grę z kontem
              </Link>
            )}
          </div>
        </div>
      </div>

      <div className="tile-grid">
        <Link to="/moje-wyzwania" className="card tile">
          <img className="pixel tile-icon" src={SPRITES.jewelSpeed} alt="" />
          <span className="tile-value">{active.length}</span>
          <span className="tile-label">aktywne wyzwania</span>
          {toClaim > 0 && <span className="badge badge-special">{toClaim} do odebrania</span>}
        </Link>
        <Link to="/profil" className="card tile">
          <img className="pixel tile-icon" src={SPRITES.stellyRun} alt="" />
          <span className="tile-value">{overall ? overall.levels_completed : "–"}</span>
          <span className="tile-label">ukończone poziomy</span>
          {overall && <span className="tile-note">Czas gry: {formatDuration(overall.play_time_s)}</span>}
        </Link>
        <Link to="/rankingi" className="card tile">
          <img className="pixel tile-icon" src={SPRITES.star} alt="" />
          <span className="tile-value">{ranking.data?.me ? `#${ranking.data.me.position}` : "–"}</span>
          <span className="tile-label">miejsce w rankingu</span>
          {ranking.data?.me && <span className="tile-note">{ranking.data.me.score} pkt</span>}
        </Link>
        <Link to="/kolekcja" className="card tile">
          <img className={`pixel tile-icon tall ${skinFilterClass(skinName)}`} src={skinSprite(skinName)} alt="" />
          <span className="tile-value">{skinName ?? "–"}</span>
          <span className="tile-label">aktualna skórka</span>
          {newItems > 0 && <span className="badge badge-special">{newItems} nowe</span>}
        </Link>
      </div>

      <div className="panel">
        <div className="page-header-row">
          <h2>Twoje aktywne wyzwania</h2>
          <Link to="/moje-wyzwania" className="button ghost small">
            Wszystkie
          </Link>
        </div>
        {challenges.data && active.length === 0 && (
          <p className="notice info">
            Nie masz aktywnych wyzwań. <Link to="/wyzwania">Wybierz pierwsze wyzwanie</Link>
          </p>
        )}
        <ul className="quest-list">
          {active.map((item) => (
            <li key={item.challenge_id}>
              <Link to={`/moje-wyzwania/${item.challenge_id}`} className="quest-name">
                {item.name}
              </Link>
              <ProgressBar value={item.progress_percent} />
              <span className="muted-text small-note">
                {item.progress_percent}% · {formatRemaining(item.ends_at)}
              </span>
            </li>
          ))}
        </ul>
      </div>

      <div className="panel how-to">
        <h2>Jak grać z kontem?</h2>
        <ol className="steps">
          <li>
            <img className="pixel" src={SPRITES.jewelShield} alt="" />
            <strong>Przyjmij wyzwanie</strong>
            <span>Wybierz wyzwanie na stronie – pojawi się w grze.</span>
          </li>
          <li>
            <img className="pixel" src={SPRITES.jewelTeal} alt="" />
            <strong>Połącz grę</strong>
            <span>W profilu wygeneruj kod i wpisz go w grze.</span>
          </li>
          <li>
            <img className="pixel" src={SPRITES.stellyJump} alt="" />
            <strong>Graj i zbieraj</strong>
            <span>Wyniki, klejnoty i postęp trafiają tu same.</span>
          </li>
          <li>
            <img className="pixel" src={SPRITES.star} alt="" />
            <strong>Odbieraj nagrody</strong>
            <span>Skórki, wzmocnienia i miejsce w rankingu.</span>
          </li>
        </ol>
      </div>
    </section>
  );
}
