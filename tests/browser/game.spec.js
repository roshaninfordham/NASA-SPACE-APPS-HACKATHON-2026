import { test, expect } from "@playwright/test";
test("launch, operate, pause, and choose a scenario without errors", async ({
  page,
}) => {
  const errors = [];
  page.on("pageerror", (e) => errors.push(e.message));
  await page.goto("/");
  await expect(page).toHaveTitle(/Red Veil/);
  await page.getByRole("button", { name: "I’m ready to explore" }).click();
  await expect(page.locator("body")).toHaveJSProperty(
    "scrollWidth",
    await page.locator("body").evaluate((e) => e.clientWidth),
  );
  await page.getByRole("button", { name: "Launch mission" }).click();
  await page.locator("#conserve").click();
  await expect(page.locator("#conserve")).toHaveAttribute(
    "aria-pressed",
    "true",
  );
  await page.locator("#shelter").click();
  await page.locator("#start").click();
  await expect(page.locator("#start")).toHaveText(/Resume/);
  const clock = await page.locator("#clock").textContent();
  await page.waitForTimeout(400);
  await expect(page.locator("#clock")).toHaveText(clock);
  await page.locator("#science-open").click();
  await expect(page.locator("#science")).toBeVisible();
  await page.getByRole("button", { name: "Close field guide" }).click();
  await page.locator("#missions-open").click();
  await page.locator('[data-mission="red-front"]').click();
  await expect(page.locator("#clock")).toHaveText("00:00");
  expect(errors).toEqual([]);
  await page.screenshot({
    path: `/tmp/red-veil-${test.info().project.name}.png`,
    fullPage: true,
  });
});
test("complete a guided mission in low graphics mode and export its evidence", async ({
  page,
}) => {
  test.setTimeout(90000);
  await page.addInitScript(() => {
    HTMLCanvasElement.prototype.getContext = () => null;
  });
  await page.clock.install();
  await page.goto("/");
  await page.getByRole("button", { name: "I’m ready to explore" }).click();
  await expect(page.locator(".scene-fallback")).toBeVisible();
  await page.locator("#start").click();
  await page.locator('[data-speed="4"]').click();
  for (let i = 0; i < 70; i++) {
    if (await page.locator("#result").isVisible()) break;
    if (await page.locator("#apply-advice").isVisible())
      await page.locator("#apply-advice").click();
    await page.clock.runFor(1000);
  }
  await expect(page.locator("#result")).toBeVisible();
  await expect(page.locator("#result-title")).toHaveText(
    "You found a way through.",
  );
  const download = page.waitForEvent("download");
  await page.locator("#export").click();
  expect((await download).suggestedFilename()).toBe(
    "red-veil-first-light.json",
  );
  await page.locator("#again").click();
  await expect(page.locator("#clock")).toHaveText("00:00");
});
