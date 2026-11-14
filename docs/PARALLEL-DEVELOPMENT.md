# Parallel development and review

Parallel work is used for independent implementation and review. One integration owner combines the result, runs the complete checks, and serializes Git commits, pushes, and release operations. More agents or more commits do not establish correctness by themselves.

## Task contract

Each task names its objective, permitted files, interfaces, acceptance checks, dependencies, and limits. A useful assignment has this form:

```text
Outcome: the behavior a player or maintainer should receive.
Owned files: an explicit list; other files are read-only.
Interfaces: argument/return types and shared state or signal contracts.
Acceptance: observable success, failure, recovery and regression checks.
Dependencies: what must be provided by another owner before integration.
Handoff: changed files, commands run, results, remaining risks and blockers.
Git authority: integration owner only; no worker staging, commit or push.
```

Workers send interface changes to the integration owner and affected peers before depending on them. Questions about assumptions are part of review; a long prompt is not proof that the requirements are understood.

## Current update work ownership

| Owner                       | Files and responsibility                                                                                                                          |
| --------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| Integration owner           | Main game/menu integration, project autoload configuration, validation workflow, general documentation, combined tests and Git/release operations |
| Update bootstrap            | `game/updater/store.gd`, `bootstrap.gd`, `verifier.gd`, their bootstrap/store tests and temporary-project test harness                            |
| Update client/interface     | `game/updater/client.gd`, `panel.gd`, and client tests                                                                                            |
| Release automation          | Build/signing/setup scripts, download workflow, export presets, release-tool tests and update instructions                                        |
| Requirements review         | This delivery contract and cross-module review; no production-code edits                                                                          |
| Independent security review | Read-only inspection and isolated probes; findings go to the relevant owner and integration owner                                                 |

Generated script identifiers belong to the same owner as their scripts. Shared files are changed by the integration owner after the worker handoff. Workers do not reset the workspace, discard others' changes, rebase shared history, or run a shared import/export concurrently. Test keys and boot-test projects belong in isolated temporary directories; tests must not use a real player's update or practice profile.

## Shared updater interfaces

The `Updates` autoload owns the immutable bootstrap trust boundary. It exposes `store`, `running_version`, `startup_notice`, and `mark_healthy()`. The store accepts its root directory, bundled baseline version, and a public `CryptoKey` captured before any downloaded resource pack is mounted.

The store provides configuration detection, signed manifest validation, staging, activation, boot selection, and health acknowledgment. The client uses those functions and exposes current/available versions, status, message, progress, busy/restart state, a `changed` signal, and check/install/restart actions. The panel displays client state; it does not decide which bytes are trusted. The game decides when a notification can appear without interrupting a mission.

The GitHub release contract uses fixed assets: `update-manifest.json`, `update-manifest.sig`, and `red-veil-content.pck`. A manifest identifies the repository, supported engine/schema, exact version/source commit, and content size/hash. No server-supplied executable path or arbitrary download URL becomes an execution instruction.

## Delivery acceptance gates

| Area             | Required evidence before calling it complete                                                                                                                                                                                                      |
| ---------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Discover         | A bounded public GitHub response selects a newer compatible published version with the required assets; errors and no-update states are distinct. Automatic checks are throttled.                                                                 |
| Notify           | A small title/debrief notification is visible, dismissible, and understandable. It does not interrupt an active mission or force an update to keep playing.                                                                                       |
| Verify           | Missing/wrong keys, changed signatures/manifests/packs, unsafe names, excessive sizes, unsupported engines, and downgrades fail closed. The pinned key is captured before pack mounting.                                                          |
| Stage            | Partial downloads, cancellation/network loss, and write failures leave the currently playable version intact. Only verified bytes can become an activation candidate.                                                                             |
| Activate         | Explicit player action schedules the update and restart. No downloaded code is mounted into the middle of a running mission. Journal changes are checked for write failure.                                                                       |
| Recover          | An unacknowledged trial boot restores a verified previous version or the bundled baseline on the next launch. A new installer cannot be replaced by an older cached pack.                                                                         |
| Sign and publish | The private key stays outside Git/artifacts/logs; its public key matches the committed trust root. The exact source revision, build version, release tag, signed manifest and published assets agree. Published assets are not silently replaced. |
| Preserve privacy | Checks use public release metadata, without learner profiles, mission logs, API credentials or personal fields.                                                                                                                                   |
| Integrate        | Main-scene startup, local academy progress, pause/resume, a complete mission and export smoke checks still pass after wiring the updater.                                                                                                         |
| Report           | Documentation distinguishes implemented code, automated checks, published installers, and physical-device verification.                                                                                                                           |

## Test matrix

Use disposable signing keys for deterministic verification tests. A real resource pack in an isolated project should demonstrate successful activation, failed-start recovery, corrupt-state fallback, and tampered-pack rejection. Transport tests should cover network and HTTP failures, malformed/oversized metadata, conflicting versions, interrupted downloads, and duplicate requests without contacting production services. Release-tool tests should reject mismatched public/private keys and inconsistent release metadata.

Headless Linux startup does not establish Mac/Windows restart behavior, mobile support, scientific validity, educational benefit, or every gameplay path's health. A startup acknowledgment proves only its explicitly tested startup checkpoint. Power-loss durability beyond the file operations actually tested must not be promised.

## Version and platform boundaries

Published `0.3.0-alpha.1` contains the academy and signature-verification foundation, but no enabled in-game update flow. Existing installations need one manual installation of an updater-enabled release. Until a production public key is pinned, the signing secret is provisioned, and the complete flow is tested, automatic installation must remain disabled.

Same-engine desktop resource updates can replace game content and scripts. Engine/trust-root changes can require a full installer. Resource signatures do not replace Apple/Windows application signing or notarization. Native mobile builds are not yet distributed; their update design must respect the actual distribution channel. The browser's application/service-worker lifecycle is a separate path and must not be advertised as the tested desktop restart flow.

## Contribution activity

Activity should come from useful implementation, regression fixes, tests, research records, design assets, and documentation. Commits should be coherent and reviewable. There is no empty-commit, backdating, history-rewriting, or artificial splitting scheme to reach a numerical quota. A goal of hundreds of contributions over sustained development does not change the acceptance gates or justify publishing incomplete features as finished.
