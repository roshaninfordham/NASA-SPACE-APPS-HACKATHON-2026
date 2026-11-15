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
func any_alert(audio) -> bool:
	for player in audio._effects:
		if player.playing and audio.ALERT_INTERVAL_MS.has(str(player.get_meta("cue_kind", ""))): return true
	return false
func feedback_players(audio) -> Array:
	var players: Array = []
	for player in audio._effects:
		if player.playing and str(player.get_meta("cue_kind", "")) in audio.FEEDBACK_KINDS: players.append(player)
	return players
func tone_frequency(stream: AudioStreamWAV, start_seconds: float, end_seconds: float) -> float:
	var crossings := 0
	var first := int(start_seconds * stream.mix_rate)
	var last := int(end_seconds * stream.mix_rate)
	for sample_index in range(first + 1, last):
		if stream.data.decode_s16((sample_index - 1) * 2) <= 0 and stream.data.decode_s16(sample_index * 2) > 0: crossings += 1
	return float(crossings) / (end_seconds - start_seconds)
func run() -> void:
	var original_master := AudioServer.is_bus_mute(0)
	var audio := JourneyAudio.new()
	root.add_child(audio)
	check(not audio.snapshot().unlocked and not any_music(audio), "Fresh application does not autoplay music")
	audio.set_context("mission")
	check(not any_music(audio) and not audio.cue("confirm") and not audio.cue("pace_up"), "Context and cues cannot bypass first user gesture")
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
	check(not any_effect(audio) and not audio.cue("warning") and not audio.cue("section"), "Focus loss stops effects and rejects background warning and progress cues")
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
	check(audio.cue("pace_up") and feedback_players(audio).size() == 1, "A faster command has one short directional feedback voice")
	check(not audio.cue("pace_down"), "Rapid slider events share a real-time cooldown across both directions")
	audio._last_pace_ms = Time.get_ticks_msec() - 130
	check(audio.cue("pace_down") and feedback_players(audio).size() == 1 and feedback_players(audio)[0].get_meta("cue_kind") == "pace_down", "Slower feedback replaces the earlier faster voice instead of stacking")
	var pace_gain: float = feedback_players(audio)[0].get_meta("cue_gain")
	check(audio.cue("section") and feedback_players(audio).size() == 1 and not audio.cue("section"), "Completing a panel section gives one bounded, non-stacking progress chime")
	audio.set_paused(true)
	check(feedback_players(audio).is_empty() and not audio.cue("section") and not audio.cue("pace_up"), "Pausing stops progress sounds and rejects further mission feedback")
	audio.set_paused(false)
	audio.set_reduced_motion(true)
	audio._last_pace_ms = Time.get_ticks_msec() - 130
	check(not audio.cue("pace_up"), "Calmer presentation spaces optional feedback farther apart")
	audio._last_pace_ms = Time.get_ticks_msec() - 260
	check(audio.cue("pace_up") and float(feedback_players(audio)[0].get_meta("cue_gain")) < pace_gain, "Calmer presentation keeps directional feedback at a softer level")
	check(audio.cue("countdown") and any_alert(audio), "Mission countdown uses the original soft alert after a user gesture")
	check(feedback_players(audio).is_empty() and not audio.cue("pace_down") and not audio.cue("section"), "Warnings take priority over optional pace and progress chimes")
	audio.set_reduced_motion(false)
	check(not audio.cue("countdown") and not audio.cue("warning") and not audio.cue("urgent"), "Alert kinds share a cooldown so rapid frames cannot layer warnings")
	audio._last_alert_ms = Time.get_ticks_msec() - 1100
	check(not audio.cue("warning") and audio.cue("urgent"), "An urgent alert can escalate after one real second without waiting five seconds")
	audio.set_paused(true)
	check(not any_alert(audio) and not audio.cue("urgent") and audio.cue("open"), "Pause immediately stops alerts while keeping intentional learning-panel feedback")
	audio.set_paused(false)
	audio._last_alert_ms = Time.get_ticks_msec() - 2600
	check(audio.cue("warning"), "A double warning can resume after its real-time cooldown")
	audio.set_context("debrief")
	check(not any_alert(audio) and not audio.cue("urgent") and not audio.cue("section"), "Finishing the mission cancels alerts and rejects mission cues on the result page")
	audio.set_context("mission")
	check(audio.cue("countdown"), "A new mission starts with a fresh alert cooldown")
	audio.set_effects_enabled(false)
	check(not any_alert(audio) and not audio.cue("urgent") and not audio.cue("pace_up"), "Effects mute cancels warning and feedback families as well as ordinary UI cues")
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
	for kind in audio.ALERT_INTERVAL_MS:
		var alert: AudioStreamWAV = audio._make_effect(kind)
		var peak := 0
		for offset in range(0, alert.data.size(), 2): peak = maxi(peak, absi(alert.data.decode_s16(offset)))
		check(peak > 0 and peak < 16384 and alert.data.decode_s16(0) == 0 and alert.data.decode_s16(alert.data.size() - 2) == 0, "Alert waveform has headroom and silent endpoints: " + kind)
		var gap_start := int(0.13 * alert.mix_rate)
		var gap_end := int(0.17 * alert.mix_rate)
		var silent_gap := true
		for sample_index in range(gap_start, gap_end):
			if alert.data.decode_s16(sample_index * 2) != 0: silent_gap = false
		check(silent_gap, "Alert has a genuine silence gap rather than a continuous alarm: " + kind)
	check(audio._make_effect("countdown").get_length() < audio._make_effect("warning").get_length() and audio._make_effect("warning").get_length() < audio._make_effect("urgent").get_length(), "Single, double and triple beep rhythms distinguish increasing urgency")
	var faster: AudioStreamWAV = audio._make_effect("pace_up")
	var slower: AudioStreamWAV = audio._make_effect("pace_down")
	check(tone_frequency(faster, 0.095, 0.145) > tone_frequency(faster, 0.015, 0.065) + 80.0, "Faster feedback rises in measured pitch")
	check(tone_frequency(slower, 0.095, 0.145) < tone_frequency(slower, 0.015, 0.065) - 80.0, "Slower feedback falls in measured pitch")
	var resolved: AudioStreamWAV = audio._make_effect("success")
	check(absf(tone_frequency(resolved, 0.03, 0.12) - tone_frequency(resolved, 0.465, 0.555)) < 20.0, "Success returns to its starting pitch for a calm resolution")
	for kind in ["open", "close", "pace_up", "pace_down", "section", "success"]:
		var soft: AudioStreamWAV = audio._make_effect(kind)
		var peak := 0
		for offset in range(0, soft.data.size(), 2): peak = maxi(peak, absi(soft.data.decode_s16(offset)))
		check(soft.data.decode_s16(0) == 0 and soft.data.decode_s16(soft.data.size() - 2) == 0 and peak < 16384, "Pleasant transition has silent endpoints and waveform headroom: " + kind)
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
