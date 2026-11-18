import { readFileSync } from "node:fs";
import { expect, type Page } from "@playwright/test";

export const DEMO = { email: "demo@example.com", password: "Demo12345" };
export const DEMO2 = { email: "demo2@example.com", password: "Demo12345" };
export const PASSWORD = "Tajne1234";
export const CHALLENGE = { firstSteps: 1, gemHunter: 2, timeMaster: 3, expired: 4, disabled: 5 };

let counter = 0;

export function unique(prefix = "gracz"): { username: string; email: string } {
  const id = `${Date.now().toString(36)}${counter++}`;
  return { username: `${prefix}_${id}`, email: `${prefix}_${id}@example.com` };
}

export async function dismissDailyRewardIfOpen(page: Page) {
  const modal = page.getByTestId("daily-reward-modal");
  try {
    await modal.waitFor({ state: "visible", timeout: 4000 });
    await modal.getByRole("button", { name: "Zamknij" }).click();
    await expect(modal).toBeHidden();
  } catch {
    // Modal nie pojawił się (nagroda już odebrana lub wyłączona w teście).
  }
}

export async function login(
  page: Page,
  account: { email: string; password: string },
  options: { dismissDaily?: boolean } = {},
) {
  await page.goto("/logowanie");
  await page.getByLabel("E-mail").fill(account.email);
  await page.getByLabel("Hasło").fill(account.password);
  await page.getByRole("button", { name: "Zaloguj się" }).click();
  await expect(page.getByTestId("current-user")).toBeVisible();
  if (options.dismissDaily !== false) {
    await dismissDailyRewardIfOpen(page);
  }
}

export async function register(page: Page, account = unique(), options: { dismissDaily?: boolean } = {}) {
  await page.goto("/rejestracja");
  await page.getByLabel("Nazwa użytkownika").fill(account.username);
  await page.getByLabel("E-mail").fill(account.email);
  await page.getByLabel("Hasło").fill(PASSWORD);
  await page.getByRole("button", { name: "Utwórz konto" }).click();
  await expect(page.getByTestId("current-user")).toHaveText(account.username);
  if (options.dismissDaily !== false) {
    await dismissDailyRewardIfOpen(page);
  }
  return account;
}

export async function pairGameSession(page: Page): Promise<string> {
  const codeRes = await page.request.post("/api/me/pairing-code");
  expect(codeRes.ok()).toBeTruthy();
  const { code } = (await codeRes.json()) as { code: string };
  const pairRes = await page.request.post("/api/auth/pair", { data: { code }, headers: { Cookie: "" } });
  expect(pairRes.ok()).toBeTruthy();
  const { token } = (await pairRes.json()) as { token: string };
  return token;
}

export function lastEmailToken(): string {
  const log = readFileSync(process.env.E2E_BACKEND_LOG!, "utf8");
  const tokens = [...log.matchAll(/potwierdz-email\?token=(\S+)/g)];
  return tokens.at(-1)![1];
}

export function lastResetToken(): string {
  const log = readFileSync(process.env.E2E_BACKEND_LOG!, "utf8");
  const tokens = [...log.matchAll(/nowe-haslo\?token=(\S+)/g)];
  return tokens.at(-1)![1];
}
