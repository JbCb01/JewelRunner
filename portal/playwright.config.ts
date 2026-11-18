import { defineConfig } from "@playwright/test";

export default defineConfig({
  testDir: "e2e",
  workers: 1,
  timeout: 30000,
  reporter: "line",
  use: {
    baseURL: process.env.E2E_BASE_URL ?? "http://localhost:5174",
    channel: process.env.E2E_BROWSER_CHANNEL || undefined,
    locale: "pl-PL",
    viewport: { width: 1280, height: 800 },
  },
});
