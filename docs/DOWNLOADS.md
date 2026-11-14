# Download and play <!-- brand:display_name -->KŌMAKU: Shield Protocol<!-- /brand -->

Downloads are published as **GitHub Release assets**, not GitHub Packages. A repository containing code and export presets does not imply that an installer exists. Use the release notes to distinguish built, launch-tested, unsigned, and unsupported targets.

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

| Action                   | Keyboard / mouse   | Controller                 |
| ------------------------ | ------------------ | -------------------------- |
| Walk / look              | WASD / mouse       | Left / right sticks        |
| Inspect or use equipment | E; hold to inspect | X; hold to inspect         |
| Clean visor              | Q                  | Y                          |
| Hop                      | Space              | A                          |
| Pause                    | Escape             | Start                      |
| Field guide              | F1                 | Open from the title screen |

From alpha 0.6, choose **Explorer Suit Lab** or **Habitat Field Notes** on the title menu. In untimed exploration, **I** opens the habitat lessons. The suit lab also opens from Pause. Back/Escape returns you to the previous activity. These learning interfaces pause mission time and resources.

No account is required. There are no ads, analytics, or remote game APIs. A mission summary is stored locally. Tell us the release version, device, OS, what you did, and what happened when reporting a problem; do not include personal information in public issues.
