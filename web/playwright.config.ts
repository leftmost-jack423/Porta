import { defineConfig, devices } from "@playwright/test";

// Playwright config for Porta's web receiver. Tests hit a real Vite preview
// server (built from src/) and mock /v1/* and /p/* at the browser route
// layer, so they need zero backend infrastructure.
export default defineConfig({
  testDir: "./tests/ui",
  fullyParallel: true,
  reporter: process.env.CI ? [["list"], ["github"]] : [["list"]],
  retries: process.env.CI ? 1 : 0,
  use: {
    baseURL: "http://127.0.0.1:4173",
    trace: "retain-on-failure",
    screenshot: "only-on-failure",
    video: "retain-on-failure",
  },
  projects: [
    { name: "chromium-desktop", use: { ...devices["Desktop Chrome"] } },
    // Mobile viewport emulation, still on Chromium so CI only needs one
    // browser binary. Pixel 7 is close enough to iPhone 14 for layout checks.
    { name: "mobile", use: { ...devices["Pixel 7"] } },
  ],
  webServer: {
    command:
      "npm run build && npm run preview -- --host 127.0.0.1 --port 4173 --strictPort",
    url: "http://127.0.0.1:4173",
    reuseExistingServer: !process.env.CI,
    timeout: 120_000,
    stdout: "pipe",
    stderr: "pipe",
  },
});
