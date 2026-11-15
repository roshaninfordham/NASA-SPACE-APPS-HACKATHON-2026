# Real local-coach evaluation — cloud experiment

**Decision: keep the built-in coach authoritative; do not ship this neural model as the default.** Local inference succeeded, but factual review found errors that JSON validation did not catch. A stricter prompt improved some answers without resolving the key science failures. This is an actual CPU experiment, not an API mock or a claim of production-ready AI tutoring.

## Reproduce

From the repository root on the cloud Linux x86_64 machine:

```sh
# Explicit one-time public downloads, outside the Git checkout; SHA-256 verified.
python scripts/evaluate_local_coach.py --prepare --prepare-only

# Actual CPU inference on the game's eight catalog concepts and three challenge cases.
python scripts/evaluate_local_coach.py --threads 2

# Separate repeat of six known failure cases; does not overwrite the baseline report.
python scripts/evaluate_local_coach.py --threads 2 --strict-retry
```

The harness owns the temporary server lifecycle and stops it when finished. It uses only the game's bounded `game/data/mission-concepts.json` facts and fixed test questions; no child inputs, credentials, cloud inference, shell tools or web browsing are supplied to the model. A per-run token protects the local API. The server binds only `127.0.0.1`, receives a local model path, and starts with `--offline`, no agent/tools, no web UI and no multimodal projector. No prompt is sent to Gemini or another hosted model. OS-level network-namespace isolation was not part of this test; the runtime's offline mode and loopback configuration were explicit.

The script can download only the two pinned artifacts listed below when `--prepare` is requested. It verifies both artifacts before inference and safely re-extracts the verified runtime archive. Missing/corrupt files prevent startup. Model/runtime/results stay under `/workspace/tooling`, **outside Git and off the user's Mac**. This is not an installed in-game model-pack manager or a native mobile inference integration.

## Artifacts and hardware

| Item                      | Verified value                                                                         |
| ------------------------- | -------------------------------------------------------------------------------------- |
| Model                     | Qwen3-1.7B, official Q8_0 GGUF, Apache-2.0                                             |
| Model revision            | `90862c4b9d2787eaed51d12237eafdfe7c5f6077`                                             |
| Model size                | 1,834,426,016 bytes, approximately 1.83 GB decimal / 1.71 GiB                          |
| Model SHA-256             | `061b54daade076b5d3362dac252678d17da8c68f07560be70818cace6590cb1a`                     |
| Runtime                   | Official llama.cpp `b12421`, Ubuntu x64 CPU archive, MIT license                       |
| Archive size              | 23,372,946 bytes                                                                       |
| Archive SHA-256           | `3070bfe3d5a66d32d6b43dec0878f864545623c2f24070fb8cc117c7ba0c017e`                     |
| Host visible to container | AMD EPYC 9V74; x86_64; five visible logical CPUs                                       |
| Cgroup limits             | CPU `400000 100000` = four CPU-equivalents; memory 34,359,738,368 bytes = 32 GiB       |
| Run allocation            | Two CPU generation/prompt threads; zero GPU layers; one request slot                   |
| Context/output            | 2,048-token context; maximum 160 generated tokens                                      |
| Generation                | Non-thinking template; temperature 0.2; seed 42; constrained JSON explanation/question |

Publisher sources: [Qwen model card and license](https://huggingface.co/Qwen/Qwen3-1.7B), [pinned official GGUF](https://huggingface.co/Qwen/Qwen3-1.7B-GGUF/tree/90862c4b9d2787eaed51d12237eafdfe7c5f6077), [llama.cpp release b12421](https://github.com/ggml-org/llama.cpp/releases/tag/b12421), [runtime source/license](https://github.com/ggml-org/llama.cpp).

The downloads' exact hashes matched publisher metadata, and the local runtime generated the outputs described below. The shared cloud host may run other development tasks: these timings are reproducible experiment observations, **not a controlled laptop, Apple Silicon, phone or concurrent-game benchmark**. Model verification reads the whole file before launch, so startup benefits from the filesystem cache and must not be called a cold-disk startup measurement.

## Measured results

| Metric                                    |                        Baseline |           Stricter prompt retry |
| ----------------------------------------- | ------------------------------: | ------------------------------: |
| Cases                                     |                              11 |        6 repeated failure cases |
| Process-to-ready time, filesystem warm    |                         1.795 s |                         1.518 s |
| Request minimum / median / maximum        |       5.914 / 10.509 / 17.685 s |        6.752 / 9.869 / 14.368 s |
| Requests over proposed 12-second deadline |                          4 / 11 |                           1 / 6 |
| Sampled peak server RSS                   | 2,533,941,248 bytes (~2.36 GiB) | 2,425,950,208 bytes (~2.26 GiB) |
| Structural-check passes                   |                         11 / 11 |                           5 / 6 |
| Scientific/teaching release gate          |                  **Not passed** |                  **Not passed** |

Structural checks cover completed generation, JSON shape, bounded string fields, digit tokens drawn from the facts, and absent thinking tags. They do not judge scientific meaning. The stricter `time` answer used `20` where the supplied facts spell out “twenty”; the conservative literal-digit check flagged it. That flag alone is **not an invented numerical value**, demonstrating that automated validators can also reject a defensible answer. Human review is still necessary.

| Case                  | Baseline latency | Strict retry latency |
| --------------------- | ---------------: | -------------------: |
| radiation             |         17.685 s |             14.368 s |
| dose                  |         15.867 s |             11.046 s |
| sievert               |         13.903 s |              8.692 s |
| dust                  |         13.095 s |                    — |
| power                 |         10.119 s |                    — |
| time                  |         11.074 s |             11.927 s |
| speed                 |         10.395 s |                    — |
| shelter               |         10.509 s |                    — |
| same_final_dose       |          5.914 s |              6.752 s |
| no_personal_sievert   |          6.963 s |                    — |
| reject_false_forecast |          7.479 s |              7.130 s |

These are non-streaming end-to-end request times, not time to first token. No speed comparison against Gemini or another model was performed.

## Observed failures, preserved rather than hidden

- **Dose versus dose rate:** the baseline asks what could cause a difference between accumulated dose and “210 µGy/day.” Those are different quantities; asking a learner to compare them directly undermines the lesson.
- **Sievert:** the baseline describes Sv as measuring “radiation damage,” then asks how to improve a smartwatch to calculate sieverts. The game explicitly lacks the needed measurements. The strict prompt says not to describe Sv as damage, yet the retry still begins **“Sievert measures radiation damage.”** This is a clear release blocker for a child-facing explanation.
- **Timer:** the baseline calls the timer elapsed time and blurs real play time with simulated mission duration. The stricter prompt improves the explanation but still creates an awkward question about “NASA's Martian sol calculation.”
- **Same final dose:** the baseline first falsely states that the game assumes faster cleaning reduces final dose, then contradicts itself with the correct facts. The strict retry correctly says cleaning pace does not affect final dose.
- **False forecast premise:** the baseline accepts a request to claim that the Sun image predicts the game storm, despite supplied contrary facts. The strict retry still begins **“The game assumes the NASA Sun image predicts the storm exactly,”** before partially correcting itself. The NASA image does not drive this storm. Merely including a later correction is insufficient for a clear child-facing answer.
- Several replies use three explanatory sentences even though the prompt requests one or two, and some questions require reasoning beyond the current player controls. JSON validity is not adherence to the intended teaching experience.

The strict repeat added explicit instructions about those failures and preserved the same source facts. It was an **in-sample prompt repair experiment**, not a held-out benchmark. Improvement on selected cases does not establish generalization, and persistent errors show that prompt changes alone are insufficient here.

## Evidence retained in the cloud workspace

- `/workspace/tooling/local-coach-evaluation/report.json` — full baseline outputs, timings, input-catalog hash and metadata.
- `/workspace/tooling/local-coach-evaluation/report-strict.json` — separate strict retry outputs and metadata.
- Corresponding `server.log` and `server-strict.log` — local runtime timings/configuration; no user data supplied.
- Baseline report SHA-256: `aac9c3677a0cbf1e4f519d84ca2223290240ca59a4b72313549f42c62a59fce4`.
- Strict report SHA-256: `64040bcc9a91c3a716ee68ebe64c61747a76c6bc86f49f09c4dbfe9df2c9ceb7`.

The exact small reports are now preserved in Git as [baseline JSON](evidence/local-coach/report.json) and [strict-retry JSON](evidence/local-coach/report-strict.json), with the hashes above. They contain fixed catalog-test outputs, not child data, credentials, model weights or server logs. Re-running the harness updates only its outside-Git report paths; the committed reports preserve this run. The baseline did not record a harness SHA before the strict-retry option was added, so no retrospective baseline script hash is claimed; the default baseline prompt/cases are retained in the current reproducible harness. The strict report records the executed harness SHA, allowing later formatting or edits to be distinguished from that run.

## Next candidate and next gate

Publisher metadata confirms **[Qwen3.5-2B](https://huggingface.co/Qwen/Qwen3.5-2B/tree/15852e8c16360a2fea060d615a32b45270f8a8fc)** at revision `15852e8c16360a2fea060d615a32b45270f8a8fc`, Apache-2.0, architecture `qwen3_5`. This is a reasonable newer small-model candidate to compare, **not evidence that it solves these failures or is the best model**. The attempted official `Qwen/Qwen3.5-2B-GGUF` endpoint returned 401; no official quantized artifact was verified, and no additional multi-gigabyte model was downloaded. A separate candidate is publisher [SmolLM3-3B](https://huggingface.co/HuggingFaceTB/SmolLM3-3B/tree/a07cc9a04f16550a088caea529712d1d335b0ac1), also Apache-2.0; its larger parameter count is not a quality guarantee.

Before expanding downloads, select a bounded comparison pack with verified license/hash and compatible runtime support, then evaluate both models on **new held-out facts/conflicts**, not only the repaired prompts above. Measure laptop responsiveness with the game actually running and retain the built-in explanation during inference. Do not let generated prose change simulation numbers, source IDs, score or learner progress. A useful model must improve factual clarity at acceptable latency; local execution alone is not sufficient.

The current offline game source therefore keeps the deterministic built-in coach authoritative. This source milestone is unreleased. The experiment establishes that local inference can run in the cloud development environment and provides a reproducible quality gate; it does not install AI on players' machines, fine-tune on children, or justify an adaptive-learning or SOTA claim.
