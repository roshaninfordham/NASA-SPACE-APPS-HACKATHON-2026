extends SceneTree
var failures := 0
func check(ok: bool, label: String) -> void:
	if ok: print("PASS: ", label)
	else:
		push_error(label)
		failures += 1
func frames(count := 8) -> void:
	for i in range(count): await process_frame
func key(code: Key) -> void:
	for down in [true,false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		root.push_input(event)
	await frames()
func click(button: Button) -> void:
	for down in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = button.get_global_rect().get_center() * Vector2(root.size) / root.get_visible_rect().size
		event.pressed = down
		root.push_input(event)
	await frames()
func target(button: Button, label: String) -> void:
	var physical: Vector2 = button.size * root.size.x / root.get_visible_rect().size.x
	check(Rect2(Vector2.ZERO, root.get_visible_rect().size).grow(1).encloses(button.get_global_rect()), label + " inside viewport")
	check(physical.x >= 44 and physical.y >= 44, label + " at least 44px")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for dimensions in [Vector2i(1280,720),Vector2i(960,540),Vector2i(390,844),Vector2i(844,390)]:
		root.size = dimensions
		var game = load("res://main.tscn").instantiate()
		root.add_child(game)
		current_scene = game
		await frames(16)
		var ui = game.interface_root
		var visible := 0
		for button in ui._buttons:
			if button.is_visible_in_tree(): visible += 1
		check(visible == 3, "Three primary title actions " + str(dimensions))
		for name in ["Begin", "Explore", "More"]: target(ui.get_node("%" + name), "Title " + name)
		await click(ui.get_node("%More"))
		check(ui.get_node("%SuitLab").is_visible_in_tree() and not ui.get_node("%Begin").is_visible_in_tree(), "More reveals preserved features")
		ui.get_node("%MoreBack").grab_focus()
		await key(KEY_ENTER)
		check(ui.get_node("%Begin").is_visible_in_tree(), "More Back returns to simple title")
		await click(ui.get_node("%More"))
		ui.get_node("%EVAMission").grab_focus()
		await key(KEY_ENTER)
		check(game.running and game.player.enabled and not game.paused, "More opens explicit outdoor EVA mission")
		check("Inspect array" in game.objective.text and "m" in game.objective.text, "First objective locates physical array")
		for name in ["PanelCleaning", "SavePower", "FindShelter"]: target(ui.get_node("%" + name), "Mission " + name)
		check(ui._base_gauge.title == "BASE" and ui._suit_gauge.title == "SUIT", "Battery identities are distinct")
		await key(KEY_TAB)
		var before: Dictionary = game.mission.summary().duplicate(true)
		game._process(0.25)
		await frames()
		check(game.control_mode and game.paused and not game.player.enabled and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Tab exposes usable cursor and pauses")
		check(before == game.mission.summary(), "Controls consume no time, energy or dose")
		await click(ui.get_node("%PanelCleaning"))
		check(root.gui_get_focus_owner() == null, "Returning to walking releases button focus so Space remains jump")
		check(game.mission.cleaning and not game.paused and not game.control_mode and game.player.enabled, "Actual mouse click toggles panels and resumes")
		await key(KEY_2)
		check(game.mission.conserving, "2 toggles saving power")
		await key(KEY_TAB)
		await click(ui.get_node("%SavePower"))
		check(not game.mission.conserving and not game.paused, "Save button toggles and resumes")
		await key(KEY_TAB)
		var position_before: Vector3 = game.player.global_position
		var shelter_before: bool = game.mission.shelter
		await click(ui.get_node("%FindShelter"))
		check(game.shelter_guidance and "refuge" in game.objective.text, "Find refuge gives route cue")
		check(game.player.global_position.distance_to(position_before) < 0.05 and game.mission.shelter == shelter_before, "Find refuge never teleports or grants shielding")
		await key(KEY_TAB)
		await key(KEY_ESCAPE)
		check(not game.control_mode and not game.paused and game.player.enabled, "Esc returns from controls to walking")
		await key(KEY_TAB)
		await click(ui.get_node("%Details"))
		check(ui._details_visible and ui._radio_card.is_visible_in_tree(), "Details opens an optional readable tray")
		check(Rect2(Vector2.ZERO, root.get_visible_rect().size).grow(1).encloses(ui._radio_card.get_global_rect()), "Details stays within screen")
		check(ui._radio_card.get_global_rect().encloses(game.clock.get_global_rect()), "Simulated clock is visible in Details")
		await key(KEY_ESCAPE)
		for resized in [Vector2i(390,844),Vector2i(844,390),dimensions]:
			root.size = resized
			await frames(16)
			check(Rect2(Vector2.ZERO, root.get_visible_rect().size).grow(1).encloses(ui._resource_card.get_global_rect()), "Live rotation keeps both gauges on screen " + str(resized))
		game.player.at_training_boundary = true
		game.update_hud()
		check("Training area edge" in game.prompt.text, "Boundary cue explains turn back without inventing a physical wall")
		game.player.at_training_boundary = false
		game.shelter_guidance = false
		game.mission.inspection = 1
		game.mission.time = 1
		game.update_hud()
		check("POWER CONTROL" in game.prompt.text, "Finished array directs to power control instead of stale array")
		game.mission.time = 3.3
		game.mission.inspection = 0
		game.shelter_guidance = false
		game.update_hud()
		check("refuge" in game.objective.text, "Particle warning outranks unfinished inspection")
		game.toggle_pause()
		var previous: bool = game.mission.cleaning
		game.apply_primary_action("cleaning")
		check(game.mission.cleaning == previous, "Ordinary pause blocks hidden control actions")
		game.resume()
		game.ended = true
		game.apply_primary_action("cleaning")
		check(game.mission.cleaning == previous, "Ended mission rejects control mutation")
		game.queue_free()
		await frames()
	print("CLEAN INTERFACE FAILURES: ", failures)
	quit(1 if failures else 0)
