# Download and play <!-- brand:display_name -->KŌMAKU: Shield Protocol<!-- /brand -->

Downloads are published as **GitHub Release assets**, not GitHub Packages. A repository containing code and export presets does not imply that an installer exists. Use the release notes to distinguish built, launch-tested, unsigned, and unsupported targets.

From version 0.5 onward, ZIP names begin with `KOMAKU-Shield-Protocol-<version>`. Historical 0.4 and earlier downloads retain `Red-Veil` filenames and the previous app name; those published artifacts are not renamed. The signed content filename and local save/update identities remain unchanged for compatibility. Use the notes attached to the version you download.

## MacBook with Apple Silicon, including M5

Download the macOS universal ZIP from the release, extract it, and open `KŌMAKU- Shield Protocol.app`. The universal binary contains both arm64 and x86_64 slices. No Node, Rust, Godot editor, or terminal is needed to play the app.

Early alpha builds are unsigned and not notarized. macOS may block opening them. Verify that the download comes from this repository and compare the published SHA-256 checksum. If you choose to trust this alpha, use Apple's documented **Privacy & Security → Open Anyway** workflow. Do not disable Gatekeeper globally. Signing and notarization require the project's Apple developer identity and are not completed by this build.

The alpha has been cross-exported on Linux, not launched on a physical Mac. M5 performance and input behavior need your testing before any quality claim.

## Windows and Linux

Windows x64: extract the ZIP and run `KOMAKU-Shield-Protocol.exe`. The early build is unsigned and may trigger a reputation warning. Windows runtime testing is still required.

Linux x64: extract the ZIP and run `KOMAKU-Shield-Protocol.x86_64`. A headless launch of the exported binary is verified in the build environment. Desktop-driver and distribution coverage are not established by that check.

## Browser and mobile

The Web ZIP is a static Godot export. Serve its folder over HTTP(S); do not double-click `index.html` with a file URL. For a local test, `python3 -m http.server 5190 --directory <extracted-folder>` is sufficient. The single-thread export avoids requiring cross-origin-isolation headers. WebGL2 is required.

Touch controls are provided for landscape browser play. Native Android and iOS packages have not been built. Their SDK, signing, store, accessibility, and device testing remain separate work.

## Controls

| Action                   | Keyboard / mouse   | Controller                 |
| ------------------------ | ------------------ | -------------------------- |
| Walk / look              | WASD / mouse       | Left / right sticks        |
| Inspect or use equipment | E; hold to inspect | X; hold to inspect         |
| Clean visor              | Q                  | Y                          |
| Hop                      | Space              | A                          |
| Pause                    | Escape             | Start                      |
| Field guide              | F1                 | Open from the title screen |

No account is required. There are no ads, analytics, or remote game APIs. A mission summary is stored locally. Tell us the release version, device, OS, what you did, and what happened when reporting a problem; do not include personal information in public issues.
