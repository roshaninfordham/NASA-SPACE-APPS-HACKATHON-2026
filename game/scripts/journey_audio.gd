extends Node
## Team-supplied music and original project cues, with a user-gesture gate.
## Per-player levels never mutate the legacy game's Master bus or player data.
const MUSIC_PATHS := {
	"orbit": "res://assets/audio/journey/orbit.ogg",
	"surface": "res://assets/audio/journey/surface.ogg",
	"reflection": "res://assets/audio/journey/reflection.ogg",
	"minyo": "res://assets/audio/journey/minyo-san-kyoku.mp3",
	"floating": "res://assets/audio/journey/floating-lanterns.mp3",
}
const CONTEXT_TRACKS := {"story": "orbit", "preparation": "orbit", "mission": "surface", "debrief": "reflection", "home": "orbit", "silent": ""}
const SUPPLIED_CONTEXT_TRACKS := {"story": "minyo", "preparation": "minyo", "mission": "floating", "debrief": "floating", "home": "minyo", "silent": ""}
# The supplied Floating recording has a 9.2 dB higher measured average level.
# Apply this trim per player, so outgoing and incoming tracks crossfade evenly.
const TRACK_GAINS := {"floating": 0.34673685}
const EFFECT_KINDS := ["typewriter", "open", "close", "confirm", "ready", "countdown", "warning", "urgent", "arrival", "success", "retry"]
# Original, offline alert cues. These are not the inaccessible Drive recording.
# Cooldowns use real time: increasing simulation pace cannot create an audio burst.
const ALERT_INTERVAL_MS := {"countdown": 5000, "warning": 2500, "urgent": 1000}
const ALERT_GAIN := {"countdown": 0.22, "warning": 0.28, "urgent": 0.30}
const TYPEWRITER_INTERVAL_MS := 125
const EFFECT_RATE := 22050
const MUSIC_LEVEL := 0.42
var music_enabled := true
var effects_enabled := true
var music_volume := 0.6
var effects_volume := 0.65
var soundtrack := "supplied"
var _context := "home"
var _unlocked := false
var _focused := true
var _paused := false
var _music: Array[AudioStreamPlayer] = []
var _effects: Array[AudioStreamPlayer] = []
var _music_cache: Dictionary = {}
var _effect_cache: Dictionary = {}
var _gains: Array[float] = [0.0, 0.0]
var _target_gains: Array[float] = [0.0, 0.0]
var _active_slot := -1
var _active_track := ""
var _next_effect := 0
var _last_typewriter_ms := -1000000
var _last_alert_ms := -1000000
var _accepted_cues := 0
var _shutdown := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for index in range(2):
		var player := AudioStreamPlayer.new()
		player.name = "Music" + str(index)
		player.volume_db = -80
		add_child(player)
		_music.append(player)
	for index in range(4):
		var player := AudioStreamPlayer.new()
		player.name = "Effect" + str(index)
		add_child(player)
		_effects.append(player)
	_sync_music()

func on_user_gesture() -> void:
	if _unlocked: return
	_unlocked = true
	_sync_music()

func set_context(value: String) -> bool:
	if not CONTEXT_TRACKS.has(value): return false
	if value != _context:
		_stop_alerts()
		_last_alert_ms = -1000000
	_context = value
	_sync_music()
	return true

func set_soundtrack(value: String) -> bool:
	if value not in ["supplied", "original"]: return false
	soundtrack = value
	_sync_music()
	return true

func set_music_enabled(value: bool) -> void:
	music_enabled = value
	if not value: _stop_music()
	else: _sync_music()

func set_effects_enabled(value: bool) -> void:
	effects_enabled = value
	if not value: _stop_effects()

func set_music_volume(value: float) -> void:
	if not is_finite(value): return
	music_volume = clampf(value, 0.0, 1.0)
	_update_levels()

func set_effects_volume(value: float) -> void:
	if not is_finite(value): return
	effects_volume = clampf(value, 0.0, 1.0)
	for player in _effects:
		player.volume_db = linear_to_db(maxf(0.0001, effects_volume * float(player.get_meta("cue_gain", 0.25))))

func set_paused(value: bool) -> void:
	_paused = value
	if value: _stop_alerts()
	# Reading a concept may have UI cues, but quieter music supports attention.
	_update_levels()

func set_focused(value: bool) -> void:
	_focused = value
	for player in _music: player.stream_paused = not value
	if not value: _stop_effects()
	else: _sync_music()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT: set_focused(false)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN: set_focused(true)

func _sync_music() -> void:
	if _shutdown or _music.is_empty() or not _unlocked or not music_enabled: return
	var tracks: Dictionary = SUPPLIED_CONTEXT_TRACKS if soundtrack == "supplied" else CONTEXT_TRACKS
	var track: String = tracks[_context]
	if track.is_empty():
		_target_gains = [0.0, 0.0]
		_active_track = ""
		_active_slot = -1
		return
	if track == _active_track: return
	if not _music_cache.has(track):
		var resource := load(MUSIC_PATHS[track]) as AudioStream
		if resource == null: return
		if not (resource is AudioStreamOggVorbis or resource is AudioStreamMP3): return
		var stream := resource.duplicate() as AudioStream
		stream.set("loop", true)
		_music_cache[track] = stream
	var next := 0 if _active_slot != 0 else 1
	var player := _music[next]
	player.stop()
	player.stream = _music_cache[track]
	player.set_meta("track_gain", TRACK_GAINS.get(track, 1.0))
	player.volume_db = -80
	_gains[next] = 0
	_target_gains = [0.0, 0.0]
	_target_gains[next] = 1.0
	_active_slot = next
	_active_track = track
	player.play()
	player.stream_paused = not _focused

func _process(delta: float) -> void:
	if _shutdown or not _focused: return
	for index in range(_music.size()):
		# A frame-rate-independent ~0.6 s transition; no Tween can outlive a mute.
		_gains[index] = lerpf(_gains[index], _target_gains[index], 1.0 - exp(-5.0 * maxf(0, delta)))
		if _target_gains[index] == 0.0 and _gains[index] < 0.001:
			_gains[index] = 0
			_music[index].stop()
	_update_levels()

func _update_levels() -> void:
	for index in range(_music.size()):
		var gain := _gains[index] * music_volume * MUSIC_LEVEL * float(_music[index].get_meta("track_gain", 1.0)) * (0.35 if _paused else 1.0)
		_music[index].volume_db = linear_to_db(maxf(0.0001, gain))

func cue(kind: String) -> bool:
	if _shutdown or kind not in EFFECT_KINDS or not _unlocked or not _focused or not effects_enabled or effects_volume <= 0 or _effects.is_empty(): return false
	var now := Time.get_ticks_msec()
	if kind == "typewriter":
		if now - _last_typewriter_ms < TYPEWRITER_INTERVAL_MS: return false
		_last_typewriter_ms = now
	if ALERT_INTERVAL_MS.has(kind):
		if _paused or _context != "mission" or now - _last_alert_ms < int(ALERT_INTERVAL_MS[kind]): return false
		_last_alert_ms = now
		# An urgent cue replaces a previous alert instead of layering over it.
		_stop_alerts()
	if not _effect_cache.has(kind): _effect_cache[kind] = _make_effect(kind)
	var player := _effects[_next_effect]
	_next_effect = (_next_effect + 1) % _effects.size()
	player.stop()
	player.stream = _effect_cache[kind]
	var gain := 0.12 if kind == "typewriter" else float(ALERT_GAIN.get(kind, 0.25))
	player.set_meta("cue_kind", kind)
	player.set_meta("cue_gain", gain)
	player.volume_db = linear_to_db(maxf(0.0001, effects_volume * gain))
	player.play()
	_accepted_cues += 1
	return true

func _make_effect(kind: String) -> AudioStreamWAV:
	if ALERT_INTERVAL_MS.has(kind): return _make_alert(kind)
	var duration := 0.035 if kind == "typewriter" else 0.24
	if kind in ["arrival", "success", "ready"]: duration = 0.58
	var notes: Array[float] = [440.0]
	match kind:
		"typewriter": notes = [620.0]
		"open": notes = [330.0, 440.0]
		"close": notes = [440.0, 330.0]
		"confirm": notes = [440.0, 587.33]
		"ready": notes = [440.0, 587.33, 659.25]
		"arrival", "success": notes = [392.0, 523.25, 659.25]
		"retry": notes = [392.0, 440.0]
	var count := int(duration * EFFECT_RATE)
	var data := PackedByteArray()
	data.resize(count * 2)
	for index in range(count):
		var time := float(index) / EFFECT_RATE
		var note_index := mini(notes.size() - 1, int(time / duration * notes.size()))
		var local_time := fmod(time, duration / notes.size())
		var local_length := duration / notes.size()
		var envelope := minf(1.0, local_time / 0.008) * pow(maxf(0, 1.0 - local_time / local_length), 1.6)
		var sample := sin(TAU * notes[note_index] * local_time) * envelope * 0.42
		data.encode_s16(index * 2, int(sample * 32767))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = EFFECT_RATE
	stream.stereo = false
	stream.data = data
	return stream

func _make_alert(kind: String) -> AudioStreamWAV:
	# Soft attacks, real gaps and distinct rhythms make urgency readable without
	# a continuous siren. The highest tone remains below 1 kHz.
	var notes: Array[float] = [523.25]
	if kind == "warning": notes = [440.0, 587.33]
	elif kind == "urgent": notes = [622.25, 739.99, 880.0]
	var slot_seconds := 0.18
	var tone_seconds := 0.12
	var count := int(slot_seconds * notes.size() * EFFECT_RATE)
	var data := PackedByteArray()
	data.resize(count * 2)
	for index in range(count):
		var time := float(index) / EFFECT_RATE
		var note_index := mini(notes.size() - 1, int(time / slot_seconds))
		var local_time := fmod(time, slot_seconds)
		var sample := 0.0
		if local_time < tone_seconds:
			var attack := sin(minf(1.0, local_time / 0.014) * PI * 0.5)
			var release := sin(minf(1.0, (tone_seconds - local_time) / 0.045) * PI * 0.5)
			var phase := TAU * notes[note_index] * local_time
			sample = (sin(phase) + 0.10 * sin(phase * 2.0)) * attack * release * 0.36
		data.encode_s16(index * 2, int(sample * 32767))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = EFFECT_RATE
	stream.stereo = false
	stream.data = data
	return stream

func _stop_music() -> void:
	for player in _music: player.stop()
	_active_slot = -1
	_active_track = ""
	_gains = [0.0, 0.0]
	_target_gains = [0.0, 0.0]

func _stop_effects() -> void:
	for player in _effects: player.stop()

func _stop_alerts() -> void:
	for player in _effects:
		if ALERT_INTERVAL_MS.has(str(player.get_meta("cue_kind", ""))): player.stop()

func snapshot() -> Dictionary:
	return {"context": _context, "unlocked": _unlocked, "focused": _focused, "paused": _paused, "music_enabled": music_enabled, "effects_enabled": effects_enabled, "music_volume": music_volume, "effects_volume": effects_volume, "soundtrack": soundtrack, "active_track": _active_track, "accepted_cues": _accepted_cues}

func shutdown() -> void:
	_shutdown = true
	_stop_music()
	_stop_effects()
	for player in _music: player.stream = null
	for player in _effects: player.stream = null
	_music_cache.clear()
	_effect_cache.clear()

func _exit_tree() -> void:
	shutdown()
