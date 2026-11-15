extends Control
## The mission UI reads a detached model snapshot. It never advances the model.
const Style = preload("res://ui/journey_style.gd")
const ConceptOrb = preload("res://ui/concept_orb.gd")
signal clean_requested
signal stop_clean_requested
signal return_requested
signal concept_requested(id: String)
signal pause_requested
signal notebook_requested
const CONCEPT_IDS := ["radiation","dose","sievert","dust","power","time","speed","shelter"]
var snapshot: Dictionary = {}
var reduced_motion := false
var orbs: Dictionary = {}
var clean_button: Button
var return_button: Button
var notebook_button: Button
var pause_button: Button
var _top: Panel
var _bottom: Panel
var _rail: ScrollContainer
var _orb_row: HBoxContainer
var _mission_label: Label
var _chapter_label: Label
var _timer_label: Label
var _timer_caption: Label
var _power_title: Label
var _power_value: Label
var _cue_label: Label
var _work_label: Label
var _progress: ProgressBar
var _preview: PanelWorkDisplay

class PanelWorkDisplay extends Control:
	var complete := 0
	var sections := 4
	var progress := 0.0
	var cleaning := false
	var reduced_motion := false
	var sweep := 0.0
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_process(false)
	func update_work(count: int, fraction: float, active: bool, reduced: bool, section_count: int = 4) -> void:
		complete = count
		sections = clampi(section_count,1,12)
		progress = fraction
		cleaning = active
		reduced_motion = reduced
		set_process(active and not reduced)
		queue_redraw()
	func _process(delta: float) -> void:
		if not is_visible_in_tree(): return
		sweep = fmod(sweep + delta * 0.35, 1.0)
		queue_redraw()
	func _draw() -> void:
		var cell_width := (size.x - (sections - 1) * 4.0) / sections
		for cell in range(sections):
			var rect := Rect2(Vector2(cell * (cell_width + 4.0), 0), Vector2(cell_width,size.y))
			draw_style_box(_cell_style(cell < complete), rect)
			for line in range(1,4):
				var y := rect.position.y + rect.size.y * line / 4.0
				draw_line(Vector2(rect.position.x + 2,y),Vector2(rect.end.x - 2,y),Color(Style.CYAN,0.15),1.0,true)
			if cell >= complete:
				var opacity := 1.0 - progress if cell == complete else 1.0
				for speck in range(9):
					var location := rect.position + Vector2(4.0 + fmod(speck * 7.0, maxf(1.0,cell_width - 6.0)),5.0 + fmod(speck * 11.0, maxf(1.0,size.y - 8.0)))
					draw_circle(location,1.3,Color(Style.AMBER,0.65 * opacity),true,-1.0,true)
				if cell == complete and cleaning:
					var scan_y := size.y * (0.5 if reduced_motion else sweep)
					draw_line(Vector2(rect.position.x + 1,scan_y),Vector2(rect.end.x - 1,scan_y),Style.CYAN,2.0,true)
	func _cell_style(cleared: bool) -> StyleBoxFlat:
		var box := StyleBoxFlat.new()
		box.bg_color = Color("143444") if cleared else Style.RAISED
		box.border_color = Style.CYAN if cleared else Color(Style.MUTED,0.38)
		box.set_border_width_all(1)
		box.set_corner_radius_all(4)
		return box

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = Style.theme()
	_top = Panel.new()
	_top.add_theme_stylebox_override("panel",Style.panel())
	_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_top)
	_chapter_label = Style.label("MISSION 01 · MARS",12,Style.MUTED,"mono")
	_top.add_child(_chapter_label)
	_mission_label = Style.label("Bring Ren home",22,Style.PEARL,"display")
	_mission_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_top.add_child(_mission_label)
	_timer_label = Style.label("05:00",38,Style.CYAN,"mono")
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_top.add_child(_timer_label)
	_timer_caption = Style.label("TIME LEFT",12,Style.MUTED,"mono")
	_timer_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_top.add_child(_timer_caption)
	pause_button = Style.button("Pause")
	pause_button.name = "TrainingPause"
	pause_button.tooltip_text = "Pause the mission. Escape also pauses and releases the pointer."
	pause_button.pressed.connect(func():pause_requested.emit())
	_top.add_child(pause_button)
	_rail = ScrollContainer.new()
	_rail.name = "ScienceConceptRail"
	_rail.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_rail.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_rail.follow_focus = true
	_rail.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_rail)
	_orb_row = HBoxContainer.new()
	_orb_row.add_theme_constant_override("separation",10)
	_rail.add_child(_orb_row)
	for id in CONCEPT_IDS:
		var orb := ConceptOrb.new()
		orb.name = "Concept_" + id
		orb.configure(id,ConceptOrb.short_title(id))
		orb.custom_minimum_size = Vector2(92,104)
		orb.pressed.connect(func():concept_requested.emit(orb.concept_id))
		_orb_row.add_child(orb)
		orbs[id] = orb
	_bottom = Panel.new()
	_bottom.add_theme_stylebox_override("panel",Style.panel())
	_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bottom)
	_preview = PanelWorkDisplay.new()
	_bottom.add_child(_preview)
	_work_label = Style.label("SECTIONS 0 / 4",12,Style.MUTED,"mono")
	_work_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bottom.add_child(_work_label)
	_power_title = Style.label("POWER OUTLOOK",12,Style.MUTED,"mono")
	_bottom.add_child(_power_title)
	_power_value = Style.label("4 Mars days · goal 15",18,Style.AMBER,"display")
	_bottom.add_child(_power_value)
	_cue_label = Style.label("Clean 2 sections, then guide Ren home.",18,Style.PEARL)
	_cue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# A first layout can begin at a one-pixel width. Bound its measured line
	# height so that temporary wrapping cannot push the cue outside the panel.
	_cue_label.max_lines_visible = 2
	_cue_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_bottom.add_child(_cue_label)
	_progress = ProgressBar.new()
	_progress.show_percentage = false
	_progress.max_value = 1.0
	_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bottom.add_child(_progress)
	clean_button = Style.button("1 · Clean panels",true)
	clean_button.name = "TrainingClean"
	clean_button.pressed.connect(_on_clean)
	_bottom.add_child(clean_button)
	return_button = Style.button("3 · Walk home")
	return_button.name = "TrainingReturn"
	return_button.pressed.connect(func():return_requested.emit())
	_bottom.add_child(return_button)
	notebook_button = Style.button("Mission book")
	notebook_button.name = "TrainingNotebook"
	notebook_button.pressed.connect(func():notebook_requested.emit())
	_bottom.add_child(notebook_button)
	resized.connect(_layout)
	_layout()
	refresh(snapshot)

func _on_clean() -> void:
	if bool(snapshot.get("cleaning",false)): stop_clean_requested.emit()
	else: clean_requested.emit()

func set_reduced_motion(value: bool) -> void:
	reduced_motion = value
	for orb in orbs.values(): orb.set_reduced_motion(value)
	if is_instance_valid(_preview):
		_preview.update_work(int(snapshot.get("sections_cleaned",0)),float(snapshot.get("section_progress",0.0)),bool(snapshot.get("cleaning",false)),value,int(snapshot.get("max_sections",4)))

static func format_clock(seconds: float) -> String:
	var whole := maxi(0,int(ceil(seconds - 0.000001)))
	return "%02d:%02d" % [whole / 60, whole % 60]

func refresh(value: Dictionary) -> void:
	snapshot = value.duplicate(true)
	if not is_instance_valid(_timer_label): return
	var remaining := float(snapshot.get("remaining_seconds",300.0))
	var return_left := float(snapshot.get("return_seconds_remaining",90.0))
	var warning := float(snapshot.get("warning_seconds",1800.0))
	var elapsed_sim := float(snapshot.get("sim_elapsed_seconds",0.0))
	var fraction := clampf(elapsed_sim / maxf(1.0,warning),0.0,1.0)
	var count := int(snapshot.get("sections_cleaned",0))
	var max_sections := maxi(1,int(snapshot.get("max_sections",4)))
	var progress := float(snapshot.get("section_progress",0.0))
	var margin := float(snapshot.get("power_margin_sols",1.0/0.28))
	var target := float(snapshot.get("target_margin_sols",15.0))
	var phase := str(snapshot.get("phase","outside"))
	var status := str(snapshot.get("status","running"))
	var cleaning := bool(snapshot.get("cleaning",false))
	var running := status == "running"
	var outside := phase == "outside"
	var urgent := outside and remaining <= return_left + 20.0
	_timer_label.text = format_clock(remaining)
	_timer_label.add_theme_color_override("font_color",Style.AMBER if urgent else Style.CYAN)
	_timer_caption.text = "RETURN NOW" if urgent else "TIME LEFT"
	clean_button.disabled = not running or not outside or count >= max_sections
	return_button.disabled = not running or not outside
	var focused_control := get_viewport().gui_get_focus_owner()
	if focused_control in [clean_button,return_button] and focused_control.disabled:
		notebook_button.grab_focus.call_deferred()
	var narrow := size.x < 600.0
	clean_button.text = ("Stop" if narrow else "1 · Stop cleaning") if cleaning else ("Clean" if narrow else "1 · Clean panels")
	if count >= max_sections: clean_button.text = "All clean" if narrow else "Panels complete"
	if not outside: clean_button.text = "Task closed" if narrow else "Cleaning closed"
	return_button.text = "Walking…" if phase == "returning" else ("Entering…" if phase == "airlock" else ("Inside" if phase == "sheltered" else ("Walk home" if narrow else "3 · Walk home")))
	clean_button.tooltip_text = "Cleaning stops when Ren starts home. Completed sections stay clean; an unfinished section adds no gain."
	return_button.tooltip_text = "Walk home takes " + format_clock(return_left) + ". Reading science cards pauses this clock."
	_power_title.text = "POWER OUTLOOK · MODEL"
	_power_value.text = "%.0f Mars days · goal %.0f" % [margin,target]
	_power_value.add_theme_color_override("font_color",Style.CYAN if margin >= target else Style.AMBER)
	_work_label.text = "SECTIONS %d / %d" % [count,max_sections]
	_progress.value = progress
	_preview.update_work(count,progress,cleaning,reduced_motion,max_sections)
	var sections_needed := maxi(0,int(snapshot.get("sections_needed",2)))
	var cue := "Clean %d sections, then guide Ren home." % sections_needed
	if cleaning: cue = "Cleaning section %d… You can stop or walk home." % mini(max_sections,count + 1)
	if margin >= target and outside: cue = "Power goal met. Bring Ren home before time runs out."
	if urgent: cue = "Walk home now. Ren needs " + format_clock(return_left) + " to reach shelter."
	if phase == "returning": cue = "Ren is on her way. " + format_clock(return_left) + " to shelter."
	elif phase == "airlock": cue = "Ren is at the airlock. Protection starts after entry."
	elif phase == "sheltered": cue = "Ren is inside. Let’s connect what you learned."
	if not running and status == "late": cue = "The return target was missed. Review the plan and try again."
	elif not running and status == "power-shortfall": cue = "Ren returned, but the power outlook missed the goal."
	_cue_label.text = cue
	orbs.radiation.set_level(fraction,"Return now" if urgent else "Forecast","caution" if urgent else "normal")
	var dose := float(snapshot.get("dose_ugy",0.0))
	var rate := float(snapshot.get("dose_rate_ugy_per_hour",210.0/24.0))
	var reference_dose := maxf(0.001, rate * warning / 3600.0)
	orbs.dose.set_level(dose / reference_dose,"%.2f µGy" % dose)
	orbs.sievert.set_level(0.0,"Other unit")
	orbs.dust.set_level(float(count) / max_sections,"%d/%d clean" % [count,max_sections])
	orbs.power.set_level(margin / maxf(1.0,target),"Goal met" if margin >= target else "Low outlook","normal" if margin >= target else "caution")
	orbs.time.set_level(1.0 - fraction,format_clock(remaining),"caution" if urgent else "normal")
	var walking_speed := float(snapshot.get("speed_mps",snapshot.get("walking_speed_mps",0.8)))
	orbs.speed.set_level(0.0,"%.1f m/s" % walking_speed)
	orbs.shelter.set_level(float(snapshot.get("return_progress",0.0)),"Protected" if phase == "sheltered" else ("Walking" if phase == "returning" else ("Entering" if phase == "airlock" else "Outside")))
	accessibility_description = cue + " Time left " + format_clock(remaining) + ". " + _power_value.text + "."

func _layout() -> void:
	if not is_instance_valid(_top): return
	# Apply compact labels before assigning button rectangles, so their previous
	# wider text cannot force an overflowing minimum size during a live rotation.
	refresh(snapshot)
	var narrow := size.x < 600.0
	var short := size.y < 500.0
	var margin := 12.0 if narrow or short else 20.0
	var width := maxf(200.0,size.x - margin * 2.0)
	var top_height := 64.0 if short else 78.0
	_top.position = Vector2(margin,margin)
	_top.size = Vector2(width,top_height)
	_chapter_label.position = Vector2(16,10 if short else 12)
	_chapter_label.size = Vector2(140,18)
	_chapter_label.text = "MISSION 01" if narrow else "MISSION 01 · MARS"
	_chapter_label.add_theme_font_size_override("font_size",12)
	_mission_label.position = Vector2(16,28)
	_mission_label.text = "Help Ren" if narrow else "Bring Ren home"
	_mission_label.size = Vector2(104 if narrow else width * 0.36,29)
	_mission_label.add_theme_font_size_override("font_size",17 if narrow else 22)
	_timer_label.position = Vector2(width * 0.5 - 59,3 if short else 7)
	_timer_label.size = Vector2(118,42)
	_timer_label.add_theme_font_size_override("font_size",30 if narrow or short else 38)
	_timer_caption.position = Vector2(width * 0.5 - 65,42 if short else 49)
	_timer_caption.size = Vector2(130,19)
	pause_button.position = Vector2(width - 84,8 if short else 15)
	pause_button.size = Vector2(68,48)
	pause_button.add_theme_font_size_override("font_size",16)
	var rail_height := 90.0 if short else 112.0
	_rail.position = Vector2(margin,margin + top_height + 8.0)
	_rail.size = Vector2(width,rail_height)
	for orb in orbs.values():
		orb.custom_minimum_size = Vector2(86 if narrow or short else 100,82 if short else 104)
	_orb_row.add_theme_constant_override("separation",8 if narrow or short else 10)
	var bottom_height := 186.0 if narrow else (132.0 if short else 144.0)
	_bottom.position = Vector2(margin,size.y - margin - bottom_height)
	_bottom.size = Vector2(width,bottom_height)
	var info_y := 61.0 if narrow else 14.0
	_preview.position = Vector2(16,info_y)
	_preview.size = Vector2(86 if narrow else 104,26 if short and not narrow else 34)
	_work_label.position = Vector2(10,info_y + (27 if short and not narrow else 35))
	_work_label.size = Vector2(100 if narrow else 116,18)
	_power_title.position = Vector2(118 if narrow else 140,info_y)
	_power_title.size = Vector2(width - _power_title.position.x - 12 if narrow else 200,18)
	_power_title.add_theme_font_size_override("font_size",12)
	_power_value.position = Vector2(118 if narrow else 140,info_y + 19)
	_power_value.size = Vector2(width - _power_value.position.x - 12 if narrow else 200,29)
	_power_value.add_theme_font_size_override("font_size",16 if narrow else 20)
	_cue_label.position = Vector2(16,9) if narrow else Vector2(360,10)
	_cue_label.size = Vector2(width - 32,44) if narrow else Vector2(maxf(1,width - 380),48 if short else 52)
	_cue_label.add_theme_font_size_override("font_size",16 if narrow or short else 18)
	_progress.position = Vector2(16,114 if narrow else (60 if short else 69))
	_progress.size = Vector2(width - 32,4)
	var gap := 8.0 if narrow else 12.0
	var action_width := (width - 32.0 - gap * 2.0) / 3.0
	var y := bottom_height - 62.0
	notebook_button.text = "Science" if narrow else "Mission book"
	for index in range(3):
		var button: Button = [clean_button,return_button,notebook_button][index]
		button.add_theme_font_size_override("font_size",16 if narrow else 18)
		var normal: StyleBoxFlat = button.get_theme_stylebox("normal").duplicate()
		# Narrow targets retain 48px height without large text-side padding.
		if narrow:
			for state in ["normal","hover","pressed","disabled"]:
				var box: StyleBoxFlat = button.get_theme_stylebox(state).duplicate()
				box.content_margin_left = 6
				box.content_margin_right = 6
				button.add_theme_stylebox_override(state,box)
		normal.content_margin_left = 6 if narrow else 18
		normal.content_margin_right = 6 if narrow else 18
		button.add_theme_stylebox_override("normal",normal)
		button.position = Vector2(16 + index * (action_width + gap),y)
		button.size = Vector2(action_width,48)
	_follow_rail_focus.call_deferred()
	refresh(snapshot)

func _follow_rail_focus() -> void:
	if not is_inside_tree(): return
	await get_tree().process_frame
	if not is_instance_valid(_rail): return
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null and _rail.is_ancestor_of(focused): _rail.ensure_control_visible(focused)
