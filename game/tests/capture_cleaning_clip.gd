extends SceneTree
## Whole production viewport, ordinary runtime clock. Only the initial mission
## state is prepared; one ordinary HUD slider change demonstrates faster work.
## No camera, character-joint or animation assignments follow.
var output := "/tmp/komaku-cleaning-clip"
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if DisplayServer.get_name() == "headless" or OS.get_environment("XDG_DATA_HOME").is_empty():
		push_error("Native display and isolated user data are required")
		quit(1)
		return
	var arguments := OS.get_cmdline_user_args()
	for index in range(arguments.size()-1):
		if arguments[index] == "--output": output = arguments[index+1]
	DirAccess.make_dir_recursive_absolute(output.path_join("frames"))
	root.size = Vector2i(960,540)
	var game = load("res://main.tscn").instantiate()
	game.online_sources_enabled = false
	root.add_child(game)
	for index in range(3): await process_frame
	game.set_process(false)
	game.focused = true
	game.start_mission()
	game.launch_mission()
	game._process(0.0)
	game.model.advance(18.0)
	game.set_cleaning_speed(1.25)
	game.model.advance(24.0)
	game.hud.speed_slider.value = 1.0
	AudioServer.set_bus_mute(0,true)
	game.hud.refresh(game.model.snapshot())
	game._sync_world(game.model.snapshot())
	# Exclude one-time shader/font startup from the actual six-second recording.
	# Normal child-node animation can render during warm-up; mission time is held.
	for index in range(8):
		await process_frame
		await RenderingServer.frame_post_draw
	var initial: Dictionary = game.model.snapshot()
	game.set_process(true)
	var started := Time.get_ticks_usec()
	var next_frame := started
	var frames: Array[Dictionary] = []
	var control_actions: Array[Dictionary] = []
	while Time.get_ticks_usec()-started < 6000000:
		await process_frame
		if control_actions.is_empty() and Time.get_ticks_usec()-started >= 2000000:
			# Use the real slider signal and controller; never assign model work or joints.
			game.hud.speed_slider.value = 1.75
			control_actions.append({"action":"HUD cleaning slider from1.00x to1.75x", "wall_seconds":float(Time.get_ticks_usec()-started)/1000000.0, "active_play_seconds":game.model.snapshot().elapsed_seconds, "selected_multiplier":game.model.snapshot().selected_multiplier})
		if Time.get_ticks_usec() < next_frame: continue
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		var file := "frames/%03d.png" % frames.size()
		if root.get_texture().get_image().save_png(output.path_join(file)) != OK:
			push_error("Could not save an actual native animation frame")
			quit(1)
			return
		var state: Dictionary = game.model.snapshot()
		frames.append({"file":file,"wall_seconds":float(now-started)/1000000.0,"active_play_seconds":state.elapsed_seconds,"simulated_seconds":state.sim_elapsed_seconds,"cleaned_work":state.cleaned_work,"clean_fraction":state.clean_fraction,"selected_multiplier":state.selected_multiplier,"fatigue":state.fatigue})
		next_frame = now+125000
	var final: Dictionary = game.model.snapshot()
	var elapsed := float(Time.get_ticks_usec()-started)/1000000.0
	var record := {"kind":"actual-native-cleaning-animation","method":"Actual main.tscn at960x540. Explicit START MISSION; initial fixture:18active seconds at1.0x plus24at1.25x with actual model fatigue (1.9cleared sections), then the normal HUD slider selects1x without advancing the model, followed by8render warm-up frames with mission time held. Thereafter the production game_process clock and normal character/panel logic run for approximately6wall-clock seconds. After2wallseconds the actual HUD slider selects1.75x to show the immediate speed change. No camera or joint assignments or synthetic animation frames; the normal production20x simulation clock is unchanged during recording. Audio is muted for this silent GIF and online sources are disabled.","source_viewport":[960,540],"target_frames_per_second":8,"wall_seconds":elapsed,"initial_snapshot":initial,"final_snapshot":final,"control_actions":control_actions,"frames":frames}
	var file := FileAccess.open(output.path_join("clip-provenance.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(record,"  ")+"\n")
	file.close()
	# Software-renderer load changes the number of real frames. Require enough
	# samples to inspect motion, not an invented playback frame-rate guarantee.
	var valid: bool = frames.size() >= 12 and elapsed >= 5.5 and elapsed < 15.0 and final.elapsed_seconds > initial.elapsed_seconds and final.cleaned_work > initial.cleaned_work and final.cleaning and control_actions.size() == 1 and initial.selected_multiplier == 1.0 and final.selected_multiplier == 1.75
	print("CLEANING_CLIP frames=",frames.size()," wall_seconds=",elapsed," active_delta=",float(final.elapsed_seconds)-float(initial.elapsed_seconds)," clean_delta=",float(final.cleaned_work)-float(initial.cleaned_work))
	game.queue_free()
	await process_frame
	quit(0 if valid else 1)
