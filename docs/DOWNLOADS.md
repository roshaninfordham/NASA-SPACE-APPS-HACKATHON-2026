# Download and play <!-- brand:display_name -->KŌMAKU: Shield Protocol<!-- /brand -->

Downloads are published as **GitHub Release assets**, not GitHub Packages. A repository containing code and export presets does not imply that an installer exists. Use the release notes to distinguish built, launch-tested, unsigned, and unsupported targets.

**Published prerelease: [0.8.0-alpha.1](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/releases/tag/v0.8.0-alpha.1).** Released November 15, 2026 at 06:07:25 UTC (01:07:25 America/New_York), from source `8b13e027ce5e0fa941a6bbeb1e09c5873b11baee`. All ten public assets were downloaded again and matched to the accepted build. [Release evidence](evidence/release-0.8.0-alpha.1.json).

The platform links below are the published **0.8.0-alpha.1** downloads. Read this version's release notes and `START-HERE.txt`; historical [0.7.1 evidence](evidence/release-0.7.1-alpha.1.json) belongs to the earlier operator mission.

| Platform or document      | Published versioned asset                                                                                                                                                          |
| ------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Mac Apple Silicon / Intel | [macOS universal ZIP](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/releases/download/v0.8.0-alpha.1/KOMAKU-Shield-Protocol-0.8.0-alpha.1-macOS-universal.zip) |
| Windows x64               | [Windows ZIP](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/releases/download/v0.8.0-alpha.1/KOMAKU-Shield-Protocol-0.8.0-alpha.1-Windows-x64.zip)             |
| Linux x64                 | [Linux ZIP](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/releases/download/v0.8.0-alpha.1/KOMAKU-Shield-Protocol-0.8.0-alpha.1-Linux-x64.zip)                 |
| WebGL2 browser            | [Web ZIP](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/releases/download/v0.8.0-alpha.1/KOMAKU-Shield-Protocol-0.8.0-alpha.1-Web.zip)                         |
| Science guide             | [16-page PDF](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/releases/download/v0.8.0-alpha.1/KOMAKU-Shield-Protocol-0.8.0-alpha.1-Science-Guide.pdf)           |

The release has **ten verified assets**: four platform ZIPs, the standalone 16-page science PDF, signed game content, its update manifest/signature, the release manifest and checksums. All ten were downloaded again and hash matched; all four ZIP CRC checks passed. Every ZIP includes versioned `START-HERE.txt`, the exact reviewed science guide and the technical two-page equation PDF in its bundled documentation. Extract the whole archive, then read `START-HERE.txt`.

The separate [words-only equation notes](VIDEO-EQUATIONS-SIMPLE.md), [one-page simple equation PDF](media/KOMAKU-Video-Equations-Simple.pdf) and [proposed result-screen copy](RESULT-SCREEN-COPY.md) are repository follow-ups created after this build. They are not in the published ZIPs.

From version 0.5 onward, ZIP names begin with `KOMAKU-Shield-Protocol-<version>`. Historical 0.4 and earlier downloads retain `Red-Veil` filenames and the previous app name; those published artifacts are not renamed. The signed content filename and local save/update identities remain unchanged for compatibility. Use the notes attached to the version you download.

Historically, version **0.7.1** preserved the indoor mission and visual framing while deferring optional scenery until requested. The first outdoor/Field Notes visit builds that content and keeps it cached afterward; see [startup measurements and tradeoffs](WINDOW-STARTUP-PERFORMANCE.md). Existing compatible desktop apps could install that signed 0.7.1 content through **Update available → Install → Restart**; actual public 0.7.0 Mac/Windows binaries passed this content-activation gate alongside older baselines. [Updater scope](UPDATES.md).

## Play the 0.8 journey

After the opening, the control room is in **preflight**. Choose Ren's starting cleaning pace, inspect any science bubbles you want, then press **START MISSION**. No time, dose, fatigue, work or battery energy advances before Start. The separate science constellation is optional.

Use **SLOWER / 1**, **FASTER / 3** or the stepped slider to choose pace 0.25–1.75. **Enter** starts from preflight; Escape handles Back/Pause and fullscreen exit, while F11 toggles fullscreen. The mission book pauses every quantity while explaining it.

Ren cleans at the nearby panel while fictional fatigue affects effective work. Partial cleaning increases solar generation; generation minus load changes actual battery kWh. After 30 simulated minutes—five active minutes at the standard sixfold clock—Ren enters automatically. There is no recall, walk or manual work hold. All completed default rounds have the same 10.9375 µGy model dose; no health judgement or lower-dose bonus is calculated.

The debrief classifies cleanliness as WIN at 80% or more, PASS at 40% or more, otherwise LOSE, and connects the actual run to its equations. The older operator/EVA/labs remain under **Advanced lab · earlier mission** with separate rules.

The shared source suite, exact native Mac/Windows launch gates, signed-content baseline gates and publication passed. [Release evidence](evidence/release-0.8.0-alpha.1.json) · [Model and units](TRAINING-MODEL.md) · [Navigation](NAVIGATION.md).

For compatible existing desktop installations, open **Updates & downloads**, check for the new version, download it and confirm Restart. The released 0.8 pack passed activation/recovery gates on the public 0.6.0, 0.6.1, 0.7.0 and 0.7.1 Mac/Windows installers and the documented Linux 0.4 baseline. These are local signed-content tests; see [updater evidence and limits](UPDATES.md) for the separate HTTP, notification and relaunch scope.

## MacBook with Apple Silicon, including M5

The published **0.8.0-alpha.1** app retains the Mac bundle-signing repair introduced in **0.6.1-alpha.1** for the invalid 0.6.0 signature. If your existing app says “damaged,” download the corrected macOS universal ZIP; an app that cannot launch cannot install its own content update. Saves stay in the existing user-data location.

1. Download the macOS universal ZIP from the official release and extract it. It includes Apple Silicon (arm64, including M5) and Intel (x86_64).
2. Open `KŌMAKU- Shield Protocol.app`. This alpha is locally **ad-hoc signed**, but has **no Apple Developer ID or notarization**. A valid integrity signature does not grant Apple's downloaded-app approval.
3. If macOS blocks it, use **System Settings → Privacy & Security → Open Anyway**, when offered, after confirming that you trust this project's download.
4. If macOS offers no usable override, the ZIP includes **Install KŌMAKU.command**. It checks the app's signature, asks for explicit consent, copies it into your own `~/Applications`, keeps an existing app as a backup, removes quarantine **only from that verified copy**, and opens it. It needs no administrator password. It does not establish publisher authenticity: use it only for a trusted official download.

If macOS also blocks the `.command` file, open Terminal, type `/bin/bash ` (including the trailing space), drag **Install KŌMAKU.command** from Finder into Terminal, and press Return. Read the consent dialog before continuing. This is a one-time local installation step; no developer tools or account enrollment are needed. Do not run commands that disable Gatekeeper globally. For an extra integrity check, compare `shasum -a 256 <downloaded-zip>` with the release's `SHA256SUMS.txt`.

The [0.8 macOS Actions gate](evidence/native-launch-0.8-macos.json) passed the exact archive's strict bundle signature, both architectures, and headless/graphical startup checks. They do not reproduce every Finder download route or certify M5 performance. [Root cause and verification limits](MACOS-LAUNCH-REPAIR.md).

## Windows and Linux

Windows x64: extract the **whole ZIP** and run `KOMAKU-Shield-Protocol.exe`. No editor or development runtime is needed. Windows may show SmartScreen because this alpha has no publisher certificate/reputation. Only if you trust this repository's download, use the available **More info → Run anyway** option. Managed-device policy can prohibit that override. The [0.8 Windows hosted gate](evidence/native-launch-0.8-windows.json) passed native headless and graphical startup checks; this does not remove SmartScreen.

Linux x64: extract the ZIP and run `KOMAKU-Shield-Protocol.x86_64`. A headless launch of the exported binary is verified in the build environment. Desktop-driver and distribution coverage are not established by that check.

## Browser and mobile

The Web ZIP is a static Godot export. Public website deployment was skipped at the owner's request; hosting remains deferred. Serve its folder over HTTP(S); do not double-click `index.html` with a file URL. For a local test, `python3 -m http.server 5190 --directory <extracted-folder>` is sufficient. The single-thread export avoids requiring cross-origin-isolation headers. WebGL2 is required.

Touch controls are provided for landscape browser play. No production native Android or iOS package is published. An earlier Android arm64 build was internal tooling validation only; production signing and physical-device testing remain separate work.

## Historical 0.7.1 and advanced-mode controls

The earlier 0.7 title has **Start mission**, **Explore · no timer**, and **Learn & more**. Start and Explore use the indoor room, with only dunes and Mira in the default forward window view. Extra labs, learning tools, the guide, updates and **Outdoor EVA mission** are under **Learn & more**.

| Action                       | Keyboard / mouse                                                 |
| ---------------------------- | ---------------------------------------------------------------- |
| Move/look inside the room    | **WASD / mouse**; movement stays within the operator area        |
| Toggle panel cleaning        | **1**, or the cleaner button                                     |
| Toggle power saving          | **2**, or the save button                                        |
| Begin Mira’s return          | **3 / Guide Mira**; Mira follows a continuous side-airlock route |
| Pause for clickable controls | **Tab**; **Escape** returns to walking                           |
| Compare mission plans        | **P**, or Pause → **Compare mission plans**                      |

The third action progresses through **Mira returning**, **Airlock cycling**, **Mira entering** and **Mira safe**. Her suit energy and dose remain separate from the operator’s location; shelter applies only after her airlock cycle and final walk to the indoor receiver. Keep base power working through **12 simulated hours** after starting, rather than stopping the mission as soon as Mira returns. The route and airlock countdown are explicit game assumptions, not a physical pressure simulation.

Pause during an untimed tour offers **Resume room tour**, **Start rescue mission** and **Return to title**. Starting the rescue resets the practice switches, clock and Mira’s waiting state.

**Outdoor EVA mission** retains the earlier outdoor mechanics and equipment. There, **E** interacts, **Q** cleans the player’s visor, and **Space** hops. It remains an optional advanced activity.

The optional planner compares four cleaner/power-saving policies over one simulated hour while paused, holding Mira’s present protection state fixed. It does not simulate her journey or the airlock cycle. **Use this plan** applies only the chosen switches. [Planner assumptions](MISSION-PLANNER.md). The guide for the published version is bundled into each ZIP after its source-fingerprint check. The repository guide may be newer; use the release-linked PDF for the version you downloaded.

## Retained outdoor EVA controls

Movement, pause and guide controls are shared. Equipment interaction, visor cleaning and hopping belong to **Learn & more → Outdoor EVA mission**, the original outdoor mode also found in historical 0.6.1:

| Action                   | Keyboard / mouse   | Controller               |
| ------------------------ | ------------------ | ------------------------ |
| Walk / look              | WASD / mouse       | Left / right sticks      |
| Inspect or use equipment | E; hold to inspect | X; hold to inspect       |
| Clean visor              | Q                  | Y                        |
| Hop                      | Space              | A                        |
| Pause                    | Escape             | Start                    |
| Field guide              | F1                 | Open from the title menu |

The retained advanced **Learn & more** menu also offers **Explorer suit lab** and **Habitat field notes**. In untimed exploration, **I** opens habitat lessons. The suit lab opens from Pause too. Back/Escape returns to the previous activity; these learning interfaces pause mission resources.

No account is required. There are no ads, analytics, or remote game APIs. A mission summary is stored locally. Tell us the release version, device, OS, what you did, and what happened when reporting a problem; do not include personal information in public issues.
