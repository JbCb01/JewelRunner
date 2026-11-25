import { expect, test } from "@playwright/test";
import { DEMO, login, register } from "./helpers";

test.describe("2.3, 2.7 Filtry rankingu i znajomi", () => {
  test("przełączanie okresów, zapamiętywanie filtra, brak wyników i brak znajomych", async ({ page }) => {
    await register(page);
    await page.goto("/rankingi");

    // Domyślnie ogółem (100 wyników z seed_dev).
    await expect(page.getByRole("button", { name: "Ogółem" })).toHaveAttribute("aria-pressed", "true");
    await expect(page.locator("tbody tr")).toHaveCount(100);

    // Tydzień -> brak wyników w tym okresie. Odpowiedź serwera podstawiamy, bo inne testy mogą
    // dodać wyniki w bieżącym tygodniu i wtedy lista nie byłaby pusta.
    await page.route("**/api/ranking?period=*", async (route) => {
      const response = await route.fetch();
      const body = await response.json();
      await route.fulfill({ response, json: { ...body, items: [], me: null, empty_reason: "no_results" } });
    });
    await page.getByRole("button", { name: "Tydzień" }).click();
    await expect(page.getByTestId("ranking-empty")).toContainText("Brak wyników w tym okresie");
    await page.unroute("**/api/ranking?period=*");

    // Filtr jest zapamiętywany przez serwer po przeładowaniu.
    await page.reload();
    await expect(page.getByRole("button", { name: "Tydzień" })).toHaveAttribute("aria-pressed", "true");

    // Znajomi bez dodanych znajomych -> zachęta „Dodaj znajomych”.
    await page.getByRole("button", { name: "Znajomi" }).click();
    await expect(page.getByTestId("ranking-empty")).toContainText("Dodaj znajomych");
  });

  test("przy błędzie sieci podczas zmiany filtra zostaje poprzednia lista", async ({ page }) => {
    await login(page, DEMO);
    await page.goto("/rankingi");
    await expect(page.locator("tbody tr")).toHaveCount(100);

    await page.route("**/api/ranking?period=*", (route) => route.abort());
    await page.getByRole("button", { name: "Miesiąc" }).click();
    await expect(page.getByRole("alert")).toContainText("Pokazano poprzednią listę");
    await expect(page.locator("tbody tr")).toHaveCount(100);
  });

  test("wyszukiwanie, dodawanie, ranking znajomych i usuwanie znajomego", async ({ page }) => {
    await register(page);
    await page.goto("/znajomi");
    await expect(page.getByText("Nie masz jeszcze żadnych znajomych.")).toBeVisible();

    const searchForm = page.getByRole("form", { name: "Wyszukaj gracza" });
    await searchForm.getByRole("searchbox").fill("gracz001");
    await searchForm.getByRole("button", { name: "Szukaj" }).click();

    const results = page.getByTestId("friend-search-results");
    await expect(results).toContainText("gracz001");
    await results.getByRole("button", { name: "Dodaj do znajomych" }).click();
    await expect(page.getByRole("status")).toContainText("Dodano gracza gracz001");
    await expect(page.getByTestId("friends-table")).toContainText("gracz001");

    // Ranking znajomych pokazuje dodanego znajomego.
    await page.goto("/rankingi");
    await page.getByRole("button", { name: "Znajomi" }).click();
    await expect(page.locator("tbody tr")).toHaveCount(1);
    await expect(page.locator("tbody tr").first()).toContainText("gracz001");

    // Usunięcie znajomego.
    await page.goto("/znajomi");
    await page.getByTestId("friends-table").getByRole("button", { name: "Usuń" }).click();
    await expect(page.getByRole("status")).toContainText("Usunięto gracza gracz001");
    await expect(page.getByText("Nie masz jeszcze żadnych znajomych.")).toBeVisible();
  });
});
