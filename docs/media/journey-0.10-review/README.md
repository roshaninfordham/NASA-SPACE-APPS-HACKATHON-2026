# Additional native screenshots for the screen review

The first fourteen PNG files listed below are byte-for-byte copies from the existing **135-screen 0.10 native capture run**, not newly rendered mockups or retouched images. They supplement the [main 0.10 gallery](../journey-0.10/README.md) with paused, expanded-detail and small-screen states. The review manifest reuses the existing gallery images where possible instead of duplicating them. Three further native screenshots capture actual PASS / TRY AGAIN outcomes and the idle source-run update interface, as described below.

The original run loaded the actual `game/main.tscn`, disabled online requests, isolated player data and explicitly advanced the real mission model to repeatable points. The loading image captured the actual temporary loading state; the bubble-merge frame intentionally held the real shell transition at 0.35 seconds. NASA viewer images in this set show a clearly labeled bundled example, not a fresh network observation. Native phone-shaped viewport screenshots do not establish browser or physical-phone compatibility.

`capture-provenance.json` retains the original runtime/source fingerprints, actual model snapshots and fixture actions for these additional files, together with their image hashes. The original source stayed unchanged throughout the capture and the five-viewport run reported zero horizontal layout findings. The game source commit is `26f19540baf330b00b0ac4a1b470d0e1439f7382`. These additional image files are committed later; the review-site builder pins their image URLs to the commit that contains them while retaining the original game source commit.

| Image                                              | Original capture                 | Viewport   |
| -------------------------------------------------- | -------------------------------- | ---------- |
| [storm-soon.png](storm-soon.png)                   | 07-storm-soon-1280x720.png       | 1280 × 720 |
| [power-card.png](power-card.png)                   | 13-energy-concept-1280x720.png   | 1280 × 720 |
| [mission-microgray.png](mission-microgray.png)     | 10-live-concept-1280x720.png     | 1280 × 720 |
| [nasa-details.png](nasa-details.png)               | 26-nasa-details-1280x720.png     | 1280 × 720 |
| [pause.png](pause.png)                             | 05-pause-1280x720.png            | 1280 × 720 |
| [settings.png](settings.png)                       | 06-settings-1280x720.png         | 1280 × 720 |
| [worked-numbers.png](worked-numbers.png)           | 15-energy-equation-1280x720.png  | 1280 × 720 |
| [run-graphs.png](run-graphs.png)                   | 12-debrief-graphs-1280x720.png   | 1280 × 720 |
| [learning-question.png](learning-question.png)     | 09-debrief-question-1280x720.png | 1280 × 720 |
| [phone-story.png](phone-story.png)                 | 01-story-320x568.png             | 320 × 568  |
| [small-phone-mission.png](small-phone-mission.png) | 04-cleaning-320x568.png          | 320 × 568  |
| [small-phone-results.png](small-phone-results.png) | 08-debrief-320x568.png           | 320 × 568  |
| [phone-science.png](phone-science.png)             | 14-worked-equations-390x844.png  | 390 × 844  |
| [landscape-mission.png](landscape-mission.png)     | 04-cleaning-844x390.png          | 844 × 390  |

The source capture directory was `/tmp/komaku-journey-0.10-final`. It is a reproducible local QA artifact, not a public download URL. To reproduce the full native capture from the corresponding game source, use `scripts/capture_journey.py` with a fresh output directory, Godot, Xvfb and Pillow. The screen-review build uses committed PNG bytes directly and verifies dimensions and SHA-256 hashes before copying them.

## Additional computed outcomes

These three files are new, unretouched captures of the same game source commit. The review-only helper verifies every original game capture input against commit `26f19540baf330b00b0ac4a1b470d0e1439f7382` before running, and checks source fingerprints again afterward. It loads the actual main scene, sets the real cleaning slider, presses Start, then advances the unmodified model by 90 active seconds. The coordinator creates its own result screen; the fixture never supplies a fabricated result dictionary. Audio is muted and online requests are disabled in isolated player data.

| Image                                          | Actual model result                                               | Viewport   |
| ---------------------------------------------- | ----------------------------------------------------------------- | ---------- |
| [mission-pass.png](mission-pass.png)           | 0.5× pace; PASS; 46.875% clean; 1.703125 kWh; 10.9375 µGy         | 1280 × 720 |
| [mission-try-again.png](mission-try-again.png) | 0.25× pace; TRY AGAIN; 23.4375% clean; 1.3515625 kWh; 10.9375 µGy | 1280 × 720 |
| [updates.png](updates.png)                     | Home → Updates & downloads; source-run idle interface             | 1280 × 720 |

Both completed missions put Ren inside automatically. The update screenshot explicitly reports that in-game installation is unavailable in this source-run mode. No update check, download or install is performed. This is review evidence for the source-run interface, not evidence of packaged-host update support or successful installation. Native captures likewise do not establish macOS, Windows or physical-phone behavior.

`outcome-capture-provenance.json` records the three actual model snapshots, UI actions, game and helper fingerprints, verified game commit, image hashes and zero fixture failures. The capture source and helper files stayed unchanged throughout the run. The helper is under `game/tests/`, excluded from game exports.

Reproduce into a new directory, using the corresponding game source plus these review helpers:

```sh
python3 scripts/capture_review_outcomes.py --output /tmp/komaku-review-outcomes-new --xvfb /path/to/Xvfb
```
