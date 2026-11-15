# <!-- brand:display_name -->KŌMAKU: Shield Protocol<!-- /brand --> credits and asset provenance

This file covers the current source, including the **0.8.0-alpha.1 source snapshot**. Published releases contain the notices for their own assets. Reviewed November 15, 2026, America/New_York.

## Runtime

Godot Engine 4.6.3, MIT license. Official export templates are verified against the publisher's SHA-512 manifest. Engine and third-party notices are pinned to `4.6.3-stable` and bundled in `game/licenses/Godot-MIT.txt` and `Godot-THIRDPARTY.txt`.

## Music and sound

The design team supplied **Minyo San Kyoku — Doug Maxwell / Zac Zinger** and **Floating Lanterns — The Mini Vandals**. The user reported team confirmation that the recordings were usable and directed their inclusion. Artist names preserve the supplied credits; the original MP3s have no embedded artist/license information. Their individual license terms have not been independently verified, and they are not covered by the repository's code license or Kenney's CC0 notice.

[Audio credits and playback behavior](docs/AUDIO-CREDITS.md) records the rights boundary, sources, levels, and verification scope. [Supplied recording provenance](game/assets/audio/journey/supplied-music-provenance.json) records unchanged file hashes and original filenames.

The alternative `orbit.ogg`, `surface.ogg`, and `reflection.ogg` loops are original procedural project ambience, with the [generator](game/assets/audio/journey/generate_ambient.py) and [provenance](game/assets/audio/journey/provenance.json) included. Journey typewriter and interface cues are synthesized by the project; they contain no samples from the supplied recordings.

## Kenney starter kit

Source: https://github.com/KenneyNL/Starter-Kit-3D-Platformer

Inspected revision: `3fa8a04b1c01ab23db43123d4ce814a34c3fc7f0`.

Controller patterns informed the independently adapted first-person controller. Selected `coin`, `land`, `walking`, and `jump` OGG files are included unchanged. The repository's code is MIT licensed; identified assets and effects are CC0 under its supplied notice. [MIT notice](game/licenses/Kenney-MIT.txt) · [Asset notice](game/licenses/Kenney-ASSETS.md). These permissions do not apply to the separately supplied music.

## Fonts

| Font               | Attribution and use                                                 | License notice                                                |
| ------------------ | ------------------------------------------------------------------- | ------------------------------------------------------------- |
| Jost               | The Jost Project Authors; journey display typography                | [SIL OFL 1.1](game/licenses/jost-OFL.txt)                     |
| IBM Plex Sans      | IBM Corp.; journey reading text                                     | [SIL OFL 1.1](game/licenses/ibmplexsans-OFL.txt)              |
| IBM Plex Mono      | IBM Corp.; journey numeric/technical labels                         | [SIL OFL 1.1](game/licenses/ibmplexmono-OFL.txt)              |
| Lilita One         | Juan Montoreano; retained earlier interface                         | [SIL OFL 1.1](game/licenses/Lilita-OFL.txt)                   |
| DejaVu Sans / Mono | Bitstream Vera-derived fonts with DejaVu contributions; science PDF | [Complete font notice](game/licenses/DejaVu-Font-License.txt) |

[Journey font provenance](game/licenses/Journey-Font-Sources.json) lists source URLs and SHA-256 hashes. The science PDF embeds font subsets and includes the complete DejaVu notice as an attachment.

## Science and reference material

The [journey source ledger](docs/SCIENCE-JOURNEY-SOURCES.md) identifies NASA/primary research, EPA unit definitions, the historical Curiosity detector result, and explicit game assumptions. Stationary cleaning rates, partial-work transmission, panel/load/battery settings, and the configurable recall-entry transition are authored teaching choices; no source is claimed to certify astronaut cleaning speed. The [16-page guide](docs/media/KOMAKU-Science-Guide.pdf) separates the short mission from the retained advanced model. NASA does not endorse this project; its insignia is not the product logo. Publication summaries are not raw instrument time-series datasets.

The team's concept references inform the procedural environment and Asian-inspired wave, blossom, lattice, lantern, and textile motifs. These are original interpretations, not claims of pixel-identical or photoreal reproduction. The new journey emphasizes quiet window framing and shared typography rather than restoring every earlier ornament. User-supplied design PDFs and discussion are preserved byte-for-byte with [source hashes](docs/design-specs/source/journey-2026-11-14/provenance.json); their unverified claims are not implementation authority.

## Live NASA imagery

**Courtesy of NASA/SDO and the AIA, EVE, and HMI science teams.** The optional solar view retrieves the latest available AIA 193 Å browse image from [NASA SDO](https://sdo.gsfc.nasa.gov/data/), labels cache/retrieval status, and keeps it separate from gameplay physics. NASA’s [Data Rights and Rules for Data Use](https://sdo.gsfc.nasa.gov/data/rules.php) encourage public education with attribution; browse products are not intended for scientific analysis/publication without the principal investigator’s consent. No scientific values are derived from the image, and no image is presented as a Mars radiation measurement. The [bundled example provenance](game/assets/nasa/sdo-aia-193-provenance.json) records its NASA source, retrieval time, and checksum. This credit does not imply NASA endorsement or extend the repository’s code license to NASA imagery.

## Science-guide tools

ReportLab, Matplotlib, Pillow, and PyMuPDF generate the illustrated PDF and diagrams from repository sources. They are build tools, not requirements for playing the native app. The generator records source/artifact fingerprints and verifies the exact embedded font notice. Future third-party assets must record creator, license, source, and modifications before distribution.

Made with love by Team Roshan Xingbo at the NASA Space App Hackathon 2026, NYC.
