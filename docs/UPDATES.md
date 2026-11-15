# Updating <!-- brand:display_name -->KŌMAKU: Dust & Radiation<!-- /brand -->

**Published [0.10.0-alpha.1](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/releases/tag/v0.10.0-alpha.1) — November 15, 2026, 13:53:05 UTC.** Built from `26f19540baf330b00b0ac4a1b470d0e1439f7382`. This release simplifies the interface and corrects the installation handoff while preserving the 90-second mission and its equations. [Release notes](releases/0.10.0-alpha.1.md).

The accepted signed pack passed activation, healthy repeat startup and same-size corruption recovery using unchanged public **0.6.0, 0.6.1, 0.7.0, 0.7.1, 0.8.0 and 0.9.0** installers on both Mac and Windows—**twelve passed jobs**—plus the documented Linux 0.4 baseline. [Native matrix run](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/actions/runs/43721023112).

| Baseline | Mac                                                | Windows                                              |
| -------- | -------------------------------------------------- | ---------------------------------------------------- |
| 0.6.0    | [Passed](evidence/update-0.6.0-to-0.10-macos.json) | [Passed](evidence/update-0.6.0-to-0.10-windows.json) |
| 0.6.1    | [Passed](evidence/update-0.6.1-to-0.10-macos.json) | [Passed](evidence/update-0.6.1-to-0.10-windows.json) |
| 0.7.0    | [Passed](evidence/update-0.7.0-to-0.10-macos.json) | [Passed](evidence/update-0.7.0-to-0.10-windows.json) |
| 0.7.1    | [Passed](evidence/update-0.7.1-to-0.10-macos.json) | [Passed](evidence/update-0.7.1-to-0.10-windows.json) |
| 0.8.0    | [Passed](evidence/update-0.8.0-to-0.10-macos.json) | [Passed](evidence/update-0.8.0-to-0.10-windows.json) |
| 0.9.0    | [Passed](evidence/update-0.9.0-to-0.10-macos.json) | [Passed](evidence/update-0.9.0-to-0.10-windows.json) |

[Linux 0.4 → 0.10](evidence/update-0.4-to-0.10-linux.json) also passed. [Mac](evidence/native-launch-0.10-macos.json) and [Windows](evidence/native-launch-0.10-windows.json) package startup passed in [build run 43720633663](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/actions/runs/43720633663). These hosted update checks use local signed artifacts, so they do not independently prove HTTP delivery, notification clicks or automatic graphical relaunch. [Public-file verification](evidence/release-0.10.0-alpha.1.json) matched all ten assets to the accepted build, passed all four ZIP checks and confirmed the current instructions and three exact PDFs. The unauthenticated public manifest returned HTTP 200.

Accepted manifest SHA-256: `dbf95ccd9fd266070f04e8dafa8b73b62b931244d6525fbfdc5d71d682b01657`. Existing app filenames and save locations remain stable. A broken older Mac bundle that cannot open still needs one corrected full installation.

## Additional live HTTP and restart check

A separate [Linux live-update test](evidence/live-update-0.10-linux.json) passed real production `HTTPRequest` discovery and download from GitHub: metadata, signed manifest, signature and the 17,485,976-byte content pack all returned HTTP 200. It exercised the actual journey update-offer dialog, signature verification, staging, healthy activation, repeat startup, tamper recovery and an `OS.create_instance` graphical restart into 0.10.0 under Xvfb. The restarted process stayed alive with a healthy activation journal for the three-second observation.

This test used a disposable exact-source **0.10.0-alpha.0 fixture**, with fixture-only proxy/verified-CA configuration; it was **not an upgrade from a published installer**. The separate twelve-job native matrix supplies the historical-installer evidence. This Linux cloud result does not establish physical Mac/Windows behavior, GPU performance or device audio. The harness was updated after publication for the current journey main scene; signed production content was unchanged.

## Historical 0.9 baseline

The [0.9 public-file record](evidence/release-0.9.0-alpha.1.json) identifies its unchanged artifacts. The 0.10 interface and package-guide correction ship as a new signed version; old assets are not replaced in place.

## Historical 0.8 update evidence

**Published [0.8.0-alpha.1](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/releases/tag/v0.8.0-alpha.1) — November 15, 2026.** Built from `8b13e027ce5e0fa941a6bbeb1e09c5873b11baee`. All ten public files were redownloaded and matched to the accepted build; all four ZIPs passed integrity checks and contain the reviewed science and technical equation PDFs. [Release evidence](evidence/release-0.8.0-alpha.1.json).

## Update behavior and earlier acceptance scope

**0.8.0-alpha.1 is published and available to compatible desktop installations.** The exact signed pack passed activation, healthy repeat startup and same-size corruption recovery using unchanged public **0.6.0, 0.6.1, 0.7.0 and 0.7.1 Mac/Windows executables**, plus **0.4 Linux**. [Release record](evidence/release-0.8.0-alpha.1.json) · [Eight native update jobs](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/actions/runs/43683700390).

These headless tests use local signed artifact bytes; they do not independently establish HTTP transfer, notification clicks or automatic graphical relaunch. The separately hosted Mac/Windows package launch gates passed, and every public file was redownloaded and hash-matched. A historical 0.6.0 Mac executable can load content in a harness while its invalid Finder bundle still needs one corrected full installation. Physical devices and first-download OS trust remain separate checks.

The desktop flow is **Update available → Install → Restart**. Checks use this public GitHub repository without a GitHub login. The game checks a signed manifest and exact pack size/hash before staging new game content. It keeps the previous working content for recovery if startup fails. It never asks a player for administrator credentials or a GitHub token. A missing signing configuration allows a manual-preview release notice, not unsigned automatic installation.

Updates can replace game scripts, scenes, models, textures, and audio for the same Godot 4.6.3 runtime. Replacing the native engine, changing the installer's pinned trust root, adding native libraries, or changing startup registries is outside the supported content-update contract and requires a new full installer. Signed scripts are executable trusted code, not a sandbox against a compromised release author. The desktop content pack is exported with desktop texture formats; it is not a native mobile update package. Browser and future mobile distribution need their own supported update flow. No Android/iOS installer is currently published.

Godot initializes global script-class and resource UID registries before content mounting. New script types must use explicit preload paths and stable resource paths; a PCK cannot be assumed to refresh those registries. The signed manifest requires `runtime_contract: "red-veil-desktop-v1"`, matched by the verifier embedded in the baseline installer. Missing or different contracts require a full-installer transition. Bump this contract when a pack changes required bootstrap interfaces, native dependencies, global-class/UID registration assumptions, or other baseline startup contracts; an engine change also requires a full installer. The string is a compatibility promise from the release author, not automatic proof. Each signed pack needs boot testing against every supported baseline installer. Registry or startup-contract changes may need a full installer even when the engine version stays the same.

A successful startup acknowledgement only means that the startup checkpoint completed. It cannot certify every mission, device, or later gameplay path. Initial app signing/notarization, backups, real-device tests, and release review remain separate from content signatures.

## Accepted 0.8 journey — historical artifact evidence

The final pace/fatigue journey retains the Godot 4.6.3 runtime and existing pinned public key. Published pack SHA-256 is `652c48d054742f2ad81c3d7b2639b5ec21ac18c6e8d4e4d7d942532cead14dab`; source is `8b13e027ce5e0fa941a6bbeb1e09c5873b11baee`. The build, native launch, supported baseline transitions, repeat startup, tamper recovery and public-file checks all passed on these exact bytes.

| Baseline | Mac                                               | Windows                                             |
| -------- | ------------------------------------------------- | --------------------------------------------------- |
| 0.6.0    | [Passed](evidence/update-0.6.0-to-0.8-macos.json) | [Passed](evidence/update-0.6.0-to-0.8-windows.json) |
| 0.6.1    | [Passed](evidence/update-0.6.1-to-0.8-macos.json) | [Passed](evidence/update-0.6.1-to-0.8-windows.json) |
| 0.7.0    | [Passed](evidence/update-0.7.0-to-0.8-macos.json) | [Passed](evidence/update-0.7.0-to-0.8-windows.json) |
| 0.7.1    | [Passed](evidence/update-0.7.1-to-0.8-macos.json) | [Passed](evidence/update-0.7.1-to-0.8-windows.json) |

[Linux 0.4 → 0.8](evidence/update-0.4-to-0.8-linux.json) also passed. Historical releases keep their own evidence. Every future signed pack still requires exact-artifact acceptance; unchanged engine/key identities alone are insufficient.

## Existing signing setup (already completed)

The repository already has its signing setup. **Do not repeat setup or rotate the key for a routine content update or product rename.** The commands below document recovery/provisioning for an owner who needs it; they are not a new action request. Use a trusted owner laptop for that work. No private signing key has been generated or provisioned by the development agents.

Prerequisites: Python 3.11+, OpenSSL, the GitHub `gh` CLI, and a local checkout of this repository. Sign in with the repository owner account:

```sh
gh auth login --hostname github.com --web
```

From the checkout, update it, then run the setup helper:

```sh
git pull --ff-only
python3 scripts/configure_update_signing.py --install-github-secret --publish-public-key
```

The helper does the following:

1. Generates or reuses a 3072-bit RSA private key under `~/.config/red-veil/signing/`, outside Git, with restrictive file permissions.
2. Checks the local and remote public trust root. A different existing root stops setup before its signing secret is replaced. Key rotation requires a planned new installer.
3. When absent on main, commits only the public key at `game/updater/public_key.pem` using GitHub's contents API. Publish mode leaves that path untouched in the local checkout so the next `git pull` can receive it without an untracked-file collision. A public copy also remains beside the private key outside Git. No local Git author setup or manual public-key commit is needed. An identical existing root does not create another commit. The first successful public-key creation is the initial setup boundary.
4. Re-reads and verifies the remote public root, then uploads the private key directly to GitHub's encrypted Actions secret **`RED_VEIL_UPDATE_SIGNING_KEY`**. It never prints the key or writes it into the checkout. If setup stops between the public commit and secret upload, signed builds fail closed until setup completes.

Keep an encrypted backup of the private key. Never paste the private key into chat, a public issue, or documentation. If the helper fails partway through, retain the existing key and rerun after addressing the stated error; do not generate a new trust root casually. Pull the public-key commit before the next release build.

If the local branch has uncommitted work or cannot fast-forward, resolve that in the usual development workflow before setup. A successful helper run provisions signing; it does **not** publish a release or make existing installers update themselves.

Without CLI secret permissions, omit `--install-github-secret`, add the private file through **Settings → Secrets and variables → Actions**, and review/commit only the public file. The full automated command is preferred on an owner-authorized laptop.

## Building a signed desktop update

Use a clean committed checkout whose `game/project.godot` version matches the release. The pinned public key must be committed in that exact source revision. Keep Godot at 4.6.3 unless creating a new full-installer transition.

The **Build downloadable game** Actions workflow has independent `signed_updates` and `publish` inputs. `signed_updates=true` requires the encrypted signing secret. If it is missing, malformed, or mismatched with the committed public key, the build fails; it never silently produces an unsigned installable update. Temporary private material lives outside the checkout with mode 0600 and is removed when the build exits. The secret is removed from child-process environments. The signing key still exists in a private temporary file during that trusted build; only reviewed source revisions and workflow code may receive signing access. This does not isolate the key from malicious repository code.

For local builds, use an existing key outside the checkout:

```sh
python3 scripts/build_game.py --version 0.10.0-alpha.1 --signed-updates --private-key "$HOME/.config/red-veil/signing/update-private.pem"
```

This example targets the 0.10.0-alpha.1 patch and requires its project version and frozen source to match. Published 0.9.0-alpha.1 and all earlier releases must not be overwritten. A local build is not publication or proof of baseline compatibility.

Signed builds produce four platform ZIPs, a standalone versioned science PDF and these five fixed assets (ten total):

- `red-veil-content.pck`
- `update-manifest.json`
- `update-manifest.sig`
- `release-manifest.json`
- `SHA256SUMS.txt`

The content manifest binds the exact repository, version, source commit, Godot version, runtime contract, pack filename, length, and SHA-256 hash. Its detached RSA/SHA-256 signature is verified against the same public key included in the installers. `SHA256SUMS.txt` covers all four ZIPs, the standalone PDF and the three update assets. The separate release-verification record also hashes the release manifest and checksum file. Only the exact declared files enter `releases/distribution/` and the Actions artifact; stale packs from older local builds are excluded.

## Publication and source binding

The build workflow must pass native Mac signature/universal-binary/startup checks and Windows startup checks on the exact archives before publication. The exported Linux startup is checked during export. A failed native gate blocks both direct publication and acceptance of that build run.

Create a draft targeting the exact built source commit. The workflow's `publish=true` path verifies the draft version, source target, and any existing tag. It verifies local hashes and, for signed releases, the signature and full content manifest before uploading. After upload it checks the complete asset set, sizes, and GitHub-provided digests when available, then publishes a prerelease. It refuses to replace an already published release. Unexpected draft assets require review; they are not silently deleted.

Published alphas are immutable. Fixes get a new version and changelog entry. Do not label an alpha stable just to alter GitHub's sidebar. The [changelog](../CHANGELOG.md) and release manifest identify what actually shipped.

## Validation and limits

`python3 -m unittest discover -s tests -p test_release_tools.py -v` exercises key matching/strength, signature tampering, version limits, private-file cleanup on failure, remote trust-root conflicts, stale/private asset exclusion, source/tag mismatches, and immutable published releases. The exported Linux smoke check uses an isolated data directory so it cannot modify a developer's real update journal or learning profile.

No production key is used in these tests. Passing them does not establish complete client/bootstrap correctness or Apple/Windows/mobile compatibility. The runtime update tests and real-device checks must pass separately before claiming seamless updating.

---

made with love by Team Roshan Xingbo at the NASA Space App Hackathon 2026, NYC
