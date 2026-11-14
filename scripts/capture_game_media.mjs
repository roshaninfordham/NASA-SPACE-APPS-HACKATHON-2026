#!/usr/bin/env node
// Capture actual exported gameplay. Does not alter game state, artwork, or outcomes.
import { chromium } from "@playwright/test";
import { mkdir, writeFile } from "node:fs/promises";
import { resolve, join } from "node:path";
import { spawnSync } from "node:child_process";

const argumentsMap = new Map();
for (let index = 2; index < process.argv.length; index += 2) {
  argumentsMap.set(process.argv[index], process.argv[index + 1]);
}
const url = argumentsMap.get("--url");
const version = argumentsMap.get("--version");
const source = argumentsMap.get("--source");
if (!url || !version || !/^[0-9a-f]{40}$/.test(source || "")) {
  throw new Error(
    "Use --url URL --version VERSION --source EXACT_40_CHARACTER_COMMIT [--output DIRECTORY]",
  );
}
if (!/^\d+\.\d+\.\d+(?:-alpha\.\d+)?$/.test(version)) {
  throw new Error("Unsupported capture version");
}
const output = resolve(argumentsMap.get("--output") || "docs/media");
const raw = resolve(argumentsMap.get("--raw") || "/tmp/red-veil-media-capture");
await mkdir(output, { recursive: true });
await mkdir(raw, { recursive: true });
const prefix = `red-veil-${version}`;
const browser = await chromium.launch({
  executablePath: process.env.CHROMIUM_PATH || "/usr/bin/chromium",
  args: [
    "--no-sandbox",
    "--use-angle=swiftshader",
    "--enable-unsafe-swiftshader",
  ],
});
const errors = [];
const watch = (page) => {
  page.on("pageerror", (error) => errors.push(error.message));
  page.on("console", (message) => {
    if (message.type() === "error") errors.push(message.text());
  });
};
const ready = async (page) => {
  await page.goto(url);
  await page.waitForFunction(() => !document.querySelector("#status"), {
    timeout: 60_000,
  });
  await page.waitForTimeout(1000);
};
try {
  if (argumentsMap.get("--mode") !== "gameplay") {
    const stills = await browser.newContext({
      viewport: { width: 1280, height: 720 },
    });
    const page = await stills.newPage();
    watch(page);
    await ready(page);
    await page.screenshot({ path: join(output, `${prefix}-title.png`) });
    await page.mouse.click(440, 580);
    await page.waitForTimeout(400);
    await page.screenshot({ path: join(output, `${prefix}-academy.png`) });
    await page.mouse.click(600, 200);
    await page.waitForTimeout(400);
    await page.screenshot({ path: join(output, `${prefix}-question.png`) });
    await stills.close();
  }

  const recording = await browser.newContext({
    viewport: { width: 960, height: 540 },
    recordVideo: { dir: raw, size: { width: 960, height: 540 } },
  });
  const videoEpoch = Date.now();
  const game = await recording.newPage();
  watch(game);
  await ready(game);
  const gameplayStart = (Date.now() - videoEpoch) / 1000;
  await game.mouse.click(230 * 0.75, 515 * 0.75);
  await game.waitForTimeout(500);
  await game.mouse.move(515 * 0.75, 515 * 0.75, { steps: 12 });
  await game.keyboard.down("w");
  await game.waitForTimeout(5300);
  await game.keyboard.up("w");
  await game.keyboard.press("q");
  await game.keyboard.down("e");
  await game.waitForTimeout(2500);
  await game.screenshot({ path: join(output, `${prefix}-mission.png`) });
  await game.waitForTimeout(1500);
  await game.keyboard.up("e");
  const duration = (Date.now() - videoEpoch) / 1000 - gameplayStart;
  const video = game.video();
  await recording.close();
  const videoPath = join(raw, `${prefix}-gameplay.webm`);
  await video.saveAs(videoPath);
  const gif = join(output, `${prefix}-gameplay.gif`);
  const ffmpeg = spawnSync(
    "ffmpeg",
    [
      "-hide_banner",
      "-loglevel",
      "error",
      "-y",
      "-ss",
      String(gameplayStart),
      "-t",
      String(duration),
      "-i",
      videoPath,
      "-filter_complex",
      "[0:v]fps=10,split[a][b];[a]palettegen=max_colors=128:stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=3",
      "-loop",
      "0",
      gif,
    ],
    { encoding: "utf8" },
  );
  if (ffmpeg.status !== 0)
    throw new Error(`GIF encoding failed: ${ffmpeg.stderr}`);
  const evidence = {
    version,
    source,
    url,
    captured_utc: new Date().toISOString(),
    viewport: "1280x720 title/academy stills; 960x540 gameplay recording",
    gif: "960x540, 10 fps, 128-color GIF encoding",
    inputs:
      "Begin; mouse turn toward array; walk forward (W); toggle visor cleaning (Q); hold interaction (E)",
    actual_gameplay: true,
    limits:
      "Software-rendered Chromium capture, provisional artwork, not a performance benchmark or native-platform validation. GIF omits startup/loading and has no audio.",
    browser_errors: errors,
  };
  await writeFile(
    join(raw, "capture-evidence.json"),
    `${JSON.stringify(evidence, null, 2)}\n`,
  );
  console.log(JSON.stringify(evidence, null, 2));
  if (errors.length) process.exitCode = 1;
} finally {
  await browser.close();
}
