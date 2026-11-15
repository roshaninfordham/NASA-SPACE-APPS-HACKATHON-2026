extends SceneTree
## Exercise menu/input routes and responsive overlays against the real assembled game.
var failures := 0
func check(ok: bool, message: String) -> void:
	if ok: print("PASS: ", message)
	else:
		push_error(message)
		failures += 1
func frames(count: int = 8) -> void:
	for index in range(count): await process_frame
func key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event)
	await frames()
func activate(control: Button) -> void:
	control.grab_focus()
	await frames(2)
	await key(KEY_ENTER)
func within(control: Control) -> bool:
	return Rect2(Vector2.ZERO, root.get_visible_rect().size).encloses(control.get_global_rect())
func touch_size(control: Control, label: String) -> void:
	# Ancestor transforms are included; use a physical-pixel touch target.
	var physical_height: float = control.get_global_rect().size.y * root.size.x / root.get_visible_rect().size.x
	check(physical_height >= 43.9, label + " touch target >=44 physical px (actual %.1f)" % physical_height)
func reachable(control: Control, label: String) -> void:
	control.grab_focus()
	await frames()
	check(within(control), label + " can be focused inside viewport")
	touch_size(control, label)
	var ancestor := control.get_parent()
	while ancestor:
		if ancestor is ScrollContainer:
			check(ancestor.get_global_rect().grow(root.get_visible_rect().size.x / root.size.x).encloses(control.get_global_rect()), label + " scrolls fully into its container (1px rounding tolerance)")
		ancestor = ancestor.get_parent()
func snapshot(game) -> Array:
	return [game.mission.time, game.mission.energy, game.mission.suit_energy, game.mission.dose]
func freeze_check(game, label: String) -> void:
	var before := snapshot(game)
	game._process(1.0)
	await frames()
	check(snapshot(game) == before, label + " freezes mission clock, batteries and dose")
	check(not game.player.enabled and not game.touch_controls.visible, label + " blocks walking and touch controls")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for viewport_size in [Vector2i(1280,720), Vector2i(960,540), Vector2i(390,844), Vector2i(844,390)]:
		root.size = viewport_size
		var game = load("res://legacy_mission.tscn").instantiate()
		root.add_child(game)
		current_scene = game
		await frames(12)
		var label := str(viewport_size)
		var hud_root: Control = game.menu.get_parent()
		check(not hud_root._hero.get_global_rect().intersects(hud_root._menu_scroll.get_global_rect()), "Title wordmark and subtitle clear the menu " + label)
		await activate(hud_root.get_node("%More"))
		check(hud_root.get_node("%SuitLab").is_visible_in_tree(), "More reveals real learning entries " + label)
		var suit_button: Button = hud_root.get_node("%SuitLab")
		await reachable(suit_button, "Suit entry " + label)
		await activate(suit_button)
		check(is_instance_valid(game.exhibit), "Menu keyboard opens Suit Lab " + label)
		if not is_instance_valid(game.exhibit):
			game.queue_free()
			await frames()
			continue
		var lab = game.exhibit
		check(not game.menu.visible and not game.hud.visible, "Suit Lab owns visible interface " + label)
		check(root.disable_3d and not lab.stage.disable_3d, "Suit Lab disables hidden world but retains live stage " + label)
		await freeze_check(game, "Suit Lab " + label)
		for control in [lab.back_button, lab.view_selector, lab.theme_selector, lab.test_selector, lab.slider, lab.run_button]:
			await reachable(control, "Suit " + control.name + " " + label)
		game.show_updates()
		game.show_academy()
		check(not is_instance_valid(game.update_panel) and not is_instance_valid(game.academy), "Suit Lab prevents overlapping update/academy " + label)
		await key(KEY_ESCAPE)
		check(not is_instance_valid(game.exhibit) and game.menu.visible and not game.running, "Suit Escape returns to title " + label)
		check(not root.disable_3d, "Suit Escape restores world rendering " + label)
		var notes_button: Button = hud_root.get_node("%HabitatNotes")
		await reachable(notes_button, "Field notes entry " + label)
		await activate(notes_button)
		check(is_instance_valid(game.exhibit), "Menu keyboard opens field notes " + label)
		if is_instance_valid(game.exhibit):
			var notes = game.exhibit
			check(not root.disable_3d, "Field notes retain live habitat rendering " + label)
			check(within(notes._card) and within(notes._heading), "Initial field-note card and heading fit " + label)
			await freeze_check(game, "Field notes " + label)
			check(notes.points.size() == 4, "Four live habitat anchors available " + label)
			for index in range(notes.points.size()):
				await activate(notes._tabs.get_child(index))
				check(notes.selected == index, "Field note keyboard selection " + str(index) + " " + label)
				check(within(notes._card) and within(notes._heading), "Selected field-note card and heading fit " + str(index) + " " + label)
				var answer: Button = notes._answers.get_child(0)
				await reachable(answer, "Field note answer " + str(index) + " " + label)
				await activate(answer)
				check(notes._feedback.text != "Choose an answer to explore the science.", "Field note quiz gives explanation " + str(index) + " " + label)
			if viewport_size == Vector2i(1280,720):
				for resized in [Vector2i(390,844), Vector2i(844,390), viewport_size]:
					root.size = resized
					await frames(12)
					check(within(notes._card) and within(notes._heading) and within(notes._done), "Open field notes survive window resize " + str(resized))
			await reachable(notes._done, "Field note Back " + label)
			await activate(notes._done)
			check(not is_instance_valid(game.exhibit) and game.menu.visible, "Field note Back returns title " + label)
		game.explore_habitat()
		await frames()
		await key(KEY_I)
		check(is_instance_valid(game.exhibit), "Explore I opens architecture notes " + label)
		if is_instance_valid(game.exhibit):
			await freeze_check(game, "Explore notes " + label)
			await key(KEY_ESCAPE)
			check(not game.paused and game.player.enabled and game.hud.visible, "Notes Escape resumes explore " + label)
		game.toggle_pause()
		await frames()
		await activate(game.finish_panel.find_child("Secondary",true,false))
		check(game.operator_mode and not game.exploring and not game.paused, "Room tour pause starts a fresh rescue " + label)
		game.toggle_pause()
		await frames()
		var pause_panel = game.finish_panel
		await activate(pause_panel.find_child("Secondary",true,false))
		check(is_instance_valid(game.exhibit), "Pause action opens Suit Lab " + label)
		if is_instance_valid(game.exhibit):
			await activate(game.exhibit.back_button)
			check(game.paused and not game.player.enabled and is_instance_valid(game.finish_panel), "Suit Back restores pause dialog " + label)
			await activate(game.finish_panel.find_child("Primary",true,false))
			check(not game.paused and game.player.enabled, "Restored pause resumes " + label)
		game.queue_free()
		await frames()
	print("SPEC INTEGRATION FAILURES: ", failures)
	quit(1 if failures else 0)
