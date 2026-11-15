# <!-- brand:display_name -->KŌMAKU: Dust & Radiation<!-- /brand --> branding

The product name is **<!-- brand:display_name -->KŌMAKU: Dust & Radiation<!-- /brand -->**. Ren is the current mission crewmate; Mira belongs to the retained earlier mission. Neither is a separate product name.

`game/data/brand.json` is the canonical source for the display name, title, subtitle and portable package names. Keep the macron in **KŌMAKU** in visible text. Use the canonical ASCII package stem where a portable filename is needed; do not invent another spelling in export or release scripts.

Game code reads `res://scripts/branding.gd` through an explicit preload and calls its static `display_name()`, `title()` or `subtitle()` accessors. This keeps newly introduced code independent of Godot’s global class registry. Shared components should read this source instead of copying brand strings into individual scenes. Product metadata on Mira’s scene follows the same source; her personal name remains Mira.

After editing the canonical JSON, run these commands from the repository root and review the changes:

```sh
python scripts/sync_brand.py
python scripts/sync_brand.py --check
```

Synchronization updates the Godot product name and export metadata, export package paths, npm package name, browser entry title and description, web manifest names and generated icons. It preserves legacy save paths, package script entries, the authoritative project version, application identifiers and updater assets. Native export version fields are derived from that project version rather than maintained separately: for `0.9.0-alpha.1`, macOS metadata is `0.9.0` and Windows file/product metadata is `0.9.0.1`. The full alpha version remains the release/update identity. Runtime UI obtains the current text from the helper; build tools read the canonical package stem. All three PDF generators also read the canonical display name and fingerprint the brand JSON/helper, so a rename requires a new PDF build rather than leaving old headings.

For macOS, `config/name.macos` is generated from the canonical name with **`&` replaced by `and`**, then normalized to Unicode NFD (decomposed form). The technical value is `KŌMAKU: Dust and Radiation`; the exported app filename is `KŌMAKU- Dust and Radiation.app`. The running game's window title and interface retain the exact canonical **KŌMAKU: Dust & Radiation** spelling.

This technical spelling avoids an export issue in Godot 4.6.3: its Mac binary-name substitution can put a raw ampersand into `Info.plist`, producing invalid XML. NFD normalization also preserves the filename form needed for the bundle-signing path. Both are derived export rules, not a second manually maintained product name. The Mac install helper's `APP_NAME` and `APP_NAME_NFD` are generated from the same rule so app discovery and process checks match the exported bundle.

Do not hand-normalize or rename files inside an already signed app. New candidates still require their own native plist, architecture, signature and startup gates; the export configuration alone is not proof of successful native launch or physical-Mac acceptance. See the [Mac launch repair](MACOS-LAUNCH-REPAIR.md).

Current documentation uses explicit HTML comment synchronization markers named `brand:display_name` and `/brand`. These are rewritten by the synchronization script without touching unmarked historical evidence. Current documentation must also be reviewed alongside code. The synchronization script does not rewrite historical documentation or guarantee that every illustration, screenshot or third-party listing has changed. Review visible screens and release filenames before shipping.

## Stable identities and historical evidence

Internal names such as `red_veil` resource paths, saved application data, updater storage, pinned repository identity, signing trust root and runtime compatibility contract can intentionally retain the legacy Red Veil identifier. These are compatibility boundaries. Renaming a directory or identifier without migration can lose access to progress or installed updates; changing a signing key or runtime contract can require a new baseline installer.

A product rename alone must not rotate keys, reset progress, change the GitHub repository identity or silently migrate application data. Keep native application and bundle identifiers stable unless a separately reviewed migration explicitly changes them.

Published release names, asset filenames, hashes, signed manifests, source commits, acceptance evidence and dated changelog entries describe what was actually shipped. Preserve that evidence, including the Red Veil name on older releases. Do not relabel or replace an existing published artifact to make history look as though the new name was always in use. New releases can use the current display name and portable package stem while their updater remains compatible with the documented baseline.

Visual art remains replaceable independently of the brand source. The current Ren model uses original procedural stylized geometry with articulated brushing; it is not a claim of photoreal likeness or validated suit engineering. Story illustrations are unlettered generated adaptations, with titles rendered as separate accessible UI text. Their provenance is recorded in `game/assets/art/journey/provenance.json`.

An existing installer updated through a content pack keeps its original application-bundle filename and OS registration. The updated game sets its window title and current interface from the canonical brand. New installers carry the new display/package names. This preserves the update trust root and save location without attempting to rewrite platform installer metadata from game content.

## Versioned package names

`archive_stem(version)` preserves the prefix that was actually published:

| Version               | Portable package prefix     |
| --------------------- | --------------------------- |
| 0.4 and earlier       | `Red-Veil`                  |
| 0.5–0.8               | `KOMAKU-Shield-Protocol`    |
| Current 0.9 candidate | `KOMAKU-Dust-and-Radiation` |

The new display name is **KŌMAKU: Dust & Radiation**, with `DUST & RADIATION` as the subtitle and `komaku-dust-and-radiation` as the package slug. Historical asset names are derived from version, not from untrusted downloaded brand metadata. This permits the new updater/tests to identify older official archives after a rename.
