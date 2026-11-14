extends SceneTree
var failures := 0
func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1
	else: print("PASS: ", message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	# A real desktop viewport, rather than the headless driver’s 64×64 placeholder.
	root.size = Vector2i(1280, 720)
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var bindings := InputMap.action_get_events("interact").size()
	game.setup_inputs()
	check(InputMap.action_get_events("interact").size() == bindings, "Reopening a mission does not duplicate input bindings")
	# Keep automated learner activity out of a real local player's profile.
	game.learning = load("res://scripts/learning.gd").new("user://academy-ui-test-%d.json" % OS.get_process_id())
	game.learning.reset()
	game.show_academy()
	await process_frame
	check(is_instance_valid(game.academy), "Academy opens from the title screen")
	game.academy.start_lesson(0)
	game.academy.show_hint()
	game.academy.submit(1)
	check(game.learning.skills.energy.attempts == 0, "Academy hint use does not claim independent learning evidence")
	game.academy.close()
	await process_frame
	game.begin_eva()
	await process_frame
	await process_frame
	check(game.player.enabled, "Mission launch enables first-person controls")
	check(Rect2(Vector2.ZERO, root.get_visible_rect().size).encloses(game.metrics.get_global_rect()), "Power and suit HUD is inside the viewport")
	game.player.global_position = Vector3(16, 0.3, -5.7)
	game._process(0.1)
	check(game.nearby == "array", "Approaching equipment enables its interaction")
	game.touch_interact = true
	for i in range(60): game._process(0.25)
	game.touch_interact = false
	check(game.mission.inspection >= 1, "Holding the interaction completes the physical array inspection")
	game.interact()
	check(game.mission.cleaning, "Inspected array enables the cleaning switch")
	game.player.global_position = Vector3(1, 0.3, -3)
	game._process(0.1)
	game.interact()
	check(game.mission.conserving, "Power kiosk preserves essential power")
	game.player.global_position = Vector3(-14, 0.3, -7)
	game._process(0.1)
	check(game.mission.shelter, "Physically entering the refuge applies passive shielding")
	game.mission.cleaning = false
	game.toggle_pause()
	var before: float = game.mission.time
	game._process(0.25)
	check(game.mission.time == before, "Pause stops mission resource consumption")
	game.resume()
	for i in range(1100): game._process(0.25)
	check(game.mission.status == "success", "Playable interactions can complete the mission safely")
	check(game.ended and game.finish_panel.visible, "Completed mission presents a debrief")
	game.show_academy()
	await process_frame
	game.academy.start_lesson(0)
	game.academy.submit(1)
	check(game.learning.skills.energy.attempts == 1, "Debrief leads to an independent practice answer")
	game.academy.close()
	await process_frame
	check(not game.player.enabled, "Closing academy after debrief does not restart a finished mission")
	game.learning.reset()
	await create_timer(0.5).timeout
	game.action_audio.stop()
	game.player.footsteps.stop()
	game.queue_free()
	await create_timer(0.15).timeout
	quit(1 if failures else 0)
