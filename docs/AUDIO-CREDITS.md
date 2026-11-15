# Audio credits and playback behavior

The journey uses quiet, separate music and effects controls. Music begins after a player gesture, crossfades between activities, becomes quieter while reading or paused, and pauses when the application loses focus. Typewriter ticks are limited to eight per second. Alerts use brief, spaced beeps instead of a continuous siren. These settings do not change the scientific model or the legacy game's global audio bus.

## Music supplied by the design team

The default soundtrack includes the team's two supplied recordings. The user reported that their team confirmed these recordings were usable and directed their inclusion.

| Track                 | Artist attribution supplied in filename |       Duration | Plays during                |
| --------------------- | --------------------------------------- | -------------: | --------------------------- |
| **Minyo San Kyoku**   | **Doug Maxwell / Zac Zinger**           | 153.29 seconds | Home, story and preparation |
| **Floating Lanterns** | **The Mini Vandals**                    | 116.27 seconds | Mission and debrief         |

The original MP3 bytes are preserved without transcoding. [Supplied music provenance](../game/assets/audio/journey/supplied-music-provenance.json) records original filenames, SHA-256 hashes, durations, credits and measured levels. The files contain only an `encoder=Google` metadata tag, without embedded artist or license information. The artist names above therefore preserve the credits supplied by the team.

**Rights status:** these recordings are included at the user and team's direction. Their specific license has not been independently verified. They are not covered by any repository code license or the Kenney CC0 asset notice. This credit is not a claim of Creative Commons, royalty-free or unrestricted redistribution terms. The user identified YouTube as the source; the official [YouTube Audio Library help](https://support.google.com/youtube/answer/3376882?hl=en) explains how to obtain the applicable license and exact attribution from individual entries. That general page does not verify either supplied recording.

The audio manager lowers Floating Lanterns by 9.2 dB relative to Minyo San Kyoku because their decoded average levels differ. This is an engineering level adjustment, not a perceptual loudness certification. Both play beneath interface cues, with independent music/effects volume and mute controls. Context changes use a gentle crossfade; adjacent contexts sharing the same recording keep its playback position.

## Original alternative score and cues

An original ambient soundtrack remains available through the shared audio manager's `set_soundtrack("original")` setting; `set_soundtrack("supplied")` restores the default recordings. The caller owns saving the player's preference, alongside their separate volume and mute settings.

The bundled `orbit.ogg`, `surface.ogg` and `reflection.ogg` are original procedural project ambience. Their small harmonic score uses no sampled recordings or material from the supplied tracks. The complete generator is [generate_ambient.py](../game/assets/audio/journey/generate_ambient.py); it uses Python's standard library and FFmpeg/libvorbis to write three 16-second loops. Container bytes can vary by encoder version; the score and PCM synthesis are deterministic. [Original score provenance](../game/assets/audio/journey/provenance.json) records the generator and exported files.

The typewriter, open/close, confirmation, readiness, countdown, warning, urgent, arrival and retry cues are generated from short sine-wave envelopes in [journey_audio.gd](../game/scripts/journey_audio.gd). No network service or microphone is used. This original project material is separate from the supplied recordings.

The countdown and warning design uses an **original fallback**, because the Drive beep mentioned by the team was not accessible. It does not sample or reproduce that unprovided recording. [Cue provenance](../game/assets/audio/journey/cue-provenance.json) identifies the synthesis source and alert recipes.

| Alert     | Rhythm             | Duration | Minimum interval between alerts |
| --------- | ------------------ | -------: | ------------------------------: |
| Countdown | One soft beep      |   0.18 s |                             5 s |
| Warning   | Two rising beeps   |   0.36 s |                           2.5 s |
| Urgent    | Three rising beeps |   0.54 s |                             1 s |

The intervals use real monotonic time, so faster simulation settings cannot cause a burst of overlapping alerts. An urgent cue replaces a preceding alert; pause, reading, focus loss, effects mute and leaving the mission stop alerts immediately. A new mission resets the cooldown. Soft attacks, silent gaps and tones below 1 kHz distinguish the rhythms without a continuous alarm. The displayed countdown and warning text remain available when sound is off.

## Existing game effects

Earlier footsteps and action sounds remain subject to the [Kenney asset notice](../game/licenses/Kenney-ASSETS.md). That CC0 notice applies to the identified Kenney material, not to either supplied music track.

## Verification scope

Automated checks cover the gesture gate, independent controls, focus/pause behavior, shared alert cooldowns, warning escalation, context reuse, supplied/original selection, relative track levels and bounded cue generation using Godot's Dummy audio driver. Alert checks also verify waveform headroom, silent endpoints, genuine silence gaps and distinct single/double/triple durations. They do not establish comfortable volume on every speaker/headphone or actual device audio output. Listening and learner comfort remain physical-device review tasks.

made with love by Team Roshan Xingbo at the NASA Space App Hackathon 2026, NYC
