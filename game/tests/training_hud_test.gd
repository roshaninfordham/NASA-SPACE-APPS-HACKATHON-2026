extends SceneTree
const Hud = preload("res://ui/training_hud.gd")
const Model = preload("res://scripts/pace_mission.gd")
const Style = preload("res://ui/journey_style.gd")
var failures := 0
var assertions := 0
func check(condition: bool, message: String) -> void:
	assertions += 1
	if condition: print("PASS: ",message)
	else:
		push_error(message)
		failures += 1
func frames() -> void:
	for index in range(5): await process_frame
func target(control: Control, description: String) -> void:
	check(control.is_visible_in_tree(),description+" is visible without opening another pane")
	check(Rect2(Vector2.ZERO,root.get_visible_rect().size).grow(1).encloses(control.get_global_rect()),description+" remains in viewport")
	check(control.size.x >= 48 and control.size.y >= 48,description+" has a48px target")
func text_fits(label: Label, description: String) -> void:
	if not label.is_visible_in_tree(): return
	var width := label.get_theme_font("font").get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,label.get_theme_font_size("font_size")).x
	check(width <= label.size.x+1,description+" remains fully readable")
	check(Rect2(Vector2.ZERO,label.get_parent().size).grow(1).encloses(label.get_rect()),description+" stays inside its panel")
func advance_mission(model: RefCounted, simulated_seconds: float) -> void:
	model.advance(simulated_seconds/float(model.snapshot().effective_time_scale))
func press(button: Button) -> void:
	button.grab_focus()
	await frames()
	for down in [true,false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ENTER
		event.physical_keycode = KEY_ENTER
		event.pressed = down
		root.push_input(event)
	await frames()
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var hud := Hud.new()
	root.add_child(hud)
	var model := Model.new()
	var events: Array[String] = []
	hud.cleaning_speed_requested.connect(func(value:float):
		events.append("speed:%.2f" % value)
		model.set_cleaning_speed(value)
		hud.refresh(model.snapshot()))
	hud.start_requested.connect(func():events.append("start"))
	hud.pause_requested.connect(func():events.append("pause"))
	hud.notebook_requested.connect(func():events.append("book"))
	for dimensions in [Vector2i(1280,720),Vector2i(960,540),Vector2i(390,844),Vector2i(844,390),Vector2i(320,568),Vector2i(1280,720)]:
		root.size = dimensions
		for before_start in [true,false]:
			hud.set_preflight(before_start)
			hud.refresh(model.snapshot())
			await frames()
			for control in [hud.slower_button,hud.faster_button,hud.speed_slider,hud.notebook_button,hud.pause_button]: target(control,str(control.name)+" "+str(dimensions))
			if before_start: target(hud.start_button,"Start "+str(dimensions))
			check(not hud.slower_button.get_global_rect().intersects(hud.speed_slider.get_global_rect()) and not hud.speed_slider.get_global_rect().intersects(hud.faster_button.get_global_rect()),"Pace actions and slider do not overlap")
			check(not hud.notebook_button.get_global_rect().intersects(hud.pause_button.get_global_rect()),"Science and Pause remain separate actions")
			if before_start:
				check(not hud.start_button.get_global_rect().intersects(hud.faster_button.get_global_rect()),"Start does not overlap the pace controls")
			for label in [hud._title_label,hud._subtitle_label,hud._clean_title,hud._clean_value,hud._power_title,hud._power_value,hud._timer_label,hud._timer_caption,hud._mission_label,hud._pace_value,hud._effort_label]:
				text_fits(label,label.text+" "+str(dimensions))
			for label in [hud._clean_value,hud._power_value,hud._timer_label]:
				check(label.is_visible_in_tree() and label.get_theme_font_size("font_size") >= 26,"All three primary readings stay visible and large")
			check(hud._clean_progress.is_visible_in_tree() and is_equal_approx(hud._clean_progress.value,model.snapshot().clean_fraction),"Cleaned fraction is direct rather than dust-left arithmetic")
			check("80%" in hud._clean_title.text and hud._clean_target.is_visible_in_tree(),"The visible cleaning goal agrees with the model win target")
			check(not hud._rail.is_visible_in_tree() and not hud._left_rail.is_visible_in_tree() and not hud._right_rail.is_visible_in_tree(),"Science concepts do not permanently crowd the working scene")
			for orb in hud.orbs.values(): check(not orb.is_visible_in_tree(),"Optional "+orb.title+" is kept out of the main play HUD")
			var work_rect := hud.get_work_view_rect()
			check(work_rect.size.x >= dimensions.x-24.1 and work_rect.size.y >= 120,"Work camera receives the full available window width")
			check(work_rect.position.y >= hud._top.get_rect().end.y and work_rect.end.y < hud._bottom.get_rect().position.y,"Work camera rectangle avoids header and controls")
			# Every selectable pace remains legible even on a small phone.
			for pace in [0.25,1.0,1.75]:
				var sample := model.snapshot()
				sample.selected_multiplier = pace
				hud.refresh(sample)
				text_fits(hud._pace_value,"Pace name "+str(pace)+" "+str(dimensions))
			hud.refresh(model.snapshot())
	hud.set_preflight(true)
	hud.refresh(model.snapshot())
	check(Style.font("display_bold") is FontVariation,"Shared headings use bundled bold variable fonts")
	check(Style.font("display").has_char(0x014c) and Style.font("mono").has_char(0x00b5),"Fonts support the name and microgray prefix")
	check(Hud.format_clock(0.0) == "00:00" and Hud.format_clock(1800.0) == "30:00" and Hud.format_clock(60.01) == "01:01","Clock rounds partial seconds without negative time")
	check(hud._timer_label.text == "01:30" and hud._timer_caption.text == "Storm in","Primary clock clearly shows90seconds of play before the authored storm")
	check("simulated" in hud._timer_label.tooltip_text,"The real and simulated clocks remain distinguished in optional detail")
	check(hud._clean_value.text == "0%" and hud._clean_progress.value == 0.0,"Preflight starts with a wholly dusty panel")
	check(hud.notebook_button.text == "Science","One clearly named Science action exposes the optional library")
	var before := model.snapshot()
	await press(hud.faster_button)
	check(events == ["speed:1.25"] and model.snapshot().selected_multiplier == 1.25,"Faster selects one quarter-step from the keyboard")
	check(hud._pace_value.text == "Quick","Changing pace gives immediate plain-language feedback")
	check(model.snapshot().sim_elapsed_seconds == before.sim_elapsed_seconds and model.snapshot().cleaned_work == 0,"Selecting preflight pace does not advance work or time")
	await press(hud.slower_button)
	check(events[-1] == "speed:1.00" and hud._pace_value.text == "Steady","Slower selects the adjacent pace with immediate feedback")
	hud.speed_slider.value = 1.75
	check(events[-1] == "speed:1.75" and hud.faster_button.disabled and not hud.slower_button.disabled,"Upper pace bound prevents further increments")
	hud.speed_slider.value = 0.25
	check(events[-1] == "speed:0.25" and hud.slower_button.disabled and not hud.faster_button.disabled,"Lower pace bound prevents further decrements")
	hud.speed_slider.grab_focus()
	var arrow := InputEventKey.new()
	arrow.keycode = KEY_RIGHT
	arrow.pressed = true
	root.push_input(arrow)
	await frames()
	check(events[-1] == "speed:0.50","Focused pace slider supports one-step arrow-key changes")
	hud.speed_slider.value = 1.0
	await press(hud.start_button)
	check(events[-1] == "start" and model.snapshot().sim_elapsed_seconds == 0,"Start emits an intent without advancing physics")
	hud.set_preflight(false)
	advance_mission(model,360)
	hud.refresh(model.snapshot())
	check(not hud.start_button.visible and hud._clean_value.text == "18%","Active play shows actual cleaning progress and removes Start")
	check(hud._timer_label.text == "01:12","Primary timer advances in real play seconds")
	check(hud._effort_label.text == "Ren is fresh.","Normal starting pace shows a short effort cue")
	var readings := hud.get_science_readings()
	check(readings.size() == 8,"All eight scientific concepts remain available to the optional library")
	check(readings.speed.value == "0.125/min" and readings.dust.value == "81% left","Optional readings retain actual cleaning rate and remaining dust")
	check("µGy/d" in readings.radiation.value and "authored rise" in readings.radiation.detail,"Optional radiation shows its units and authored ramp")
	check(readings.sievert.value == "Not inferred" and "does not fabricate" in readings.sievert.detail,"Sievert never fabricates a personal health reading")
	check("µGy" in readings.dose.value and hud.orbs.dose.tone == "normal","Accumulated dose is not assigned a medical danger colour")
	check(readings.shelter.value == "At the door","Ren has no fabricated walking-distance return")
	readings.dust.value = "changed"
	check(hud.get_science_readings().dust.value != "changed","Library readings are detached from the HUD state")
	await press(hud.faster_button)
	advance_mission(model,480)
	hud.refresh(model.snapshot())
	check(hud._pace_value.text == "Quick" and "working hard" in hud._effort_label.text,"Effort feedback responds to accumulating game fatigue")
	check(hud._power_value.text == "%.2f kWh" % model.snapshot().battery_kwh,"Energy stored remains an actual value with units")
	check(hud._clean_value.text == "47%" and is_equal_approx(hud._clean_progress.value,0.475),"The main progress bar follows continuous modeled work")
	check("authored effort" in hud._fatigue_value.tooltip_text and "not a medical" in hud._fatigue_value.tooltip_text,"Optional fatigue remains an authored effort indicator")
	before = model.snapshot()
	hud.set_reduced_motion(true)
	await frames()
	check(model.snapshot() == before,"Layout and reduced motion never advance the model")
	for id in hud.orbs: check(hud.orbs[id].reduced_motion,"Reduced-motion preference reaches "+id)
	hud.speed_slider.value = 0.5
	advance_mission(model,120)
	hud.refresh(model.snapshot())
	check(hud._effort_label.text == "Ren is recovering.","A gentler pace clearly explains fatigue recovery")
	await press(hud.notebook_button)
	await press(hud.pause_button)
	check(events.slice(events.size()-2) == ["book","pause"],"Science and Pause are available from keyboard without hidden-orb interaction")
	var sample := model.snapshot()
	sample.clean_fraction = 0.79999
	sample.dust_fraction = 1.0-sample.clean_fraction
	hud.refresh(sample)
	check(hud._clean_value.text == "79%" and "Goal reached" not in hud._mission_label.text,"Rounding cannot prematurely claim the80percent goal")
	sample.clean_fraction = 0.8
	hud.refresh(sample)
	check(hud._clean_value.text == "80%" and hud._mission_label.text == "Goal reached!","Reaching the true goal gets a clear visible acknowledgement")
	hud.refresh(model.snapshot())
	hud.speed_slider.value = 1.0
	advance_mission(model,660)
	hud.refresh(model.snapshot())
	check(hud._timer_label.text == hud.orbs.time.status_text,"Primary and optional time readings stay synchronized")
	hud.faster_button.grab_focus()
	advance_mission(model,600)
	hud.refresh(model.snapshot())
	await frames()
	check(hud.slower_button.disabled and hud.faster_button.disabled and not hud.speed_slider.editable,"Completed mission disables all pace input")
	check(root.gui_get_focus_owner() == hud.notebook_button,"Completion moves focus to available Science navigation")
	check(hud.orbs.shelter.status_text == "Inside" and hud._timer_label.text == "00:00","Countdown ends with automatic shelter entry")
	check(not hud.has_signal("return_requested") and not hud.has_signal("radio_cue_requested"),"No discarded recall or radio mechanic returns")
	hud.queue_free()
	await frames()
	print("TRAINING HUD ASSERTIONS: ",assertions," FAILURES: ",failures)
	quit(1 if failures else 0)
