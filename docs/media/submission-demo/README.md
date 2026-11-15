# KŌMAKU submission demo

[Download the 29.5-second MP4](KOMAKU-30-second-demo.mp4). H.264/AAC, 1920×1080, 24 fps, approximately 2.5 MB; captions are burned in. The native footage was captured at a lower resolution and scaled for the 1080p presentation.

The edit shows the actual prototype: outpost window, Ren’s animated cleaning, two ordinary pace-slider commands, NASA research context, a computed mission result and the science connections screen. It is an edited engine capture, not footage of a human child playing or a hardware-performance benchmark. No generated actor or invented gameplay frames appear. The 14-second game segment uses Godot MovieWriter’s fixed 24 fps; the full mission remains 90 active-play seconds. The result and science screens use a later completed-model fixture, documented alongside the source captures.

## Narration and music

AI-generated Indian English male narration using Microsoft **en-IN-PrabhatNeural**, rate +10%; 27.144 seconds. It is not a human voice recording. The script, timed captions and word boundaries are included. Pronunciation text uses “Koh mah koo”; on-screen captions retain the actual game name. Background audio is the project’s original procedural `orbit.ogg`; the two team-supplied YouTube recordings are not used in this demo. Fonts are the repository’s licensed Jost and IBM Plex Sans.

## NASA sources

- Curiosity RAD historical Mars surface radiation: https://ntrs.nasa.gov/citations/20180007641
- Pathfinder settled-dust/solar-cell research: https://ntrs.nasa.gov/citations/20020031145

These research anchors are distinct from the authored storm, cleaning speed and fatigue settings. The separate live NASA SDO viewer does not predict the Mars mission’s storm. No partner data or sponsor integration is claimed in the narration.

## Edit and verification

0–2.5s story; 2.5–16.5s actual gameplay; 16.5–21.5s NASA research card; 21.5–25s computed result; 25–29.5s science connections. Full viewport images preserve the controls. Narration captions occupy a separate lower band.

`demo-provenance.json` records source/video hashes and FFprobe output. `sources/` contains the original screen captures, trimmed gameplay and native-capture provenance, including source hashes taken during the visual upgrade. This is preview footage; it is not evidence that a new game release has been published. The `.gd.txt` file preserves the MovieWriter capture fixture as evidence without importing it into the game.

Rebuild the final edit with Python/Pillow and FFmpeg installed:

```sh
python scripts/build_submission_demo.py
```

Made with love by Team Roshan Xingbo at the NASA Space App Hackathon 2026, NYC.
