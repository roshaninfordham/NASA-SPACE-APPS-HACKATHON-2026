# Mac launch repair: 0.6.1-alpha.1

A player reported “damaged and can’t be opened” on an Apple M5 with macOS Tahoe 26.6.2. This was a release blocker, not evidence that the player installed development tools incorrectly.

## Five whys

1. **Why could the player not open the app?** macOS rejected the downloaded bundle. The exact user-machine failure has not been remotely reproduced, but the public ZIP independently fails Apple's strict bundle-signature verification.
2. **Why is the signature invalid?** `codesign --verify --deep --strict` reports “code has no resources but signature indicates they must be present.” The executable retains the Godot template's signing identifier, while the exported app has no matching sealed-resource signature.
3. **Why did export leave that state?** The macOS export preset explicitly disabled signing (`codesign/codesign=0`). The fix enables Godot 4.6.3's built-in ad-hoc signing (`1`). Native checks also caught a second defect in the first candidate: Unicode bundle/executable/resource names must use the decomposed form expected by Apple's verifier. The shared brand generator now derives `config/name.macos` in that form; the displayed name is unchanged. This is local integrity signing, not Developer ID authentication.
4. **Why did release validation miss it?** Builds cross-exported on Linux. ZIP checksums/CRCs and Linux startup proved transfer integrity and Linux execution, not Mac bundle validity. The actual public 0.6 executable even starts headlessly on native macOS when invoked directly, illustrating why direct execution alone is insufficient.
5. **Why was that enough to publish?** The pipeline had no native Mac/Windows gate. Native archive verification and startup are now required before either publication route. Failed jobs prevent a successful accepted build.

## Evidence

[Diagnostic run 43647118906](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/actions/runs/43647118906) downloaded the immutable public 0.6 ZIP, matched SHA-256 `4c0caf99c2d39d8c178aa8733508aab56d389bc057ea59fb402e4195f4df77b7`, and tested it on an arm64 Mac runner (virtual M2 Pro, macOS 26.7.2). Strict signature verification failed; direct headless startup reached the game. A manual re-sign experiment crashed and is not prescribed as a repair. [Sanitized result](evidence/macos-0.6-launch-diagnosis.json).

[Candidate diagnosis 43648155992](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/actions/runs/43648155992) showed that both executable-page and resource hashes matched, but the composed-Unicode bundle still failed resource verification. Native re-signing treated its decomposed executable path as an unsigned subcomponent; an otherwise equivalent copy with ASCII internal filenames signed and verified correctly. This isolated filename handling from damaged download bytes.

The replacement uses decomposed Mac filenames and must pass its own strict native verification. Reports record the exact archive and manifest hashes, OS/architecture, headless and graphical startup. They do not certify Finder acceptance, physical M5 frame rates or complete playthroughs.

## What the fix can and cannot do

A valid ad-hoc signature fixes bundle integrity; it does not satisfy Apple's downloaded-app publisher/notarization policy. The corrected ZIP includes an explicit-consent installer for trusted downloads. It verifies the bundle, preserves an existing app, installs a complete copy, and removes quarantine only from that verified copy. It never disables system-wide Gatekeeper. Its consent dialog distinguishes integrity from publisher identity. [Player instructions](DOWNLOADS.md).

Truly frictionless first-time Mac downloads normally require Developer ID signing and notarization, even when distributed outside the App Store. The project has not provisioned those credentials. Windows reputation warnings also remain possible. No claim is made that a framework or content signature bypasses OS distribution rules.

The app's signed content updater covers compatible game content after installation. It does not replace the native executable or repair a quarantined/invalid bundle that cannot start. Install the corrected app once, then use in-game notices and explicit restart for compatible releases. The update store and local saves remain outside the app bundle.
