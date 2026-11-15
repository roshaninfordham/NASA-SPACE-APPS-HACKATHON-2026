extends SceneTree
const Rescue = preload("res://scripts/companion_rescue.gd")
const Mission = preload("res://scripts/mission.gd")
var failures := 0
func check(ok: bool, label: String) -> void:
	if ok: print("PASS: ",label)
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
func _initialize() -> void: call_deferred("run")
func model_contract() -> void:
	var route := Rescue.new()
	route.advance(1)
	check(route.position == Rescue.START and not route.protected(), "Waiting crewmate does not move or gain shelter")
	check(route.request_return() and not route.protected(), "Command starts travel without instant shielding")
	var bounded := true
	var pane_clear := true
	var cycle_valid := true
	var states: Array[String] = []
	for i in range(180):
		var previous: Vector3 = route.position
		var before: String = route.phase
		route.advance(Mission.STEP_HOURS)
		bounded = bounded and previous.distance_to(route.position) <= Rescue.WALK_METRES_PER_HOUR * Mission.STEP_HOURS + 0.00001
		if previous.z > -9.8 and route.position.z <= -9.8: pane_clear = route.position.x >= -8.25 and route.position.x <= -6.05
		if route.phase == "cycling": cycle_valid = cycle_valid and route.position == Rescue.ROUTE[-1] and not route.protected()
		if not states.has(route.phase): states.append(route.phase)
		var unchanged: Vector3 = route.position
		check(not route.request_return() and route.position == unchanged, "Repeated command cannot reset route " + str(i)) if i in [2,40,90] else null
		if route.protected(): break
	check(bounded, "Every movement step obeys authored speed, with no teleport")
	check(pane_clear, "Route crosses the left airlock opening, never front glazing")
	check(cycle_valid and states.has("cycling") and states.has("entering"), "Airlock cycle precedes inner-door walk")
	check(route.protected() and route.position == Rescue.INDOOR_RECEIVER and route.cycle_hours == Rescue.AIRLOCK_HOURS, "Shielding begins only at indoor receiver after complete cycle")
	var sheltered_position: Vector3 = route.position
	check(not route.request_return(), "Rescued crew cannot be recalled outside")
	route.advance(10)
	check(route.position == sheltered_position and route.protected(), "Later updates preserve protected arrival")
func run() -> void:
	model_contract()
	for dimensions in [Vector2i(1280,720),Vector2i(960,540),Vector2i(390,844),Vector2i(844,390)]:
		root.size = dimensions
		var game = load("res://legacy_mission.tscn").instantiate()
		root.add_child(game)
		current_scene = game
		await frames(12)
		game.set_process(false)
		var ui = game.interface_root
		await click(ui.get_node("%Begin"))
		game.player.set_physics_process(false)
		check(game.operator_mode and game.world.is_window_presentation() and game.player.operator_area, "Default Start is indoor operator mode " + str(dimensions))
		check(game.player.position.z < -11 and game.player.camera.fov == 52, "First playable view stays inside at the window")
		check("MIRA" in ui._suit_gauge.title and "Mira exposure" in game.metrics.text, "Suit and dose explicitly belong to Mira")
		check("Guide Mira" in game.objective.text, "Launch gives a coherent rescue objective")
		game.player.position.x = 2
		game._process(0.25)
		check(not game.mission.shelter and game.mission.suit_energy < 0.9, "Operator indoor position never shields or refills exposed Mira")
		await key(KEY_TAB)
		var before: Dictionary = game.mission.summary().duplicate(true)
		var position_before: Vector3 = game.rescue.position
		game._process(0.25)
		check(game.mission.summary() == before and game.rescue.position == position_before, "Paused controls freeze both mission and companion")
		await click(ui.get_node("%FindShelter"))
		check(game.rescue.phase == "walking" and game.rescue.position == position_before and not game.mission.shelter, "Guide Mira click acknowledges travel without moving or shielding instantly")
		game._process(0.25)
		check(game.rescue.position != position_before and not game.mission.shelter, "Next simulation step moves the exposed companion")
		game.show_planner()
		await frames()
		check(is_instance_valid(game.exhibit) and game.exhibit.report.suit_subject == "Mira" and "does not predict travel" in game.exhibit.report.safety_note, "Planner explicitly freezes Mira protection and discloses no travel prediction")
		before = game.mission.summary().duplicate(true)
		position_before = game.rescue.position
		game._process(0.25)
		check(game.mission.summary() == before and game.rescue.position == position_before, "Planner pauses travel as well as battery and exposure")
		await key(KEY_ESCAPE)
		await key(KEY_TAB)
		await click(ui.get_node("%Details"))
		position_before = game.rescue.position
		game._process(0.25)
		check(game.rescue.position == position_before and game.paused, "Details freezes the return journey")
		await key(KEY_ESCAPE)
		var suit_before: float = game.mission.suit_energy
		for step in range(100):
			game._process(0.25)
			if game.rescue.protected(): break
		check(game.rescue.protected() and game.mission.shelter and game.mission.suit_energy < suit_before, "Mira arrives after travel, cycle and suit consumption")
		check(game.world.get_node("CompanionAnchor").position == Rescue.INDOOR_RECEIVER, "Visible companion and protected model arrive at the same receiver")
		game.update_hud()
		check("Mira is safe" in game.objective.text and not game.ended, "Rescue completion leaves the separate base-recovery mission running")
		var sheltered_suit: float = game.mission.suit_energy
		game._process(0.25)
		check(game.mission.suit_energy == sheltered_suit, "Existing model stops suit draw only after protected arrival")
		game.apply_primary_action("shelter")
		check(game.rescue.protected() and game.rescue.position == Rescue.INDOOR_RECEIVER, "Repeat rescue intent never restarts or unshelters Mira")
		game.mission.conserving = true
		game.mission.cleaning = false
		for step in range(1100):
			if game.ended: break
			game._process(0.25)
		check(game.ended and game.mission.status == "success", "Indoor rescue and unchanged power equations can complete the full 12-hour scenario")
		var debrief = game.finish_panel
		await key(KEY_F1)
		game.resume()
		check(game.finish_panel == debrief and is_instance_valid(debrief) and not game.player.enabled, "F1 and direct resume cannot replace terminal debrief or revive ended mission")
		game.queue_free()
		await frames()
	var reset_game = load("res://legacy_mission.tscn").instantiate()
	root.add_child(reset_game)
	await frames()
	check(reset_game.rescue.phase == "waiting" and reset_game.mission.time == 0 and not reset_game.mission.shelter, "Fresh scene resets companion and all mission protection")
	reset_game.art = reset_game.art.duplicate()
	reset_game.art.start_in_window_presentation = false
	reset_game.begin()
	check(not reset_game.operator_mode and not reset_game.world.is_window_presentation() and not reset_game.player.operator_area, "Design flag false restores coherent outdoor EVA default")
	reset_game.queue_free()
	await frames()
	var tour_game = load("res://legacy_mission.tscn").instantiate()
	root.add_child(tour_game)
	current_scene = tour_game
	await frames()
	tour_game.set_process(false)
	tour_game.explore_habitat()
	tour_game.mission.cleaning = true
	tour_game.mission.conserving = true
	tour_game.toggle_pause()
	await frames()
	check(tour_game.finish_panel.find_child("Secondary",true,false).text == "START RESCUE MISSION" and tour_game.finish_panel.find_child("Tertiary",true,false).text == "RETURN TO TITLE", "Room tour has visible paths to timed rescue and title")
	tour_game.finish_panel.find_child("Secondary",true,false).grab_focus()
	await key(KEY_ENTER)
	check(tour_game.running and not tour_game.exploring and tour_game.operator_mode and not tour_game.paused, "Tour Start rescue button launches the real indoor mission")
	check(tour_game.mission.time == 0 and not tour_game.mission.cleaning and not tour_game.mission.conserving and tour_game.rescue.phase == "waiting", "Starting rescue clears tour practice switches and resets clocks")
	tour_game.queue_free()
	await frames()
	print("OPERATOR RESCUE FAILURES: ", failures)
	quit(1 if failures else 0)
