extends SceneTree
var failures := 0
func check(value: bool, message: String) -> void:
	if value: print("PASS: ", message)
	else:
		push_error(message)
		failures += 1
func frames(count: int = 8) -> void:
	for index in range(count): await process_frame
func key(code: Key) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.keycode = code
		event.pressed = down
		root.push_input(event)
	await frames()
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for viewport_size in [Vector2i(1280,720),Vector2i(390,844),Vector2i(844,390)]:
		root.size = viewport_size
		var game = load("res://main.tscn").instantiate()
		root.add_child(game)
		current_scene = game
		await frames()
		game.show_planner()
		check(not is_instance_valid(game.exhibit), "Planner cannot change a mission before launch")
		game.begin()
		await key(KEY_P)
		check(is_instance_valid(game.exhibit), "P opens native planner " + str(viewport_size))
		if not is_instance_valid(game.exhibit):
			game.queue_free()
			await frames()
			continue
		var before: Dictionary = game.mission.summary().duplicate(true)
		game._process(5.0)
		await frames()
		check(game.paused and not game.player.enabled and before == game.mission.summary(), "Preview pauses exact mission state")
		await key(KEY_ESCAPE)
		check(not game.paused and game.player.enabled and not root.disable_3d, "Escape resumes walking and 3D world")
		game.toggle_pause()
		await frames()
		var button: Button = game.finish_panel.find_child("Tertiary", true, false)
		check(Rect2(Vector2.ZERO,root.get_visible_rect().size).encloses(button.get_global_rect()), "Planner pause action fits " + str(viewport_size))
		button.grab_focus()
		await key(KEY_ENTER)
		check(is_instance_valid(game.exhibit), "Pause keyboard action opens planner")
		var planner = game.exhibit
		if planner:
			check(planner.allow_apply, "Active mission permits explicit plan application")
			planner.select_option(3)
			planner.apply_selected()
			await frames()
			check(game.mission.conserving and game.mission.cleaning, "Chosen cleaner/conservation intent reaches actual mission")
			check(game.paused and is_instance_valid(game.finish_panel), "Apply restores previous pause menu")
			check(game.last_radio.begins_with("Your plan:"), "Applied choice is recorded in mission radio/history")
			game.finish_panel.find_child("Primary",true,false).grab_focus()
			await key(KEY_ENTER)
			check(not game.paused and game.player.enabled, "Restored pause menu resumes after applying plan")
		game.queue_free()
		await frames()
	print("PLANNER INTEGRATION FAILURES: ",failures)
	quit(1 if failures else 0)
