# Validation record

## Verified in this environment

- Node 24.22.1; frozen dependency installation via package lock.
- Sixteen simulation tests: habitat energy balance, dose accumulation, passive shielding, atmospheric-versus-surface dust, mandatory life support, deterministic and viable adaptive policies for three scenarios, fixed-policy failures, terminal-state invariance, invalid time steps, separate suit/visor energy, shelter travel, inspection visibility, and suit aborts.
- Production build with local assets and a content-versioned offline cache.
- Chromium desktop (1440 px) and mobile-sized (390 px) interaction checks: briefing, launch, conservation, shelter command, pause, field guide, scenario selection, no horizontal overflow, and no uncaught browser errors.
- Complete guided mission in low-graphics mode on both browser sizes, successful debrief, mission-log download, and restart.
- Production offline reload, mission launch, visor control, and zero third-party runtime requests.
- Visual inspection of desktop capture. This is a prototype art direction, not final approved art.

## Still required before a product-grade claim

- Physical MacBook M5 profiling: cold start, frame times, RSS, power use, and thermal behavior. Cloud Chromium timings are not a substitute.
- Real Safari/WebKit, Firefox, iOS, Android, Windows, Linux, keyboard-only and screen-reader sessions.
- Additional browser walkthroughs for each abort branch and graphics-context recovery.
- Context-loss and low-memory recovery, versioned save migration, native package signing and verification.
- Subject-matter review of radiation/energy simplifications and review of current challenge rules.
- Age-appropriate supervised playtesting for comprehension, fun, reading burden, and learning transfer. No children have been recruited or data collected.

## Proposed measurable acceptance criteria

At least 80% of pilot participants should explain why clean panels may still produce little power under a dusty sky after one guided mission. At least 80% should identify that visor and habitat cleaners draw from different energy stores. These are targets, not results.

Performance targets to measure on agreed devices: first interaction within two seconds from a local cached launch; stable 30 fps during the mission; no growing memory across ten restarts. Set hard memory targets after measuring a physical low-end device and the primary MacBook. Compare alternatives using identical content rather than framework marketing numbers.
