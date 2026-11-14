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
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.begin()
	check(game.player.enabled, "Mission launch enables first-person controls")
	check(game.metrics.get_parent().global_position.x > 900, "Power and suit HUD is inside the viewport")
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
	await create_timer(0.5).timeout
	game.action_audio.stop()
	game.player.footsteps.stop()
	game.queue_free()
	await create_timer(0.15).timeout
	quit(1 if failures else 0)
