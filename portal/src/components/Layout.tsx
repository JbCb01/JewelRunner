import { Link, NavLink, Outlet, useNavigate } from "react-router-dom";
import { useAuth } from "../auth/AuthContext";
import { SPRITES } from "../lib/sprites";
import { DailyRewardModal } from "./DailyRewardModal";

const MENU = [
  ["/", "Start"],
  ["/wyzwania", "Wyzwania"],
  ["/moje-wyzwania", "Moje wyzwania"],
  ["/rankingi", "Rankingi"],
  ["/znajomi", "Znajomi"],
  ["/kolekcja", "Kolekcja"],
  ["/sklep", "Sklep"],
  ["/profil", "Profil"],
] as const;

/** Ekran powitalny obok formularzy logowania i rejestracji. */
function AuthHero() {
  return (
    <aside className="auth-hero" aria-hidden="true">
      <img className="auth-logo pixel" src={SPRITES.logo} alt="" />
      <p className="auth-tagline">Biegaj, skacz, zbieraj klejnoty i rywalizuj w rankingu!</p>
      <div className="auth-stage">
        <img className="auth-stelly pixel" src={SPRITES.stellyHero} alt="" />
        <img className="float-gem gem-1 pixel" src={SPRITES.jewel} alt="" />
        <img className="float-gem gem-2 pixel" src={SPRITES.jewelTeal} alt="" />
        <img className="float-gem gem-3 pixel" src={SPRITES.jewelSpeed} alt="" />
        <img className="float-gem gem-4 pixel" src={SPRITES.star} alt="" />
      </div>
      <ul className="auth-features">
        <li>
          <img className="pixel" src={SPRITES.jewel} alt="" /> Wyzwania i nagrody
        </li>
        <li>
          <img className="pixel" src={SPRITES.star} alt="" /> Ranking i znajomi
        </li>
        <li>
          <img className="pixel" src={SPRITES.jewelShield} alt="" /> Skórki i wzmocnienia
        </li>
      </ul>
    </aside>
  );
}

function Footer() {
  return (
    <footer className="site-footer">
      <div className="footer-parade" aria-hidden="true">
        <img className="pixel" src={SPRITES.enemySlime} alt="" />
        <img className="pixel" src={SPRITES.jewel} alt="" />
        <img className="pixel parade-runner" src={SPRITES.stellyRun} alt="" />
        <img className="pixel" src={SPRITES.enemyBat} alt="" />
        <img className="pixel" src={SPRITES.jewelTeal} alt="" />
        <img className="pixel" src={SPRITES.enemyCrab} alt="" />
      </div>
      <p>Jewel Runner · portal gracza · zespół 26KC2S1_JewelRunner</p>
    </footer>
  );
}

export function Layout() {
  const { user, gems, dailyReward, openDailyReward, logout } = useAuth();
  const navigate = useNavigate();

  async function handleLogout() {
    await logout().catch(() => undefined);
    navigate("/logowanie");
  }

  return (
    <>
      <header className="topbar">
        <Link to="/" className="brand" aria-label="Jewel Runner – strona główna">
          <img className="brand-logo pixel" src={SPRITES.logo} alt="Jewel Runner" />
        </Link>
        {user && (
          <nav aria-label="Menu główne">
            {MENU.map(([to, label]) => (
              <NavLink key={to} to={to} end={to === "/"}>
                {label}
              </NavLink>
            ))}
          </nav>
        )}
        {user && (
          <div className="account">
            {dailyReward?.available && (
              <button
                type="button"
                className="button accent-small"
                onClick={openDailyReward}
                data-testid="daily-reward-trigger"
              >
                Nagroda dzienna
              </button>
            )}
            <span className="wallet-pill" data-testid="header-gems" title="Saldo klejnotów">
              <img className="pixel" src={SPRITES.jewel} alt="" width={20} height={20} />
              {gems ?? "–"}
            </span>
            <span className="user-chip">
              <img className="pixel" src={SPRITES.stellyRun} alt="" />
              <span data-testid="current-user">{user.username}</span>
            </span>
            <button className="button ghost small" onClick={handleLogout}>
              Wyloguj
            </button>
          </div>
        )}
      </header>
      {user ? (
        <main className="content">
          <Outlet />
        </main>
      ) : (
        <main className="content auth-layout">
          <AuthHero />
          <div className="auth-main">
            <Outlet />
          </div>
        </main>
      )}
      <Footer />
      {user && <DailyRewardModal />}
    </>
  );
}
