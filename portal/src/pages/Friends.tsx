import { useState, type FormEvent } from "react";
import { Link } from "react-router-dom";
import { api, ApiError } from "../api/client";
import type { Friend, ItemList, PlayerSearchResult } from "../api/types";
import { ErrorBox, Loading } from "../components/Status";
import { formatDate } from "../lib/format";
import { useApi } from "../lib/useApi";

function friendError(error: ApiError): string {
  switch (error.code) {
    case "player_not_found":
      return "Nie znaleziono gracza o takiej nazwie.";
    case "already_friend":
      return "Ten gracz jest już na Twojej liście znajomych.";
    case "cannot_add_self":
      return "Nie możesz dodać samego siebie do znajomych.";
    case "too_many_friends":
      return "Osiągnięto limit 100 znajomych.";
    default:
      return "Nie udało się zaktualizować listy znajomych.";
  }
}

export function Friends() {
  const { data, error, loading, reload } = useApi<ItemList<Friend>>("/me/friends");
  const [query, setQuery] = useState("");
  const [results, setResults] = useState<PlayerSearchResult[] | null>(null);
  const [searching, setSearching] = useState(false);
  const [searchError, setSearchError] = useState<string | null>(null);
  const [actionMessage, setActionMessage] = useState<{ kind: "success" | "error"; text: string } | null>(null);
  const [busyId, setBusyId] = useState<string | null>(null);

  async function handleSearch(event: FormEvent) {
    event.preventDefault();
    const trimmed = query.trim();
    if (trimmed.length < 2) {
      setSearchError("Wpisz co najmniej 2 znaki nazwy gracza.");
      setResults(null);
      return;
    }
    setSearching(true);
    setSearchError(null);
    setActionMessage(null);
    try {
      const response = await api<ItemList<PlayerSearchResult>>(
        `/players?search=${encodeURIComponent(trimmed)}`,
      );
      setResults(response.items);
    } catch (caught) {
      const err = caught as ApiError;
      setSearchError(err.isUnavailable ? "Brak połączenia z serwerem." : "Nie udało się wyszukać graczy.");
    } finally {
      setSearching(false);
    }
  }

  async function handleAdd(username: string, playerId?: string) {
    setBusyId(playerId ?? username);
    setActionMessage(null);
    try {
      await api("/me/friends", { method: "POST", body: { username } });
      setActionMessage({ kind: "success", text: `Dodano gracza ${username} do znajomych.` });
      setResults((prev) =>
        prev ? prev.map((item) => (item.username === username ? { ...item, is_friend: true } : item)) : prev,
      );
      reload();
    } catch (caught) {
      setActionMessage({ kind: "error", text: friendError(caught as ApiError) });
    } finally {
      setBusyId(null);
    }
  }

  async function handleRemove(friend: Friend) {
    setBusyId(friend.player_id);
    setActionMessage(null);
    try {
      await api(`/me/friends/${friend.player_id}`, { method: "DELETE" });
      setActionMessage({ kind: "success", text: `Usunięto gracza ${friend.username} ze znajomych.` });
      setResults((prev) =>
        prev ? prev.map((item) => (item.player_id === friend.player_id ? { ...item, is_friend: false } : item)) : prev,
      );
      reload();
    } catch (caught) {
      setActionMessage({ kind: "error", text: friendError(caught as ApiError) });
    } finally {
      setBusyId(null);
    }
  }

  return (
    <section className="stack-lg">
      <div className="panel">
        <div className="page-header-row">
          <h1>Znajomi</h1>
          <Link to="/rankingi" className="button ghost">
            Ranking znajomych
          </Link>
        </div>

        <form onSubmit={handleSearch} className="inline-search-form" aria-label="Wyszukaj gracza">
          <label className="grow">
            Wyszukaj gracza (min. 2 znaki)
            <input
              type="search"
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder="Np. gracz001"
            />
          </label>
          <button type="submit" className="button primary" disabled={searching}>
            {searching ? "Szukanie..." : "Szukaj"}
          </button>
        </form>

        {searchError && (
          <p className="field-error" role="alert">
            {searchError}
          </p>
        )}
        {actionMessage && (
          <p
            className={actionMessage.kind === "success" ? "notice success" : "notice error"}
            role={actionMessage.kind === "success" ? "status" : "alert"}
          >
            {actionMessage.text}
          </p>
        )}

        {results !== null && (
          <div className="search-results" data-testid="friend-search-results">
            <h2>Wyniki wyszukiwania</h2>
            {results.length === 0 ? (
              <p className="notice info">Nie znaleziono pasujących graczy.</p>
            ) : (
              <table>
                <thead>
                  <tr>
                    <th>Gracz</th>
                    <th>Akcja</th>
                  </tr>
                </thead>
                <tbody>
                  {results.map((player) => (
                    <tr key={player.player_id}>
                      <td>
                        <Link to={`/gracze/${player.player_id}`}>{player.username}</Link>
                      </td>
                      <td>
                        {player.is_friend ? (
                          <span className="badge badge-linked">Znajomy</span>
                        ) : (
                          <button
                            type="button"
                            className="button primary"
                            disabled={busyId === player.player_id}
                            onClick={() => handleAdd(player.username, player.player_id)}
                          >
                            Dodaj do znajomych
                          </button>
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </div>
        )}
      </div>

      <div className="panel">
        <h2>Twoi znajomi</h2>
        {loading && <Loading />}
        {error && <ErrorBox message="Nie można pobrać listy znajomych." onRetry={reload} />}
        {data && data.items.length === 0 && <p className="notice info">Nie masz jeszcze żadnych znajomych.</p>}
        {data && data.items.length > 0 && (
          <table data-testid="friends-table">
            <thead>
              <tr>
                <th>Gracz</th>
                <th>Wynik ogólny</th>
                <th>Dodano</th>
                <th>Akcja</th>
              </tr>
            </thead>
            <tbody>
              {data.items.map((friend) => (
                <tr key={friend.player_id}>
                  <td>
                    <Link to={`/gracze/${friend.player_id}`}>{friend.username}</Link>
                  </td>
                  <td>{friend.score ?? "–"}</td>
                  <td>{formatDate(friend.added_at)}</td>
                  <td>
                    <button
                      type="button"
                      className="button ghost"
                      disabled={busyId === friend.player_id}
                      onClick={() => handleRemove(friend)}
                    >
                      Usuń
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </section>
  );
}
