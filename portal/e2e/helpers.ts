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

export async function login(page: Page, account: { email: string; password: string }) {
  await page.goto("/logowanie");
  await page.getByLabel("E-mail").fill(account.email);
  await page.getByLabel("Hasło").fill(account.password);
  await page.getByRole("button", { name: "Zaloguj się" }).click();
  await expect(page.getByTestId("current-user")).toBeVisible();
}

export async function register(page: Page, account = unique()) {
  await page.goto("/rejestracja");
  await page.getByLabel("Nazwa użytkownika").fill(account.username);
  await page.getByLabel("E-mail").fill(account.email);
  await page.getByLabel("Hasło").fill(PASSWORD);
  await page.getByRole("button", { name: "Utwórz konto" }).click();
  await expect(page.getByTestId("current-user")).toHaveText(account.username);
  return account;
}

export function lastEmailToken(): string {
  const log = readFileSync(process.env.E2E_BACKEND_LOG!, "utf8");
  const tokens = [...log.matchAll(/potwierdz-email\?token=(\S+)/g)];
  return tokens.at(-1)![1];
}
