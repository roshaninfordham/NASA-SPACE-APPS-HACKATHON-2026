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

## Managed terminal authentication limitation

On November 14, 2026, the owner completed a personal device login. A corrected `env -u GH_TOKEN -u GITHUB_TOKEN gh repo edit ...` still returned HTTP 403, "Resource not accessible by integration", despite the stored credential being a user OAuth token and the account having admin access. Do not repeatedly ask the owner to sign in. Use the About gear in the owner's browser, or run the following on the owner's own laptop terminal, outside the managed cloud environment:

```sh
gh auth login --hostname github.com --web
gh repo edit roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026 --description "Red Veil — a first-person Mars learning adventure for ages 7–12. Explore, protect your crew, and discover space science." --homepage "https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/releases" --add-topic "godot,mars,educational-game,space-apps,first-person,stem-education,offline-game"
```

Each command is a single line. Do not paste shell prompts, HTML escapes, or backslashes before options. If the managed terminal cannot open the device-login URL, it can be opened manually in a browser; a later "Authentication complete" means that step succeeded. Plain-text credential storage means the cloud machine has no supported credential keyring; personal credentials should not be shared in chat or committed. The repository build and release workflows continue using their scoped Actions token.
