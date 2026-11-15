# Additional native screenshots for the 0.11 screen review

The review gallery contains **41 actual game screenshots**. It reuses the 24 selected images in the [main 0.11 gallery](../journey-0.11/README.md), adds the fourteen unchanged captures listed below, and includes three additional actual outcome/update screenshots. No screenshot is a mockup, retouched image or substitute render.

The game source commit is `20e361a2099f7bc67aacb0e7eedb65c7eab9d0a0`. These review-only image files are committed later. The review builder pins each image URL to the commit containing that image while retaining the original game source commit and exact SHA-256 hash, so feedback identifies the correct version and image.

## Additional screens from the full capture

These files are byte-for-byte copies from the **170-screen native capture**, which covered 34 states at five viewport sizes. The actual main scene uses the Science window by default: the outpost frame and eight live concept bubbles surround the work area. Focused window gives the panel and Ren more room while keeping Science available. Portrait layouts use a horizontally scrollable concept rail; the short landscape example uses compact side columns. The new navigation screenshots show View, Focused window and settings returning to their actual View, mission-menu or Home origin.

The full fixture disabled online requests, isolated user data, muted audio and explicitly advanced the real mission model to repeatable points. The loading capture is the real cancellable loading state. The bubble merge is the real transition held at 0.35 seconds for reproducibility. NASA screenshots show the explicitly labeled bundled example, not a fresh observation. Mission values and results come from the actual model; result summaries are never fabricated.

| Image                                                  | Original capture                 | Native viewport |
| ------------------------------------------------------ | -------------------------------- | --------------- |
| [storm-soon.png](storm-soon.png)                       | 07-storm-soon-1280x720.png       | 1280 × 720      |
| [power-card.png](power-card.png)                       | 13-energy-concept-1280x720.png   | 1280 × 720      |
| [mission-microgray.png](mission-microgray.png)         | 10-live-concept-1280x720.png     | 1280 × 720      |
| [nasa-details.png](nasa-details.png)                   | 26-nasa-details-1280x720.png     | 1280 × 720      |
| [pause.png](pause.png)                                 | 05-pause-1280x720.png            | 1280 × 720      |
| [settings.png](settings.png)                           | 06-settings-1280x720.png         | 1280 × 720      |
| [view-settings.png](view-settings.png)                 | 29-view-settings-1280x720.png    | 1280 × 720      |
| [worked-numbers.png](worked-numbers.png)               | 15-energy-equation-1280x720.png  | 1280 × 720      |
| [run-graphs.png](run-graphs.png)                       | 12-debrief-graphs-1280x720.png   | 1280 × 720      |
| [learning-question.png](learning-question.png)         | 09-debrief-question-1280x720.png | 1280 × 720      |
| [phone-story.png](phone-story.png)                     | 01-story-320x568.png             | 320 × 568       |
| [small-phone-view-menu.png](small-phone-view-menu.png) | 27-view-menu-320x568.png         | 320 × 568       |
| [small-phone-results.png](small-phone-results.png)     | 08-debrief-320x568.png           | 320 × 568       |
| [phone-science.png](phone-science.png)                 | 14-worked-equations-390x844.png  | 390 × 844       |

`capture-provenance.json` records the selected original fixture actions, model snapshots, all 100 source fingerprints, unchanged-source status and zero horizontal-layout findings. It retains the original capture revision metadata and adds the game commit verified against those exact source bytes. The full local artifact was `/tmp/komaku-journey-0.11-final`; this is a QA directory, not a public download link. Reproduce the full run from the corresponding game source using `scripts/capture_journey.py` with Godot, Xvfb and Pillow.

## PASS, TRY AGAIN and the update menu

Three further captures use the same unchanged game source. They load the actual main scene, set the real slider, press Start and advance the unmodified model by 90 active seconds. The coordinator displays the computed outcome. Both outcomes put Ren inside automatically.

| Image                                          | Actual model outcome                                                                  | Native viewport |
| ---------------------------------------------- | ------------------------------------------------------------------------------------- | --------------- |
| [mission-pass.png](mission-pass.png)           | 0.5× pace; PASS; 46.875% cleaned; 1.703125 kWh stored; 10.9375 µGy model dose         | 1280 × 720      |
| [mission-try-again.png](mission-try-again.png) | 0.25× pace; TRY AGAIN; 23.4375% cleaned; 1.3515625 kWh stored; 10.9375 µGy model dose | 1280 × 720      |
| [updates.png](updates.png)                     | Home → Updates & downloads; isolated source-run idle interface                        | 1280 × 720      |

`outcome-capture-provenance.json` records their actual snapshots, UI actions, helper and game hashes, unchanged-source status and zero fixture failures. The local artifact was `/tmp/komaku-outcomes-0.11-final`. The update interface correctly says that in-game installation is unavailable in this source-run mode. No update check, download or install was requested; the screenshot does not establish packaged-host updater behavior.

These Linux/Godot compatibility-renderer captures check composition at desktop, portrait and landscape viewport sizes. They do not establish real-time play, audio quality, physical-phone performance, macOS/Windows installation or updater success. Model fatigue, cleaning rates and the radiation storm remain authored teaching settings; the images are not medical readings or NASA forecasts. The gallery builder verifies the copied PNG hashes and dimensions before producing the review site.
