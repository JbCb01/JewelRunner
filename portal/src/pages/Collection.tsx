import { useEffect, useRef, useState } from "react";
import { api, ApiError } from "../api/client";
import type {
  AppearanceCatalogItem,
  AppearanceCurrent,
  AppearanceState,
  AppearanceType,
} from "../api/types";
import { ErrorBox, Loading } from "../components/Status";
import { formatUnlockCondition } from "../lib/format";
import { useApi } from "../lib/useApi";

const TABS: { type: AppearanceType; label: string }[] = [
  { type: "skórka", label: "Skórki" },
  { type: "kolor", label: "Kolory" },
  { type: "akcesorium", label: "Akcesoria" },
];

type Message = { kind: "success" | "error"; text: string } | null;

function appearanceError(error: ApiError): string {
  switch (error.code) {
    case "element_not_owned":
      return "Ten element jest zablokowany i nie należy do Twojej kolekcji.";
    case "slot_taken":
      return "W jednym miejscu na postaci może być tylko jedno akcesorium.";
    case "appearance_conflict":
      return "Wygląd został zmieniony na innym urządzeniu. Załadowano aktualny stan.";
    default:
      return "Nie udało się zapisać wyglądu postaci.";
  }
}

export function Collection() {
  const { data, error, loading, reload } = useApi<AppearanceState>("/me/appearance");
  const [tab, setTab] = useState<AppearanceType>("skórka");
  const [selectedSkinId, setSelectedSkinId] = useState<number | null>(null);
  const [selectedColorId, setSelectedColorId] = useState<number | null>(null);
  const [selectedAccessories, setSelectedAccessories] = useState<Record<string, number>>({});
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState<Message>(null);
  const seenSentRef = useRef(false);
  const saveSeqRef = useRef(0);

  useEffect(() => {
    if (!data?.current) return;
    setSelectedSkinId(data.current.skin.id);
    setSelectedColorId(data.current.color.id);
    const accMap: Record<string, number> = {};
    for (const acc of data.current.accessories) {
      accMap[acc.slot] = acc.accessory.id;
    }
    setSelectedAccessories(accMap);
  }, [data]);

  useEffect(() => {
    if (!data || data.new_count <= 0 || seenSentRef.current) return;
    seenSentRef.current = true;
    api("/me/appearance/seen", { method: "POST", body: {} }).catch(() => undefined);
  }, [data]);

  const catalog = data?.catalog ?? [];
  const itemsInTab = catalog.filter((item) => item.type === tab);

  const selectedSkin = catalog.find((item) => item.id === selectedSkinId);
  const selectedColor = catalog.find((item) => item.id === selectedColorId);
  const equippedAccessories = Object.values(selectedAccessories)
    .map((id) => catalog.find((item) => item.id === id))
    .filter((item): item is AppearanceCatalogItem => Boolean(item));

  async function persistAppearance(
    skinId: number,
    colorId: number,
    accMap: Record<string, number>,
    lockButton: boolean,
  ) {
    const seq = ++saveSeqRef.current;
    if (lockButton) {
      setBusy(true);
    }
    setMessage(null);
    try {
      const updated = await api<AppearanceCurrent>("/me/appearance", {
        method: "PUT",
        body: {
          skin_id: skinId,
          color_id: colorId,
          accessories: Object.values(accMap).map((accessory_id) => ({
            accessory_id,
            color_id: colorId,
          })),
        },
      });
      if (seq !== saveSeqRef.current) return;
      setSelectedSkinId(updated.skin.id);
      setSelectedColorId(updated.color.id);
      const nextAcc: Record<string, number> = {};
      for (const acc of updated.accessories) {
        nextAcc[acc.slot] = acc.accessory.id;
      }
      setSelectedAccessories(nextAcc);
      setMessage({ kind: "success", text: "Wygląd postaci został zapisany." });
    } catch (caught) {
      if (seq !== saveSeqRef.current) return;
      const err = caught as ApiError;
      setMessage({ kind: "error", text: appearanceError(err) });
      if (err.code === "appearance_conflict") {
        reload();
      }
    } finally {
      if (lockButton) {
        setBusy(false);
      }
    }
  }

  function handleSelect(item: AppearanceCatalogItem) {
    if (!item.owned) return;
    let nextSkinId = selectedSkinId;
    let nextColorId = selectedColorId;
    let nextAcc = selectedAccessories;

    if (item.type === "skórka") {
      nextSkinId = item.id;
      setSelectedSkinId(nextSkinId);
    } else if (item.type === "kolor") {
      nextColorId = item.id;
      setSelectedColorId(nextColorId);
    } else if (item.type === "akcesorium" && item.slot) {
      nextAcc = { ...selectedAccessories };
      if (nextAcc[item.slot] === item.id) {
        delete nextAcc[item.slot];
      } else {
        nextAcc[item.slot] = item.id;
      }
      setSelectedAccessories(nextAcc);
    }

    if (nextSkinId !== null && nextColorId !== null) {
      void persistAppearance(nextSkinId, nextColorId, nextAcc, false);
    }
  }

  function isSelected(item: AppearanceCatalogItem): boolean {
    if (item.type === "skórka") return item.id === selectedSkinId;
    if (item.type === "kolor") return item.id === selectedColorId;
    if (item.type === "akcesorium" && item.slot) return selectedAccessories[item.slot] === item.id;
    return false;
  }

  async function handleSave() {
    if (selectedSkinId === null || selectedColorId === null) return;
    await persistAppearance(selectedSkinId, selectedColorId, selectedAccessories, true);
  }

  return (
    <section className="stack-lg">
      <div className="panel">
        <h1>Kolekcja i wygląd postaci</h1>
        {loading && !data && <Loading />}
        {error && <ErrorBox message="Nie można pobrać kolekcji." onRetry={reload} />}

        {data && (
          <>
            <div className="appearance-preview" data-testid="appearance-preview">
              <div
                className="appearance-swatch-lg"
                style={{ backgroundColor: selectedColor?.color_hex ?? "#6A3FB5" }}
                aria-hidden="true"
              />
              <div className="appearance-summary">
                <p>
                  <strong>Skórka:</strong> {selectedSkin?.name ?? data.current?.skin.name ?? "–"}
                </p>
                <p>
                  <strong>Kolor:</strong> {selectedColor?.name ?? data.current?.color.name ?? "–"}
                </p>
                <p>
                  <strong>Akcesoria:</strong>{" "}
                  {equippedAccessories.length > 0
                    ? equippedAccessories.map((acc) => `${acc.name} (${acc.slot})`).join(", ")
                    : "Brak"}
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

            <div className="filter-bar" role="tablist" aria-label="Kategorie kolekcji">
              {TABS.map((entry) => {
                const newInTab = catalog.filter((item) => item.type === entry.type && item.is_new).length;
                return (
                  <button
                    key={entry.type}
                    type="button"
                    role="tab"
                    aria-selected={tab === entry.type}
                    className={`button filter-btn${tab === entry.type ? " active" : ""}`}
                    onClick={() => setTab(entry.type)}
                  >
                    {entry.label}
                    {newInTab > 0 && <span className="tab-dot"> ({newInTab} nowe)</span>}
                  </button>
                );
              })}
            </div>

            <div className="card-grid" data-testid="collection-grid">
              {itemsInTab.map((item) => {
                const active = isSelected(item);
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

                    {item.color_hex && (
                      <div className="color-row">
                        <span className="color-dot" style={{ backgroundColor: item.color_hex }} aria-hidden="true" />
                        <code>{item.color_hex}</code>
                      </div>
                    )}
                    {item.slot && <p className="muted-text">Miejsce: {item.slot}</p>}

                    {item.owned ? (
                      <button
                        type="button"
                        className={`button ${active ? "ghost" : "primary"}`}
                        onClick={() => handleSelect(item)}
                      >
                        {item.type === "akcesorium" ? (active ? "Zdejmij" : "Załóż") : active ? "Wybrane" : "Wybierz"}
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
