import { existsSync } from "node:fs";
import { defineConfig, chromium } from "@playwright/test";

const localChromium =
  !process.env.CI && existsSync("/usr/bin/chromium")
    ? "/usr/bin/chromium"
    : chromium.executablePath();

export default defineConfig({
  testDir: "./tests",
  testMatch: "screen-review.spec.js",
  timeout: 45000,
  expect: { timeout: 10000 },
  fullyParallel: false,
  workers: 1,
  retries: 0,
  outputDir: "test-results/screen-review",
  use: {
    serviceWorkers: "block",
    launchOptions: {
      executablePath: process.env.CHROMIUM_PATH || localChromium,
      args: ["--no-sandbox"],
    },
  },
  // Each project builds its own temporary gallery and local server. GitHub
  // issue navigation is intercepted; these tests never submit public feedback.
  projects: [
    { name: "review-desktop", use: { viewport: { width: 1440, height: 960 } } },
    {
      name: "review-phone",
      use: {
        viewport: { width: 390, height: 844 },
        isMobile: true,
        hasTouch: true,
      },
    },
  ],
});
