import { Link, NavLink, Outlet, useNavigate } from "react-router-dom";
import { useAuth } from "../auth/AuthContext";
import jewel from "../assets/jewel.png";
import { DailyRewardModal } from "./DailyRewardModal";

const MENU = [
  ["/wyzwania", "Wyzwania"],
  ["/moje-wyzwania", "Moje wyzwania"],
  ["/rankingi", "Rankingi"],
  ["/znajomi", "Znajomi"],
  ["/kolekcja", "Kolekcja"],
  ["/sklep", "Sklep"],
  ["/profil", "Profil"],
] as const;

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
        <Link to="/" className="brand">
          <img src={jewel} alt="" width={28} height={28} />
          Jewel Runner
        </Link>
        {user && (
          <nav aria-label="Menu główne">
            {MENU.map(([to, label]) => (
              <NavLink key={to} to={to}>
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
              <img src={jewel} alt="" width={18} height={18} />
              {gems ?? "–"}
            </span>
            <span data-testid="current-user">{user.username}</span>
            <button className="button ghost" onClick={handleLogout}>
              Wyloguj
            </button>
          </div>
        )}
      </header>
      <main className="content">
        <Outlet />
      </main>
      {user && <DailyRewardModal />}
    </>
  );
}
