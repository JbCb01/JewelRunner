import { expect, test } from "@playwright/test";
import { CHALLENGE, lastResetToken, login, pairGameSession, register } from "./helpers";

test.describe("7.3 Sklep ze wzmocnieniami", () => {
  test("zakup wzmocnienia aktualizuje saldo i stan posiadania, a brak środków pokazuje brakującą kwotę", async ({
    page,
  }) => {
    await register(page);
    await page.goto("/sklep");

    // Nowe konto ma 0 klejnotów -> widać brakującą kwotę i błąd przy próbie zakupu.
    const shieldCard = page.getByTestId("shop-item-tarcza");
    await expect(shieldCard).toContainText("Masz: 0");
    await expect(shieldCard).toContainText("Brakuje 100 klejnotów");
    await shieldCard.getByRole("button", { name: "Kup" }).click();
    await page.getByTestId("shop-confirm-modal").getByRole("button", { name: "Potwierdź zakup" }).click();
    await expect(page.getByRole("alert")).toContainText("Brakuje 100 klejnotów");

    // Dodajemy 150 klejnotów przez synchronizację portfela z gry.
    const token = await pairGameSession(page);
    const sync = await page.request.post("/api/me/wallet/sync", {
      headers: { Authorization: `Bearer ${token}`, Cookie: "" },
      data: { operations: [{ id: "SES-1763700000-7777", gems: 150, reason: "poziom" }] },
    });
    expect(sync.ok()).toBeTruthy();

    await page.reload();
    await expect(page.getByTestId("shop-balance")).toContainText("150");
    await shieldCard.getByRole("button", { name: "Kup" }).click();
    await page.getByTestId("shop-confirm-modal").getByRole("button", { name: "Potwierdź zakup" }).click();

    await expect(page.getByRole("status")).toContainText("Kupiono: Tarcza");
    await expect(page.getByTestId("shop-balance")).toContainText("50");
    await expect(page.getByTestId("header-gems")).toContainText("50");
    await expect(page.getByTestId("shop-owned-tarcza")).toContainText("Masz: 1");
  });

  test("A4: niedostępność sieci pokazuje komunikat offline", async ({ page }) => {
    await register(page);
    await page.route("**/api/shop", (route) => route.abort());
    await page.goto("/sklep");
    await expect(page.getByRole("alert")).toContainText("Sklep jest niedostępny offline.");
  });
});

test.describe("2.5 Odbiór nagrody za wyzwanie", () => {
  test("odbiór nagrody w Moich wyzwaniach oraz w szczegółach wyzwania", async ({ page }) => {
    // 1. Odbiór w szczegółach wyzwania dla świeżego konta (Pierwsze kroki -> 50 klejnotów).
    await register(page);
    await page.goto(`/wyzwania/${CHALLENGE.firstSteps}`);
    await page.getByRole("button", { name: "Przyjmij wyzwanie" }).click();
    await expect(page.locator(".notice.success")).toBeVisible();

    const token = await pairGameSession(page);
    const runRes = await page.request.post("/api/game/runs", {
      headers: { Authorization: `Bearer ${token}`, Cookie: "" },
      data: {
        session_id: "SES-1763700000-8888",
        level: 1,
        completed: true,
        score: 300,
        time_s: 40.0,
        gems: 5,
        enemies_defeated: 1,
      },
    });
    expect(runRes.ok()).toBeTruthy();

    await page.reload();
    await page.getByRole("button", { name: "Odbierz nagrodę" }).click();
    await expect(page.getByRole("status")).toContainText("Odebrano 50 klejnotów");
    await expect(page.getByTestId("header-gems")).toContainText("50");
    await expect(page.getByText("Nagroda została już odebrana.")).toBeVisible();

    // 2. Odbiór w „Moich wyzwaniach” (Łowca klejnotów -> 200 klejnotów).
    await page.goto(`/wyzwania/${CHALLENGE.gemHunter}`);
    await page.getByRole("button", { name: "Przyjmij wyzwanie" }).click();
    await expect(page.locator(".notice.success")).toBeVisible();

    const runRes2 = await page.request.post("/api/game/runs", {
      headers: { Authorization: `Bearer ${token}`, Cookie: "" },
      data: {
        session_id: "SES-1763700000-8889",
        level: 1,
        completed: true,
        score: 400,
        time_s: 42.0,
        gems: 10,
        enemies_defeated: 2,
      },
    });
    expect(runRes2.ok()).toBeTruthy();

    await page.goto("/moje-wyzwania");
    const completedCard = page.locator(".card").filter({ hasText: "Łowca klejnotów" });
    await completedCard.getByRole("button", { name: "Odbierz nagrodę" }).click();
    await expect(page.locator(".notice.success")).toContainText("Odebrano 200 klejnotów");
    await expect(page.getByTestId("header-gems")).toContainText("250");
    await expect(completedCard).toContainText("Nagroda odebrana");
  });
});

test.describe("8.5 Odzyskiwanie hasła", () => {
  test("wysłanie linku, ustawienie nowego hasła, słabe hasło i wygasły token", async ({ page }) => {
    const account = await register(page);
    await page.getByRole("button", { name: "Wyloguj" }).click();

    // Nieistniejący e-mail daje ten sam komunikat.
    await page.goto("/odzyskiwanie-hasla");
    await page.getByLabel("E-mail").fill("nieistnieje@example.com");
    await page.getByRole("button", { name: "Wyślij link" }).click();
    await expect(page.getByRole("status")).toContainText("Jeśli konto istnieje, wysłaliśmy link");

    // Istniejący e-mail generuje link w logu backendu.
    await page.getByLabel("E-mail").fill(account.email);
    await page.getByRole("button", { name: "Wyślij link" }).click();
    await expect(page.getByRole("status")).toContainText("Jeśli konto istnieje, wysłaliśmy link");

    const token = lastResetToken();
    await page.goto(`/nowe-haslo?token=${token}`);

    // Słabe hasło zatrzymane z komunikatem.
    await page.getByLabel("Nowe hasło", { exact: true }).fill("slabe");
    await page.getByLabel("Powtórz nowe hasło").fill("slabe");
    await page.getByRole("button", { name: "Zapisz nowe hasło" }).click();
    await expect(page.getByRole("alert")).toContainText("co najmniej 8 znaków");

    // Poprawne nowe hasło działa.
    const nextPassword = "ResetHaslo99";
    await page.getByLabel("Nowe hasło", { exact: true }).fill(nextPassword);
    await page.getByLabel("Powtórz nowe hasło").fill(nextPassword);
    await page.getByRole("button", { name: "Zapisz nowe hasło" }).click();
    await expect(page.getByRole("status")).toContainText("Hasło zostało zmienione");

    // Ponowne użycie tego samego tokenu -> „Link wygasł” z opcją wysłania nowego.
    await page.goto(`/nowe-haslo?token=${token}`);
    await page.getByLabel("Nowe hasło", { exact: true }).fill("InneHaslo99");
    await page.getByLabel("Powtórz nowe hasło").fill("InneHaslo99");
    await page.getByRole("button", { name: "Zapisz nowe hasło" }).click();
    await expect(page.getByRole("alert")).toContainText("Link wygasł");
    await expect(page.getByRole("link", { name: "Wyślij nowy link" })).toBeVisible();

    // Logowanie nowym hasłem udaje się.
    await login(page, { email: account.email, password: nextPassword });
    await expect(page.getByTestId("current-user")).toHaveText(account.username);
  });
});
