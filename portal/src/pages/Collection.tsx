import { useEffect, useRef, useState } from "react";
import { api, ApiError } from "../api/client";
import type { AppearanceCatalogItem, AppearanceCurrent, AppearanceState } from "../api/types";
import { ErrorBox, Loading } from "../components/Status";
import { formatUnlockCondition } from "../lib/format";
import { skinFilterClass, skinSprite } from "../lib/sprites";
import { useApi } from "../lib/useApi";

type Message = { kind: "success" | "error"; text: string } | null;

function appearanceError(error: ApiError): string {
  switch (error.code) {
    case "element_not_owned":
      return "Ten element jest zablokowany i nie należy do Twojej kolekcji.";
    case "appearance_conflict":
      return "Wygląd został zmieniony na innym urządzeniu. Załadowano aktualny stan.";
    default:
      return "Nie udało się zapisać wyglądu postaci.";
  }
}

export function Collection() {
  const { data, error, loading, reload } = useApi<AppearanceState>("/me/appearance");
  const [selectedSkinId, setSelectedSkinId] = useState<number | null>(null);
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState<Message>(null);
  const seenSentRef = useRef(false);
  const saveSeqRef = useRef(0);

  useEffect(() => {
    if (data?.current) setSelectedSkinId(data.current.skin.id);
  }, [data]);

  useEffect(() => {
    if (!data || data.new_count <= 0 || seenSentRef.current) return;
    seenSentRef.current = true;
    api("/me/appearance/seen", { method: "POST", body: {} }).catch(() => undefined);
  }, [data]);

  // Portal pokazuje tylko skórki. Kolorów i akcesoriów nie używamy, więc serwerowi wysyłamy
  // dotychczasowy kolor bez zmian i pustą listę akcesoriów.
  const skins = (data?.catalog ?? []).filter((item) => item.type === "skórka");
  const selectedSkin = skins.find((item) => item.id === selectedSkinId);
  const currentColorId = data?.current?.color.id ?? null;
  const newSkins = skins.filter((item) => item.is_new).length;

  async function persistAppearance(skinId: number, lockButton: boolean) {
    if (currentColorId === null) return;
    const seq = ++saveSeqRef.current;
    if (lockButton) setBusy(true);
    setMessage(null);
    try {
      const updated = await api<AppearanceCurrent>("/me/appearance", {
        method: "PUT",
        body: { skin_id: skinId, color_id: currentColorId, accessories: [] },
      });
      if (seq !== saveSeqRef.current) return;
      setSelectedSkinId(updated.skin.id);
      setMessage({ kind: "success", text: "Wygląd postaci został zapisany." });
    } catch (caught) {
      if (seq !== saveSeqRef.current) return;
      const err = caught as ApiError;
      setMessage({ kind: "error", text: appearanceError(err) });
      if (err.code === "appearance_conflict") reload();
    } finally {
      if (lockButton) setBusy(false);
    }
  }

  function handleSelect(item: AppearanceCatalogItem) {
    if (!item.owned) return;
    setSelectedSkinId(item.id);
    void persistAppearance(item.id, false);
  }

  async function handleSave() {
    if (selectedSkinId === null) return;
    await persistAppearance(selectedSkinId, true);
  }

  const skinName = selectedSkin?.name ?? data?.current?.skin.name;

  return (
    <section className="stack-lg">
      <div className="panel">
        <h1>Kolekcja skórek</h1>
        {loading && !data && <Loading />}
        {error && <ErrorBox message="Nie można pobrać kolekcji." onRetry={reload} />}
        {data && (
          <>
            <div className="appearance-preview" data-testid="appearance-preview">
              <div className="sprite-stage large" aria-hidden="true">
                <img className={`pixel ${skinFilterClass(skinName)}`} src={skinSprite(skinName)} alt="" />
              </div>
              <div className="appearance-summary">
                <p className="muted-text small-note">Aktualna skórka</p>
                <p className="preview-skin-name">{skinName ?? "–"}</p>
                <p className="muted-text small-note">
                  Posiadasz {skins.filter((item) => item.owned).length} z {skins.length} skórek
                  {newSkins > 0 && ` · ${newSkins} nowe`}
                </p>
              </div>
              <button type="button" className="button primary" onClick={handleSave} disabled={busy}>
                {busy ? "Zapisywanie..." : "Zapisz wygląd"}
              </button>
            </div>

            {message && (
              <p
                className={message.kind === "success" ? "notice success" : "notice error"}
                role={message.kind === "success" ? "status" : "alert"}
              >
                {message.text}
              </p>
            )}

            <div className="card-grid" data-testid="collection-grid">
              {skins.map((item) => {
                const active = item.id === selectedSkinId;
                return (
                  <article
                    key={item.id}
                    className={`card collection-card${active ? " selected" : ""}${!item.owned ? " locked" : ""}`}
                    data-testid={`collection-item-${item.id}`}
                  >
                    <div className="card-title">
                      <h2>{item.name}</h2>
                      <div className="badge-group">
                        {item.is_new && (
                          <span className="badge badge-special" data-testid="badge-new">
                            Nowe
                          </span>
                        )}
                        {active && <span className="badge badge-linked">Wybrane</span>}
                        {!item.owned && <span className="badge badge-unlinked">Zablokowane</span>}
                      </div>
                    </div>
                    <div className="sprite-stage" aria-hidden="true">
                      <img className={`pixel ${skinFilterClass(item.name)}`} src={skinSprite(item.name)} alt="" />
                    </div>
                    {item.owned ? (
                      <button
                        type="button"
                        className={`button ${active ? "ghost" : "primary"}`}
                        onClick={() => handleSelect(item)}
                      >
                        {active ? "Wybrane" : "Wybierz"}
                      </button>
                    ) : (
                      <p className="muted-text small-note">{formatUnlockCondition(item.unlock_condition)}</p>
                    )}
                  </article>
                );
              })}
            </div>
          </>
        )}
      </div>
    </section>
  );
}
