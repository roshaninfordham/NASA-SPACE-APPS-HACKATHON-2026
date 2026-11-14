import { test, expect } from "@playwright/test";
import { createServer } from "node:http";
import { mkdtemp, mkdir, writeFile, readFile, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join, resolve, extname, sep } from "node:path";
import { execFileSync } from "node:child_process";

const repository = resolve(import.meta.dirname, "..");
const prefix = "/training/red-veil/";
let temporary;
let server;
let origin;
let active;
let corrupt = false;
let missing = false;
let delayed = false;
let releaseAsset;
let heldResponse;
const builds = {};
const png = Buffer.from(
  "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/lN0AAAAASUVORK5CYII=",
  "base64",
);

async function fixture(version, commit) {
  const folder = join(temporary, version);
  await mkdir(join(folder, "textures"), { recursive: true });
  const config = {
    args: [],
    executable: "index",
    serviceWorker: "index.service.worker.js",
    ensureCrossOriginIsolationHeaders: false,
  };
  await writeFile(
    join(folder, "index.html"),
    `<!doctype html><html><head><meta charset="utf-8"><title>Red Veil fixture</title><link rel="manifest" href="index.manifest.json"></head><body><h1 id="game-version"></h1><p id="game-assets"></p><script src="index.js"></script><script>const GODOT_CONFIG = ${JSON.stringify(config)};\nconst GODOT_THREADS_ENABLED = false;</script></body></html>`,
  );
  await writeFile(
    join(folder, "index.js"),
    `document.querySelector('#game-version').textContent=${JSON.stringify(version)}; window.gameSession = crypto.randomUUID(); Promise.all(['index.pck','index.wasm','textures/dust sample.txt'].map(name=>fetch(new URL(name, document.baseURI)).then(r=>{if(!r.ok) throw Error('asset unavailable'); return r.text();}))).then(values=>document.querySelector('#game-assets').textContent=values.join('|'));`,
  );
  await writeFile(join(folder, "index.pck"), `PACK ${version}`);
  await writeFile(join(folder, "index.wasm"), `ENGINE ${version}`);
  await writeFile(join(folder, "textures/dust sample.txt"), `DUST ${version}`);
  await writeFile(join(folder, "index.512x512.png"), png);
  await writeFile(join(folder, "index.manifest.json"), "{}");
  await writeFile(
    join(folder, "index.service.worker.js"),
    "// replaced by packager",
  );
  execFileSync(
    "python3",
    [
      "scripts/prepare_web_release.py",
      "--directory",
      folder,
      "--version",
      version,
      "--commit",
      commit,
    ],
    { cwd: repository },
  );
  const metadata = JSON.parse(
    await readFile(join(folder, "web-release.json"), "utf8"),
  );
  return { folder, metadata };
}

async function startFixture() {
  temporary = await mkdtemp(join(tmpdir(), "red-veil-pwa-"));
  builds.first = await fixture("0.4.0-alpha.1", "a".repeat(40));
  builds.second = await fixture("0.4.0-alpha.2", "b".repeat(40));
  builds.third = await fixture("0.4.0-alpha.3", "c".repeat(40));
  active = builds.first;
  server = createServer(async (request, response) => {
    try {
      const path = decodeURIComponent(
        new URL(request.url, "http://localhost").pathname,
      );
      if (!path.startsWith(prefix)) {
        response.writeHead(404).end();
        return;
      }
      const relative = path.slice(prefix.length) || "index.html";
      const file = resolve(active.folder, relative);
      if (!file.startsWith(active.folder + sep)) {
        response.writeHead(403).end();
        return;
      }
      const bytes = await readFile(file);
      if (relative.endsWith("index.wasm") && delayed) {
        heldResponse = response;
        await new Promise((resolveDelay) => {
          releaseAsset = resolveDelay;
        });
      }
      if (relative.endsWith("index.wasm") && missing) {
        response.writeHead(503).end("Unavailable");
        return;
      }
      let body = bytes;
      if (relative.endsWith("index.wasm") && corrupt) {
        body = Buffer.from(bytes);
        body[0] ^= 1;
      }
      const contentTypes = {
        ".html": "text/html",
        ".js": "text/javascript",
        ".css": "text/css",
        ".json": "application/json",
        ".wasm": "application/wasm",
        ".png": "image/png",
      };
      response.writeHead(200, {
        "Content-Type":
          contentTypes[extname(file)] || "application/octet-stream",
        "Cache-Control": "no-store",
        "Content-Length": body.length,
      });
      response.end(body);
    } catch {
      response.writeHead(404).end("Not found");
    }
  });
  await new Promise((resolveListen) =>
    server.listen(0, "127.0.0.1", resolveListen),
  );
  origin = `http://127.0.0.1:${server.address().port}`;
}

async function ready(page) {
  await page.goto(origin + prefix);
  await expect(page.locator("#game-version")).toHaveText("0.4.0-alpha.1");
  await expect(page.locator("#game-assets")).toContainText(
    "DUST 0.4.0-alpha.1",
  );
  await page.getByRole("button", { name: "Game updates", exact: true }).click();
  await expect(page.locator("#red-veil-web-update-status")).toContainText(
    "saved for offline play",
  );
  await page.waitForFunction(() => Boolean(navigator.serviceWorker.controller));
}

async function updateReady(page) {
  active = builds.second;
  await page
    .getByRole("button", { name: "Check for updates", exact: true })
    .click();
  await expect(
    page.getByRole("button", { name: "Update and restart", exact: true }),
  ).toBeVisible();
  await expect(page.locator("#red-veil-web-update-status")).toContainText(
    "0.4.0-alpha.2",
  );
}

test.describe("Godot browser updates", () => {
  test.beforeEach(async () => {
    corrupt = false;
    missing = false;
    delayed = false;
    releaseAsset = undefined;
    heldResponse = undefined;
    await startFixture();
  });
  test.afterEach(async () => {
    if (releaseAsset) releaseAsset();
    if (heldResponse && !heldResponse.writableEnded) heldResponse.destroy();
    server.closeAllConnections();
    await new Promise((resolveClose) => server.close(resolveClose));
    await rm(temporary, { recursive: true, force: true });
  });

  test("prepares every exported asset, supports a repository subpath, and plays offline", async ({
    page,
    context,
  }) => {
    await ready(page);
    const state = await page.evaluate(async () => {
      const registration = await navigator.serviceWorker.getRegistration();
      const manifest = await (
        await fetch(new URL("../../index.manifest.json", document.baseURI))
      ).json();
      const keys = await caches.keys();
      const cache = await caches.open(
        keys.find((name) => name.startsWith("red-veil-web:")),
      );
      return {
        scope: registration.scope,
        manifest,
        paths: (await cache.keys()).map(
          (request) => new URL(request.url).pathname,
        ),
      };
    });
    expect(state.scope).toBe(origin + prefix);
    expect(state.manifest.id).toBe("./");
    expect(state.manifest.scope).toBe("./");
    expect(state.manifest.start_url).toBe("./");
    for (const asset of builds.first.metadata.assets)
      expect(state.paths).toContain(prefix + asset.path);
    await context.setOffline(true);
    await page.reload();
    await expect(page.locator("#game-version")).toHaveText("0.4.0-alpha.1");
    await expect(page.locator("#game-assets")).toContainText(
      "DUST 0.4.0-alpha.1",
    );
  });

  test("new version waits for complete caching, Later preserves play, and explicit update restarts", async ({
    page,
    context,
  }) => {
    await ready(page);
    const session = await page.evaluate(() => window.gameSession);
    delayed = true;
    active = builds.second;
    await page
      .getByRole("button", { name: "Check for updates", exact: true })
      .click();
    await expect.poll(() => Boolean(releaseAsset)).toBe(true);
    await expect(
      page.getByRole("button", { name: "Update and restart", exact: true }),
    ).toBeHidden();
    expect(await page.evaluate(() => window.gameSession)).toBe(session);
    delayed = false;
    releaseAsset();
    releaseAsset = undefined;
    await expect(
      page.getByRole("button", { name: "Update and restart", exact: true }),
    ).toBeVisible();
    await page
      .getByRole("button", { name: "Later — keep playing", exact: true })
      .click();
    await expect(page.locator("#red-veil-web-update-panel")).toBeHidden();
    expect(await page.evaluate(() => window.gameSession)).toBe(session);
    await expect(page.locator("#game-version")).toHaveText("0.4.0-alpha.1");
    await page
      .getByRole("button", { name: "Update ready", exact: true })
      .click();
    await page
      .getByRole("button", { name: "Update and restart", exact: true })
      .click();
    await expect(page.locator("#game-version")).toHaveText("0.4.0-alpha.2");
    expect(await page.evaluate(() => window.gameSession)).not.toBe(session);
    await context.setOffline(true);
    await page.reload();
    await expect(page.locator("#game-assets")).toContainText(
      "ENGINE 0.4.0-alpha.2",
    );
  });

  for (const failure of ["hash", "fetch"]) {
    test(`failed ${failure} keeps the complete previous game available offline`, async ({
      page,
      context,
    }) => {
      await ready(page);
      const session = await page.evaluate(() => window.gameSession);
      active = builds.second;
      corrupt = failure === "hash";
      missing = failure === "fetch";
      await page
        .getByRole("button", { name: "Check for updates", exact: true })
        .click();
      await expect(page.locator("#red-veil-web-update-status")).toContainText(
        "could not be saved or checked",
      );
      await expect(
        page.getByRole("button", { name: "Update and restart", exact: true }),
      ).toBeHidden();
      expect(await page.evaluate(() => window.gameSession)).toBe(session);
      const cachesAfter = await page.evaluate(() => caches.keys());
      expect(
        cachesAfter.some((name) =>
          name.endsWith(builds.second.metadata.build_id),
        ),
      ).toBe(false);
      await context.setOffline(true);
      await page.reload();
      await expect(page.locator("#game-version")).toHaveText("0.4.0-alpha.1");
      await expect(page.locator("#game-assets")).toContainText(
        "PACK 0.4.0-alpha.1",
      );
    });
  }

  test("does not restart another open game window", async ({
    page,
    context,
  }) => {
    await ready(page);
    const other = await context.newPage();
    await other.goto(origin + prefix);
    await expect(other.locator("#game-version")).toHaveText("0.4.0-alpha.1");
    const otherSession = await other.evaluate(() => window.gameSession);
    await updateReady(page);
    await page
      .getByRole("button", { name: "Update and restart", exact: true })
      .click();
    await expect(page.locator("#red-veil-web-update-status")).toContainText(
      "Close the other Red Veil tabs",
    );
    await expect(other.locator("#game-version")).toHaveText("0.4.0-alpha.1");
    expect(await other.evaluate(() => window.gameSession)).toBe(otherSession);
    await other.close();
    await page
      .getByRole("button", { name: "Update and restart", exact: true })
      .click();
    await expect(page.locator("#game-version")).toHaveText("0.4.0-alpha.2");
  });

  test("activating a ready build preserves a newer build still being prepared", async ({
    page,
    context,
  }) => {
    await ready(page);
    await updateReady(page);
    active = builds.third;
    delayed = true;
    await page.evaluate(async () => {
      const registration = await navigator.serviceWorker.getRegistration();
      await registration.update();
    });
    await expect.poll(() => Boolean(releaseAsset)).toBe(true);
    const cacheBefore = await page.evaluate(() => caches.keys());
    expect(
      cacheBefore.some((name) => name.endsWith(builds.third.metadata.build_id)),
    ).toBe(true);
    const extraCaches = await page.evaluate(async () => {
      const registration = await navigator.serviceWorker.getRegistration();
      const root = new URL(registration.scope);
      const prefix = `red-veil-web:${root.pathname}:`;
      const marker = new URL(".red-veil-complete", root).href;
      const unactivated = "d".repeat(24);
      const unknown = "e".repeat(24);
      const obsolete = "f".repeat(24);
      for (const [id, contents] of [
        [
          unactivated,
          JSON.stringify({ build_id: unactivated, activated_at: 0 }),
        ],
        [unknown, "incomplete metadata"],
        [obsolete, JSON.stringify({ build_id: obsolete, activated_at: 1 })],
      ]) {
        await (
          await caches.open(prefix + id)
        ).put(marker, new Response(contents));
      }
      return {
        unactivated: prefix + unactivated,
        unknown: prefix + unknown,
        obsolete: prefix + obsolete,
      };
    });
    // B is waiting, while C has an open cache and a held engine response.
    await page
      .getByRole("button", { name: "Update and restart", exact: true })
      .click();
    await expect(page.locator("#game-version")).toHaveText("0.4.0-alpha.2");
    const cacheDuring = await page.evaluate(() => caches.keys());
    expect(
      cacheDuring.some((name) => name.endsWith(builds.third.metadata.build_id)),
    ).toBe(true);
    expect(cacheDuring).toContain(extraCaches.unactivated);
    expect(cacheDuring).toContain(extraCaches.unknown);
    expect(cacheDuring).not.toContain(extraCaches.obsolete);
    delayed = false;
    releaseAsset();
    releaseAsset = undefined;
    await expect(
      page.getByRole("button", { name: "Update and restart", exact: true }),
    ).toBeVisible();
    await expect(page.locator("#red-veil-web-update-status")).toContainText(
      "0.4.0-alpha.3",
    );
    await page
      .getByRole("button", { name: "Update and restart", exact: true })
      .click();
    await expect(page.locator("#game-version")).toHaveText("0.4.0-alpha.3");
    await context.setOffline(true);
    await page.reload();
    await expect(page.locator("#game-assets")).toContainText(
      "ENGINE 0.4.0-alpha.3",
    );
  });

  test("packager is repeatable and detects modified prepared assets", async () => {
    const args = [
      "scripts/prepare_web_release.py",
      "--directory",
      builds.first.folder,
      "--version",
      "0.4.0-alpha.1",
      "--commit",
      "a".repeat(40),
    ];
    const result = JSON.parse(
      execFileSync("python3", args, { cwd: repository, encoding: "utf8" }),
    );
    expect(result.build_id).toBe(builds.first.metadata.build_id);
    const pack = builds.first.metadata.assets.find((asset) =>
      asset.path.endsWith("index.pck"),
    );
    await writeFile(
      join(builds.first.folder, decodeURIComponent(pack.path)),
      "changed",
    );
    expect(() =>
      execFileSync("python3", args, { cwd: repository, stdio: "pipe" }),
    ).toThrow();
  });
});
