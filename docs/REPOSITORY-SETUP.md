# Repository presentation and distribution

## Completed through the repository

The README, screenshots, engine decision, science ledger, design handoff, validation record, credits, submission outline, playtest protocol, issue templates, CI, and reproducible download workflow are versioned in Git. Native binaries are Release assets, with source-commit manifests and checksums. GitHub Packages is not required for game installers.

## About fields requiring repository settings access

The connected integration can push code and manage release metadata, but GitHub rejected its repository-settings update with HTTP 403. The account's reported admin role did not grant this integration the required API permission. No credential values were requested or stored.

A repository owner can use the About section's gear icon to set:

- **Description:** Red Veil — a first-person Mars survival learning game for ages 7–12. Explore, protect your crew, and learn the science of energy, dust, and radiation.
- **Website:** https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/releases
- **Topics:** godot, mars, educational-game, space-apps, first-person, stem-education, offline-game

GitHub computes Languages and Contributors from repository history and may update them asynchronously. Stars and watchers are not build or project-readiness indicators.

## Publication boundary

The build script produces local archives without publishing. The manual workflow can upload and publish an explicitly selected existing draft release. It refuses to modify an already published release. Direct workstation uploads were rejected by GitHub's upload endpoint; repository-scoped Actions successfully performs the upload with its built-in token.

Unsigned alpha builds and verified checks must remain clearly distinguished from signed releases, real-device validation, and final art. A new code or packaging revision should get a new release rather than silently replacing a published artifact.
