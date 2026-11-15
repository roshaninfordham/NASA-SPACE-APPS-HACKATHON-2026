# Download and play <!-- brand:display_name -->KŌMAKU: Dust & Radiation<!-- /brand -->

**This package: 0.11.0-alpha.1.** These instructions name the files in this version. Official downloads and publication status are listed on the [0.11.0 release page](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/releases/tag/v0.11.0-alpha.1). GitHub **Release assets**, rather than the Packages tab or source-code ZIP, contain the runnable game.

This version restores the outpost window and eight live science bubbles while retaining the clearer fonts, controls and 90-second format of [0.10.0-alpha.1](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/releases/tag/v0.10.0-alpha.1). The underlying science equations remain unchanged. That earlier release is preserved rather than overwritten. Use the files and filenames for this package below.

## Choose the download for this version

| Platform or document      | Official 0.11.0 file                                                                                                                                                                                                             |
| ------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Mac Apple Silicon / Intel | [KOMAKU-Dust-and-Radiation-0.11.0-alpha.1-macOS-universal.zip](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/releases/download/v0.11.0-alpha.1/KOMAKU-Dust-and-Radiation-0.11.0-alpha.1-macOS-universal.zip) |
| Windows x64               | [KOMAKU-Dust-and-Radiation-0.11.0-alpha.1-Windows-x64.zip](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/releases/download/v0.11.0-alpha.1/KOMAKU-Dust-and-Radiation-0.11.0-alpha.1-Windows-x64.zip)         |
| Linux x64                 | [KOMAKU-Dust-and-Radiation-0.11.0-alpha.1-Linux-x64.zip](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/releases/download/v0.11.0-alpha.1/KOMAKU-Dust-and-Radiation-0.11.0-alpha.1-Linux-x64.zip)             |
| WebGL2 browser            | [KOMAKU-Dust-and-Radiation-0.11.0-alpha.1-Web.zip](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/releases/download/v0.11.0-alpha.1/KOMAKU-Dust-and-Radiation-0.11.0-alpha.1-Web.zip)                         |
| Science guide             | [KOMAKU-Dust-and-Radiation-0.11.0-alpha.1-Science-Guide.pdf](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/releases/download/v0.11.0-alpha.1/KOMAKU-Dust-and-Radiation-0.11.0-alpha.1-Science-Guide.pdf)     |

Extract the **whole archive** into a normal folder before starting. Read its `START-HERE.txt`; native players do not need Godot, a code editor or a developer account. The archives include the science guide, technical equation sheet and word-only equation sheet. Keep bundled data files with the application.

## MacBook / macOS

1. Extract the macOS universal ZIP. It contains Apple Silicon arm64 and Intel x86_64 code.
2. Open **`KŌMAKU- Dust and Radiation.app`**. The filename intentionally uses “and”; the game displays **KŌMAKU: Dust & Radiation**. Do not rename files inside the app.
3. This alpha is ad-hoc signed, without Apple Developer ID or notarization. If macOS blocks a download you trust, use **System Settings → Privacy & Security → Open Anyway**, when offered.
4. If no usable override appears, the archive includes **`Install KŌMAKU.command`**. It verifies app integrity, requests explicit consent, copies the app to your own `~/Applications`, preserves an existing destination as a backup, removes quarantine only from that verified installed copy, and opens it. It does not require an administrator password or establish publisher identity; use it only for a trusted official download.

If macOS also blocks the helper, open Terminal, type `/bin/bash ` with a trailing space, drag **Install KŌMAKU.command** from Finder into Terminal, and press Return. Read its consent prompt before continuing. Do not disable Gatekeeper globally. For an extra integrity check, compare the archive's `shasum -a 256` output with the release's `SHA256SUMS.txt`.

An older app that cannot launch needs one corrected full installation before it can use in-game updates. Existing saves retain their location. Native hosted checks and a universal binary do not establish performance or every Finder/security-policy path on a physical M5 MacBook. [Mac repair context](MACOS-LAUNCH-REPAIR.md).

## Windows

Extract the whole Windows ZIP, then run **`KOMAKU-Dust-and-Radiation.exe`**. Do not open an executable from inside the ZIP preview. No development runtime is required.

This alpha has no Windows publisher certificate/reputation. If SmartScreen appears, use its available **More info → Run anyway** option only when you trust this repository's official download. Managed-device policy may prevent an override. Hosted startup checks do not remove SmartScreen or validate every graphics driver.

## Linux

Extract the Linux ZIP, then run **`KOMAKU-Dust-and-Radiation.x86_64`**. If your archive tool did not preserve its executable permission, enable “Allow executing file as program” in your file manager, or run `chmod +x KOMAKU-Dust-and-Radiation.x86_64` from that extracted folder. Keep the other archive files beside it. Distribution and graphics-driver coverage need their own testing.

## Start playing and reach the ending

After the three story scenes, **Opening the window…** appears while Ren and the panel are prepared. **Back to Home** cancels loading. The control room then opens in **preflight**: choose Ren's starting pace and press **START MISSION**, or press **Enter**. Nothing advances before Start.

The main view shows **panel cleaned, energy stored and storm time**, with eight live science bubbles around the outpost window. **View** offers the default **Science window** or a **Focused window**; switching preserves the current mission. **Menu** opens paused navigation. Scripted radio captions remain visible when sound is off. Use **Slower / 1**, **Faster / 3**, or the red stepped slider to choose pace. The timer counts about **90 active real seconds** at standard pacing. **Science** pauses the mission and opens the optional eight-concept library; cards begin with a short explanation and diagram, with **Learn more** and **Data & sources** for detail. **Time → Learn more** explains the **30 simulated minutes** used in the equations.

Pause, reading and accessibility clock settings can extend actual wall time. Escape handles the current dialog, Pause and fullscreen exit; F11 toggles fullscreen.

At zero, Ren automatically enters and the result opens with actual cleaned percentage, stored kWh and absorbed model dose. Choose **See how science connects** for the bubble merge and four short relationships, then **Explore my numbers and graphs** for the full equations. **Back to results**, **Try another plan** and **Home** remain available. There is no return walk or recall command in this mission.

WIN means at least 80% cleaned, PASS at least 40%, otherwise TRY AGAIN. Ren is inside in every outcome. Energy and dose explain the run rather than adding hidden success tests. Completed default rounds share the same 10.9375 µGy model dose; the game does not infer health or personal sievert readings. [Model](TRAINING-MODEL.md).

## Updates after installation

Open **Updates & downloads**, check for a new compatible release, choose **Install**, then confirm **Restart**. The game verifies the signed content and keeps recovery content. It also checks at a fresh launch; there are no closed-app push notifications or forced restarts. Native engine/bootstrap changes require a full installer.

A content update preserves the existing OS app filename while the game displays its current title. This is expected; progress, app IDs and signing trust remain stable. New 0.11.0 installers use the filenames above. Mac metadata is `0.11.0`, Windows file/product metadata is `0.11.0.1`, and the full game/update identity is `0.11.0-alpha.1`.

Release acceptance uses activation/recovery checks on seven original Mac/Windows baseline versions, including 0.10.0, plus the documented Linux 0.4 baseline. See the official release page and [update evidence and limits](UPDATES.md) for the results and scope; local content-activation checks do not establish every physical-device or HTTP/relaunch path.

## Browser and mobile

The Web archive requires HTTP(S) hosting and WebGL2; do not double-click `index.html` using a file URL. For a local test, serve the extracted folder with `python3 -m http.server 5190 --directory <extracted-folder>`, then visit that server in a browser. Public hosting of the current playable game remains deferred. The separate [screen-review gallery](https://roshaninfordham.github.io/NASA-SPACE-APPS-HACKATHON-2026/review/) contains screenshots and annotations, not a playable browser build. No production native Android or iOS installer is published.

## Historical versions and optional earlier activities

Versions 0.5–0.8 used `KOMAKU-Shield-Protocol` archive/executable names; 0.4 and earlier used `Red-Veil`. Those names apply only to those older downloads. The [0.8 release record](evidence/release-0.8.0-alpha.1.json) documents the earlier five-minute standard round. Do not follow its old executable names when opening the current package.

The retained **Advanced lab · earlier mission** offers the older operator/EVA activities with their own rules. Walking, equipment interaction, Mira's return route and the longer survival mission belong there, not to the current short Ren/panel mission. [Earlier mission planner](MISSION-PLANNER.md).

No account is required. Report the release version, device, operating system, steps and exact error when asking for help, without including personal information in public issues.
