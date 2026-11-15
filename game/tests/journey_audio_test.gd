extends SceneTree
const JourneyAudio = preload("res://scripts/journey_audio.gd")
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	if value: print("PASS: ", label)
	else:
		failures += 1
		push_error(label)
func any_music(audio) -> bool:
	for player in audio._music:
		if player.playing: return true
	return false
func any_effect(audio) -> bool:
	for player in audio._effects:
		if player.playing: return true
	return false
func run() -> void:
	var original_master := AudioServer.is_bus_mute(0)
	var audio := JourneyAudio.new()
	root.add_child(audio)
	check(not audio.snapshot().unlocked and not any_music(audio), "Fresh application does not autoplay music")
	audio.set_context("mission")
	check(not any_music(audio) and not audio.cue("confirm"), "Context and cues cannot bypass first user gesture")
	check(not audio.set_context("untrusted-path.ogg") and audio.snapshot().context == "mission", "Unknown context cannot load arbitrary audio")
	audio.on_user_gesture()
	check(audio.snapshot().unlocked and audio.snapshot().soundtrack == "supplied" and audio.snapshot().active_track == "floating" and any_music(audio), "First gesture enables the team-supplied mission recording")
	check(audio._music[audio._active_slot].stream is AudioStreamMP3 and audio._music[audio._active_slot].stream.loop, "Supplied recording plays directly as a looping MP3")
	check(is_equal_approx(float(audio._music[audio._active_slot].get_meta("track_gain")), 0.34673685), "The louder supplied recording receives its measured relative trim")
	var original_slot: int = audio._active_slot
	var stream: AudioStream = audio._music[original_slot].stream
	audio.set_context("mission")
	audio.on_user_gesture()
	check(audio._active_slot == original_slot and audio._music[original_slot].stream == stream, "Repeated context and gesture reuse the playing stream")
	audio._process(0.5)
	var normal_db: float = audio._music[original_slot].volume_db
	audio.set_paused(true)
	check(audio._music[original_slot].volume_db < normal_db - 8.0, "Reading and pause lower music without hiding feedback cues")
	check(audio.cue("open"), "Paused learning panels can play a short UI cue")
	audio.set_focused(false)
	check(not any_effect(audio) and not audio.cue("warning"), "Focus loss stops effects and rejects background warning cues")
	check(audio._music[original_slot].stream_paused, "Focus loss pauses the ambient stream")
	audio.set_focused(true)
	check(not audio._music[original_slot].stream_paused, "Returning focus resumes existing music")
	audio.set_paused(false)
	audio.set_music_enabled(false)
	check(not any_music(audio) and audio.cue("confirm"), "Music mute is independent of sound effects")
	audio.set_effects_enabled(false)
	check(not any_effect(audio) and not audio.cue("confirm"), "Effects mute immediately stops current and future effects")
	audio.set_music_enabled(true)
	check(any_music(audio) and not audio.cue("confirm"), "Re-enabling music does not re-enable effects")
	audio.set_effects_enabled(true)
	var count: int = audio.snapshot().accepted_cues
	check(audio.cue("typewriter") and not audio.cue("typewriter") and audio.snapshot().accepted_cues == count + 1, "Typewriter accepts only one cue within its 125 ms limit")
	# Audio rate limiting follows real monotonic time, independent of game pace.
	var deadline := Time.get_ticks_msec() + 140
	while Time.get_ticks_msec() < deadline: await process_frame
	check(audio.cue("typewriter"), "Typewriter can resume after the rate-limit interval")
	count = audio.snapshot().accepted_cues
	check(not audio.cue("alarm-invalid") and audio.snapshot().accepted_cues == count, "Unknown cues produce no fabricated or external sound")
	audio.set_music_volume(4.0)
	audio.set_effects_volume(-3.0)
	check(audio.music_volume == 1.0 and audio.effects_volume == 0.0 and not audio.cue("confirm"), "Independent level controls clamp to a safe normalized range")
	audio.set_music_volume(NAN)
	audio.set_effects_volume(INF)
	check(audio.music_volume == 1.0 and audio.effects_volume == 0.0, "Non-finite settings cannot poison audio levels")
	audio.set_effects_volume(0.5)
	audio.set_context("preparation")
	check(audio.snapshot().active_track == "minyo", "Story and preparation choose Minyo San Kyoku")
	audio.set_context("debrief")
	check(audio.snapshot().active_track == "floating", "Mission and debrief choose Floating Lanterns")
	check(audio.set_soundtrack("original") and audio.snapshot().active_track == "reflection", "Original ambient score remains available through one shared setting")
	audio.set_context("mission")
	check(audio.snapshot().active_track == "surface", "Original soundtrack selection applies across contexts")
	check(not audio.set_soundtrack("untrusted-path.mp3") and audio.snapshot().soundtrack == "original", "Soundtrack selector rejects arbitrary asset paths")
	check(audio.set_soundtrack("supplied") and audio.snapshot().active_track == "floating", "Switching back restores the supplied soundtrack without changing the mission")
	audio.set_context("silent")
	audio._process(2.0)
	check(not any_music(audio) and audio.snapshot().active_track.is_empty(), "Leaving the journey can fade to silence")
	var snapshot: Dictionary = audio.snapshot()
	snapshot.music_enabled = false
	check(audio.music_enabled, "Returned settings snapshot cannot mutate the live manager")
	check(AudioServer.is_bus_mute(0) == original_master, "Journey settings never mutate the legacy Master bus")
	for kind in audio.EFFECT_KINDS:
		var cue: AudioStreamWAV = audio._make_effect(kind)
		check(cue.mix_rate == 22050 and cue.format == AudioStreamWAV.FORMAT_16_BITS and cue.data.size() > 0 and cue.get_length() <= 0.6, "Original cue is bounded, offline and short: " + kind)
	stream = null
	audio.shutdown()
	audio.set_context("mission")
	audio.set_focused(true)
	check(not any_music(audio) and not audio.cue("confirm"), "Focus or context callbacks cannot restart audio during shutdown")
	# The audio mix thread releases stopped playback on its real-time tick.
	deadline = Time.get_ticks_msec() + 80
	while Time.get_ticks_msec() < deadline: await process_frame
	audio.queue_free()
	await process_frame
	await process_frame
	print("JOURNEY AUDIO FAILURES: ", failures)
	quit(1 if failures else 0)
