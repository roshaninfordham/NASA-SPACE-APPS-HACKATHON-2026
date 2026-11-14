# Signed content updater — work in progress

Alpha.1 and alpha.2 have no updater. This directory introduces the verification boundary for a future updater-enabled installer. Do not claim automatic updating is shipped until its bootstrap, transport, activation, rollback, UI, and signed release workflow are validated together.

A candidate manifest is verified with the public key pinned in the installer before its fields are trusted. Packs must match an exact size and SHA-256 hash, come from this repository's fixed release path, use the supported engine/schema, and have a newer supported version. Unknown keys, altered bytes, oversized files, downgrades, arbitrary filenames, and incompatible engines are rejected.

Godot's official resource-pack mechanism can replace scenes, scripts, shaders, models, textures, and audio without replacing the engine. Packs must be mounted before the main scene preloads content. Desktop engine or trust-root upgrades still require a full installer. Mobile store distribution has its own update constraints.

## Owner setup

The connected integration cannot read or write repository Actions secrets. Run this on a trusted owner machine from a checkout:

```sh
python3 scripts/configure_update_signing.py --install-github-secret
```

This requires OpenSSL and an authenticated owner `gh` CLI with permission to manage repository secrets. It generates a 3072-bit RSA key outside Git, sets restrictive local permissions, uploads the private key directly to GitHub's encrypted Actions secret, and writes only the public key into `game/updater/public_key.pem`. Review and commit that public file. Keep an encrypted backup of the private key.

Without `gh`, omit `--install-github-secret` and use GitHub's secure repository-secret UI for `RED_VEIL_UPDATE_SIGNING_KEY`. Never paste private key material into chat, documentation, or an issue. Do not run setup repeatedly with new keys; the script refuses to replace an existing trust root silently.

The initial installer remains a trust boundary. Signed content updates do not replace Apple/Windows application signing or make an untrusted installer safe.
