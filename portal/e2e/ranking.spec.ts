import { expect, test } from "@playwright/test";
import { DEMO, DEMO2, login, register } from "./helpers";

test.describe("2.3 Wyświetlanie rankingu", () => {
  test("100 najlepszych z wyróżnioną pozycją gracza", async ({ page }) => {
    await login(page, DEMO);
    await page.goto("/rankingi");
    await expect(page.locator("tbody tr")).toHaveCount(100);
    await expect(page.locator("tbody tr").first()).toContainText("gracz001");
    const mine = page.locator("tr.highlight");
    await expect(mine).toHaveCount(1);
    await expect(mine).toContainText("Demo");
  });

  test("A4: przy remisie wyżej wcześniejszy wynik", async ({ page }) => {
    await login(page, DEMO);
    await page.goto("/rankingi");
    await expect(page.locator("tbody tr")).not.toHaveCount(0);
    const names = await page.locator("tbody tr td:nth-child(2)").allTextContents();
    expect(names.indexOf("gracz009")).toBeLessThan(names.indexOf("gracz010"));
    expect(names.indexOf("gracz050")).toBeLessThan(names.indexOf("Demo"));
  });

  test("A1: gracz spoza setki widzi swoją pozycję pod tabelą", async ({ page }) => {
    await login(page, DEMO2);
    await page.goto("/rankingi");
    const row = page.getByTestId("my-position");
    await expect(row).toContainText("Demo2 (Ty)");
    await expect(row).toContainText("5");
  });

  test("A2: gracz bez wyniku", async ({ page }) => {
    await register(page);
    await page.goto("/rankingi");
    await expect(page.getByText("Ukończ poziom, aby pojawić się w rankingu.")).toBeVisible();
    await expect(page.locator("tbody tr")).toHaveCount(100);
  });

  test("A3: przy niedostępnym serwerze pokazuje ostatni ranking z datą", async ({ page }) => {
    await login(page, DEMO);
    await page.goto("/rankingi");
    await expect(page.locator("tbody tr")).toHaveCount(100);
    await page.route("**/api/ranking", (route) =>
      route.fulfill({ status: 503, json: { error: { code: "database_unavailable", message: "x", details: null } } }),
    );
    await page.reload();
    await expect(page.getByText(/Serwer jest niedostępny\. Dane z:/)).toBeVisible();
    await expect(page.locator("tbody tr")).toHaveCount(100);
  });

  test("A3: bez zapamiętanego rankingu pokazuje błąd", async ({ page }) => {
    await login(page, DEMO);
    await page.route("**/api/ranking", (route) => route.abort());
    await page.goto("/rankingi");
    await expect(page.getByRole("alert")).toContainText("Nie można pobrać rankingu.");
  });

  test("wylogowanie usuwa zapamiętany ranking", async ({ page }) => {
    await login(page, DEMO);
    await page.goto("/rankingi");
    await expect(page.locator("tbody tr")).toHaveCount(100);
    await page.getByRole("button", { name: "Wyloguj" }).click();
    await expect(page).toHaveURL(/\/logowanie$/);
    expect(await page.evaluate(() => localStorage.getItem("jr_ranking"))).toBeNull();
  });

  test("kroki 5-6: profil publiczny gracza", async ({ page }) => {
    await login(page, DEMO);
    await page.goto("/rankingi");
    await page.getByRole("link", { name: "gracz001" }).click();
    await expect(page.getByRole("heading", { name: "gracz001" })).toBeVisible();
    await expect(page.getByText("Ukończone poziomy")).toBeVisible();
    await expect(page.getByText("example.com")).toHaveCount(0);
  });

  test("nieznany gracz", async ({ page }) => {
    await login(page, DEMO);
    await page.goto("/gracze/00000000-0000-0000-0000-000000000000");
    await expect(page.getByRole("alert")).toContainText("Nie znaleziono gracza.");
  });
});
