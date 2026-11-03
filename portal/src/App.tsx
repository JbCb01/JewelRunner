import { Navigate, Route, Routes } from "react-router-dom";
import { Layout } from "./components/Layout";
import { RequireAuth } from "./components/RequireAuth";
import { Attempts } from "./pages/Attempts";
import { ChallengeDetails } from "./pages/ChallengeDetails";
import { Challenges } from "./pages/Challenges";
import { ConfirmEmail } from "./pages/ConfirmEmail";
import { Login } from "./pages/Login";
import { MyChallenges } from "./pages/MyChallenges";
import { NotFound } from "./pages/NotFound";
import { PasswordRecovery } from "./pages/PasswordRecovery";
import { PlayerProfile } from "./pages/PlayerProfile";
import { Profile } from "./pages/Profile";
import { Ranking } from "./pages/Ranking";
import { Register } from "./pages/Register";

export function App() {
  return (
    <Routes>
      <Route element={<Layout />}>
        <Route path="/logowanie" element={<Login />} />
        <Route path="/rejestracja" element={<Register />} />
        <Route path="/odzyskiwanie-hasla" element={<PasswordRecovery />} />
        <Route element={<RequireAuth />}>
          <Route path="/" element={<Navigate to="/wyzwania" replace />} />
          <Route path="/wyzwania" element={<Challenges />} />
          <Route path="/wyzwania/:id" element={<ChallengeDetails />} />
          <Route path="/moje-wyzwania" element={<MyChallenges />} />
          <Route path="/moje-wyzwania/:id" element={<Attempts />} />
          <Route path="/rankingi" element={<Ranking />} />
          <Route path="/gracze/:id" element={<PlayerProfile />} />
          <Route path="/profil" element={<Profile />} />
          <Route path="/potwierdz-email" element={<ConfirmEmail />} />
        </Route>
        <Route path="*" element={<NotFound />} />
      </Route>
    </Routes>
  );
}
