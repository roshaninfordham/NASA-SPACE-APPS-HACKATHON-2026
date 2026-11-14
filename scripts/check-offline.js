import { chromium } from "@playwright/test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
const brand = JSON.parse(
  readFileSync(new URL("../game/data/brand.json", import.meta.url), "utf8"),
);
const browser = await chromium.launch({
  executablePath: process.env.CHROMIUM_PATH || "/usr/bin/chromium",
  args: [
    "--no-sandbox",
    "--use-angle=swiftshader",
    "--enable-unsafe-swiftshader",
  ],
});
try {
  const context = await browser.newContext();
  const page = await context.newPage();
  const external = [];
  page.on("request", (r) => {
    if (
      !r.url().startsWith("http://127.0.0.1:4173/") &&
      !r.url().startsWith("data:")
    )
      external.push(r.url());
  });
  await page.goto("http://127.0.0.1:4173/");
  await page.evaluate(async () => {
    await navigator.serviceWorker.ready;
    if (!navigator.serviceWorker.controller)
      await new Promise((resolve) =>
        navigator.serviceWorker.addEventListener("controllerchange", resolve, {
          once: true,
        }),
      );
  });
  await context.setOffline(true);
  await page.reload();
  assert.equal(await page.title(), brand.display_name);
  await page.getByRole("button", { name: "I’m ready to explore" }).click();
  await page.locator("#start").click();
  await page.locator("#visorCleaning").click();
  assert.equal(
    await page.locator("#visorCleaning").getAttribute("aria-pressed"),
    "true",
  );
  assert.deepEqual(external, []);
  console.log(
    "PASS: offline reload, launch, visor control, and zero third-party runtime requests",
  );
} finally {
  await browser.close();
}
