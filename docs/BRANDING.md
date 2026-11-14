# <!-- brand:display_name -->KŌMAKU: Shield Protocol<!-- /brand --> branding

The product name is **<!-- brand:display_name -->KŌMAKU: Shield Protocol<!-- /brand -->**. Mira is a crewmate’s name, not a separate product name.

`game/data/brand.json` is the canonical source for the display name, title, subtitle and portable package names. Keep the macron in **KŌMAKU** in visible text. Use the canonical ASCII package stem where a portable filename is needed; do not invent another spelling in export or release scripts.

Game code reads `res://scripts/branding.gd` through an explicit preload and calls its static `display_name()`, `title()` or `subtitle()` accessors. This keeps newly introduced code independent of Godot’s global class registry. Shared components should read this source instead of copying brand strings into individual scenes. Product metadata on Mira’s scene follows the same source; her personal name remains Mira.

After editing the canonical JSON, run these commands from the repository root and review the changes:

```sh
python scripts/sync_brand.py
python scripts/sync_brand.py --check
```

Synchronization updates the Godot product name and export metadata, export package paths, npm package name, browser entry title and description, web manifest names and generated icons. It preserves legacy save paths, package script entries, version numbers, application identifiers and updater assets. Runtime UI obtains the current text from the helper; build tools read the canonical package stem.

For macOS, the generator also writes `config/name.macos` using Unicode NFD (decomposed form). The visible **KŌMAKU: Shield Protocol** brand remains identical; only the filename normalization used by the exported bundle changes. This is required for the ad-hoc bundle signature to verify on native macOS. Do not hand-normalize or rename files inside a signed app after export. The platform-specific field is generated from the same canonical display name, not a second independently maintained brand. See the [Mac launch repair](MACOS-LAUNCH-REPAIR.md).

Current documentation uses explicit HTML comment synchronization markers named `brand:display_name` and `/brand`. These are rewritten by the synchronization script without touching unmarked historical evidence. Current documentation must also be reviewed alongside code. The synchronization script does not rewrite historical documentation or guarantee that every illustration, screenshot or third-party listing has changed. Review visible screens and release filenames before shipping.

## Stable identities and historical evidence

Internal names such as `red_veil` resource paths, saved application data, updater storage, pinned repository identity, signing trust root and runtime compatibility contract can intentionally retain the legacy Red Veil identifier. These are compatibility boundaries. Renaming a directory or identifier without migration can lose access to progress or installed updates; changing a signing key or runtime contract can require a new baseline installer.

A product rename alone must not rotate keys, reset progress, change the GitHub repository identity or silently migrate application data. Keep native application and bundle identifiers stable unless a separately reviewed migration explicitly changes them.

Published release names, asset filenames, hashes, signed manifests, source commits, acceptance evidence and dated changelog entries describe what was actually shipped. Preserve that evidence, including the Red Veil name on older releases. Do not relabel or replace an existing published artifact to make history look as though the new name was always in use. New releases can use the current display name and portable package stem while their updater remains compatible with the documented baseline.

Visual art remains replaceable independently of the brand source. The current Mira model is original procedural stylized art, with a clear helmet silhouette and subtle idle motion; it is not a production animation rig or a claim of validated suit engineering.

An existing installer updated through a content pack keeps its original application-bundle filename and OS registration. The updated game sets its window title and current interface from the canonical brand. New installers carry the new display/package names. This preserves the update trust root and save location without attempting to rewrite platform installer metadata from game content.
