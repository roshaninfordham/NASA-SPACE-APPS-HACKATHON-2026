extends Control
## Read-only presentation of the pace mission. User intents never advance physics.
const Style = preload("res://ui/journey_style.gd")
const Branding = preload("res://scripts/branding.gd")
const ConceptOrb = preload("res://ui/concept_orb.gd")
const WindowFrame = preload("res://ui/outpost_window_frame.gd")
signal start_requested
signal cleaning_speed_requested(multiplier: float)
signal concept_requested(id: String)
signal pause_requested
signal notebook_requested
signal work_view_changed
signal view_requested
const CONCEPT_IDS := ["radiation","dose","sievert","dust","power","time","speed","shelter"]
const MIN_PACE := 0.25
const MAX_PACE := 1.75
const PACE_STEP := 0.25
var snapshot: Dictionary = {}
var preflight := true
var reduced_motion := false
var orbs: Dictionary = {}
var slower_button: Button
var faster_button: Button
var clean_button: Button # Compatibility name for the faster control, never a toggle.
var speed_slider: HSlider
var start_button: Button
var notebook_button: Button
var pause_button: Button
var view_button: Button
var _window_frame: Control
var _mission_view := "science"
var _feedback_paused := false
var _radio_player := ""
var _radio_reply := ""
var _radio_elapsed := 5.0
var _effort_copy := ""
var _effort_tint := Style.MUTED
var _compact_energy := false
var _top: Panel
var _bottom: Panel
var _rail: ScrollContainer
var _orb_row: HBoxContainer
var _left_rail: Control
var _right_rail: Control
var _side_orbs := false
var _laying_out := false
var _title_label: Label
var _subtitle_label: Label
var _timer_label: Label
var _timer_caption: Label
var _storm_label: Label
var _storm_progress: ProgressBar
var _storm_caption: Label
var _rate_label: Label
var _pace_min: Label
var _pace_value: Label
var _pace_max: Label
var _power_title: Label
var _power_value: Label
var _solar_title: Label
var _solar_value: Label
var _fatigue_title: Label
var _fatigue_value: Label
var _fatigue_progress: ProgressBar
var _mission_label: Label
var _mission_subtitle: Label
var _selected_multiplier := 1.0
var _clean_title: Label
var _clean_value: Label
var _clean_progress: ProgressBar
var _clean_target: ColorRect
var _effort_label: Label
var _goal_fraction := 0.8
const PACE_NAMES := ["Gentlest", "Gentle", "Easy", "Steady", "Quick", "Fast", "Fastest"]

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = Style.theme()
	_window_frame = WindowFrame.new()
	_window_frame.name = "OutpostWindowFrame"
	add_child(_window_frame)
	_window_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_process(false)
	_top = _panel()
	add_child(_top)
	_timer_label = _label(_top,"01:30",46,Style.CORAL,"mono")
	_timer_caption = _label(_top,"Storm in",16,Style.MUTED,"body_bold")
	_title_label = _label(_top,Branding.title(),40,Style.PEARL,"display_bold")
	_subtitle_label = _label(_top,Branding.subtitle(),13,Style.MUTED,"display_bold")
	for label in [_title_label,_subtitle_label]: label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_storm_label = _label(_top,"TIME TO STORM",11,Style.MUTED,"mono")
	_storm_progress = _bar(_top,Style.CORAL)
	_storm_progress.accessibility_name = "Elapsed fraction of the mission before the authored storm"
	_storm_caption = _label(_top,"Ready to begin",11,Style.MUTED)
	_clean_title = _label(_top,"Clean · goal 80%",16,Style.MUTED,"body_bold")
	_clean_value = _label(_top,"0%",38,Style.PEARL,"display_bold")
	_clean_progress = _bar(_top,Style.CYAN)
	_clean_progress.accessibility_name = "Panel cleaned"
	_clean_target = ColorRect.new()
	_clean_target.name = "CleanGoalMarker"
	_clean_target.color = Style.PEARL
	_clean_target.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top.add_child(_clean_target)
	pause_button = _button(_top,"Menu","TrainingPause")
	pause_button.tooltip_text = "Pause or open navigation. Escape also pauses."
	pause_button.pressed.connect(func():pause_requested.emit())
	view_button = _button(_top,"View","TrainingView")
	view_button.tooltip_text = "Choose Science window or Focused window. View changes do not change the mission."
	view_button.pressed.connect(func():view_requested.emit())
	_rail = ScrollContainer.new()
	_rail.name = "ScienceConceptRail"
	_rail.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_rail.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_rail.follow_focus = true
	_rail.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_rail)
	_orb_row = HBoxContainer.new()
	_orb_row.add_theme_constant_override("separation",8)
	_rail.add_child(_orb_row)
	_left_rail = Control.new()
	_right_rail = Control.new()
	for rail in [_left_rail,_right_rail]:
		rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(rail)
	for id in CONCEPT_IDS:
		var orb := ConceptOrb.new()
		orb.name = "Concept_" + id
		orb.configure(id,ConceptOrb.short_title(id))
		orb.set_measurement_scale(id not in ["sievert","shelter"])
		orb.pressed.connect(func():concept_requested.emit(orb.concept_id))
		_orb_row.add_child(orb)
		orbs[id] = orb
	_bottom = _panel()
	add_child(_bottom)
	_rate_label = _label(_bottom,"Cleaning · 0.000 sections/min",20,Style.PEARL,"body_bold")
	_rate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slower_button = _button(_bottom,"− Slower","TrainingSlower")
	faster_button = _button(_bottom,"+ Faster","TrainingFaster",true)
	clean_button = faster_button
	slower_button.pressed.connect(func():_request_pace(_selected_multiplier-PACE_STEP))
	faster_button.pressed.connect(func():_request_pace(_selected_multiplier+PACE_STEP))
	speed_slider = HSlider.new()
	speed_slider.name = "TrainingPaceSlider"
	speed_slider.min_value = MIN_PACE
	speed_slider.max_value = MAX_PACE
	speed_slider.step = PACE_STEP
	speed_slider.value = 1.0
	speed_slider.tick_count = 7
	speed_slider.ticks_on_borders = true
	speed_slider.custom_minimum_size = Vector2(48,48)
	speed_slider.focus_mode = Control.FOCUS_ALL
	speed_slider.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	speed_slider.accessibility_name = "Cleaning pace"
	speed_slider.tooltip_text = "Choose 0.25× to 1.75× in quarter steps. Arrow keys change one step. Above 1× builds game fatigue; below 1× recovers."
	_style_slider()
	speed_slider.value_changed.connect(_request_pace)
	_bottom.add_child(speed_slider)
	_pace_min = _label(_bottom,"0.25×",10,Style.MUTED,"mono")
	_pace_value = _label(_bottom,"1.00× · steady",20,Style.CORAL,"display_bold")
	_pace_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pace_max = _label(_bottom,"1.75×",10,Style.MUTED,"mono")
	_pace_max.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_power_title = _label(_top,"Energy stored",16,Style.MUTED,"body_bold")
	_power_value = _label(_top,"0.00 kWh",32,Style.PEARL,"display_bold")
	_solar_title = _label(_bottom,"SOLAR NOW",10,Style.MUTED,"mono")
	_solar_value = _label(_bottom,"0.00 kW",20,Style.PEARL,"display")
	_fatigue_title = _label(_bottom,"GAME FATIGUE",10,Style.MUTED,"mono")
	_fatigue_value = _label(_bottom,"0% · fresh",18,Style.CYAN,"display")
	_fatigue_progress = _bar(_bottom,Style.AMBER)
	_fatigue_progress.accessibility_name = "Game fatigue, an authored effort indicator"
	_mission_label = _label(_bottom,"Choose Ren’s cleaning pace",24,Style.PEARL,"display_bold")
	_mission_subtitle = _label(_bottom,"Power Up the Outpost",12,Style.MUTED)
	_effort_label = _label(_bottom,"Ren is ready.",17,Style.MUTED,"body_bold")
	start_button = _button(_bottom,"START MISSION","TrainingStart",true)
	start_button.pressed.connect(func():start_requested.emit())
	notebook_button = _button(_top,"Science","TrainingNotebook")
	notebook_button.tooltip_text = "Open the mission science notebook. Reading pauses the mission."
	notebook_button.pressed.connect(func():notebook_requested.emit())
	resized.connect(_layout)
	_layout()
	refresh(snapshot)

func _panel() -> Panel:
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel",Style.panel())
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return panel

func _label(parent: Node, value: String, text_size: int, tint: Color, face: String = "body") -> Label:
	var label := Style.label(value,text_size,tint,face)
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, node_name: String, primary := false) -> Button:
	var button := Style.button(text,primary)
	button.name = node_name
	for state in ["normal","hover","pressed","disabled"]:
		var box: StyleBoxFlat = button.get_theme_stylebox(state).duplicate()
		box.content_margin_left = 8
		box.content_margin_right = 8
		button.add_theme_stylebox_override(state,box)
	parent.add_child(button)
	return button

func _bar(parent: Node, tint: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.max_value = 1.0
	bar.step = 0.0
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill: StyleBoxFlat = theme.get_stylebox("fill","ProgressBar").duplicate()
	fill.bg_color = tint
	bar.add_theme_stylebox_override("fill",fill)
	parent.add_child(bar)
	return bar

func _style_slider() -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Color("532630")
	track.border_color = Color(Style.CORAL,0.6)
	track.set_border_width_all(1)
	track.set_corner_radius_all(6)
	track.content_margin_top = 6
	track.content_margin_bottom = 6
	var fill := track.duplicate() as StyleBoxFlat
	fill.bg_color = Style.CORAL
	speed_slider.add_theme_stylebox_override("slider",track)
	speed_slider.add_theme_stylebox_override("grabber_area",fill)
	speed_slider.add_theme_stylebox_override("grabber_area_highlight",fill)
	for state in ["grabber","grabber_highlight","grabber_disabled"]:
		var texture_image := Image.create(34,34,false,Image.FORMAT_RGBA8)
		texture_image.fill(Color.TRANSPARENT)
		for y in range(34):
			for x in range(34):
				var radius := Vector2(x+0.5,y+0.5).distance_to(Vector2(17,17))
				if radius <= 16.0:
					texture_image.set_pixel(x,y,Style.MUTED if state == "grabber_disabled" else (Style.PEARL if radius > 11.0 else Style.CORAL))
		speed_slider.add_theme_icon_override(state,ImageTexture.create_from_image(texture_image))
	var tick := Image.create(4,16,false,Image.FORMAT_RGBA8)
	tick.fill(Style.PEARL)
	speed_slider.add_theme_icon_override("tick",ImageTexture.create_from_image(tick))

func _request_pace(value: float) -> void:
	if not is_instance_valid(speed_slider) or not speed_slider.editable: return
	var chosen := clampf(snappedf(value,PACE_STEP),MIN_PACE,MAX_PACE)
	if is_equal_approx(chosen,_selected_multiplier): return
	_selected_multiplier = chosen
	speed_slider.set_value_no_signal(chosen)
	cleaning_speed_requested.emit(chosen)

func set_preflight(value: bool) -> void:
	preflight = value
	if is_instance_valid(start_button):
		start_button.visible = value
		_layout()
		refresh(snapshot)

func set_reduced_motion(value: bool) -> void:
	# The HUD has no decorative process/tween. Model values remain visible.
	reduced_motion = value
	for orb in orbs.values(): orb.set_reduced_motion(value)

func set_mission_view(mode: String) -> void:
	if mode not in ["science","focus"]: return
	if mode == _mission_view: return
	_mission_view = mode
	if is_instance_valid(_top):
		var focused := get_viewport().gui_get_focus_owner()
		if mode == "focus" and focused in orbs.values(): view_button.grab_focus.call_deferred()
		_layout()

func get_mission_view() -> String:
	return _mission_view

func set_feedback_paused(value: bool) -> void:
	_feedback_paused = value
	for orb in orbs.values(): orb.set_feedback_paused(value)
	set_process(not value and _radio_elapsed < 5.0)

func show_radio_exchange(player: String, reply: String) -> void:
	_radio_player = player.strip_edges().left(160)
	_radio_reply = reply.strip_edges().left(160)
	_radio_elapsed = 0.0
	if is_instance_valid(_effort_label):
		_refresh_radio_caption()
		if orbs.has("speed"): orbs.speed.pulse()
	set_process(not _feedback_paused)

func clear_radio_exchange() -> void:
	_radio_player = ""
	_radio_reply = ""
	_radio_elapsed = 5.0
	set_process(false)
	if is_instance_valid(_effort_label): _refresh_radio_caption()

func get_radio_exchange() -> Dictionary:
	return {"player":_radio_player,"reply":_radio_reply,"phase":"idle" if _radio_elapsed >= 5.0 else ("player" if _radio_elapsed < 1.2 else "reply"),"active":_radio_elapsed < 5.0}

func _process(delta: float) -> void:
	if _feedback_paused: return
	_radio_elapsed = minf(5.0,_radio_elapsed+minf(maxf(delta,0.0),0.25))
	_refresh_radio_caption()
	if _radio_elapsed >= 5.0: set_process(false)

func _refresh_radio_caption() -> void:
	var active := _radio_elapsed < 5.0
	_effort_label.text = (("You: "+_radio_player) if _radio_elapsed < 1.2 else ("Ren: "+_radio_reply)) if active else _effort_copy
	_effort_label.tooltip_text = ("You: "+_radio_player+"\nRen: "+_radio_reply) if active else "Authored game effort feedback, not a health measurement."
	_effort_label.accessibility_description = _effort_label.tooltip_text
	_effort_label.add_theme_color_override("font_color",Style.CYAN if active else _effort_tint)
	_effort_label.visible = not preflight or active

static func format_clock(seconds: float) -> String:
	var whole := maxi(0,int(ceil(seconds-0.000001)))
	return "%02d:%02d" % [whole/60,whole%60]

func refresh(value: Dictionary) -> void:
	snapshot = value.duplicate(true)
	if not is_instance_valid(_timer_label): return
	var simulated_remaining := float(snapshot.get("sim_remaining_seconds",1800.0))
	var clock_scale := maxf(0.001,float(snapshot.get("effective_time_scale",20.0)))
	var remaining := float(snapshot.get("remaining_seconds",simulated_remaining/clock_scale))
	var fraction := clampf(float(snapshot.get("storm_progress",0.0)),0.0,1.0)
	var fatigue := clampf(float(snapshot.get("fatigue",0.0)),0.0,1.0)
	var rate := float(snapshot.get("cleaning_rate_sections_per_minute",0.0))
	var battery := float(snapshot.get("battery_kwh",0.0))
	var solar := float(snapshot.get("solar_power_kw",0.0))
	var dust := clampf(float(snapshot.get("dust_fraction",1.0)),0.0,1.0)
	var radiation := float(snapshot.get("radiation_rate_ugy_per_day",210.0))
	var dose := float(snapshot.get("dose_ugy",0.0))
	var phase := str(snapshot.get("phase","outside"))
	var running := str(snapshot.get("status","running")) == "running"
	var inside := phase == "sheltered"
	var adjustable := (preflight or running) and not inside
	_selected_multiplier = clampf(float(snapshot.get("selected_multiplier",snapshot.get("cleaning_multiplier",1.0))),MIN_PACE,MAX_PACE)
	speed_slider.set_value_no_signal(_selected_multiplier)
	speed_slider.editable = adjustable
	slower_button.disabled = not adjustable or _selected_multiplier <= MIN_PACE
	faster_button.disabled = not adjustable or _selected_multiplier >= MAX_PACE
	start_button.disabled = not preflight or not running
	start_button.visible = preflight
	var focused := get_viewport().gui_get_focus_owner()
	if focused in [slower_button,faster_button,start_button] and (focused.disabled or not focused.visible):
		(speed_slider if adjustable else notebook_button).grab_focus.call_deferred()
	_timer_label.text = format_clock(remaining)
	_timer_caption.text = "Storm in"
	_timer_label.tooltip_text = "Real play time remaining while the mission is active. Reading and pause stop this clock. This scenario compresses 30 simulated minutes using a %.0f× simulation clock." % clock_scale
	_timer_caption.tooltip_text = _timer_label.tooltip_text
	_storm_progress.value = fraction
	_storm_caption.text = "Ren is inside" if inside else (("Storm soon · " if fraction >= 0.8 else "")+format_clock(simulated_remaining)+" on Mars")
	if size.x < 360.0 and not inside:
		_storm_caption.text = "Storm soon" if fraction >= 0.8 else format_clock(simulated_remaining)+" on Mars"
	_storm_caption.add_theme_color_override("font_color",Style.CORAL if fraction >= 0.8 and not inside else Style.MUTED)
	_storm_progress.tooltip_text = "Time until the authored radiation storm. This bar is a countdown, not a measured distance or a NASA forecast."
	_rate_label.text = "Cleaning · %.3f sections/min" % (0.0 if preflight else rate)
	_rate_label.tooltip_text = "A section is one quarter of the model panel. Rate = 0.125 × selected pace × (1 − game fatigue) sections per simulated minute."
	_mission_subtitle.text = "One round · about %d seconds" % int(ceil(float(snapshot.get("warning_seconds",1800.0))/clock_scale)) if preflight else "Dust clears. Solar power grows."
	var pace_index := clampi(int(round((_selected_multiplier-MIN_PACE)/PACE_STEP)),0,PACE_NAMES.size()-1)
	_pace_value.text = PACE_NAMES[pace_index]
	_pace_value.tooltip_text = "Selected cleaning pace %.2f×. The slider has seven quarter-step settings." % _selected_multiplier
	_effort_copy = "Ren is ready." if preflight else ("Ren is inside." if inside else ("Ren is getting tired." if fatigue >= 0.4 else ("Ren is recovering." if _selected_multiplier < 1.0 and fatigue > 0.02 else ("Ren is working hard." if fatigue >= 0.1 else "Ren is fresh."))))
	_effort_tint = Style.AMBER if fatigue >= 0.4 else Style.MUTED
	_refresh_radio_caption()
	_mission_label.text = "Choose Ren’s cleaning pace" if preflight else ("Goal reached!" if float(snapshot.get("clean_fraction",0.0)) >= float(snapshot.get("win_clean_fraction",0.8)) else ("Cleaning pace" if size.x < 600.0 else "Help Ren clear the panel."))
	speed_slider.accessibility_description = "Selected pace %.2f times normal. Actual cleaning %.3f sections per simulated minute. Game fatigue %.0f percent. This is an authored game effort indicator, not a health reading." % [_selected_multiplier,0.0 if preflight else rate,fatigue*100.0]
	_power_value.text = ("%.2f" if _compact_energy else "%.2f kWh") % battery
	_goal_fraction = clampf(float(snapshot.get("win_clean_fraction",0.8)),0.0,1.0)
	var cleaned := clampf(float(snapshot.get("clean_fraction",1.0-dust)),0.0,1.0)
	_clean_title.text = ("Clean to %d%%" if size.x < 600.0 else "Clean · goal %d%%") % int(round(_goal_fraction*100.0))
	_clean_value.text = "%d%%" % int(floor(cleaned*100.0+0.00001))
	_clean_progress.value = cleaned
	_clean_progress.tooltip_text = "Panel %.1f%% clean. Reach at least %.0f%% for the full cleaning goal. More cleaning lets more sunlight reach the cells." % [cleaned*100.0,_goal_fraction*100.0]
	_clean_progress.accessibility_description = _clean_progress.tooltip_text
	_clean_value.tooltip_text = _clean_progress.tooltip_text
	_clean_target.position.x = _clean_progress.position.x+_clean_progress.size.x*_goal_fraction-1.0
	_clean_target.tooltip_text = "Cleaning goal %.0f%%" % (_goal_fraction*100.0)
	_power_value.tooltip_text = "Energy stored now: %.3f kWh of %.2f kWh capacity. This is actual modeled storage, not a forecast." % [battery,float(snapshot.get("battery_capacity_kwh",0.0))]
	_solar_value.text = "%.2f kW" % solar
	_solar_value.tooltip_text = "Current solar power %.3f kW, habitat load %.3f kW, net %.3f kW. Power is a rate; stored energy uses kWh." % [solar,float(snapshot.get("habitat_load_kw",0.0)),float(snapshot.get("net_power_kw",0.0))]
	_fatigue_value.text = "%.0f%%" % (fatigue*100.0)
	_fatigue_value.add_theme_color_override("font_color",Style.AMBER if fatigue >= 0.5 else Style.CYAN)
	_fatigue_progress.value = fatigue
	_fatigue_value.tooltip_text = "Game fatigue is an authored effort indicator. Faster than 1× builds it; slower than 1× recovers. Normal pace preserves the current level. It is not a medical measurement."
	_fatigue_progress.tooltip_text = _fatigue_value.tooltip_text
	orbs.radiation.set_level(clampf(radiation/840.0,0,1),"%.0f µGy/d" % radiation,"caution" if fraction >= 0.8 else "normal")
	orbs.radiation.tooltip_text = "Modeled absorbed-dose rate: %.1f microgray per day. The authored rise starts from a historical 210 µGy/day detector reference. It is not live Mars data or a personal health reading." % radiation
	orbs.dose.set_level(dose/11.0,"%.2f µGy" % dose)
	orbs.dose.tooltip_text = "Accumulated model absorbed dose: %.3f microgray. This only increases while Ren is outside; it is not a diagnosis or a survival threshold." % dose
	orbs.sievert.set_level(0.0,"Not inferred")
	orbs.sievert.tooltip_text = "Sievert is a different dose quantity. Radiation and tissue weighting are needed; this game does not fabricate a personal Sv reading from microgray. Open the science card."
	orbs.dust.set_level(dust,"%.0f%% left" % (dust*100.0),"caution" if dust > 0.75 else "normal")
	orbs.power.set_level(battery/maxf(0.001,float(snapshot.get("battery_capacity_kwh",3.0))),"%.2f kWh" % battery)
	orbs.power.tooltip_text = _power_value.tooltip_text+" "+_solar_value.tooltip_text
	orbs.time.set_level(1.0-fraction,format_clock(remaining),"caution" if fraction >= 0.8 else "normal")
	orbs.time.tooltip_text = "Real play time remaining %s. Simulated mission time remaining %s. Reading and pausing stop both clocks; the simulation time scale is %.0f×." % [format_clock(remaining),format_clock(simulated_remaining),clock_scale]
	orbs.speed.set_level(rate/0.21875,"%.3f/min" % (0.0 if preflight else rate),"caution" if fatigue >= 0.5 else "normal")
	orbs.speed.tooltip_text = "Actual cleaning %.3f sections per simulated minute at selected pace %.2f× and %.0f%% game fatigue. This is a cleaning task rate, not walking metres per second." % [0.0 if preflight else rate,_selected_multiplier,fatigue*100.0]
	orbs.shelter.set_level(1.0 if inside else 0.0,"Inside" if inside else "At the door")
	orbs.shelter.tooltip_text = "Ren works directly beside the shelter door. At the countdown's end she steps inside automatically; there is no walking-distance model."
	for orb in orbs.values(): orb.accessibility_description = orb.tooltip_text
	accessibility_description = "Dust Off the Solar Panel. Time left %s. Selected pace %.2f times normal. Game fatigue %.0f percent. Battery %.2f kilowatt-hours, solar %.2f kilowatts." % [format_clock(remaining),_selected_multiplier,fatigue*100.0,battery,solar]

func _place(control: Control, x: float, y: float, width: float, height: float) -> void:
	control.position = Vector2(x,y)
	control.size = Vector2(maxf(1,width),maxf(1,height))

func _layout() -> void:
	if not is_instance_valid(_top) or _laying_out: return
	_laying_out = true
	var phone := size.x < 600.0
	var compact := size.x < 1000.0 or size.y < 600.0
	var short := size.y < 600.0
	var margin := 12.0 if phone or short else 20.0
	var width := maxf(240.0,size.x-margin*2.0)
	var top_height := 180.0 if phone else (78.0 if short else 98.0)
	_place(_top,margin,margin,width,top_height)
	_arrange_orbs(margin,width,top_height,short,phone)
	for hidden in [_storm_label,_storm_progress,_storm_caption,_rate_label,_pace_min,_pace_max,_solar_title,_solar_value,_fatigue_title,_fatigue_value,_fatigue_progress,_mission_subtitle]:
		hidden.hide()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_title_label.add_theme_font_size_override("font_size",24 if size.x < 360.0 else (29 if compact else 36))
	_subtitle_label.add_theme_font_size_override("font_size",12 if compact else 14)
	_subtitle_label.visible = not phone
	notebook_button.add_theme_font_size_override("font_size",15 if phone else (17 if short else 19))
	pause_button.add_theme_font_size_override("font_size",15 if phone else (17 if short else 19))
	view_button.add_theme_font_size_override("font_size",15 if phone else (17 if short else 19))
	var nav_gap := 6.0 if phone else 8.0
	var science_width := 94.0 if compact else 108.0
	var pause_width := 76.0 if compact else 88.0
	var view_width := 70.0 if compact else 84.0
	var nav_x := width-14.0-science_width-pause_width-view_width-nav_gap*2.0
	if phone:
		var action_width := (width-28.0-nav_gap*2.0)/3.0
		for index in range(3):
			_place([notebook_button,view_button,pause_button][index],14.0+index*(action_width+nav_gap),48.0,action_width,48.0)
	else:
		var nav_y := 15.0 if short else 25.0
		_place(notebook_button,nav_x,nav_y,science_width,48.0)
		_place(view_button,nav_x+science_width+nav_gap,nav_y,view_width,48.0)
		_place(pause_button,width-14.0-pause_width,nav_y,pause_width,48.0)
	var metrics_x := 14.0 if phone else (174.0 if compact else 242.0)
	var metrics_width := width-28.0 if phone else nav_x-metrics_x-18.0
	var metric_gap := 12.0 if phone else 18.0
	var metric_width := (metrics_width-metric_gap*2.0)/3.0
	var metrics_y := 104.0 if phone else 9.0
	_compact_energy = phone or metric_width < 138.0
	if phone:
		_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_place(_title_label,14,3,width-28.0,44)
	else:
		_place(_title_label,16,9.0 if short else 14.0,metrics_x-30.0,44)
		_place(_subtitle_label,17,49.0 if short else 58.0,metrics_x-31.0,22)
	for index in range(3):
		var title: Label = [_clean_title,_power_title,_timer_caption][index]
		var value: Label = [_clean_value,_power_value,_timer_label][index]
		var x := metrics_x+index*(metric_width+metric_gap)
		title.add_theme_font_size_override("font_size",12 if phone or compact else 15)
		value.add_theme_font_size_override("font_size",(29 if index != 2 else 26) if phone else ((28 if index != 2 else 30) if compact else (32 if index == 1 else 40)))
		_place(title,x,metrics_y,metric_width,21.0)
		_place(value,x,metrics_y+20.0,metric_width,43.0)
	_power_title.text = "Energy · kWh" if _compact_energy else "Energy stored"
	_place(_clean_progress,metrics_x,metrics_y+63.0,metric_width,5.0)
	_place(_clean_target,metrics_x+metric_width*_goal_fraction-1.0,metrics_y+60.0,2.0,11.0)
	# One compact console: one pace choice, one plain-language effort cue.
	# Start is a separate preflight action and disappears once the round runs.
	var bottom_width := minf(900.0,width-2.0*((146.0 if short else 160.0)+12.0)) if _mission_view == "science" and not phone else minf(900.0,width)
	var bottom_height := (184.0 if preflight else 126.0) if phone else ((146.0 if preflight else 116.0) if short else (150.0 if preflight else 132.0))
	_place(_bottom,(size.x-bottom_width)*0.5,size.y-margin-bottom_height,bottom_width,bottom_height)
	var inner := bottom_width-28.0
	_mission_label.add_theme_font_size_override("font_size",18 if phone else (20 if short else 24))
	_mission_label.visible = true
	_mission_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if phone and preflight else HORIZONTAL_ALIGNMENT_LEFT
	_place(_mission_label,14,4.0 if not preflight else 8.0,(inner if preflight else inner*0.60) if phone else (inner-(190.0 if short else 210.0) if preflight else inner*0.65),26.0 if not preflight else 30.0)
	var controls_y := (40.0 if preflight else 36.0) if phone else ((60.0 if preflight else 32.0) if short else (64.0 if preflight else 42.0))
	var button_width := 68.0 if phone else (96.0 if compact else 112.0)
	for button in [slower_button,faster_button]:
		button.add_theme_font_size_override("font_size",16 if phone else 20)
	_place(slower_button,14,controls_y,button_width,48.0)
	_place(faster_button,bottom_width-14.0-button_width,controls_y,button_width,48.0)
	var slider_x := 24.0+button_width
	var slider_width := bottom_width-slider_x*2.0
	_place(speed_slider,slider_x,controls_y,slider_width,48.0)
	_pace_value.add_theme_font_size_override("font_size",22 if phone else 25)
	_pace_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(_pace_value,bottom_width*0.60 if phone and not preflight else slider_x,4.0 if phone and not preflight else controls_y+48.0,inner*0.38 if phone and not preflight else slider_width,29.0)
	_effort_label.add_theme_font_size_override("font_size",16 if phone or short else 18)
	_effort_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if phone else HORIZONTAL_ALIGNMENT_RIGHT
	_place(_effort_label,14 if phone else 14.0+inner*0.65,controls_y+52.0 if phone else 5.0,inner if phone else inner*0.35,25.0)
	# Phone labels use shorter familiar words, while accessible names keep the
	# full action and precise selected pace. Buttons retain48px hit targets.
	slower_button.text = "−" if phone else "− Slower"
	faster_button.text = "+" if phone else "+ Faster"
	slower_button.accessibility_name = "Slower cleaning pace"
	faster_button.accessibility_name = "Faster cleaning pace"
	if phone:
		_effort_label.visible = not preflight
		_place(start_button,14,bottom_height-58.0,inner,48.0)
	else:
		_effort_label.visible = not preflight
		var start_width := 176.0 if short else 196.0
		_place(start_button,bottom_width-14.0-start_width,6.0,start_width,48.0)
	start_button.add_theme_font_size_override("font_size",19 if phone or short else 21)
	_laying_out = false
	refresh(snapshot)
	_window_frame.set_opening(get_work_view_rect())
	_follow_rail_focus.call_deferred()
	work_view_changed.emit()

func _arrange_orbs(margin: float, width: float, top_height: float, short: bool, phone: bool) -> void:
	var science := _mission_view == "science"
	var side := not phone
	var previous_focus := get_viewport().gui_get_focus_owner()
	if side != _side_orbs:
		for index in range(CONCEPT_IDS.size()):
			var orb: Control = orbs[CONCEPT_IDS[index]]
			orb.reparent((_left_rail if index < 4 else _right_rail) if side else _orb_row,false)
		_side_orbs = side
		if previous_focus in orbs.values() and science: previous_focus.grab_focus.call_deferred()
	_rail.visible = science and not side
	_left_rail.visible = science and side
	_right_rail.visible = science and side
	if side:
		var rail_width := 146.0 if short else 160.0
		var rail_y := margin+top_height+10.0
		var available := size.y-rail_y-margin
		var gap := 8.0
		var orb_height := minf(132.0,(available-gap*3.0)/4.0)
		_place(_left_rail,margin,rail_y,rail_width,available)
		_place(_right_rail,size.x-margin-rail_width,rail_y,rail_width,available)
		for index in range(CONCEPT_IDS.size()):
			var orb: Control = orbs[CONCEPT_IDS[index]]
			orb.custom_minimum_size = Vector2(110.0,60.0 if short else 96.0)
			_place(orb,0,(index%4)*(orb_height+gap),rail_width,orb_height)
	else:
		var compact_phone := size.y < 700.0
		_place(_rail,margin,margin+top_height+8.0,width,96.0 if compact_phone else 120.0)
		for orb in orbs.values(): orb.custom_minimum_size = Vector2(146.0,88.0) if compact_phone else Vector2(148.0,112.0)

func _follow_rail_focus() -> void:
	if not is_inside_tree(): return
	await get_tree().process_frame
	if not is_instance_valid(_rail) or not _rail.visible: return
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null and _rail.is_ancestor_of(focused): _rail.ensure_control_visible(focused)

func get_work_view_rect() -> Rect2:
	if not is_instance_valid(_top) or not is_instance_valid(_bottom):
		return Rect2(Vector2.ZERO,size)
	var side := _mission_view == "science" and _side_orbs
	var left := _left_rail.position.x+_left_rail.size.x+12.0 if side else 12.0
	var right := _right_rail.position.x-12.0 if side else size.x-12.0
	var upper := _rail.position.y+_rail.size.y+10.0 if _mission_view == "science" and not _side_orbs else _top.position.y+_top.size.y+10.0
	var lower := _bottom.position.y-10.0
	return Rect2(Vector2(left,upper),Vector2(maxf(1.0,right-left),maxf(1.0,lower-upper)))

func get_science_readings() -> Dictionary:
	# Optional library consumers get the same current model readings as the
	# primary HUD. This is presentation data, never another simulation.
	var readings := {}
	for id in CONCEPT_IDS:
		var orb: Button = orbs[id]
		readings[id] = {"title":orb.title,"value":orb.status_text,"detail":orb.tooltip_text,"level":orb.level}
	return readings
