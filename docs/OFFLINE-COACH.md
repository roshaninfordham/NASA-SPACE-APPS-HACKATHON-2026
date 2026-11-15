# Offline mission guide

The Godot client has a deterministic, source-based explanation module at [`game/scripts/offline_coach.gd`](../game/scripts/offline_coach.gd). It works from the bundled science catalog and a local mission snapshot. It needs **no network connection, API key, model download, user account, or cloud inference**.

This is contextual teaching support, not a neural language model, open-ended chatbot, or validated adaptive tutor. The API labels it **“Offline mission guide · source-based rules”**; the compact interface says **“Source-based guide · works offline.”** It must not be labelled as Gemini output or as a local LLM response.

## API for the interface

```gdscript
const OfflineCoach = preload("res://scripts/offline_coach.gd")
var explanation: Dictionary = OfflineCoach.explain("power", model.snapshot())
```

`explain(concept_id: String, snapshot: Dictionary = {}) -> Dictionary` accepts the existing eight catalog IDs: `radiation`, `dose`, `sievert`, `dust`, `power`, `time`, `speed`, and `shelter`.

A known topic returns:

| Field                        | Purpose                                                          |
| ---------------------------- | ---------------------------------------------------------------- |
| `available`, `id`, `title`   | Whether the topic exists, and its catalog identity               |
| `provider`, `label`          | `offline-rules` and the explicit implementation label            |
| `explanation`                | A short explanation selected from authored source-based rules    |
| `question`                   | A low-stakes question to investigate; not a scored mastery claim |
| `live_reading`               | Formatted values from the supplied snapshot, with units          |
| `source_label`, `source_url` | Attribution copied from the existing bundled catalog             |
| `boundary`                   | Relevant game assumptions and scientific limitations             |

An unknown ID returns `available: false`, an instruction to choose a supported concept, and no source URL. Missing, malformed, infinite, negative-for-nonnegative-quantities, or out-of-range numeric observations are omitted rather than silently replaced with invented readings. Values are not inferred from free-form input. The returned dictionary can be edited by the caller without changing the retained source catalog.

## Integrated player experience

[`game/ui/journey_shell.gd`](../game/ui/journey_shell.gd) now adds a collapsed **Mission coach · offline +** toggle inside each concept card. Opening it reveals an investigation question and scrolls it into view without animation. **Check the explanation** reveals the reasoning and scientific boundary; existing current readings remain above instead of being repeated. Closing it restores the concise card. The existing **Back to mission** action remains visible below the scrollable reading area. Concept cards pause the mission; opening the coach does not resume or advance it.

The shell passes its live snapshot during a mission and an empty dictionary in preparation, so preparation does not invent readings. Source attribution remains available through the concept card's existing source controls. [Desktop capture](media/offline-polish/coach-desktop.png) · [Mobile capture](media/offline-polish/coach-mobile.png).

The root connection policy now blocks optional NASA and update HTTP requests by default, with an explicit Settings opt-in. The `--offline` launch option prevents that opt-in for the session. The game, explanations and local progress remain available without those services. **Source browser hyperlinks are separate, explicit external actions:** opening one still requires browser connectivity and is not a background game request. No new source download is needed to read the guide.

The explanation module itself does not open a browser, send telemetry, advance time, change simulation state, save progress, or award mastery.

## What responds to the actual mission

- **Radiation and dose:** current modeled rate and accumulated dose remain distinct, with explicit units; every completed default round shares outside duration and dose, regardless of pace.
- **Dust:** cleaned fraction and complementary dust remaining come from the actual snapshot; a fully cleaned panel gets a completion-specific explanation.
- **Power:** stored kWh and net kW remain distinct; negative net power explains drawing on available storage, and a full battery does not falsely promise further storage.
- **Time:** actual play seconds and simulated mission minutes are labelled separately.
- **Speed:** commanded multiplier and actual active cleaning rate are shown independently; the tiredness rule is an authored game assumption, not measured astronaut physiology.
- **Shelter:** actual inside/outside status is shown; ending the outside-dose counter is not a claim of zero indoor radiation.
- **Sievert:** no value is calculated from microgray; radiation and tissue weighting remain separate requirements.

Source links are inherited from [`mission-concepts.json`](../game/data/mission-concepts.json): NASA Curiosity radiation publications, the NASA research archive, Pathfinder dust research, rover power studies, Mars facts and shielding observations. The sievert definition correctly retains **US EPA** attribution rather than mislabelling that source as NASA.

## Verification

Run from the repository root:

```sh
godot --headless --path game --script res://tests/offline_coach_test.gd
```

The targeted suite passed **71 assertions** on Godot 4.6.3. It exercises all eight topics, deterministic responses, real pace-model snapshots, model/snapshot immutability, battery capacity and deficit behavior, commanded versus effective cleaning, unit separation, malformed observations, unsupported topics and the actual equal-final-dose invariant across two completed pace strategies.

These are software checks, not evidence of improved learning or a human playtest. The shell integration is implemented and captured at desktop and mobile sizes; physical-device usability still needs its own checks. A future optional local model can use this module as a transparent baseline and fallback, but its licensing, download size, throughput and factual accuracy would need separate evaluation before claiming offline AI inference.
