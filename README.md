# Red Veil

**Primary game: [first-person Godot implementation](game/README.md).** The web dashboard below remains a simulation/reference prototype. Native download packaging is in progress.

A Mars survival game for curious explorers ages 7–12. Coordinate a habitat, a spacesuit, and a dusty visor through two independent hazards. Protect the crew, preserve power, and discover why timing matters.

**Status:** playable web prototype in active development. Not certified astronaut training. Native packages and device-specific performance certification are not yet complete.

## Run

Requires Node.js 22.12+ (tested with Node 24.22.1).

```sh
npm ci
npm run dev
```

Open the development server on port 5173. `npm run build` creates a static `dist/` deployment, including an offline service worker. `npm run preview` serves that build on port 4173. Service workers require HTTPS or a loopback address. First load must be online before offline use.

## Play

Read the short mission briefing, then launch. Use the habitat controls and the visor control; keyboard shortcuts 1–4 activate them. Space pauses when focus is outside a button. All controls are touch accessible. Shelter return takes nine simulated minutes; suit life support stays on during the journey. Sound is optional and synthesized locally. Tab switching pauses the mission. Use the field guide for equations and limitations.

## Validate

```sh
npm test
npm run build
npm run test:e2e
```

Browser tests use `/usr/bin/chromium` by default. Set `CHROMIUM_PATH` to a local Chromium executable if necessary. Tests cover desktop and narrow mobile layouts. See [validation](docs/VALIDATION.md) for what has and has not been measured.

## Design and evidence

- [Core brief](docs/CORE-BRIEF.md): source-of-truth scope and audience
- [Science](docs/SCIENCE.md): equations, provenance, assumptions, and limitations
- [Architecture](docs/ARCHITECTURE.md): module boundaries and extension points
- [Validation](docs/VALIDATION.md): verification and release gaps

No remote fonts, advertising, analytics, runtime APIs, or account system. A best-score value is stored locally and can be cleared from the field guide. Mission logs are downloaded only on request. External NASA references open only when selected. Hosting providers may retain normal access logs; deployment policy is separate from game code.
