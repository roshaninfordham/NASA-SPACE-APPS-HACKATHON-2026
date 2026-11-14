# Download and play <!-- brand:display_name -->KŌMAKU: Shield Protocol<!-- /brand -->

Downloads are published as **GitHub Release assets**, not GitHub Packages. A repository containing code and export presets does not imply that an installer exists. Use the release notes to distinguish built, launch-tested, unsigned, and unsupported targets.

**Latest published download: [v0.6.1-alpha.1](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/releases/tag/v0.6.1-alpha.1).** Version **0.7.0-alpha.1 is a source candidate**, not a published installer yet. Candidate screenshots and controls can differ from the current download.

The 0.7 packaging produces **ten assets**: four platform ZIPs, one standalone `KOMAKU-Shield-Protocol-0.7.0-alpha.1-Science-Guide.pdf`, signed game content, its update manifest/signature, the release manifest and checksums. Every 0.7 ZIP also includes `START-HERE.txt` with launch/first-mission instructions and the same 16-page guide as `KOMAKU-Science-Guide.pdf`. [Read the source guide now](media/KOMAKU-Science-Guide.pdf); use release notes to identify the eventually accepted artifacts.

From version 0.5 onward, ZIP names begin with `KOMAKU-Shield-Protocol-<version>`. Historical 0.4 and earlier downloads retain `Red-Veil` filenames and the previous app name; those published artifacts are not renamed. The signed content filename and local save/update identities remain unchanged for compatibility. Use the notes attached to the version you download.

## MacBook with Apple Silicon, including M5

Version **0.6.1-alpha.1** corrects the invalid Mac bundle signature in 0.6.0. If your existing app says “damaged,” download the corrected macOS universal ZIP; an app that cannot launch cannot install its own content update. Saves stay in the existing user-data location.

1. Download the macOS universal ZIP from the official release and extract it. It includes Apple Silicon (arm64, including M5) and Intel (x86_64).
2. Open `KŌMAKU- Shield Protocol.app`. This alpha is locally **ad-hoc signed**, but has **no Apple Developer ID or notarization**. A valid integrity signature does not grant Apple's downloaded-app approval.
3. If macOS blocks it, use **System Settings → Privacy & Security → Open Anyway**, when offered, after confirming that you trust this project's download.
4. If macOS offers no usable override, the ZIP includes **Install KŌMAKU.command**. It checks the app's signature, asks for explicit consent, copies it into your own `~/Applications`, keeps an existing app as a backup, removes quarantine **only from that verified copy**, and opens it. It needs no administrator password. It does not establish publisher authenticity: use it only for a trusted official download.

If macOS also blocks the `.command` file, open Terminal, type `/bin/bash ` (including the trailing space), drag **Install KŌMAKU.command** from Finder into Terminal, and press Return. Read the consent dialog before continuing. This is a one-time local installation step; no developer tools or account enrollment are needed. Do not run commands that disable Gatekeeper globally. For an extra integrity check, compare `shasum -a 256 <downloaded-zip>` with the release's `SHA256SUMS.txt`.

Native Actions gates check the exact archive's strict bundle signature, both architectures, and headless/graphical startup. They do not reproduce every Finder download route or certify M5 performance. [Root cause and verification limits](MACOS-LAUNCH-REPAIR.md).

## Windows and Linux

Windows x64: extract the **whole ZIP** and run `KOMAKU-Shield-Protocol.exe`. No editor or development runtime is needed. Windows may show SmartScreen because this alpha has no publisher certificate/reputation. Only if you trust this repository's download, use the available **More info → Run anyway** option. Managed-device policy can prohibit that override. Release builds now require native Windows headless and graphical startup checks; this does not remove SmartScreen.

Linux x64: extract the ZIP and run `KOMAKU-Shield-Protocol.x86_64`. A headless launch of the exported binary is verified in the build environment. Desktop-driver and distribution coverage are not established by that check.

## Browser and mobile

The Web ZIP is a static Godot export. Serve its folder over HTTP(S); do not double-click `index.html` with a file URL. For a local test, `python3 -m http.server 5190 --directory <extracted-folder>` is sufficient. The single-thread export avoids requiring cross-origin-isolation headers. WebGL2 is required.

Touch controls are provided for landscape browser play. No production native Android or iOS package is published. An earlier Android arm64 build was internal tooling validation only; production signing and physical-device testing remain separate work.

## Controls

The published 0.6.1 build uses these core controls:

| Action                   | Keyboard / mouse   | Controller               |
| ------------------------ | ------------------ | ------------------------ |
| Walk / look              | WASD / mouse       | Left / right sticks      |
| Inspect or use equipment | E; hold to inspect | X; hold to inspect       |
| Clean visor              | Q                  | Y                        |
| Hop                      | Space              | A                        |
| Pause                    | Escape             | Start                    |
| Field guide              | F1                 | Open from the title menu |

Its title menu also offers **Explorer Suit Lab** and **Habitat Field Notes**. In untimed exploration, **I** opens habitat lessons. The suit lab opens from Pause too. Back/Escape returns to the previous activity; these learning interfaces pause mission resources.

## Indoor-operator controls in the 0.7 source candidate

**This flow is implemented and source-tested; it is not in the published 0.6.1 download.** Final archive and native release-gate acceptance remain pending before publication. The candidate title has **Start mission**, **Explore · no timer**, and **Learn & more**. Start and Explore use the indoor room, with only dunes and Mira in the default forward window view. Extra labs, learning tools, the guide, updates and **Outdoor EVA mission** are under **Learn & more**.

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

The optional planner compares four cleaner/power-saving policies over one simulated hour while paused, holding Mira’s present protection state fixed. It does not simulate her journey or the airlock cycle. **Use this plan** applies only the chosen switches. [Planner assumptions](MISSION-PLANNER.md). The candidate’s [16-page science PDF](media/KOMAKU-Science-Guide.pdf) is bundled into each ZIP after its source-fingerprint check.

No account is required. There are no ads, analytics, or remote game APIs. A mission summary is stored locally. Tell us the release version, device, OS, what you did, and what happened when reporting a problem; do not include personal information in public issues.
