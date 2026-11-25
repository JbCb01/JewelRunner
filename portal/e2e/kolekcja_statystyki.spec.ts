import { expect, test } from "@playwright/test";
import { pairGameSession, register } from "./helpers";

test.describe("4.6, 5.1-5.8, 8.3, 8.4 Statystyki, historia, kolekcja i odłączenie gry", () => {
  test("nowe konto widzi zachętę do gry, a po rozgrywkach statystyki, historię ze stronicowaniem i nowe skórki", async ({
    page,
  }) => {
    await register(page);
    await page.goto("/profil");

    // Stan zerowy i podsumowanie profilu (saldo + wygląd).
    await expect(page.getByTestId("stats-zero-notice")).toBeVisible();
    await expect(page.getByTestId("profile-gems")).toContainText("0 klejnotów");
    await expect(page.getByTestId("profile-appearance")).toContainText("Skórka podstawowa");

    // Parujemy grę i wysyłamy 12 rozgrywek, aby sprawdzić stronicowanie historii oraz odblokowanie skórki Noir Stelly (1000 pkt).
    const token = await pairGameSession(page);
    const headers = { Authorization: `Bearer ${token}`, Cookie: "" };
    for (let i = 1; i <= 12; i += 1) {
      const score = i === 12 ? 1200 : 100 + i * 10;
      const runRes = await page.request.post("/api/game/runs", {
        headers,
        data: {
          session_id: `SES-1763700000-${String(1000 + i)}`,
          level: 1,
          completed: true,
          score,
          time_s: 35.5,
          gems: 5,
          enemies_defeated: 2,
        },
      });
      expect(runRes.ok()).toBeTruthy();
    }

    await page.reload();
    await expect(page.getByTestId("stats-zero-notice")).toHaveCount(0);
    await expect(page.getByTestId("stats-levels-table")).toContainText("Poziom 1");
    await expect(page.getByTestId("stats-levels-table")).toContainText("1200");
    await expect(page.getByTestId("stats-levels-table")).toContainText("35.5 s");

    // Stronicowanie historii gier (10 na pierwszą stronę, potem +2).
    await expect(page.getByTestId("runs-table").locator("tbody tr")).toHaveCount(10);
    await page.getByRole("button", { name: "Załaduj więcej" }).click();
    await expect(page.getByTestId("runs-table").locator("tbody tr")).toHaveCount(12);

    // Odłączenie gry w profilu.
    await expect(page.getByTestId("game-link-status")).toHaveText("Połączone");
    await page.getByRole("button", { name: "Odłącz grę" }).click();
    await expect(page.getByTestId("game-link-status")).toHaveText("Niepołączone");

    // Kolekcja: tylko skórki (bez kolorów i akcesoriów), oznaczenie „Nowe”, wybór i zapis wyglądu.
    await page.goto("/kolekcja");
    await expect(page.getByRole("heading", { name: "Kolekcja skórek" })).toBeVisible();
    await expect(page.getByRole("tab")).toHaveCount(0);

    const noirCard = page.locator(".collection-card").filter({ hasText: "Noir Stelly" });
    await expect(noirCard).toBeVisible();
    await expect(noirCard.getByTestId("badge-new")).toHaveText("Nowe");
    await noirCard.getByRole("button", { name: "Wybierz" }).click();
    await page.getByRole("button", { name: "Zapisz wygląd" }).click();
    await expect(page.getByRole("status")).toContainText("Wygląd postaci został zapisany.");

    // Zablokowana skórka pokazuje warunek odblokowania.
    const cyberCard = page.locator(".collection-card").filter({ hasText: "2077 Stelly" });
    await expect(cyberCard).toContainText("Zablokowane");
    await expect(cyberCard).toContainText("2500 pkt");

    // Po odświeżeniu oznaczenie „Nowe” znika (POST /me/appearance/seen) i nowy wygląd jest zapisany.
    await page.reload();
    await expect(page.getByTestId("appearance-preview")).toContainText("Noir Stelly");
    await expect(page.locator(".collection-card").filter({ hasText: "Noir Stelly" }).getByTestId("badge-new")).toHaveCount(0);

    // Nowy wygląd widać też na profilu.
    await page.goto("/profil");
    await expect(page.getByTestId("profile-appearance")).toContainText("Noir Stelly");
  });

  test("błąd zapisu wyglądu (appearance_conflict) pokazuje komunikat", async ({ page }) => {
    await register(page);
    await page.goto("/kolekcja");
    await expect(page.getByTestId("appearance-preview")).toBeVisible();

    await page.route("**/api/me/appearance", (route) => {
      if (route.request().method() === "PUT") {
        return route.fulfill({
          status: 409,
          json: { error: { code: "appearance_conflict", message: "Konflikt", details: null } },
        });
      }
      return route.continue();
    });

    await page.getByRole("button", { name: "Zapisz wygląd" }).click();
    await expect(page.getByRole("alert")).toContainText("zmieniony na innym urządzeniu");
  });
});
