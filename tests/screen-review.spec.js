import { test, expect } from "@playwright/test";
import { createServer } from "node:http";
import { mkdtemp, readFile, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join, resolve, extname, sep } from "node:path";
import { execFileSync } from "node:child_process";

const repository = resolve(import.meta.dirname, "..");
let temporary;
let folder;
let server;
let origin;
let prefix;
let manifest;
let firstScreen;

async function startGallery() {
  temporary = await mkdtemp(join(tmpdir(), "komaku-screen-review-"));
  const source = JSON.parse(
    await readFile(join(repository, "review/screens.json"), "utf8"),
  );
  prefix = `/review/${source.version}/`;
  folder = join(temporary, "review", source.version);
  execFileSync(
    "python3",
    [
      "scripts/build_screen_review.py",
      "--output",
      folder,
      "--allow-uncommitted-preview",
    ],
    { cwd: repository, encoding: "utf8", timeout: 120000 },
  );
  manifest = JSON.parse(await readFile(join(folder, "screens.json"), "utf8"));
  firstScreen = manifest.screens[0];
  server = createServer(async (request, response) => {
    try {
      const pathname = decodeURIComponent(
        new URL(request.url, "http://localhost").pathname,
      );
      if (!pathname.startsWith(prefix)) {
        response.writeHead(404).end();
        return;
      }
      const relative = pathname.slice(prefix.length) || "index.html";
      const file = resolve(folder, relative);
      if (!file.startsWith(folder + sep)) {
        response.writeHead(403).end();
        return;
      }
      const bytes = await readFile(file);
      const contentTypes = {
        ".html": "text/html; charset=utf-8",
        ".js": "text/javascript; charset=utf-8",
        ".css": "text/css; charset=utf-8",
        ".json": "application/json",
        ".png": "image/png",
        ".svg": "image/svg+xml",
      };
      response.writeHead(200, {
        "Content-Type":
          contentTypes[extname(file)] || "application/octet-stream",
        "Cache-Control": "no-store",
        "Content-Length": bytes.length,
      });
      response.end(bytes);
    } catch {
      response.writeHead(404).end("Not found");
    }
  });
  await new Promise((done) => server.listen(0, "127.0.0.1", done));
  origin = `http://127.0.0.1:${server.address().port}`;
}

async function isolateNetwork(context, externalRequests = []) {
  await context.route("**/*", async (route) => {
    const request = route.request();
    const url = new URL(request.url());
    if (url.origin === origin || ["data:", "blob:"].includes(url.protocol)) {
      await route.continue();
      return;
    }
    externalRequests.push({ url: request.url(), method: request.method() });
    // A click may open a prefilled issue draft. Intercept that navigation: no
    // network access to GitHub, authentication, or real issue creation occurs.
    if (url.hostname === "github.com" && url.pathname.endsWith("/issues/new")) {
      await route.fulfill({
        status: 200,
        contentType: "text/html",
        body: "<!doctype html><title>Intercepted issue draft</title><p>No feedback was submitted.</p>",
      });
    } else {
      await route.abort("blockedbyclient");
    }
  });
}

async function loaded(page, screen = firstScreen) {
  await page.waitForFunction(
    () =>
      document.querySelector("#app")?.getAttribute("aria-busy") === "false" ||
      document.querySelector("#load-error")?.hidden === false,
  );
  if (await page.locator("#load-error").isVisible()) {
    throw new Error(await page.locator("#load-error-message").textContent());
  }
  await expect(page.locator("#app")).toHaveAttribute("aria-busy", "false");
  await expect(page.locator("#screenshot")).toBeVisible();
  await page.waitForFunction(({ width, height }) => {
    const image = document.querySelector("#screenshot");
    return (
      image?.complete &&
      image.naturalWidth === width &&
      image.naturalHeight === height
    );
  }, screen);
  await expect(page.locator("#annotation-layer")).toBeVisible();
}

async function ready(page) {
  await page.goto(origin + prefix);
  await loaded(page);
}

function marks(page) {
  return page.locator("#annotation-layer g[data-id]");
}

async function draw(page, tool, start, end = start) {
  const previousCount = await marks(page).count();
  await page.locator(`#tool-${tool}`).click();
  const layer = page.locator("#annotation-layer");
  await layer.scrollIntoViewIfNeeded();
  const box = await layer.boundingBox();
  expect(box.width).toBeGreaterThan(100);
  const point = ([x, y]) => ({
    x: box.x + x * box.width,
    y: box.y + y * box.height,
  });
  const from = point(start);
  const to = point(end);
  if (test.info().project.use.hasTouch) {
    const session = await page.context().newCDPSession(page);
    const touch = (position) => [
      { ...position, id: 1, radiusX: 1, radiusY: 1, force: 1 },
    ];
    await session.send("Input.dispatchTouchEvent", {
      type: "touchStart",
      touchPoints: touch(from),
    });
    for (let step = 1; step <= 6; step += 1) {
      await session.send("Input.dispatchTouchEvent", {
        type: "touchMove",
        touchPoints: touch({
          x: from.x + ((to.x - from.x) * step) / 6,
          y: from.y + ((to.y - from.y) * step) / 6,
        }),
      });
    }
    await session.send("Input.dispatchTouchEvent", {
      type: "touchEnd",
      touchPoints: [],
    });
    await session.detach();
  } else {
    await page.mouse.move(from.x, from.y);
    await page.mouse.down();
    await page.mouse.move(to.x, to.y, { steps: 6 });
    await page.mouse.up();
  }
  await expect(marks(page)).toHaveCount(previousCount + 1);
}

async function downloadBytes(page, selector) {
  const pending = page.waitForEvent("download");
  await page.locator(selector).click();
  const download = await pending;
  expect(await download.failure()).toBeNull();
  return {
    bytes: await readFile(await download.path()),
    name: download.suggestedFilename(),
  };
}

async function exportReview(page) {
  const download = await downloadBytes(page, "#export-json");
  expect(download.name).toMatch(/\.json$/);
  return JSON.parse(download.bytes.toString("utf8"));
}

function identityAndFeedback(review) {
  return {
    schema: review.schema,
    version: review.version,
    sourceCommit: review.sourceCommit,
    screenId: review.screenId,
    imageSha256: review.imageSha256,
    reviewer: review.reviewer,
    comment: review.comment,
    marks: review.marks,
  };
}

async function importReview(page, value, name = "review.json") {
  await page.locator("#import-json").setInputFiles({
    name,
    mimeType: "application/json",
    buffer: Buffer.from(
      typeof value === "string" ? value : JSON.stringify(value),
    ),
  });
}

test.beforeAll(async () => startGallery());
test.afterAll(async () => {
  if (server) {
    server.closeAllConnections();
    await new Promise((done) => server.close(done));
  }
  if (temporary) await rm(temporary, { recursive: true, force: true });
});

test.beforeEach(async ({ context }) => isolateNetwork(context));

test("gallery opens at its versioned subpath and remains usable on a phone", async ({
  page,
}) => {
  const errors = [];
  page.on("pageerror", (error) => errors.push(error.message));
  await ready(page);
  await expect(page).toHaveTitle(/KŌMAKU.*screen review/i);
  await expect(page.locator("#version")).toContainText(manifest.version);
  await expect(page.locator("#screen-list [data-screen-id]")).toHaveCount(
    manifest.screens.length,
  );
  await expect(page.locator("body")).toHaveJSProperty(
    "scrollWidth",
    await page.locator("body").evaluate((body) => body.clientWidth),
  );
  for (const tool of ["Rectangle", "Ellipse", "Arrow", "Pin"]) {
    await expect(
      page.getByRole("button", { name: tool, exact: true }),
    ).toBeVisible();
  }
  const ratio = await page
    .locator("#screenshot")
    .evaluate(
      (image) =>
        image.getBoundingClientRect().width /
        image.getBoundingClientRect().height,
    );
  expect(ratio).toBeCloseTo(firstScreen.width / firstScreen.height, 2);
  expect(errors).toEqual([]);
});

test("pointer and touch marks retain normalized coordinates and notes after reload", async ({
  page,
}) => {
  await ready(page);
  const shapes = [
    { type: "rect", from: [0.08, 0.12], to: [0.32, 0.34] },
    { type: "ellipse", from: [0.48, 0.13], to: [0.77, 0.38] },
    { type: "arrow", from: [0.14, 0.72], to: [0.61, 0.56] },
    { type: "pin", from: [0.81, 0.75], to: [0.81, 0.75] },
  ];
  for (const shape of shapes) {
    await draw(page, shape.type, shape.from, shape.to);
    await page
      .locator("#selected-note")
      .fill(`Make the ${shape.type} detail clearer.`);
  }
  await page.locator("#reviewer-name").fill("Screen review tester");
  await page
    .locator("#general-comment")
    .fill("Keep the next action easy to understand.");
  const before = await exportReview(page);
  expect(before.version).toBe(manifest.version);
  expect(before.screenId).toBe(firstScreen.id);
  expect(before.imageSha256).toBe(firstScreen.sha256);
  expect(before.marks).toHaveLength(4);
  for (let index = 0; index < shapes.length; index += 1) {
    const mark = before.marks[index];
    const expected = shapes[index];
    expect(mark.type).toBe(expected.type);
    expect(mark.note).toBe(`Make the ${expected.type} detail clearer.`);
    for (const key of ["x1", "y1", "x2", "y2"]) {
      expect(Number.isFinite(mark[key])).toBe(true);
      expect(mark[key]).toBeGreaterThanOrEqual(0);
      expect(mark[key]).toBeLessThanOrEqual(1);
    }
    expect(Math.abs(mark.x1 - expected.from[0])).toBeLessThan(0.015);
    expect(Math.abs(mark.y1 - expected.from[1])).toBeLessThan(0.015);
    if (mark.type !== "pin") {
      expect(Math.abs(mark.x2 - expected.to[0])).toBeLessThan(0.015);
      expect(Math.abs(mark.y2 - expected.to[1])).toBeLessThan(0.015);
    }
  }
  await page.reload();
  await loaded(page);
  await expect(marks(page)).toHaveCount(4);
  expect(identityAndFeedback(await exportReview(page))).toEqual(
    identityAndFeedback(before),
  );
});

test("keyboard marks, selection, undo, deletion and cancelled clearing preserve user intent", async ({
  page,
}) => {
  await ready(page);
  await page.locator("#tool-rect").click();
  await page.locator("#stage").focus();
  await page.keyboard.press("Enter");
  await expect(marks(page)).toHaveCount(1);
  await page.locator("#selected-note").fill("Keep this rectangle.");
  await page.keyboard.press("Delete");
  await expect(marks(page)).toHaveCount(1);
  await page.locator("#tool-pin").click();
  await page.locator("#add-center").click();
  await expect(marks(page)).toHaveCount(2);
  await page.locator("#mark-list button").first().click();
  await expect(page.locator("#selected-note")).toHaveValue(
    "Keep this rectangle.",
  );
  await page.locator("#stage").focus();
  await page.keyboard.press("Delete");
  await expect(marks(page)).toHaveCount(1);
  await page.keyboard.press("Control+z");
  await expect(marks(page)).toHaveCount(2);
  const before = await exportReview(page);
  page.once("dialog", (dialog) => dialog.dismiss());
  await page.locator("#clear-review").click();
  expect(identityAndFeedback(await exportReview(page))).toEqual(
    identityAndFeedback(before),
  );
  await page.locator("#share-review").click();
  await expect(page.locator("#transfer-dialog")).toBeVisible();
  await page.keyboard.press("Escape");
  await expect(page.locator("#transfer-dialog")).not.toBeVisible();
  await expect(page.locator("#share-review")).toBeFocused();
});

test("browser Back restores each screen's own draft", async ({ page }) => {
  await ready(page);
  await draw(page, "pin", [0.25, 0.25]);
  await page.locator("#selected-note").fill("First screen feedback.");
  const first = await exportReview(page);
  const next = manifest.screens[1];
  if ((await page.locator("#screen-picker").getAttribute("open")) === null) {
    await page.locator("#screen-picker summary").click();
  }
  await page.locator(`#screen-list [data-screen-id="${next.id}"]`).click();
  await loaded(page, next);
  await expect(page).toHaveURL(new RegExp(`#screen=${next.id}$`));
  await draw(page, "pin", [0.7, 0.6]);
  await page.locator("#selected-note").fill("Second screen feedback.");
  await page.goBack();
  await loaded(page);
  expect(identityAndFeedback(await exportReview(page))).toEqual(
    identityAndFeedback(first),
  );
  await page.goForward();
  await loaded(page, next);
  expect((await exportReview(page)).marks[0].note).toBe(
    "Second screen feedback.",
  );
});

test("a shared link opens identical annotations in a fresh browser context", async ({
  page,
  browser,
}) => {
  await ready(page);
  await draw(page, "arrow", [0.2, 0.65], [0.55, 0.35]);
  await page
    .locator("#selected-note")
    .fill("Point the player toward this control.");
  await page
    .locator("#general-comment")
    .fill("Shared without a server account.");
  const original = await exportReview(page);
  await page.locator("#share-review").click();
  const link = await page.locator("#transfer-value").inputValue();
  expect(link).toMatch(
    new RegExp(`^${origin.replaceAll(".", "\\.")}${prefix}#review=`),
  );
  const shared = JSON.parse(
    Buffer.from(
      new URL(link).hash.slice("#review=".length),
      "base64url",
    ).toString("utf8"),
  );
  expect(identityAndFeedback(shared)).toEqual(identityAndFeedback(original));
  const cleanContext = await browser.newContext({
    viewport: test.info().project.use.viewport,
  });
  try {
    await isolateNetwork(cleanContext);
    const recipient = await cleanContext.newPage();
    await recipient.goto(link);
    await loaded(recipient);
    await expect(marks(recipient)).toHaveCount(1);
    expect(identityAndFeedback(await exportReview(recipient))).toEqual(
      identityAndFeedback(original),
    );
  } finally {
    await cleanContext.close();
  }
});

test("JSON import restores a draft and PNG preserves source width with room for its note legend", async ({
  page,
}) => {
  await ready(page);
  await draw(page, "ellipse", [0.35, 0.3], [0.72, 0.7]);
  await page.locator("#selected-note").fill("Give this region more contrast.");
  const original = await exportReview(page);
  page.on("dialog", (dialog) => dialog.accept());
  await page.locator("#clear-review").click();
  await expect(marks(page)).toHaveCount(0);
  await importReview(page, original);
  await expect(marks(page)).toHaveCount(1);
  expect(identityAndFeedback(await exportReview(page))).toEqual(
    identityAndFeedback(original),
  );
  const png = await downloadBytes(page, "#export-png");
  expect(png.name).toMatch(/\.png$/);
  expect(png.bytes.subarray(0, 8)).toEqual(
    Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
  );
  expect(png.bytes.readUInt32BE(16)).toBe(firstScreen.width);
  // Export preserves the full screenshot and adds a title/notes legend below.
  expect(png.bytes.readUInt32BE(20)).toBeGreaterThan(firstScreen.height);
  expect(png.bytes.length).toBeGreaterThan(10000);
});

test("invalid imports and untrusted share identities cannot destroy the existing draft", async ({
  page,
}) => {
  await ready(page);
  await draw(page, "pin", [0.45, 0.4]);
  await page.locator("#selected-note").fill("Do not lose this saved note.");
  const original = await exportReview(page);
  const wrongScreen = { ...original, screenId: "not-a-screen" };
  const wrongImage = { ...original, imageSha256: "0".repeat(64) };
  for (const [index, invalid] of [
    "{invalid json",
    wrongScreen,
    wrongImage,
  ].entries()) {
    await importReview(page, invalid, `invalid-${index}.json`);
    await expect(page.locator("#status")).toContainText(
      /cannot|could not|couldn|invalid|malformed|unknown|match|reject|belong|different|support/i,
    );
    expect(identityAndFeedback(await exportReview(page))).toEqual(
      identityAndFeedback(original),
    );
  }
  for (const invalidHash of [
    "not-valid$$",
    Buffer.from(JSON.stringify(wrongImage)).toString("base64url"),
  ]) {
    await page.goto(origin + prefix + "#review=" + invalidHash);
    await loaded(page);
    await expect(page.locator("#status")).toContainText(
      /cannot|could not|couldn|invalid|malformed|unknown|match|reject|belong|different|support/i,
    );
    expect(identityAndFeedback(await exportReview(page))).toEqual(
      identityAndFeedback(original),
    );
  }
});

test("review text is shown literally rather than interpreted as HTML", async ({
  page,
}) => {
  await ready(page);
  const note =
    '<img src=x onerror="window.reviewXss=1"><script>window.reviewXss=2</script>';
  await draw(page, "pin", [0.35, 0.4]);
  await page.locator("#selected-note").fill(note);
  await page
    .locator("#general-comment")
    .fill('<svg onload="window.reviewXss=3">Literal feedback</svg>');
  await page
    .locator("#reviewer-name")
    .fill('<img src=x onerror="window.reviewXss=4">');
  await page.reload();
  await loaded(page);
  await expect(page.locator("#mark-list")).toContainText(note);
  await expect(
    page.locator("#mark-list img, #mark-list script, #mark-list svg"),
  ).toHaveCount(0);
  expect(await page.evaluate(() => window.reviewXss)).toBeUndefined();
  expect((await exportReview(page)).marks[0].note).toBe(note);
});

test("zooming and scrolling keep annotations tied to source coordinates and export dimensions", async ({
  page,
}) => {
  await ready(page);
  const fitted = await page.locator("#annotation-layer").boundingBox();
  await page.locator("#zoom-in").click();
  await page.locator("#zoom-in").click();
  await page.locator("#tool-pin").click();
  const stage = page.locator("#stage");
  await stage.scrollIntoViewIfNeeded();
  await expect(stage).toHaveAttribute("data-zoomed", "true");
  const enlarged = await page.locator("#annotation-layer").boundingBox();
  expect(enlarged.width).toBeGreaterThan(fitted.width * 1.25);
  await stage.evaluate((element) => {
    element.scrollLeft = element.scrollWidth;
    element.scrollTop = element.scrollHeight;
  });
  expect(await stage.evaluate((element) => element.scrollLeft)).toBeGreaterThan(
    0,
  );
  const point = await page.evaluate(() => {
    const viewport = document.querySelector("#stage").getBoundingClientRect();
    const image = document
      .querySelector("#annotation-layer")
      .getBoundingClientRect();
    const x =
      (Math.max(20, viewport.left + 20) +
        Math.min(innerWidth - 20, viewport.right - 20)) /
      2;
    const y =
      (Math.max(20, viewport.top + 20) +
        Math.min(innerHeight - 20, viewport.bottom - 20)) /
      2;
    return {
      x,
      y,
      normalizedX: (x - image.left) / image.width,
      normalizedY: (y - image.top) / image.height,
    };
  });
  expect(point.normalizedX).toBeGreaterThan(0);
  expect(point.normalizedX).toBeLessThan(1);
  expect(point.normalizedY).toBeGreaterThan(0);
  expect(point.normalizedY).toBeLessThan(1);
  if (test.info().project.use.hasTouch)
    await page.touchscreen.tap(point.x, point.y);
  else await page.mouse.click(point.x, point.y);
  await expect(marks(page)).toHaveCount(1);
  await page.locator("#selected-note").fill("Added while zoomed and scrolled.");
  const zoomed = await exportReview(page);
  expect(Math.abs(zoomed.marks[0].x1 - point.normalizedX)).toBeLessThan(0.015);
  expect(Math.abs(zoomed.marks[0].y1 - point.normalizedY)).toBeLessThan(0.015);
  await page.locator("#zoom-fit").click();
  expect(await stage.evaluate((element) => element.scrollLeft)).toBe(0);
  expect(identityAndFeedback(await exportReview(page))).toEqual(
    identityAndFeedback(zoomed),
  );
  const png = await downloadBytes(page, "#export-png");
  expect(png.bytes.readUInt32BE(16)).toBe(firstScreen.width);
  expect(png.bytes.readUInt32BE(20)).toBeGreaterThan(firstScreen.height);
});

test("GitHub opens only a prefilled draft with the review payload and never submits feedback", async ({
  page,
  context,
}) => {
  const requests = [];
  await context.unroute("**/*");
  await isolateNetwork(context, requests);
  await ready(page);
  await draw(page, "pin", [0.3, 0.3]);
  await page.locator("#selected-note").fill("Increase this label's contrast.");
  await page.locator("#github-review").click();
  await expect(page.locator("#open-github")).toBeVisible();
  const link = await page.locator("#open-github").getAttribute("href");
  const url = new URL(link);
  expect(url.origin).toBe("https://github.com");
  expect(url.pathname).toBe(`/${manifest.repository}/issues/new`);
  expect(url.searchParams.get("title")).toMatch(/^\[Screen review\]/);
  expect(url.searchParams.get("body")).toContain(
    "Increase this label's contrast.",
  );
  expect(url.searchParams.get("body")).toContain(firstScreen.sha256);
  expect(link.length).toBeLessThanOrEqual(7500);
  expect(requests).toEqual([]);
  const pending = page.waitForEvent("popup");
  await page.locator("#open-github").click();
  const popup = await pending;
  await expect(popup).toHaveTitle("Intercepted issue draft");
  expect(requests).toEqual([{ url: link, method: "GET" }]);
  await popup.close();
});

test("oversized feedback uses a complete JSON fallback instead of truncating a share or issue URL", async ({
  page,
}) => {
  await ready(page);
  await draw(page, "pin", [0.5, 0.4]);
  const comment = "星".repeat(1800);
  await page.locator("#general-comment").fill(comment);
  await page.locator("#share-review").click();
  await expect(page.locator("#transfer-description")).toContainText(
    /too large|too long/i,
  );
  const downloaded = await downloadBytes(page, "#download-transfer");
  expect(JSON.parse(downloaded.bytes.toString("utf8")).comment).toBe(comment);
  await page.locator("#close-transfer").click();
  await page.locator("#github-review").click();
  await expect(page.locator("#transfer-description")).toContainText(
    /attach|JSON|too large|too long/i,
  );
  const link = await page.locator("#open-github").getAttribute("href");
  expect(link.length).toBeLessThanOrEqual(7500);
  const body = new URL(link).searchParams.get("body");
  expect(body).toMatch(/attach|JSON/i);
  expect(body).not.toContain(comment);
  const issueFallback = await downloadBytes(page, "#download-transfer");
  expect(JSON.parse(issueFallback.bytes.toString("utf8")).comment).toBe(
    comment,
  );
});
