import { useEffect, useState } from "react";
import { api, ApiError } from "../api/client";
import type { ShopItem, ShopPurchaseResponse, ShopState } from "../api/types";
import { useAuth } from "../auth/AuthContext";
import { ErrorBox, Loading } from "../components/Status";
import { formatBoosterName } from "../lib/format";
import jewel from "../assets/jewel.png";

type Message = { kind: "success" | "error"; text: string } | null;

function makeIdempotencyKey(boosterId: number): string {
  const rand = Math.random().toString(36).slice(2, 10);
  return `shop-${boosterId}-${Date.now().toString(36)}-${rand}`;
}

export function Shop() {
  const { setGems } = useAuth();
  const [data, setData] = useState<ShopState | null>(null);
  const [loading, setLoading] = useState(true);
  const [offline, setOffline] = useState(false);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [attempt, setAttempt] = useState(0);

  const [pendingItem, setPendingItem] = useState<ShopItem | null>(null);
  const [pendingKey, setPendingKey] = useState<string>("");
  const [buying, setBuying] = useState(false);
  const [message, setMessage] = useState<Message>(null);

  useEffect(() => {
    let active = true;
    setLoading(true);
    setOffline(false);
    setLoadError(null);

    if (typeof navigator !== "undefined" && !navigator.onLine) {
      setOffline(true);
      setLoading(false);
      return;
    }

    api<ShopState>("/shop")
      .then((shop) => {
        if (!active) return;
        setData(shop);
        setGems(shop.balance);
      })
      .catch((caught: ApiError) => {
        if (!active) return;
        if (caught.isUnavailable) {
          setOffline(true);
        } else {
          setLoadError("Nie można załadować oferty sklepu.");
        }
      })
      .finally(() => {
        if (active) setLoading(false);
      });

    return () => {
      active = false;
    };
  }, [attempt, setGems]);

  function openConfirm(item: ShopItem) {
    setMessage(null);
    setPendingItem(item);
    setPendingKey(makeIdempotencyKey(item.booster_id));
  }

  function closeConfirm() {
    if (buying) return;
    setPendingItem(null);
    setPendingKey("");
  }

  async function confirmPurchase() {
    if (!pendingItem || buying) return;
    if (typeof navigator !== "undefined" && !navigator.onLine) {
      setPendingItem(null);
      setMessage({ kind: "error", text: "Sklep jest niedostępny offline." });
      return;
    }
    setBuying(true);
    setMessage(null);
    try {
      const result = await api<ShopPurchaseResponse>("/shop/purchase", {
        method: "POST",
        body: { booster_id: pendingItem.booster_id, idempotency_key: pendingKey },
      });
      setGems(result.balance);
      setData((prev) =>
        prev
          ? {
              balance: result.balance,
              items: prev.items.map((item) =>
                item.booster_id === result.booster_id ? { ...item, owned: result.owned } : item,
              ),
            }
          : prev,
      );
      setPendingItem(null);
      setPendingKey("");
      setMessage({
        kind: "success",
        text: `Kupiono: ${formatBoosterName(result.type)}. Nowe saldo: ${result.balance} klejnotów.`,
      });
    } catch (caught) {
      const err = caught as ApiError;
      setPendingItem(null);
      setPendingKey("");
      if (err.isUnavailable) {
        setMessage({ kind: "error", text: "Sklep jest niedostępny offline." });
      } else if (err.code === "insufficient_gems") {
        const missing = (err.details as { missing_gems?: number } | null)?.missing_gems;
        setMessage({
          kind: "error",
          text: missing ? `Brakuje ${missing} klejnotów.` : err.message,
        });
      } else if (err.code === "offer_unavailable") {
        setMessage({ kind: "error", text: "To wzmocnienie nie jest obecnie dostępne w sklepie." });
        setAttempt((v) => v + 1);
      } else {
        setMessage({ kind: "error", text: "Nie udało się zrealizować zakupu. Spróbuj ponownie." });
      }
    } finally {
      setBuying(false);
    }
  }

  return (
    <section>
      <div className="page-header-row">
        <h1>Sklep</h1>
        {data && (
          <div className="shop-balance" data-testid="shop-balance">
            <img src={jewel} alt="" width={22} height={22} />
            <span>Saldo: {data.balance} klejnotów</span>
          </div>
        )}
      </div>

      {loading && !data && <Loading />}
      {offline && (
        <ErrorBox message="Sklep jest niedostępny offline." onRetry={() => setAttempt((value) => value + 1)} />
      )}
      {loadError && <ErrorBox message={loadError} onRetry={() => setAttempt((value) => value + 1)} />}

      {message && (
        <p
          className={message.kind === "success" ? "notice success" : "notice error"}
          role={message.kind === "success" ? "status" : "alert"}
        >
          {message.text}
        </p>
      )}

      {data && (
        <div className="card-grid" data-testid="shop-grid">
          {data.items.map((item) => {
            const missing = Math.max(0, item.price - data.balance);
            return (
              <article key={item.booster_id} className="card shop-card" data-testid={`shop-item-${item.type}`}>
                <div className="card-title">
                  <h2>{formatBoosterName(item.type)}</h2>
                  <span className="badge" data-testid={`shop-owned-${item.type}`}>
                    Masz: {item.owned}
                  </span>
                </div>
                <p>{item.effect}</p>
                <p className="muted-text small-note">
                  {item.duration_s ? `Czas trwania: ${item.duration_s} s` : "Działanie jednorazowe"}
                </p>
                <p className="shop-price">
                  <strong>{item.price} klejnotów</strong>
                </p>
                {missing > 0 && <p className="field-error small-note">Brakuje {missing} klejnotów</p>}
                <button type="button" className="button primary" onClick={() => openConfirm(item)}>
                  Kup
                </button>
              </article>
            );
          })}
        </div>
      )}

      {pendingItem && (
        <div className="modal-backdrop" role="presentation">
          <div
            className="modal-panel"
            role="dialog"
            aria-modal="true"
            aria-labelledby="shop-confirm-title"
            data-testid="shop-confirm-modal"
          >
            <h2 id="shop-confirm-title">Potwierdzenie zakupu</h2>
            <p>
              Czy na pewno chcesz kupić <strong>{formatBoosterName(pendingItem.type)}</strong> za{" "}
              <strong>{pendingItem.price} klejnotów</strong>?
            </p>
            <div className="actions">
              <button type="button" className="button primary" onClick={confirmPurchase} disabled={buying}>
                {buying ? "Kupowanie..." : "Potwierdź zakup"}
              </button>
              <button type="button" className="button ghost" onClick={closeConfirm} disabled={buying}>
                Anuluj
              </button>
            </div>
          </div>
        </div>
      )}
    </section>
  );
}
