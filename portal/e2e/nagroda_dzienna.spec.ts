import { expect, test } from "@playwright/test";
import { login, PASSWORD, register } from "./helpers";

test.describe("7.5 Okno nagrody dziennej", () => {
  test("po zalogowaniu otwiera modal, zamknięcie zostawia nagrodę, a odbiór aktualizuje saldo", async ({ page }) => {
    const account = await register(page, undefined, { dismissDaily: false });
    const modal = page.getByTestId("daily-reward-modal");
    await expect(modal).toBeVisible();
    await expect(modal).toContainText("+10 klejnotów");
    await expect(modal).toContainText("Dzień serii: 1 z 7");

    // Zamknięcie bez odbioru -> nagroda nadal czeka i można ją otworzyć ponownie.
    await modal.getByRole("button", { name: "Zamknij" }).click();
    await expect(modal).toBeHidden();
    await expect(page.getByTestId("header-gems")).toContainText("0");
    await expect(page.getByTestId("daily-reward-trigger")).toBeVisible();

    // Po wylogowaniu i ponownym logowaniu okno nadal się pokazuje.
    await page.getByRole("button", { name: "Wyloguj" }).click();
    await login(page, { email: account.email, password: PASSWORD }, { dismissDaily: false });
    await expect(modal).toBeVisible();

    // Odbiór nagrody aktualizuje saldo w komunikacie i w nagłówku.
    await modal.getByRole("button", { name: "Odbierz" }).click();
    await expect(modal.getByRole("status")).toContainText("Nowe saldo: 10 klejnotów");
    await expect(page.getByTestId("header-gems")).toContainText("10");
    await modal.getByRole("button", { name: "Zamknij" }).click();
    await expect(page.getByTestId("daily-reward-trigger")).toHaveCount(0);
  });

  test("siódmy dzień serii jest oznaczony jako nagroda specjalna", async ({ page }) => {
    await page.route("**/api/me/daily-reward", (route) =>
      route.fulfill({
        json: {
          today: "2026-11-19",
          available: true,
          streak_day: 7,
          gems: 100,
          special: true,
          last_claimed: "2026-11-18",
          rewards: [
            { day: 1, gems: 10, special: false },
            { day: 2, gems: 15, special: false },
            { day: 3, gems: 20, special: false },
            { day: 4, gems: 25, special: false },
            { day: 5, gems: 30, special: false },
            { day: 6, gems: 40, special: false },
            { day: 7, gems: 100, special: true },
          ],
        },
      }),
    );

    await register(page, undefined, { dismissDaily: false });
    const modal = page.getByTestId("daily-reward-modal");
    await expect(modal).toBeVisible();
    await expect(page.getByTestId("daily-reward-special")).toHaveText("Nagroda specjalna");
    await expect(modal).toContainText("+100 klejnotów");
    await expect(modal).toContainText("Dzień serii: 7 z 7");
  });
});
