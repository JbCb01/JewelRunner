import { expect, test } from "@playwright/test";
import { PASSWORD, lastEmailToken, login, register, unique } from "./helpers";

test.describe("8.6 Zmiana danych zalogowanego użytkownika", () => {
  test("zmiana nazwy jest widoczna w nagłówku", async ({ page }) => {
    await register(page);
    await page.goto("/profil");
    const name = unique("nowy").username;
    const form = page.getByRole("form", { name: "Zmiana nazwy" });
    await form.getByLabel("Nowa nazwa").fill(name);
    await form.getByRole("button", { name: "Zapisz nazwę" }).click();
    await expect(page.getByTestId("current-user")).toHaveText(name);
    await page.reload();
    await expect(page.getByTestId("current-user")).toHaveText(name);
  });

  test("A1: zajęta nazwa nie zmienia danych", async ({ page }) => {
    const me = await register(page);
    await page.goto("/profil");
    const form = page.getByRole("form", { name: "Zmiana nazwy" });
    await form.getByLabel("Nowa nazwa").fill("Maku");
    await form.getByRole("button", { name: "Zapisz nazwę" }).click();
    await expect(form.getByRole("alert")).toHaveText("Nazwa jest zajęta.");
    await expect(page.getByTestId("current-user")).toHaveText(me.username);
  });

  test("A3: anulowanie przywraca nazwę", async ({ page }) => {
    const me = await register(page);
    await page.goto("/profil");
    const form = page.getByRole("form", { name: "Zmiana nazwy" });
    await form.getByLabel("Nowa nazwa").fill("cos_innego");
    await form.getByRole("button", { name: "Anuluj" }).click();
    await expect(form.getByLabel("Nowa nazwa")).toHaveValue(me.username);
  });

  test("A2: zmiana e-maila po potwierdzeniu linkiem", async ({ page }) => {
    const me = await register(page);
    const next = unique("zmiana").email;
    await page.goto("/profil");
    const form = page.getByRole("form", { name: "Zmiana e-maila" });
    await form.getByLabel("Nowy adres e-mail").fill(next);
    await form.getByLabel("Aktualne hasło").fill(PASSWORD);
    await form.getByRole("button", { name: "Zmień e-mail" }).click();
    await expect(form.getByRole("status")).toContainText(`link potwierdzający na adres ${next}`);
    await expect(form).toContainText(me.email);

    await page.goto(`/potwierdz-email?token=${lastEmailToken()}`);
    await expect(page.getByText("Adres e-mail został zmieniony.")).toBeVisible();
    await page.getByRole("button", { name: "Wyloguj" }).click();
    await login(page, { email: next, password: PASSWORD });
  });

  test("A2: błędne hasło przy zmianie e-maila", async ({ page }) => {
    await register(page);
    await page.goto("/profil");
    const form = page.getByRole("form", { name: "Zmiana e-maila" });
    await form.getByLabel("Nowy adres e-mail").fill(unique().email);
    await form.getByLabel("Aktualne hasło").fill("Zle12345");
    await form.getByRole("button", { name: "Zmień e-mail" }).click();
    await expect(form.getByRole("alert")).toHaveText("Aktualne hasło jest nieprawidłowe.");
  });

  test("nieprawidłowy link potwierdzający", async ({ page }) => {
    await register(page);
    await page.goto("/potwierdz-email?token=zly");
    await expect(page.getByRole("alert")).toContainText("Link jest nieprawidłowy lub wygasł.");
  });

  test("A2: zmiana hasła", async ({ page }) => {
    const me = await register(page);
    const newPassword = "NoweHaslo99";
    await page.goto("/profil");
    const form = page.getByRole("form", { name: "Zmiana hasła" });
    await form.getByLabel("Aktualne hasło").fill(PASSWORD);
    await form.getByLabel("Nowe hasło", { exact: true }).fill(newPassword);
    await form.getByLabel("Powtórz nowe hasło").fill(newPassword);
    await form.getByRole("button", { name: "Zmień hasło" }).click();
    await expect(form.getByRole("status")).toHaveText("Hasło zostało zmienione.");
    await page.getByRole("button", { name: "Wyloguj" }).click();
    await login(page, { email: me.email, password: newPassword });
  });

  test("różne hasła są zatrzymane w formularzu", async ({ page }) => {
    await register(page);
    await page.goto("/profil");
    const form = page.getByRole("form", { name: "Zmiana hasła" });
    await form.getByLabel("Aktualne hasło").fill(PASSWORD);
    await form.getByLabel("Nowe hasło", { exact: true }).fill("NoweHaslo99");
    await form.getByLabel("Powtórz nowe hasło").fill("InneHaslo99");
    await form.getByRole("button", { name: "Zmień hasło" }).click();
    await expect(form.getByRole("alert")).toHaveText("Hasła nie są takie same.");
  });

  test("A4: wygasła sesja przy zapisie", async ({ page }) => {
    await register(page);
    await page.goto("/profil");
    const form = page.getByRole("form", { name: "Zmiana nazwy" });
    await expect(form).toBeVisible();
    // Sesja wygasa dokładnie przy zapisie. Czyszczenie ciasteczek było niestabilne, bo odświeżanie
    // salda w tle potrafiło wylogować gracza, zanim test zdążył wpisać nazwę.
    await page.route("**/api/me", (route) =>
      route.request().method() === "PATCH"
        ? route.fulfill({ status: 401, json: { error: { code: "unauthorized", message: "Zaloguj się.", details: null } } })
        : route.continue(),
    );
    await form.getByLabel("Nowa nazwa").fill("nowa_nazwa");
    await form.getByRole("button", { name: "Zapisz nazwę" }).click();
    await expect(page.getByText("Sesja wygasła. Zaloguj się ponownie.")).toBeVisible();
  });
});

test.describe("Połącz grę", () => {
  test("generuje kod parowania z odliczaniem i aktualizuje status powiązania", async ({ page }) => {
    await register(page);
    await page.goto("/profil");
    await expect(page.getByTestId("game-link-status")).toHaveText("Niepołączone");
    await page.getByRole("button", { name: "Wygeneruj kod" }).click();
    await expect(page.getByLabel("Kod parowania")).toHaveText(/^[A-Z2-9]{6}$/);
    await expect(page.getByTestId("game-link-status")).toHaveText("Oczekuje na wpisanie kodu");
    await expect(page.getByRole("timer")).toContainText("Kod wygaśnie za 4:");
    await expect(page.getByRole("button", { name: "Wygeneruj nowy kod" })).toBeVisible();
  });

  test("po wpisaniu kodu w grze status zmienia się na Połączone", async ({ page }) => {
    await register(page);
    await page.goto("/profil");
    await page.getByRole("button", { name: "Wygeneruj kod" }).click();
    const code = (await page.getByLabel("Kod parowania").textContent())!.trim();
    // Gra wysyła kod bez ciasteczek portalu.
    const pair = await page.request.post("/api/auth/pair", { data: { code }, headers: { Cookie: "" } });
    expect(pair.ok()).toBeTruthy();
    await page.reload();
    await expect(page.getByTestId("game-link-status")).toHaveText("Połączone");
  });
});
