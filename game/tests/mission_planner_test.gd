extends SceneTree
const Planner = preload("res://scripts/mission_planner.gd")
const Adviser = preload("res://scripts/mission_adviser.gd")
const Mission = preload("res://scripts/mission.gd")
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if ok: print("PASS: ", label)
	else:
		push_error(label)
		failures += 1
func frames(count: int = 8) -> void:
	for i in range(count): await process_frame
func key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event)
	await frames()
func activate(button: Button) -> void:
	button.grab_focus()
	await frames()
	await key(KEY_ENTER)
func click(button: Button) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = button.get_global_rect().get_center()
		event.pressed = pressed
		root.push_input(event)
	await frames()
func within(control: Control) -> bool:
	return Rect2(Vector2.ZERO, root.get_visible_rect().size).grow(0.5).encloses(control.get_global_rect())
func target(control: Control, label: String) -> void:
	var physical: Vector2 = control.get_global_rect().size * float(root.size.x) / root.get_visible_rect().size.x
	check(within(control), label + " within viewport")
	check(physical.x >= 43.9 and physical.y >= 43.9, label + " at least44px in both dimensions")
func run() -> void:
	var mission := Mission.new()
	mission.conserving = true
	mission.shelter = true
	var report: Dictionary = Adviser.analyze(mission)
	var saved := report.duplicate(true)
	for window_size in [Vector2i(1280,720),Vector2i(960,540),Vector2i(390,844),Vector2i(844,390)]:
		root.size = window_size
		await frames()
		var planner := Planner.new()
		planner.report = report
		planner.allow_apply = false
		var accepted := [0]
		planner.plan_selected.connect(func(_conserving, _cleaning): accepted[0] += 1)
		root.add_child(planner)
		await frames(16)
		var label := str(window_size)
		target(planner.back_button, "Back " + label)
		target(planner.apply_button, "Apply " + label)
		check(within(planner._outcome), "Selected battery/work/duration stays visible " + label)
		check(planner.apply_button.disabled, "Preview cannot apply switches " + label)
		await click(planner.apply_button)
		planner.apply_selected()
		check(accepted[0] == 0 and is_instance_valid(planner), "Click and direct apply cannot bypass preview " + label)
		check(planner.option_buttons.size() == 4, "Four independent policies shown " + label)
		check(bool(report.options[planner.selected].current), "Current policy starts selected " + label)
		check(planner.chart.capacity == Mission.CAPACITY, "Chart uses actual habitat capacity " + label)
		check(planner.chart.starting_energy == mission.energy, "Chart starting line matches actual battery " + label)
		for index in range(planner.option_buttons.size()):
			await activate(planner.option_buttons[index])
			target(planner.option_buttons[index], "Plan%d %s" % [index, label])
			check(planner._scroll.get_global_rect().grow(1.5).encloses(planner.option_buttons[index].get_global_rect()), "Keyboard scroll reveals selected plan " + label)
			check(planner.selected == index and planner.chart.selected == index, "Chart and selected details follow keyboard choice " + label)
		await activate(planner.details_button)
		check(planner._detail.visible and "Cumulative dose" in planner._detail.text and "not a real Mars forecast" in planner._detail.text, "Math details disclose units and forecast scope " + label)
		await activate(planner.details_button)
		check(not planner._detail.visible, "Math details collapse " + label)
		check("no field work in this preview" in planner._outcome.text, "Sheltered preview does not invent research gain " + label)
		check(report == saved, "Preview never modifies shared adviser report " + label)
		await key(KEY_ESCAPE)
		check(not is_instance_valid(planner), "Escape closes preview " + label)
		planner = Planner.new()
		planner.report = report
		planner.allow_apply = true
		var choice: Array = []
		var closed_count := [0]
		planner.plan_selected.connect(func(conserving, cleaning): choice.append([conserving, cleaning]))
		planner.closed.connect(func(): closed_count[0] += 1)
		root.add_child(planner)
		await frames(16)
		await activate(planner.option_buttons[3])
		await activate(planner.apply_button)
		check(choice == [[bool(report.options[3].conserving), bool(report.options[3].cleaning)]], "Apply emits only selected switch intent " + label)
		check(closed_count[0] == 1 and not is_instance_valid(planner), "Applying closes once " + label)
	check(mission.time == 0.0 and mission.energy == 8.0 and mission.conserving and not mission.cleaning, "Planner did not mutate mission")
	print("MISSION PLANNER FAILURES: ", failures)
	quit(1 if failures else 0)
