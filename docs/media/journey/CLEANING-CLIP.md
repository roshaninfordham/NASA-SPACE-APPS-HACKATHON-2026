# Actual native cleaning motion

![Ren cleaning the visible panel during ordinary gameplay](cleaning-live.gif)

This silent clip shows approximately six seconds of the actual native game running its ordinary clock. Ren's hand and cleaning wand use the production animation, and the visible dust layer follows the mission model continuously. The clip starts from a documented fixture of 1.9 cleared sections and 16% game fatigue, after explicit Start, 60 active seconds at steady pace and 80 at the 1.25× setting. It uses no camera changes, hand-joint assignments, time-lapse or invented frames. The additional dust cleared during six seconds is deliberately modest.

The whole 960 × 540 viewport is scaled to 640 × 360 for this GIF, after a brief renderer warm-up. Playback retains the measured frame timing; a shared GIF palette changes image colour precision. This demonstrates native Linux animation, not performance on every device. See [`cleaning-live-provenance.json`](cleaning-live-provenance.json) for source hashes, frame hashes/timestamps, model start/end values and encoding details. Raw frame paths refer to the reproducible temporary capture directory, not bundled release assets.

Reproduce from the repository root:

```sh
python3 scripts/capture_cleaning_clip.py --output /tmp/komaku-cleaning-clip --publish-to docs/media/journey
```

Godot, Xvfb and Pillow are required. Use `--xvfb /path/to/Xvfb` when needed. Online requests are disabled in this capture fixture.
