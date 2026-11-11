import { expect, test } from "@playwright/test";
import { DEMO, PASSWORD, register, unique, login } from "./helpers";

test.describe("8.1 Utworzenie profilu", () => {
  test("scenariusz główny: rejestracja loguje gracza i otwiera portal", async ({ page }) => {
    const account = unique();
    await register(page, account);
    await expect(page).toHaveURL(/\/wyzwania$/);
    await expect(page.getByRole("heading", { name: "Wyzwania" })).toBeVisible();
    await page.reload();
    await expect(page.getByTestId("current-user")).toHaveText(account.username);
  });

  test("A1: zajęta nazwa", async ({ page }) => {
    const taken = await register(page);
    await page.getByRole("button", { name: "Wyloguj" }).click();
    await page.goto("/rejestracja");
    await page.getByLabel("Nazwa użytkownika").fill(taken.username.toUpperCase());
    await page.getByLabel("E-mail").fill(unique().email);
    await page.getByLabel("Hasło").fill(PASSWORD);
    await page.getByRole("button", { name: "Utwórz konto" }).click();
    await expect(page.getByRole("alert")).toHaveText("Nazwa jest zajęta.");
  });

  test("A2: zarejestrowany e-mail daje odnośniki", async ({ page }) => {
    await page.goto("/rejestracja");
    await page.getByLabel("Nazwa użytkownika").fill(unique().username);
    await page.getByLabel("E-mail").fill(DEMO.email);
    await page.getByLabel("Hasło").fill(PASSWORD);
    await page.getByRole("button", { name: "Utwórz konto" }).click();
    const alert = page.getByRole("alert");
    await expect(alert.getByRole("link", { name: "Zaloguj się" })).toBeVisible();
    await alert.getByRole("link", { name: "odzyskaj hasło" }).click();
    await expect(page.getByRole("heading", { name: "Odzyskiwanie hasła" })).toBeVisible();
  });

  test("A3: zbyt słabe hasło jest zatrzymane w formularzu", async ({ page }) => {
    let called = false;
    await page.route("**/api/auth/register", (route) => {
      called = true;
      return route.continue();
    });
    await page.goto("/rejestracja");
    await page.getByLabel("Nazwa użytkownika").fill(unique().username);
    await page.getByLabel("E-mail").fill(unique().email);
    await page.getByLabel("Hasło").fill("samelitery");
    await page.getByRole("button", { name: "Utwórz konto" }).click();
    await expect(page.getByRole("alert")).toContainText("co najmniej 8 znaków");
    expect(called).toBe(false);
  });

  test("A4: logowanie istniejącym kontem i wylogowanie", async ({ page }) => {
    await login(page, DEMO);
    await expect(page.getByTestId("current-user")).toHaveText("Demo");
    await page.getByRole("button", { name: "Wyloguj" }).click();
    await expect(page).toHaveURL(/\/logowanie$/);
    await page.goto("/profil");
    await expect(page).toHaveURL(/\/logowanie$/);
  });

  test("błędne hasło pokazuje komunikat", async ({ page }) => {
    await page.goto("/logowanie");
    await page.getByLabel("E-mail").fill(unique().email);
    await page.getByLabel("Hasło").fill("Zle12345");
    await page.getByRole("button", { name: "Zaloguj się" }).click();
    await expect(page.getByRole("alert")).toHaveText("Nieprawidłowy login lub hasło.");
  });

  test("niezalogowany wraca po logowaniu na żądaną stronę", async ({ page }) => {
    await page.goto("/rankingi");
    await expect(page).toHaveURL(/\/logowanie$/);
    await page.getByLabel("E-mail").fill(DEMO.email);
    await page.getByLabel("Hasło").fill(DEMO.password);
    await page.getByRole("button", { name: "Zaloguj się" }).click();
    await expect(page).toHaveURL(/\/rankingi$/);
  });

  test("po wygaśnięciu sesji portal prosi o ponowne logowanie", async ({ page, context }) => {
    await login(page, DEMO);
    await expect(page.locator(".card")).toHaveCount(3);
    await context.clearCookies();
    await page.getByRole("link", { name: "Rankingi" }).click();
    await expect(page.getByText("Sesja wygasła. Zaloguj się ponownie.")).toBeVisible();
  });
});
