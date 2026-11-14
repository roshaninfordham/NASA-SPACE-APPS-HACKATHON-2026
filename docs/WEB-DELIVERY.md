# Browser and home-screen delivery

**Hosting is deferred by owner choice.** Deployment run `43638541666` succeeded, but public verification found that the account-wide Pages custom domain redirects the repository URL to another website. It is not a verified public game link. Automatic deployments require repository variable `RED_VEIL_WEB_DEPLOY_ENABLED=true`; leave it unset until a separate game address has been configured and tested. Native downloads and signed desktop updates remain available. The prepared export passed real Chromium launch and offline reload locally; 14 desktop/mobile-layout browser-update tests pass.

<!-- brand:display_name -->KŌMAKU: Shield Protocol<!-- /brand --> can have a hosted browser edition alongside the downloadable desktop game. On supported browsers, the hosted edition can be installed to the home screen without an App Store submission. This is a Progressive Web App (PWA), not a native iOS package. Browser capabilities, available memory, operating-system storage policy, and physical-device playtesting still determine whether it is a good experience on a particular phone or tablet.

The browser update system is separate from the desktop signed-content updater. Its trust boundary is the HTTPS website origin and the code that origin publishes. SHA-256 checks prevent partial or mismatched builds from becoming ready; they are not an independent signature against a compromised hosting account. There are no accounts, analytics, remote learner profiles, browser push notifications, or background phone alerts.

## Player flow

1. Open the hosted game's root URL over HTTPS. The initial online visit downloads the game and saves a complete verified copy for offline play.
2. Use the browser's Install option where available. On iPhone/iPad Safari, use **Share → Add to Home Screen**. The interface includes installation help; a browser may decide not to offer an installation prompt.
3. A small **Update ready** notice appears when the next complete build has finished caching and its hashes match. It does not restart or pause the current mission.
4. **Later — keep playing** leaves the current session running. **Update and restart** explicitly ends that session and reloads the updated game. Finish a mission before using it.
5. If another <!-- brand:display_name -->KŌMAKU: Shield Protocol<!-- /brand --> tab or app window is open, the update asks the player to close it first and click again. It does not navigate or restart other windows.

The browser checks the worker when the game is opened. **Check for updates** requests a fresh check while the game remains open. Browsers may also perform their own service-worker checks; this is not a guaranteed real-time notification service. An installed but closed PWA does not receive background alerts from this implementation.

## Packaging

After exporting the single-threaded Godot Web build:

```sh
python3 scripts/prepare_web_release.py --directory releases/web --version 0.4.0-alpha.1 --commit FULL_40_CHARACTER_SOURCE_COMMIT
```

The command works on an export directory, including an extracted published Web ZIP. Its output remains in that directory:

- `index.html`: the stable entry page, retaining the Godot canvas/loader and adding browser update controls.
- `index.manifest.json` (or the matching executable prefix): stable install identity and scope, home-screen metadata and local icons.
- `index.service.worker.js` (or the export's existing worker filename): the complete-build caching worker. Keeping the worker URL replaces the earlier default Godot worker registration.
- `red-veil-builds/<content-build-id>/`: the complete exported file inventory plus the small update script and stylesheet. Engine, PCK, worklets, icons, and other exported files have immutable build paths.
- `web-release.json`: source version/commit, content build ID, sizes, SHA-256 hashes, and the generated worker hash for inspection.

The content build ID incorporates the export files, version, source commit, and packaging templates. The actual cache inventory contains the SHA-256 hash and exact length of every packaged game asset, including the root shell and manifest. Inventory paths are percent-encoded relative URLs; resolve them against the hosting root, or URL-decode them for filesystem inspection. The worker and release inventory cannot recursively hash themselves; the generated worker embeds the game inventory, and the separate inspection metadata records the worker hash.

The packager disables Godot's built-in worker registration. Its default worker lazily caches the WASM/PCK and can reload all clients on an update message; those behaviors are not used here. The export must be single-threaded, use local HTML assets, and include the Godot PWA icons. Current packaging budgets are 256 MiB per file, 384 MiB total, and 2,048 cache entries. These are explicit engineering limits, not mobile performance claims.

Preparing an unchanged processed directory again verifies its assets and worker and returns the same build ID. A changed version needs a fresh Godot export or the original unprocessed Web ZIP. Publish the entire prepared directory as one deployment; do not upload its individual files piecemeal while users are loading it. Hosting/deployment workflows are maintained separately.

## Cache and activation guarantees

The installing worker streams each same-origin asset into a bounded buffer, checks its length and SHA-256 digest, and writes it to a new build cache. It marks the build complete only after every listed asset is present. A failed fetch, oversized/truncated response, wrong hash, or cache write error rejects installation and removes that candidate cache. The active worker and its complete cache are not replaced by that failed attempt.

A waiting worker is activated only after the player requests the update and the worker confirms that only the requesting <!-- brand:display_name -->KŌMAKU: Shield Protocol<!-- /brand --> window is open. The browser may naturally activate a waiting worker after every old game window is closed; no mission is running in that case. The application never calls `client.navigate()` and reloads only the window that requested the update.

Versioned asset paths keep old and new engine/PCK combinations separate, including a window opened during the narrow activation race. The current build and previous activated build are retained. Cleanup only targets positively identified, previously activated obsolete builds; partial, prepared-but-unactivated, and unrecognized caches are retained. Per-build Web Locks prevent cleanup from deleting a cache while another worker is preparing it, including when an older build is being offered again. Browsers without Web Locks keep the extra caches instead of pruning unsafely. Multiple windows also cause cleanup to retain additional caches. Caches belonging to the older default Godot worker are not indiscriminately deleted during migration.

If the browser evicts site storage, the device runs out of space, or the user clears website data, offline play may require another complete online download. Cache Storage is not an unlimited or permanent filesystem. The worker fails closed with a reconnect message when required saved assets are missing; it does not silently combine a partial old build with new assets from the server. A successful cache verification does not prove the new gameplay is bug-free; release validation remains necessary.

The first transition from an older default Godot Web export may require closing all old game tabs and reopening the site. An old HTML shell cannot show update controls it does not contain. Native alpha downloads likewise cannot acquire a new updater without an initial updater-capable installation.

## Repository subpaths and integration

All generated references are relative to the export's hosting root. A GitHub Pages project URL such as `/NASA-SPACE-APPS-HACKATHON-2026/` receives that scope; no service worker is registered at the account-wide `/` path. Keep the same hosting URL across updates to preserve the installed app's identity and browser storage.

The web UI exposes `window.RedVeilWebUpdates.open()` and `.check()`. The Godot Web-only menu can call these through `JavaScriptBridge`; it should not invoke the native PCK installation path. Presentation is isolated in `game/web/browser-updates.css` with color variables and ordinary accessible HTML buttons. The game remains the same Godot canvas, so this does not establish screen-reader accessibility for the whole 3D game.

Browser progress stays in local site storage. It is not synchronized with a native desktop installation or between devices. Browser installations, private browsing, and platform-specific storage separation can affect whether progress appears shared. Clearing site data may erase both cached game files and local progress.

## Validation evidence

`tests/pwa-updates.spec.js` starts its own local HTTP server and builds two small export fixtures through the production packager. It exercises:

- Complete export-inventory caching, repository subpaths, and offline reload.
- A delayed engine download that prevents an update from being offered prematurely.
- Deferring an update without restarting the session, followed by explicit update/restart and offline use of the new build.
- Fetch failure and same-size hash corruption, both retaining the previous complete offline game.
- Multiple windows: another session is never restarted; activation waits for it to close.
- Overlapping releases: activating a ready build does not delete a newer build whose engine is still downloading; both can subsequently activate and the newest works offline.
- Repeatable packaging and rejection of modified prepared files.

These transport/control fixtures do not replace an actual exported-game launch, an operating-system installation test, or physical iPhone/iPad testing. The release checklist should record those separately. The existing browser-test configuration only discovers `tests/browser`; this suite needs the dedicated PWA configuration or an explicit test configuration that includes its file.
