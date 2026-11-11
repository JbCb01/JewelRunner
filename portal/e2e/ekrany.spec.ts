// Zrzuty ekranów do dokumentacji (docs/ekrany). Zapisują wygląd bez sprawdzania logiki.
import { test } from "@playwright/test";
import { CHALLENGE, DEMO, login } from "./helpers";

const shot = (name: string) => ({ path: `docs/ekrany/${name}.png` });

test("zrzuty ekranów", async ({ page }) => {
  await page.goto("/logowanie");
  await page.waitForLoadState("networkidle");
  await page.screenshot(shot("logowanie"));
  await page.goto("/rejestracja");
  await page.waitForLoadState("networkidle");
  await page.screenshot(shot("rejestracja"));

  await login(page, DEMO);
  await page.goto("/wyzwania");
  await page.waitForLoadState("networkidle");
  await page.screenshot(shot("wyzwania"));
  await page.goto(`/wyzwania/${CHALLENGE.timeMaster}`);
  await page.waitForLoadState("networkidle");
  await page.screenshot(shot("szczegoly-wyzwania"));
  await page.goto("/moje-wyzwania");
  await page.waitForLoadState("networkidle");
  await page.screenshot(shot("moje-wyzwania"));
  await page.goto("/rankingi");
  await page.waitForLoadState("networkidle");
  await page.screenshot(shot("ranking"));
  await page.locator("tbody a").first().click();
  await page.waitForLoadState("networkidle");
  await page.screenshot(shot("profil-publiczny"));
  await page.goto("/profil");
  await page.waitForLoadState("networkidle");
  await page.screenshot(shot("ustawienia-profilu"));
});
