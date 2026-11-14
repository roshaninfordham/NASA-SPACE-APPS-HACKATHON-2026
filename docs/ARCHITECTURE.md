# Architecture and platform decision

## Current choice

A browser-first game with JavaScript modules, Three.js rendering, and Vite builds. The runtime has one third-party dependency: Three.js. No application framework, physics engine, server, or network API is required during play. This keeps deployment and iteration simple and avoids a separate engine export for each platform.

A Tauri shell is a suitable follow-on for desktop packaging when native capabilities or distribution warrant it. Tauri reuses the system webview; it does not make all webviews behave identically and it does not eliminate the need for macOS, Windows, Linux, Android, and iOS testing. Native signing and store distribution require their platform tooling and credentials. Neither “lowest possible memory” nor “every possible device” is an honest guarantee.

## Boundaries

| Module                | Responsibility                                                   | Does not own          |
| --------------------- | ---------------------------------------------------------------- | --------------------- |
| `src/scenarios.js`    | Scenario data, system parameters, source metadata                | Rendering             |
| `src/simulation.js`   | Pure state transitions, fixed-step integration, advice, baseline | DOM, network, audio   |
| `src/scene.js`        | Replaceable 3D view adapter                                      | Game rules            |
| `src/main.js`         | Input, accessible DOM, timing, dialogs, local export             | Scientific parameters |
| `src/style.css`       | Responsive appearance and motion preference                      | Simulation state      |
| `scripts/build-sw.js` | Content-versioned offline build cache                            | Remote caching        |

Simulation time uses hours, energy kWh, power kW, accumulated dose mSv. Fixed steps are 1/120 hour. The renderer targets 30 fps and caps pixel ratio at 1.5. Scene geometry is procedural, with no downloaded textures or character assets. No dynamic shadows or postprocessing passes. DOM updates are throttled. Hidden tabs pause rather than consuming mission resources.

## Evolution

Add scenarios as data with explicit units and provenance. Extend pure state transitions before adding a control. Every coupled energy or exposure mechanism needs a regression test. Replace the scene adapter with commissioned art, a different character style, or a different renderer while preserving the simulation contract. Asset revisions must include license and attribution records. Avoid unbounded event histories; a mission is finite and sampled at a bounded cadence.

The current controller uses understandable rules. A future predictive controller should be compared against multiple baselines on held-out scenarios with identical inputs. ML is not justified until there is a dataset and a measurable benefit over these rules.

## Known engineering work

The initial UI controller should be split into smaller view modules as screens grow. State exports are versioned but import/migration is not implemented. Native shell, localization, automated accessibility audit, WebKit/Firefox checks, graphics context-loss recovery, and physical-device performance measurements remain release gates. An offline first load still requires downloading the application.
