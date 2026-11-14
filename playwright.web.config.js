import { existsSync } from "node:fs";
import { defineConfig, chromium } from "@playwright/test";

const localChromium =
  !process.env.CI && existsSync("/usr/bin/chromium")
    ? "/usr/bin/chromium"
    : chromium.executablePath();

export default defineConfig({
  testDir: "./tests",
  testMatch: "pwa-updates.spec.js",
  timeout: 45000,
  expect: { timeout: 10000 },
  fullyParallel: false,
  workers: 1,
  retries: 0,
  outputDir: "test-results/pwa",
  use: {
    serviceWorkers: "allow",
    launchOptions: {
      executablePath: process.env.CHROMIUM_PATH || localChromium,
      args: ["--no-sandbox"],
    },
  },
  // Each test starts its own temporary server and export fixtures. No Vite
  // server, real learner profile, or published release is used by this suite.
  projects: [
    { name: "pwa-desktop", use: { viewport: { width: 1280, height: 800 } } },
    {
      name: "pwa-mobile-landscape",
      use: {
        viewport: { width: 844, height: 390 },
        isMobile: true,
        hasTouch: true,
      },
    },
  ],
});
