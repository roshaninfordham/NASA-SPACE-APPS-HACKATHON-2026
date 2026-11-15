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
	check(Rect2(Vector2.ZERO,root.get_visible_rect().size).grow(1).encloses(control.get_global_rect()),description+" remains in viewport")
	check(control.size.x >= 48 and control.size.y >= 48,description+" has a 48px target")
func text_fits(label: Label, description: String) -> void:
	if not label.visible: return
	var width := label.get_theme_font("font").get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,label.get_theme_font_size("font_size")).x
	check(width <= label.size.x+1,description+" remains fully readable")
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
	hud.concept_requested.connect(func(id:String):events.append(id))
	for dimensions in [Vector2i(1280,720),Vector2i(960,540),Vector2i(390,844),Vector2i(844,390),Vector2i(320,568),Vector2i(1280,720)]:
		root.size = dimensions
		hud.set_preflight(true)
		hud.refresh(model.snapshot())
		await frames()
		for control in [hud.slower_button,hud.faster_button,hud.speed_slider,hud.start_button,hud.notebook_button,hud.pause_button]: target(control,str(control.name)+" "+str(dimensions))
		check(not hud.slower_button.get_global_rect().intersects(hud.speed_slider.get_global_rect()) and not hud.speed_slider.get_global_rect().intersects(hud.faster_button.get_global_rect()),"Pace buttons and slider do not overlap")
		check(not hud.start_button.get_global_rect().intersects(hud.notebook_button.get_global_rect()),"Start and science actions do not overlap")
		check(hud._top.get_global_rect().end.y < hud._bottom.get_global_rect().position.y,"HUD leaves a clear central window")
		check(hud._bottom.get_global_rect().position.y > dimensions.y*0.615,"Footer stays below the projected working astronaut at this viewport")
		for label in [hud._title_label,hud._subtitle_label,hud._timer_label,hud._timer_caption,hud._storm_label,hud._storm_caption,hud._mission_label,hud._mission_subtitle,hud._rate_label,hud._power_value,hud._solar_value,hud._fatigue_title,hud._fatigue_value,hud._pace_value]: text_fits(label,label.text+" "+str(dimensions))
		var work_rect := hud.get_work_view_rect()
		check(work_rect.size.x >= 250 and work_rect.size.y >= 90,"Work camera receives a usable central rectangle at "+str(dimensions))
		check(work_rect.position.y >= hud._top.get_rect().end.y and work_rect.end.y < hud._bottom.get_rect().position.y,"Work camera rectangle avoids header and controls")
		for orb in hud.orbs.values():
			text_fits(orb._caption,orb.title+" name "+str(dimensions))
			text_fits(orb._status,orb.title+" measurement "+str(dimensions))
			check(orb._caption.get_theme_font_size("font_size") >= 15 and orb._status.get_theme_font_size("font_size") >= 13,"Science names and readings use larger minimum text")
		check(hud.orbs.size() == 8,"Eight science concepts remain available")
		var last_orb: Button = hud.orbs.shelter
		last_orb.grab_focus()
		await frames()
		if hud._rail.visible:
			check(hud._rail.get_global_rect().grow(1).encloses(last_orb.get_global_rect()),"Keyboard focus scrolls the last science concept into view")
		else:
			for orb in hud.orbs.values(): target(orb,str(orb.name))
		check(last_orb.size.x >= 48 and last_orb.size.y >= 48,"Science target remains usable")
	check(hud.speed_slider.get_theme_stylebox("grabber_area").bg_color == Style.CORAL and hud.speed_slider.get_theme_icon("grabber").get_width() == 34,"Pace slider has a distinct red fill and large34px handle")
	check(hud.speed_slider.tick_count == 7 and hud.speed_slider.get_theme_icon("tick").get_height() == 16,"Seven quarter-step positions remain visibly marked")
	check(Style.font("display_bold") is FontVariation,"Shared headings and science labels use the bundled bold variable font")
	check(Style.font("display").has_char(0x014c) and Style.font("mono").has_char(0x00b5),"Bundled fonts support the title and microgray prefix")
	check(Hud.format_clock(0.0) == "00:00" and Hud.format_clock(1800.0) == "30:00" and Hud.format_clock(60.01) == "01:01","Clock rounds partial seconds and never displays negative values")
	check(hud.preflight and hud.start_button.visible and not hud.is_processing(),"Preflight exposes Start and has no running UI animation")
	check(hud._timer_label.text == "01:30" and hud.orbs.time.status_text == "01:30" and hud._timer_caption.text == "PLAY TIME LEFT","Primary clock and time bubble clearly show90seconds of real play time")
	check("30:00 on Mars" in hud._storm_caption.text and "simulated" in hud._timer_label.tooltip_text,"The compressed30minute scenario remains explicit as a different time scale")
	check(hud._rate_label.text == "Cleaning · 0.000 sections/min","Preflight does not claim Ren is already cleaning")
	var before := model.snapshot()
	await press(hud.faster_button)
	check(events == ["speed:1.25"] and model.snapshot().selected_multiplier == 1.25,"Faster selects one quarter-step through a keyboard action")
	check(model.snapshot().sim_elapsed_seconds == before.sim_elapsed_seconds and model.snapshot().cleaned_work == 0,"Selecting preflight pace does not advance work or time")
	await press(hud.slower_button)
	check(events[-1] == "speed:1.00","Slower selects the adjacent lower pace")
	hud.speed_slider.value = 1.75
	check(events[-1] == "speed:1.75" and hud.faster_button.disabled and not hud.slower_button.disabled,"Slider reaches the bounded upper pace and disables its further increment")
	hud.speed_slider.value = 0.25
	check(events[-1] == "speed:0.25" and hud.slower_button.disabled and not hud.faster_button.disabled,"Slider reaches the bounded lower pace and disables its further decrement")
	hud.speed_slider.grab_focus()
	var arrow := InputEventKey.new()
	arrow.keycode = KEY_RIGHT
	arrow.pressed = true
	root.push_input(arrow)
	await frames()
	check(events[-1] == "speed:0.50","Focused pace slider supports one-step keyboard changes")
	hud.speed_slider.value = 1.0
	await press(hud.start_button)
	check(events[-1] == "start" and model.snapshot().sim_elapsed_seconds == 0,"Start emits an intent; only the controller can start physics")
	hud.set_preflight(false)
	advance_mission(model,360)
	hud.refresh(model.snapshot())
	check(not hud.start_button.visible and hud._fatigue_value.text == "0%","Normal initial pace keeps game fatigue zero")
	check(hud._rate_label.text == "Cleaning · 0.125 sections/min" and hud.orbs.speed.status_text == "0.125/min","Actual rate is a section-cleaning rate rather than walking speed")
	check(hud.orbs.dust.status_text == "81% left","Dust bubble reports dust remaining, not the opposite quantity")
	await press(hud.faster_button)
	advance_mission(model,480)
	hud.refresh(model.snapshot())
	check(hud._fatigue_value.text == "16%" and is_equal_approx(hud._fatigue_progress.value,0.16),"Faster work displays the model's accumulated game fatigue")
	check(hud.orbs.speed.status_text == "0.131/min" and hud._pace_value.text == "1.25× · faster","Selected pace is separate from the fatigue-reduced actual cleaning rate")
	check("authored effort" in hud._fatigue_value.tooltip_text and "not a medical" in hud._fatigue_value.tooltip_text,"Fatigue is explicitly an authored effort indicator")
	check(hud._power_value.text == "%.2f kWh" % model.snapshot().battery_kwh and hud._solar_value.text == "%.2f kW" % model.snapshot().solar_power_kw,"Stored energy and solar power retain distinct actual values and units")
	check("NOW" in hud._power_title.text and "forecast" not in hud.orbs.power.status_text.to_lower(),"Current battery replaces the former forecast reserve target")
	check("µGy/d" in hud.orbs.radiation.status_text and "authored rise" in hud.orbs.radiation.tooltip_text,"Radiation rate uses the authored rising reference and a dose-rate unit")
	check("µGy" in hud.orbs.dose.status_text and hud.orbs.dose.tone == "normal","Accumulated dose is not assigned a medical danger colour")
	check(hud.orbs.sievert.status_text == "Not inferred" and "does not fabricate" in hud.orbs.sievert.tooltip_text,"Sievert stays educational without a fabricated personal dose conversion")
	check(hud._storm_label.text == "TIME TO STORM" and "not a measured distance" in hud._storm_progress.tooltip_text,"Storm bar means time rather than invented spatial distance")
	check(hud.orbs.shelter.status_text == "At the door","Ren is beside shelter without an inferred walking distance")
	var source := model.snapshot()
	hud.refresh(source)
	source.fatigue = 999
	check(hud.snapshot.fatigue != 999,"HUD owns a detached snapshot")
	before = model.snapshot()
	hud.set_reduced_motion(true)
	await frames()
	check(model.snapshot() == before,"Layout and reduced-motion display never advance the model")
	for id in hud.orbs: check(hud.orbs[id].reduced_motion,"Reduced-motion preference reaches "+id)
	hud.speed_slider.value = 0.5
	advance_mission(model,120)
	hud.refresh(model.snapshot())
	check(float(hud.snapshot.fatigue) < 0.16,"A below-normal pace renders recovery from the same model")
	await press(hud.notebook_button)
	await press(hud.pause_button)
	await press(hud.orbs.radiation)
	check(events.slice(events.size()-3) == ["book","pause","radiation"],"Notebook, pause and science actions remain keyboard accessible")
	hud.speed_slider.value = 1.0
	advance_mission(model,660)
	hud.refresh(model.snapshot())
	check("Storm soon" in hud._storm_caption.text and hud._timer_label.text == hud.orbs.time.status_text,"End-of-countdown warning is explicit and both clocks stay synchronized")
	hud.faster_button.grab_focus()
	advance_mission(model,600)
	hud.refresh(model.snapshot())
	await frames()
	check(hud.slower_button.disabled and hud.faster_button.disabled and not hud.speed_slider.editable,"Completed mission closes both speed controls and the slider")
	check(root.gui_get_focus_owner() == hud.notebook_button,"Focus moves to available science navigation when the mission finishes")
	check(hud.orbs.shelter.status_text == "Inside" and hud.orbs.time.status_text == "00:00","Countdown ends with automatic shelter entry")
	check(not hud.has_signal("return_requested") and not hud.has_signal("radio_cue_requested"),"No recall or radio control remains in the final loop")
	hud.queue_free()
	await frames()
	print("TRAINING HUD ASSERTIONS: ",assertions," FAILURES: ",failures)
	quit(1 if failures else 0)
