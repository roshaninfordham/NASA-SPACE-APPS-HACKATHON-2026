extends Control
## Read-only presentation of the pace mission. User intents never advance physics.
const Style = preload("res://ui/journey_style.gd")
const Branding = preload("res://scripts/branding.gd")
const ConceptOrb = preload("res://ui/concept_orb.gd")
signal start_requested
signal cleaning_speed_requested(multiplier: float)
signal concept_requested(id: String)
signal pause_requested
signal notebook_requested
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

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = Style.theme()
	_top = _panel()
	add_child(_top)
	_timer_label = _label(_top,"05:00",36,Style.CORAL,"mono")
	_timer_caption = _label(_top,"! MISSION TIME",11,Style.CORAL,"mono")
	_title_label = _label(_top,Branding.title(),24,Style.PEARL,"display")
	_subtitle_label = _label(_top,Branding.subtitle(),12,Style.MUTED,"mono")
	for label in [_title_label,_subtitle_label]: label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_storm_label = _label(_top,"TIME TO STORM",11,Style.MUTED,"mono")
	_storm_progress = _bar(_top,Style.CORAL)
	_storm_progress.accessibility_name = "Elapsed fraction of the mission before the authored storm"
	_storm_caption = _label(_top,"Ready to begin",11,Style.MUTED)
	pause_button = _button(_top,"Pause","TrainingPause")
	pause_button.tooltip_text = "Pause or open navigation. Escape also pauses."
	pause_button.pressed.connect(func():pause_requested.emit())
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
	_rate_label = _label(_bottom,"Cleaning · 0.000 sections/min",17,Style.PEARL,"mono")
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
	_pace_value = _label(_bottom,"1.00× · steady",11,Style.CYAN,"mono")
	_pace_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pace_max = _label(_bottom,"1.75×",10,Style.MUTED,"mono")
	_pace_max.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_power_title = _label(_bottom,"BATTERY NOW",10,Style.MUTED,"mono")
	_power_value = _label(_bottom,"0.00 kWh",20,Style.PEARL,"display")
	_solar_title = _label(_bottom,"SOLAR NOW",10,Style.MUTED,"mono")
	_solar_value = _label(_bottom,"0.00 kW",20,Style.PEARL,"display")
	_fatigue_title = _label(_bottom,"GAME FATIGUE",10,Style.MUTED,"mono")
	_fatigue_value = _label(_bottom,"0% · fresh",18,Style.CYAN,"display")
	_fatigue_progress = _bar(_bottom,Style.AMBER)
	_fatigue_progress.accessibility_name = "Game fatigue, an authored effort indicator"
	_mission_label = _label(_bottom,"Dust Off the Solar Panel",22,Style.PEARL,"display")
	_mission_subtitle = _label(_bottom,"Power Up the Outpost",12,Style.MUTED)
	start_button = _button(_bottom,"START MISSION","TrainingStart",true)
	start_button.pressed.connect(func():start_requested.emit())
	notebook_button = _button(_bottom,"Science","TrainingNotebook")
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
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill: StyleBoxFlat = theme.get_stylebox("fill","ProgressBar").duplicate()
	fill.bg_color = tint
	bar.add_theme_stylebox_override("fill",fill)
	parent.add_child(bar)
	return bar

func _style_slider() -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Style.RAISED
	track.set_corner_radius_all(3)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	var fill := track.duplicate() as StyleBoxFlat
	fill.bg_color = Style.CYAN
	speed_slider.add_theme_stylebox_override("slider",track)
	speed_slider.add_theme_stylebox_override("grabber_area",fill)
	speed_slider.add_theme_stylebox_override("grabber_area_highlight",fill)
	for state in ["grabber","grabber_highlight","grabber_disabled"]:
		var texture_image := Image.create(28,28,false,Image.FORMAT_RGBA8)
		texture_image.fill(Color.TRANSPARENT)
		for y in range(28):
			for x in range(28):
				var radius := Vector2(x+0.5,y+0.5).distance_to(Vector2(14,14))
				if radius <= 13.0:
					texture_image.set_pixel(x,y,Style.MUTED if state == "grabber_disabled" else (Style.PEARL if radius > 9.0 else Style.CYAN))
		speed_slider.add_theme_icon_override(state,ImageTexture.create_from_image(texture_image))

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

static func format_clock(seconds: float) -> String:
	var whole := maxi(0,int(ceil(seconds-0.000001)))
	return "%02d:%02d" % [whole/60,whole%60]

func refresh(value: Dictionary) -> void:
	snapshot = value.duplicate(true)
	if not is_instance_valid(_timer_label): return
	var remaining := float(snapshot.get("sim_remaining_seconds",1800.0))
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
	_timer_caption.text = "! MISSION TIME ×"+str(float(snapshot.get("effective_time_scale",6.0)))
	_storm_progress.value = fraction
	_storm_caption.text = "Ready to begin" if preflight else ("Ren is inside" if inside else ("Storm soon · " if fraction >= 0.8 else "Arrives in ")+format_clock(remaining))
	_storm_caption.add_theme_color_override("font_color",Style.CORAL if fraction >= 0.8 and not inside else Style.MUTED)
	_storm_progress.tooltip_text = "Time until the authored radiation storm. This bar is a countdown, not a measured distance or a NASA forecast."
	_rate_label.text = "Cleaning · %.3f sections/min" % (0.0 if preflight else rate)
	_rate_label.tooltip_text = "A section is one quarter of the model panel. Rate = 0.125 × selected pace × (1 − game fatigue) sections per simulated minute."
	_mission_subtitle.text = "Power Up the Outpost · %.3f sections/min" % (0.0 if preflight else rate) if size.x < 760 and size.y < 700 else "Power Up the Outpost"
	_pace_value.text = "%.2f× · %s" % [_selected_multiplier,"steady" if is_equal_approx(_selected_multiplier,1.0) else ("faster" if _selected_multiplier > 1.0 else "slower")]
	speed_slider.accessibility_description = "Selected pace %.2f times normal. Actual cleaning %.3f sections per simulated minute. Game fatigue %.0f percent. This is an authored game effort indicator, not a health reading." % [_selected_multiplier,0.0 if preflight else rate,fatigue*100.0]
	_power_value.text = "%.2f kWh" % battery
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
	var narrow := size.x < 760.0
	var short := size.y < 600.0
	var compact_phone := narrow and size.y < 700.0
	var margin := 12.0 if narrow or short else 20.0
	var width := maxf(200.0,size.x-margin*2.0)
	var top_height := 118.0 if narrow else (66.0 if short else 86.0)
	_place(_top,margin,margin,width,top_height)
	pause_button.add_theme_font_size_override("font_size",15)
	if narrow:
		_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_title_label.add_theme_font_size_override("font_size",21)
		_subtitle_label.add_theme_font_size_override("font_size",10)
		_place(_title_label,14,8,width-104,27)
		_place(_subtitle_label,14,34,width-104,17)
		_place(pause_button,width-78,9,64,48)
		_timer_label.add_theme_font_size_override("font_size",32)
		_place(_timer_label,14,58,126,39)
		_place(_timer_caption,14,97,132,16)
		_place(_storm_label,158,65,width-174,17)
		_place(_storm_progress,158,87,width-174,5)
		_place(_storm_caption,158,95,width-174,18)
	else:
		_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_title_label.add_theme_font_size_override("font_size",22 if short else 28)
		_subtitle_label.add_theme_font_size_override("font_size",10 if short else 12)
		_place(_timer_label,16,2 if short else 9,150,43)
		_timer_label.add_theme_font_size_override("font_size",32 if short else 38)
		_place(_timer_caption,17,43 if short else 53,154,18)
		var brand_x := 180.0
		var brand_width := maxf(170,width-510)
		_place(_title_label,brand_x,5 if short else 16,brand_width,32)
		_place(_subtitle_label,brand_x,36 if short else 48,brand_width,20)
		_place(_storm_label,width-300,10 if short else 18,200,18)
		_place(_storm_progress,width-300,33 if short else 44,200,5)
		_place(_storm_caption,width-300,41 if short else 55,200,18)
		_place(pause_button,width-82,9 if short else 18,66,48)
	_arrange_orbs(not narrow,margin,width,top_height,short)
	var bottom_width := width if narrow else minf(900,width-248)
	var bottom_height := (204.0 if compact_phone else 264.0) if narrow else (136.0 if short else 220.0)
	_place(_bottom,(size.x-bottom_width)*0.5,size.y-margin-bottom_height,bottom_width,bottom_height)
	var inner := bottom_width-28.0
	var rate_y := 4.0 if short and not narrow else 12.0
	_rate_label.add_theme_font_size_override("font_size",13 if narrow or short else 16)
	_place(_rate_label,14,rate_y,inner,22)
	var controls_y := 45.0 if compact_phone else (22.0 if short and not narrow else 42.0)
	var button_width := 78.0 if narrow else (90.0 if short else 102.0)
	for button in [slower_button,faster_button]: button.add_theme_font_size_override("font_size",15 if narrow or short else 18)
	_place(slower_button,14,controls_y,button_width,48)
	_place(faster_button,bottom_width-14-button_width,controls_y,button_width,48)
	var slider_x := 24.0+button_width
	var slider_width := bottom_width-slider_x*2.0
	_place(speed_slider,slider_x,controls_y,slider_width,48)
	_place(_pace_min,slider_x,controls_y+43,46,16)
	_place(_pace_max,slider_x+slider_width-46,controls_y+43,46,16)
	_place(_pace_value,slider_x,controls_y+43,slider_width,16)
	# On narrow screens the end values are already exposed by the two buttons'
	# bounds and slider accessibility, leaving the selected pace unobstructed.
	_pace_min.visible = slider_width >= 240
	_pace_max.visible = slider_width >= 240
	var facts_y := 5.0 if compact_phone else 112.0
	var fact_width := inner/3.0
	for index in range(3):
		var title: Label = [_power_title,_solar_title,_fatigue_title][index]
		var reading: Label = [_power_value,_solar_value,_fatigue_value][index]
		title.add_theme_font_size_override("font_size",9 if narrow or short else 10)
		reading.add_theme_font_size_override("font_size",15 if narrow or short else 20)
		_place(title,14+index*fact_width,facts_y,fact_width-8,14)
		_place(reading,14+index*fact_width,facts_y+12,fact_width-8,24)
	_place(_fatigue_progress,14+fact_width*2,facts_y+(30 if short and not narrow else 38),fact_width-10,3)
	var footer_y := 82.0 if short and not narrow else 166.0
	var notebook_width := 76.0 if narrow else 86.0
	var start_width := 164.0 if short else 184.0
	_mission_label.add_theme_font_size_override("font_size",20 if narrow else (17 if short else 20))
	_mission_subtitle.add_theme_font_size_override("font_size",12)
	if narrow:
		_mission_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_mission_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_place(_mission_label,14,108 if compact_phone else 166,inner,26)
		_place(_mission_subtitle,14,132 if compact_phone else 190,inner,18)
		_place(start_button,14,150 if compact_phone else 210,inner-notebook_width-10,48)
		_place(notebook_button,bottom_width-14-notebook_width,150 if compact_phone else 210,notebook_width,48)
	else:
		_mission_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_mission_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		var title_width: float = inner-notebook_width-12-(start_width+10 if preflight else 0)
		_place(_mission_label,14,footer_y+1,title_width,27)
		_place(_mission_subtitle,14,footer_y+27,title_width,18)
		_place(start_button,bottom_width-24-notebook_width-start_width,footer_y,start_width,48)
		_place(notebook_button,bottom_width-14-notebook_width,footer_y,notebook_width,48)
	_rate_label.visible = not compact_phone
	_power_title.visible = not (short and not narrow)
	_power_value.visible = _power_title.visible
	_solar_title.text = "SOLAR NOW"
	_fatigue_title.text = "GAME FATIGUE"
	if short and not narrow:
		# The scene's actor feet project near 62% of the window height. A tall
		# landscape footer would cover the complete task, so use one data line.
		# Actual battery storage remains visible in the right-hand Energy orb.
		_rate_label.add_theme_font_size_override("font_size",11)
		_rate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_place(_rate_label,14,4,inner*0.46,18)
		var solar_x := 14+inner*0.46
		_solar_title.text = "SOLAR"
		_place(_solar_title,solar_x,7,36,13)
		_place(_solar_value,solar_x+36,3,inner*0.24-36,20)
		var fatigue_x := 14+inner*0.70
		_place(_fatigue_title,fatigue_x,7,76,13)
		_place(_fatigue_value,fatigue_x+76,3,inner*0.30-76,20)
		_place(_fatigue_progress,fatigue_x,21,inner*0.30-8,2)
	else:
		_rate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	start_button.add_theme_font_size_override("font_size",16 if narrow or short else 18)
	notebook_button.add_theme_font_size_override("font_size",15)
	_laying_out = false
	refresh(snapshot)
	_follow_rail_focus.call_deferred()

func _arrange_orbs(side: bool, margin: float, width: float, top_height: float, short: bool) -> void:
	var previous_focus := get_viewport().gui_get_focus_owner()
	if side != _side_orbs:
		for index in range(CONCEPT_IDS.size()):
			var orb: Control = orbs[CONCEPT_IDS[index]]
			orb.reparent((_left_rail if index < 4 else _right_rail) if side else _orb_row,false)
		_side_orbs = side
		if previous_focus in orbs.values(): previous_focus.grab_focus.call_deferred()
	_rail.visible = not side
	_left_rail.visible = side
	_right_rail.visible = side
	if side:
		var rail_width := 108.0
		var rail_y := margin+top_height+10
		var available := size.y-rail_y-margin
		var gap := 8.0
		var orb_height := minf(112.0,(available-gap*3.0)/4.0)
		_place(_left_rail,margin,rail_y,rail_width,available)
		_place(_right_rail,size.x-margin-rail_width,rail_y,rail_width,available)
		for index in range(CONCEPT_IDS.size()):
			var orb: Control = orbs[CONCEPT_IDS[index]]
			orb.custom_minimum_size = Vector2(80,64 if short else 80)
			_place(orb,0,(index%4)*(orb_height+gap),rail_width,orb_height)
	else:
		_place(_rail,margin,margin+top_height+8,width,112)
		for orb in orbs.values(): orb.custom_minimum_size = Vector2(104,104)

func _follow_rail_focus() -> void:
	if not is_inside_tree(): return
	await get_tree().process_frame
	if not is_instance_valid(_rail) or not _rail.visible: return
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null and _rail.is_ancestor_of(focused): _rail.ensure_control_visible(focused)
