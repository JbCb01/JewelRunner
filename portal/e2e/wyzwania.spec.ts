import { expect, test } from "@playwright/test";
import { CHALLENGE, DEMO, login, register } from "./helpers";

test.describe("2.1 Przeglądanie dostępnych wyzwań", () => {
  test("lista pokazuje nazwę, trudność i nagrodę tylko aktywnych wyzwań", async ({ page }) => {
    await register(page);
    const cards = page.locator(".card");
    await expect(cards).toHaveCount(3);
    const first = cards.filter({ hasText: "Pierwsze kroki" });
    await expect(first).toContainText("łatwy");
    await expect(first).toContainText("50 klejnotów");
    await expect(page.getByText("Akrobata")).toHaveCount(0);
    await expect(page.getByText("Przyjęte")).toHaveCount(0);
  });

  test("A1: błąd pobierania i ponowienie", async ({ page }) => {
    await register(page);
    await page.route("**/api/challenges", (route) => route.abort());
    await page.reload();
    await expect(page.getByRole("alert")).toContainText("Nie można pobrać wyzwań.");
    await page.unroute("**/api/challenges");
    await page.getByRole("button", { name: "Spróbuj ponownie" }).click();
    await expect(page.locator(".card")).toHaveCount(3);
  });

  test("A2: brak aktywnych wyzwań", async ({ page }) => {
    await register(page);
    await page.route("**/api/challenges", (route) => route.fulfill({ json: { items: [] } }));
    await page.reload();
    await expect(page.getByText("Brak dostępnych wyzwań.")).toBeVisible();
  });

  test("A3: przyjęte wyzwanie jest oznaczone", async ({ page }) => {
    await login(page, DEMO);
    await expect(page.locator(".card").filter({ hasText: "Pierwsze kroki" }).getByText("Przyjęte")).toBeVisible();
    await expect(page.locator(".card").filter({ hasText: "Mistrz czasu" }).getByText("Przyjęte")).toHaveCount(0);
  });
});

test.describe("2.6 Przeglądanie szczegółów wyzwania", () => {
  test("scenariusz główny", async ({ page }) => {
    await register(page);
    await page.locator(".card").filter({ hasText: "Mistrz czasu" }).click();
    await expect(page.getByRole("heading", { name: "Mistrz czasu" })).toBeVisible();
    await expect(page.getByText("Ukończ poziom poniżej 60 sekund.")).toBeVisible();
    await expect(page.getByText("Ukończ poziom w maksymalnie 60 s")).toBeVisible();
    await expect(page.getByText("Skórka: Złoty biegacz")).toBeVisible();
    await expect(page.getByRole("button", { name: "Przyjmij wyzwanie" })).toBeVisible();
    await page.getByRole("link", { name: "Powrót do listy" }).click();
    await expect(page).toHaveURL(/\/wyzwania$/);
  });

  for (const [name, id] of [["wygasłe", CHALLENGE.expired], ["wyłączone", CHALLENGE.disabled], ["nieistniejące", 999999]] as const) {
    test(`A1: ${name} wyzwanie jest niedostępne`, async ({ page }) => {
      await register(page);
      await page.goto(`/wyzwania/${id}`);
      await expect(page.getByRole("alert")).toContainText("Wyzwanie jest niedostępne.");
      await expect(page.getByRole("link", { name: "Powrót do listy" })).toBeVisible();
    });
  }

  test("A2: przyjęte wyzwanie pokazuje postęp zamiast przycisku", async ({ page }) => {
    await login(page, DEMO);
    await page.goto(`/wyzwania/${CHALLENGE.firstSteps}`);
    await expect(page.getByText("Twój postęp: 40%")).toBeVisible();
    await expect(page.getByRole("button", { name: "Przyjmij wyzwanie" })).toHaveCount(0);
  });

  test("A3: błąd połączenia i ponowienie", async ({ page }) => {
    await register(page);
    await page.route(`**/api/challenges/${CHALLENGE.firstSteps}`, (route) => route.abort());
    await page.goto(`/wyzwania/${CHALLENGE.firstSteps}`);
    await expect(page.getByRole("alert")).toContainText("Nie można pobrać szczegółów");
    await page.unroute(`**/api/challenges/${CHALLENGE.firstSteps}`);
    await page.getByRole("button", { name: "Spróbuj ponownie" }).click();
    await expect(page.getByRole("heading", { name: "Pierwsze kroki" })).toBeVisible();
  });
});

test.describe("2.2 Wybieranie wyzwania", () => {
  test("przyjęcie pokazuje warunki i zapisuje uczestnictwo", async ({ page }) => {
    await register(page);
    await page.goto(`/wyzwania/${CHALLENGE.gemHunter}`);
    await page.getByRole("button", { name: "Przyjmij wyzwanie" }).click();
    const confirmation = page.locator(".notice.success");
    await expect(confirmation).toContainText("Wyzwanie przyjęte");
    await expect(confirmation).toContainText("Zbierz co najmniej 5 klejnotów");
    await expect(page.getByText("Twój postęp: 0%")).toBeVisible();
    await page.getByRole("link", { name: "Wyzwania", exact: true }).click();
    await expect(page.locator(".card").filter({ hasText: "Łowca klejnotów" }).getByText("Przyjęte")).toBeVisible();
    await page.getByRole("link", { name: "Moje wyzwania" }).click();
    await expect(page.locator(".card").filter({ hasText: "Łowca klejnotów" })).toBeVisible();
  });

  test("A2: wyzwanie wygasło podczas przeglądania", async ({ page }) => {
    await register(page);
    await page.goto(`/wyzwania/${CHALLENGE.firstSteps}`);
    await page.route("**/accept", (route) =>
      route.fulfill({ status: 404, json: { error: { code: "challenge_unavailable", message: "x", details: null } } }),
    );
    await page.getByRole("button", { name: "Przyjmij wyzwanie" }).click();
    await expect(page.getByRole("alert")).toContainText("Wyzwanie jest niedostępne.");
  });

  test("A3: brakujący warunek jest podany", async ({ page }) => {
    await register(page);
    await page.goto(`/wyzwania/${CHALLENGE.firstSteps}`);
    await page.route("**/accept", (route) =>
      route.fulfill({
        status: 409,
        json: { error: { code: "participation_requirements_not_met", message: "x", details: { poziom_odblokowany: 2 } } },
      }),
    );
    await page.getByRole("button", { name: "Przyjmij wyzwanie" }).click();
    await expect(page.getByRole("alert")).toContainText("Odblokuj poziom 2");
  });

  test("A4: błąd zapisu", async ({ page }) => {
    await register(page);
    await page.goto(`/wyzwania/${CHALLENGE.firstSteps}`);
    await page.route("**/accept", (route) =>
      route.fulfill({ status: 500, json: { error: { code: "internal_error", message: "x", details: null } } }),
    );
    await page.getByRole("button", { name: "Przyjmij wyzwanie" }).click();
    await expect(page.getByRole("alert")).toContainText("Nie udało się przyjąć wyzwania.");
    await expect(page.getByRole("button", { name: "Przyjmij wyzwanie" })).toBeVisible();
  });
});

test.describe("2.4 Śledzenie aktywnych wyzwań", () => {
  test("lista aktywnych i historia statusów", async ({ page }) => {
    await login(page, DEMO);
    await page.goto("/moje-wyzwania");
    const active = page.locator(".card").filter({ hasText: "Pierwsze kroki" });
    await expect(active.getByRole("progressbar")).toHaveAttribute("aria-valuenow", "40");
    await expect(active).toContainText("Pozostało:");
    await expect(page.locator(".card").filter({ hasText: "Akrobata" })).toContainText("Zakończone – nieukończone");
    await expect(page.locator(".card").filter({ hasText: "Łowca klejnotów" })).toContainText("Ukończone");
  });

  test("historia prób i najlepszy wynik", async ({ page }) => {
    await login(page, DEMO);
    await page.goto("/moje-wyzwania");
    await page.locator(".card").filter({ hasText: "Pierwsze kroki" }).click();
    await expect(page.getByRole("heading", { name: "Pierwsze kroki" })).toBeVisible();
    await expect(page.getByText("Najlepszy wynik: 120")).toBeVisible();
    await expect(page.locator("tbody tr")).toHaveCount(2);
    await expect(page.locator("tbody tr").first()).toContainText("120");
  });

  test("A1: brak aktywnych wyzwań", async ({ page }) => {
    await register(page);
    await page.goto("/moje-wyzwania");
    const notice = page.getByText("Nie masz aktywnych wyzwań.");
    await expect(notice).toBeVisible();
    await notice.getByRole("link").click();
    await expect(page).toHaveURL(/\/wyzwania$/);
  });

  test("A4: brak prób", async ({ page }) => {
    await register(page);
    await page.goto(`/wyzwania/${CHALLENGE.firstSteps}`);
    await page.getByRole("button", { name: "Przyjmij wyzwanie" }).click();
    await expect(page.locator(".notice.success")).toBeVisible();
    await page.goto(`/moje-wyzwania/${CHALLENGE.firstSteps}`);
    await expect(page.getByText("Brak prób.")).toBeVisible();
  });

  test("brak dostępu do prób w cudzym uczestnictwie", async ({ page }) => {
    await register(page);
    await page.goto(`/moje-wyzwania/${CHALLENGE.firstSteps}`);
    await expect(page.getByRole("alert")).toContainText("Nie znaleziono");
  });
});
