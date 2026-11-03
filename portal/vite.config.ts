import react from "@vitejs/plugin-react";
import { defineConfig } from "vitest/config";

export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    // Lokalnie portal i API działają pod jednym adresem, więc cookie sesji działa bez dodatkowej konfiguracji.
    proxy: { "/api": process.env.VITE_API_PROXY ?? "http://localhost:8000" },
  },
  test: { environment: "jsdom", include: ["src/**/*.test.ts"] },
});
