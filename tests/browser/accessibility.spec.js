import { test, expect } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";
test("briefing and cockpit pass automated WCAG checks", async ({ page }) => {
  await page.goto("/");
  for (const view of ["briefing", "cockpit", "field guide"]) {
    if (view === "cockpit")
      await page.getByRole("button", { name: "I’m ready to explore" }).click();
    if (view === "field guide") await page.locator("#science-open").click();
    const report = await new AxeBuilder({ page })
      .withTags(["wcag2a", "wcag2aa", "wcag21aa", "wcag22aa"])
      .analyze();
    expect(
      report.violations.map((v) => ({
        id: v.id,
        impact: v.impact,
        description: v.description,
        nodes: v.nodes.map((n) => ({
          target: n.target,
          summary: n.failureSummary,
        })),
      })),
      view,
    ).toEqual([]);
  }
});
