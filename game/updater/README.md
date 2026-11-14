# Signed content updater

Published installers through 0.3.0-alpha.1 have no updater. They need one initial manual installation of an updater-enabled build. The implementation on main must pass complete discovery, verified download, activation, restart, and recovery checks before it is described as shipped.

The installer pins a public key. A candidate manifest must authenticate its repository, supported version/schema/engine/runtime contract, fixed pack filename, exact length and SHA-256 digest. The bootstrap captures the trust root before mounting content and verifies a pack again before use. Missing signing configuration must never enable unsigned installation.

Godot resource packs can replace scenes, scripts, shaders, models, textures and audio. They must be mounted before the main scene preloads content. The supported content contract excludes engine/native-library and startup-registry changes; those need a new installer. New script types use explicit preload paths, because Godot initializes global-class/UID registries before mounting. The required `red-veil-desktop-v1` runtime-contract field identifies the compatible baseline contract; registry/native/startup changes require a deliberate contract bump and full-installer transition. Each pack must still be tested against supported baseline installers. Signed scripts remain trusted executable code, not a security sandbox. Native app signing, notarization and mobile/store distribution are separate boundaries.

Owner setup, workflow inputs, exact release assets, publication checks, and limitations are in [the update guide](../../docs/UPDATES.md). The one-time owner command, from an up-to-date checkout on their own trusted laptop, is:

```sh
python3 scripts/configure_update_signing.py --install-github-secret --publish-public-key
```

This generates or reuses a private RSA key outside Git, refuses a conflicting local/remote trust root, commits only the public key through GitHub's API, re-verifies it, and then uploads the secret directly to GitHub. No private key should be pasted into chat. No production key has been provisioned by the development agents.
