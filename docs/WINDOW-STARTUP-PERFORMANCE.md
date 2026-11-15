# Window startup performance — 0.7.1

Published [0.7.1-alpha.1](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/releases/tag/v0.7.1-alpha.1) defers optional outdoor assets until they are requested. In this Linux software-renderer measurement, the default window starts with **12.0% less process RSS and 48.3% less synchronous scene-construction time**. Opening the full world incurs the deferred construction cost, and its resources remain cached afterward. This is a startup improvement, not a reduction in the fully loaded game's memory requirement.

The measured candidate's runtime fingerprints exactly match published source `c86ad73da7810176e437e33e192a8d8475ae72a8`. The raw records retain their original candidate labels. [Release verification](evidence/release-0.7.1-alpha.1.json) links the separately tested and published packages; source-run measurements do not become exported-device benchmarks through that association.

The baseline measurement checkout is post-release documentation commit `b3c7d2c1081fcee7fc0dd845596ac4f0617f0bcd`. Its `game` tree is identical to the actual published 0.7 source, `8968859e8ffdcda7b8c0c216ff0262df633400e6`: the scoped Git diff is empty and both game-tree IDs are `ca07a16fc69af9a95bb8f7acfb1e8d70a9cd6c3b`. See [baseline provenance](evidence/window-startup/baseline/provenance.json). The candidate is the frozen 0.7.1 source recorded by the evidence fingerprints. Both use the same Godot executable, measurement scripts, viewport and driver files.

## Observed results

Each value below is the median of **three fresh processes**, after one excluded warmup per backend. Baseline and candidate ran sequentially while the other agents paused heavy tests. These are Linux warm-cache results, not Apple M5 measurements, GPU frame-rate measurements or physical-device acceptance results.

| Initial window measurement              | Released 0.7 | Candidate 0.7.1 | Change |
| --------------------------------------- | -----------: | --------------: | -----: |
| Native process RSS                      |   348.43 MiB |      306.64 MiB | −12.0% |
| Native synchronous construction         |       843 ms |          436 ms | −48.3% |
| Native eight-frame readiness checkpoint |     2,987 ms |        2,236 ms | −25.2% |
| Headless process RSS                    |   121.96 MiB |       86.97 MiB | −28.7% |
| Headless synchronous construction       |       795 ms |          382 ms | −51.9% |
| Whole-tree nodes                        |          649 |             235 | −63.8% |

Native construction ranged from **735–1,120 ms** in the baseline and **421–555 ms** in the candidate. Native initial RSS ranged from **348.16–355.45 MiB** and **306.60–306.75 MiB**, respectively. The small sample and shared host limit generalization; the raw observations are retained rather than presenting a single run as a device guarantee.

The first full-world reveal takes **394 ms** of synchronous construction in the candidate versus **1.6 ms** when the baseline's already-created assets are revealed. After rendering that content, median native RSS is approximately **429 MiB for both**. Returning to the window retains those cached assets and approximately the same RSS. A first visit to outdoor EVA or Habitat Field Notes therefore moves work from initial startup to that first visit.

## Geometry is measured separately from memory

The inventory runs in a different fresh process, after the memory runs have finished. Requesting mesh arrays can allocate temporary/generated data; those allocations must not be described as startup RSS.

| Initially retained full-game inventory              | Released 0.7 | Candidate 0.7.1 |
| --------------------------------------------------- | -----------: | --------------: |
| Mesh-bearing nodes / unique meshes                  |    277 / 277 |         84 / 84 |
| Potential triangles including instance multiplicity |      220,746 |          57,680 |
| Estimated unique uncompressed mesh-channel bytes    |    8,187,944 |       2,252,872 |
| Triangles belonging to currently visible nodes      |       40,008 |          40,008 |

These counts include the whole game, including retained hidden player equipment; they are not just the world subtree. Channel bytes estimate mesh payload, excluding allocator, textures, materials, driver and instance-buffer overhead. Potential/visible triangle counts are **not GPU draw work, occlusion results or FPS**. The harness never reads MultiMesh transforms or bounds through the headless dummy renderer.

After the optional world is constructed, both versions have the same inventory: 277 unique meshes, 220,746 potential triangles and 8,187,944 estimated channel bytes. The optimization avoids constructing unused content at startup; it does not simplify the authored meshes.

## Visual and behavior checks

The [before](evidence/window-startup/baseline/visual/window_initial.png) and [after](evidence/window-startup/candidate/visual/window_initial.png) default-window captures use the same 1280×720 camera, deterministic random seed and frozen ambient time. The HUD, dunes and framing match. **52 of 921,600 pixels differ (0.0056%)**, confined to Mira's small on-screen figure; the maximum channel difference is 27/255 and the mean absolute channel difference across the image is 0.000084/255. These captures are visually equivalent at the inspected view, **not pixel-identical**; the small differences are not attributed to a proven driver cause.

The fixed full-world view differs at two pixels. Returning directly to the window reproduces each version's own initial window image exactly. Habitat Field Notes opens from a fresh title scene after demand-loading; closing it restores the exact camera transform, FOV, active camera, title visibility and window presentation. Its returned-title captures are pixel-identical across versions.

The companion's phase-by-phase route and mission-state traces are exactly equal. Both runs finish the walking/cycling/entry sequence protected, and the visual actor position matches the model. These are deterministic controller checks after full-world reveal and return, not a human playtest.

All PNGs are unedited viewport captures. Numerical pixel comparisons save statistics only; they do not create altered screenshots.

## Method and reproducibility

`scripts/profile_window_startup.py` invokes the same external `game/tests/profile_window_startup.gd` against each checkout. It uses isolated disposable user profiles and three separate process purposes:

1. **Memory/timing:** record initial window, first full-world reveal and return-to-window checkpoints. The parent samples `/proc/PID/status` five times at 10 ms intervals at each checkpoint, before any mesh-array or screenshot readback. Polling also records process high-water information separately.
2. **Inventory:** enumerate retained mesh resources and channel estimates in another fresh headless process.
3. **Visual/route:** capture fixed views, advance the real rescue controller and exercise Field Notes in a separate native process.

Construction times cover scene load, instantiation and synchronous `add_child` work. Readiness adds eight process frames from that scene-start timestamp; it is **not a measured first-frame or input-latency milestone**. The parent also records process-launch-to-checkpoint wall time. Geometry inventory and image readback do not contaminate reported startup RSS. The memory process later includes optional-world allocation, so its overall peak is not the initial-window footprint.

Native runs use authenticated X11/Xvfb and Mesa llvmpipe software OpenGL. The deferred external update query is suppressed in the harness while the allocated client node remains present. Ambient time is fixed and RNG seeded for comparison. OS/import/shader caches are warm; cold disk startup, GPU memory, battery use, physical GPUs and frame pacing are outside this experiment.

Requirements: Linux `/proc`, Godot 4.6.3, Xvfb, xauth and Pillow 13 for numerical image comparison. From the candidate checkout, use fresh output directories:

```sh
python3 scripts/profile_window_startup.py --project /path/to/released-checkout --label released-0.7 --output /tmp/window-before --runs 3 --xvfb /path/to/Xvfb
python3 scripts/profile_window_startup.py --project /path/to/candidate-checkout --label candidate-0.7.1 --output /tmp/window-after --runs 3 --xvfb /path/to/Xvfb --baseline /tmp/window-before/report.json
```

The [baseline report](evidence/window-startup/baseline/report.json), [candidate report](evidence/window-startup/candidate/report.json) and [comparison](evidence/window-startup/candidate/comparison.json) retain every measured run, ranges, source/executable/driver/harness fingerprints, inventory and QA results. Per-process JSON and logs remain beside them. Raw `.log` files were renamed `.txt` without content changes so repository ignore rules retain them. Temporary profiles and redundant acknowledgement/checkpoint synchronization files are excluded from the curated evidence.
