# Updating <!-- brand:display_name -->KŌMAKU: Shield Protocol<!-- /brand -->

## What players can expect

The **0.6.1-alpha.1 packaging repair** keeps the signed-content updater introduced in 0.4. Broken 0.6.0 Mac installations need one corrected full download: a content pack cannot repair the enclosing app signature, and a blocked app cannot run its updater. The older v0.3 installer also needs one manual upgrade. Existing saves and the pinned update key remain compatible.

From 0.6.1, discovery runs on every fresh game launch, once per process. The title screen also has **Check for updates**. An offline launch does not suppress checks for the following day. Updates appear at safe menu/debrief points, not over an active mission. There are no background notifications while the game is closed and no forced restart. Network availability and GitHub rate limits can delay discovery.

The actual published 0.4 Linux installer passed the [0.6 compatibility and recovery gate](evidence/update-0.4-to-0.6.json). [Earlier Linux live-download/restart/recovery evidence](evidence/update-0.4.0-alpha.1.json) used a disposable older-version fixture. Native startup gates and content activation tests have distinct evidence scopes; neither implies every physical device has been tested.

The desktop flow is **Update available → Install → Restart**. Checks use this public GitHub repository without a GitHub login. The game checks a signed manifest and exact pack size/hash before staging new game content. It keeps the previous working content for recovery if startup fails. It never asks a player for administrator credentials or a GitHub token. A missing signing configuration allows a manual-preview release notice, not unsigned automatic installation.

Updates can replace game scripts, scenes, models, textures, and audio for the same Godot 4.6.3 runtime. Replacing the native engine, changing the installer's pinned trust root, adding native libraries, or changing startup registries is outside the supported content-update contract and requires a new full installer. Signed scripts are executable trusted code, not a sandbox against a compromised release author. The desktop content pack is exported with desktop texture formats; it is not a native mobile update package. Browser and future mobile distribution need their own supported update flow. No Android/iOS installer is currently published.

Godot initializes global script-class and resource UID registries before content mounting. New script types must use explicit preload paths and stable resource paths; a PCK cannot be assumed to refresh those registries. The signed manifest requires `runtime_contract: "red-veil-desktop-v1"`, matched by the verifier embedded in the baseline installer. Missing or different contracts require a full-installer transition. Bump this contract when a pack changes required bootstrap interfaces, native dependencies, global-class/UID registration assumptions, or other baseline startup contracts; an engine change also requires a full installer. The string is a compatibility promise from the release author, not automatic proof. Each signed pack needs boot testing against every supported baseline installer. Registry or startup-contract changes may need a full installer even when the engine version stays the same.

A successful startup acknowledgement only means that the startup checkpoint completed. It cannot certify every mission, device, or later gameplay path. Initial app signing/notarization, backups, real-device tests, and release review remain separate from content signatures.

## One-time owner setup (completed for this repository)

Run this on **your own trusted laptop**, outside the managed cloud terminal. That terminal's repository-administration and secrets requests were denied even after a personal login. No private signing key has been generated or provisioned by the development agents.

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
python3 scripts/build_game.py --version 0.4.0-alpha.1 --signed-updates --private-key "$HOME/.config/red-veil/signing/update-private.pem"
```

Version 0.4.0-alpha.1 is already published. Update the project version deliberately before building a later release; published assets are immutable.

Signed builds produce the four platform ZIPs plus these fixed assets:

- `red-veil-content.pck`
- `update-manifest.json`
- `update-manifest.sig`
- `release-manifest.json`
- `SHA256SUMS.txt`

The content manifest binds the exact repository, version, source commit, Godot version, runtime contract, pack filename, length, and SHA-256 hash. Its detached RSA/SHA-256 signature is verified against the same public key included in the installers. Checksums cover all four ZIPs and all three update assets. Only the exact declared files enter `releases/distribution/` and the Actions artifact; stale packs from older local builds are excluded.

## Publication and source binding

The build workflow must pass native Mac signature/universal-binary/startup checks and Windows startup checks on the exact archives before publication. The exported Linux startup is checked during export. A failed native gate blocks both direct publication and acceptance of that build run.

Create a draft targeting the exact built source commit. The workflow's `publish=true` path verifies the draft version, source target, and any existing tag. It verifies local hashes and, for signed releases, the signature and full content manifest before uploading. After upload it checks the complete asset set, sizes, and GitHub-provided digests when available, then publishes a prerelease. It refuses to replace an already published release. Unexpected draft assets require review; they are not silently deleted.

Published alphas are immutable. Fixes get a new version and changelog entry. Do not label an alpha stable just to alter GitHub's sidebar. The [changelog](../CHANGELOG.md) and release manifest identify what actually shipped.

## Validation and limits

`python3 -m unittest discover -s tests -p test_release_tools.py -v` exercises key matching/strength, signature tampering, version limits, private-file cleanup on failure, remote trust-root conflicts, stale/private asset exclusion, source/tag mismatches, and immutable published releases. The exported Linux smoke check uses an isolated data directory so it cannot modify a developer's real update journal or learning profile.

No production key is used in these tests. Passing them does not establish complete client/bootstrap correctness or Apple/Windows/mobile compatibility. The runtime update tests and real-device checks must pass separately before claiming seamless updating.

---

made with love by Team Roshan Xingbo at the NASA Space App Hackathon 2026, NYC
