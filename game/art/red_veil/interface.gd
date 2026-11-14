extends Control
## Presentation only: every mission action and reading belongs to game.gd.
const Branding = preload("res://scripts/branding.gd")
const NAVY := Color("071a29")
const CYAN := Color("75e5ed")
const WHITE := Color("edf8fa")
var _supplied_theme: Theme
var _font := SystemFont.new()
var _font_nodes: Dictionary = {}
var _buttons: Array[Button] = []
var _menu: Control
var _hud: Control
var _hero: VBoxContainer
var _menu_scroll: ScrollContainer
var _menu_card: PanelContainer
var _primary: VBoxContainer
var _secondary: VBoxContainer
var _title: Label
var _tagline: Label
var _objective_card: VBoxContainer
var _resource_card: VBoxContainer
var _radio_card: PanelContainer
var _action_row: HBoxContainer
var _hint: Label
var _reticle: Label
var _prompt: Label
var _base_gauge: BatteryGauge
var _suit_gauge: BatteryGauge
var _layout_pending := false
var _built := false
var _control_mode := false
var _details_visible := false
var _operator_mode := true

class BatteryGauge extends Control:
	var value := 0.0
	var capacity := 1.0
	var title := "BASE"
	var scale_factor := 1.0
	func _draw() -> void:
		var radius := 30.0 * scale_factor
		var center := Vector2(size.x / 2.0, 34.0 * scale_factor)
		var ratio := clampf(value / capacity, 0.0, 1.0)
		for segment in range(24):
			var start := -PI * 0.5 + segment * TAU / 24
			draw_arc(center, radius, start, start + TAU / 24 * 0.68, 6, Color("75e5ed") if float(segment) / 24 < ratio else Color("254455"), 2.0 * scale_factor, true)
		var font := ThemeDB.fallback_font
		var reading := "%.1f" % value if capacity > 1 else "%.2f" % value
		draw_string(font, center + Vector2(-radius, 0), reading, HORIZONTAL_ALIGNMENT_CENTER, radius * 2, roundi(16 * scale_factor), Color("edf8fa"))
		draw_string(font, center + Vector2(-radius, 16 * scale_factor), "kWh", HORIZONTAL_ALIGNMENT_CENTER, radius * 2, roundi(10 * scale_factor), Color("a7cbd6"))
		draw_string(font, Vector2(0, 85 * scale_factor), title, HORIZONTAL_ALIGNMENT_CENTER, size.x, roundi(12 * scale_factor), Color("edf8fa"))

func configure(_profile: Resource = null, supplied_theme: Theme = null) -> void:
	_supplied_theme = supplied_theme

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font.font_names = PackedStringArray(["Inter", "Aptos", "Helvetica Neue", "Arial", "Noto Sans"])
	theme = _supplied_theme if _supplied_theme else Theme.new()
	if _supplied_theme == null: theme.default_font = _font
	var visor := ColorRect.new()
	visor.color = Color(0.55, 0.3, 0.12, 0)
	visor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_named(visor, "Visor", self)
	visor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud = Control.new()
	_named(_hud, "HUD", self)
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_hud()
	for item in [_objective_card, _resource_card]: item.minimum_size_changed.connect(_schedule_layout)
	_hud.visibility_changed.connect(queue_redraw)
	_menu = Control.new()
	_named(_menu, "Menu", self)
	_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_menu()
	_built = true
	resized.connect(_schedule_layout)
	get_window().size_changed.connect(_schedule_layout)
	_apply_layout()

func _draw() -> void:
	if not _built or not _hud.visible: return
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color(NAVY, 0.86)
	backing.set_corner_radius_all(6)
	draw_style_box(backing, _objective_card.get_rect().grow(6))
	draw_style_box(backing, _resource_card.get_rect().grow(6))

func _named(node: Node, node_name: String, parent: Node) -> void:
	node.name = node_name
	parent.add_child(node)
	node.owner = self
	node.unique_name_in_owner = true

func _label(parent: Node, value: String, font_size: int, unique_name := "") -> Label:
	var label := Label.new()
	label.text = value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color", WHITE)
	label.add_theme_color_override("font_shadow_color", Color(0.01, 0.04, 0.08, 0.95))
	label.add_theme_constant_override("shadow_offset_y", 1)
	_font_nodes[label] = font_size
	if unique_name.is_empty(): parent.add_child(label)
	else: _named(label, unique_name, parent)
	return label

func _column(parent: Node, separation := 8) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", separation)
	parent.add_child(column)
	return column

func _panel(parent: Node) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(NAVY, 0.94)
	style.border_color = Color(CYAN, 0.25)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	for edge in ["left", "right", "top", "bottom"]: style.set("content_margin_" + edge, 14)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(panel)
	return panel

func _button(parent: Node, node_name: String, value: String, primary := false) -> Button:
	var button := Button.new()
	button.text = value
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_font_nodes[button] = 16
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(CYAN, 0.94) if primary else Color(NAVY, 0.93)
		style.border_color = CYAN if state in ["hover", "pressed", "focus"] else Color(CYAN, 0.4)
		style.set_border_width_all(2 if state == "focus" else 1)
		style.set_corner_radius_all(6)
		style.content_margin_left = 8
		style.content_margin_right = 8
		button.add_theme_stylebox_override(state, style)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: button.add_theme_color_override(state, NAVY if primary else WHITE)
	_named(button, node_name, parent)
	_buttons.append(button)
	return button

func _build_menu() -> void:
	_hero = _column(_menu, 8)
	_label(_hero, "ELYSIUM / MARS", 13)
	_title = _label(_hero, Branding.title(), 64)
	_label(_hero, Branding.subtitle(), 18)
	_tagline = _label(_hero, "A world to explore. A crew to protect.", 17)
	_menu_scroll = ScrollContainer.new()
	_menu_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_menu_scroll.follow_focus = true
	_menu.add_child(_menu_scroll)
	_menu_card = _panel(_menu_scroll)
	_menu_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var content := _column(_menu_card)
	_primary = _column(content, 10)
	_label(_primary, "YOUR FIRST MISSION", 13)
	_label(_primary, "Guide Mira home. Save base power.\nKeep the crew safe through the storm.", 16, "MissionBrief")
	_button(_primary, "Begin", "Start mission", true)
	_button(_primary, "Explore", "Explore · no timer")
	_button(_primary, "More", "Learn & more").pressed.connect(func(): show_more(true))
	_secondary = _column(content, 8)
	_button(_secondary, "MoreBack", "← Back").pressed.connect(func(): show_more(false))
	_button(_secondary, "Academy", "Learn with Mira")
	_button(_secondary, "EVAMission", "Outdoor EVA mission")
	_button(_secondary, "Guide", "Field guide")
	_button(_secondary, "SuitLab", "Explorer suit lab")
	_button(_secondary, "HabitatNotes", "Habitat field notes")
	_button(_secondary, "Updates", "Game updates")
	_button(_secondary, "Sound", "SOUND: ON")
	_secondary.hide()

func _unhandled_input(event: InputEvent) -> void:
	if _menu.visible and _secondary.visible and event.is_action_pressed("ui_cancel"):
		show_more(false)
		get_viewport().set_input_as_handled()

func show_more(open: bool) -> void:
	_primary.visible = not open
	_secondary.visible = open
	_menu_scroll.scroll_vertical = 0
	get_node("%MoreBack" if open else "%More").grab_focus.call_deferred()
	_schedule_layout()

func _build_hud() -> void:
	_objective_card = _column(_hud, 5)
	_label(_objective_card, "YOUR NEXT STEP", 12)
	_label(_objective_card, "Inspect the solar array", 21, "Objective")
	_resource_card = _column(_hud, 4)
	var gauges := HBoxContainer.new()
	_resource_card.add_child(gauges)
	_base_gauge = BatteryGauge.new()
	_base_gauge.title = "BASE"
	_base_gauge.capacity = 12
	_suit_gauge = BatteryGauge.new()
	_suit_gauge.title = "SUIT"
	_suit_gauge.capacity = 0.9
	for gauge in [_base_gauge, _suit_gauge]:
		gauge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		gauges.add_child(gauge)
	var exposure := _label(_resource_card, "Exposure 0.00 mSv", 13, "Metrics")
	exposure.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_button(_resource_card, "Details", "Details").pressed.connect(toggle_details)
	_reticle = _label(_hud, "·", 24)
	_reticle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt = _label(_hud, "", 17, "Prompt")
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_radio_card = _panel(_hud)
	var detail_scroll := ScrollContainer.new()
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_scroll.follow_focus = true
	detail_scroll.focus_mode = Control.FOCUS_ALL
	detail_scroll.get_v_scroll_bar().focus_mode = Control.FOCUS_ALL
	_radio_card.add_child(detail_scroll)
	var details := _column(detail_scroll)
	_label(details, "MISSION DETAILS", 13)
	_label(details, "", 14, "Clock")
	_label(details, "", 15, "Radio")
	_label(details, "P compares plans · F1 opens the guide\nBattery and dose limits are game assumptions.", 13)
	_radio_card.hide()
	_action_row = HBoxContainer.new()
	_action_row.add_theme_constant_override("separation", 8)
	_hud.add_child(_action_row)
	_button(_action_row, "PanelCleaning", "1 · Clean panels")
	_button(_action_row, "SavePower", "2 · Save power")
	_button(_action_row, "FindShelter", "3 · Find refuge")
	_hint = _label(_hud, "WASD move · E inspect · Q visor · Tab controls", 13, "ControlHint")
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func toggle_details() -> void:
	_details_visible = not _details_visible
	_radio_card.visible = _details_visible
	get_node("%Details").text = "Hide details" if _details_visible else "Details"
	_schedule_layout()

func set_readings(base: float, suit: float, _dose: float, _time: float, _sheltered: bool, cleaning: bool, conserving: bool) -> void:
	_base_gauge.value = base
	_suit_gauge.value = suit
	_base_gauge.queue_redraw()
	_suit_gauge.queue_redraw()
	get_node("%PanelCleaning").text = "1 · Cleaner " + ("ON" if cleaning else "OFF")
	get_node("%SavePower").text = "2 · Save " + ("ON" if conserving else "OFF")

func set_operator_mode(enabled: bool) -> void:
	_operator_mode = enabled
	_suit_gauge.title = "MIRA SUIT" if enabled else "SUIT"
	get_node("%FindShelter").disabled = false
	get_node("%FindShelter").text = "3 · Guide Mira" if enabled else "3 · Find refuge"
	get_node("%MissionBrief").text = "Guide Mira home. Save base power.\nKeep the crew safe through the storm." if enabled else "Inspect the array. Save power.\nReach the refuge when warned."
	set_control_mode(_control_mode)
	_suit_gauge.queue_redraw()

func set_rescue_phase(phase: String, tour: bool) -> void:
	if not _operator_mode: return
	var labels := {"waiting": "3 · Guide Mira", "walking": "Mira returning", "cycling": "Airlock cycling", "entering": "Mira entering", "protected": "Mira safe", "halted": "Rescue paused"}
	get_node("%FindShelter").text = labels.get(phase, "3 · Guide Mira")
	get_node("%FindShelter").disabled = tour or phase != "waiting"

func set_control_mode(enabled: bool) -> void:
	_control_mode = enabled
	_hint.text = "PAUSED · Choose a control · Esc returns to walking" if enabled else ("WASD room · mouse look · Tab controls" if _operator_mode else "WASD move · E inspect · Q visor · Tab controls")
	_reticle.visible = not enabled

func _schedule_layout() -> void:
	if not _built or _layout_pending: return
	_layout_pending = true
	_apply_layout.call_deferred()

func _rect(control: Control, pos: Vector2, extent: Vector2) -> void:
	control.position = pos
	control.size = extent

func _apply_layout() -> void:
	_layout_pending = false
	if not _built: return
	queue_redraw()
	var physical := Vector2(get_window().size)
	if DisplayServer.get_name() == "headless" and physical == Vector2(64,64): physical = size
	var scale_factor := maxf(1, size.x / maxf(1, physical.x))
	var portrait := physical.y > physical.x
	var compact := physical.y < 520
	var margin := 16.0 * scale_factor
	for node in _font_nodes: node.add_theme_font_size_override("font_size", roundi(float(_font_nodes[node]) * scale_factor))
	for button in _buttons: button.custom_minimum_size = Vector2(44,48) * scale_factor
	_title.add_theme_font_size_override("font_size", roundi((42 if compact or portrait else 64) * scale_factor))
	_tagline.visible = not compact
	var hero_width := size.x - 2 * margin if portrait else size.x * 0.5 - margin
	_rect(_hero, Vector2(margin, margin), Vector2(hero_width, 130 * scale_factor))
	var menu_width := size.x - 2 * margin if portrait else minf(360 * scale_factor, size.x * 0.46)
	var menu_height := minf(286 * scale_factor, size.y - 2 * margin) if not portrait else minf(380 * scale_factor, size.y - 230 * scale_factor)
	var menu_x := size.x - margin - menu_width if compact else margin
	_rect(_menu_scroll, Vector2(menu_x, size.y - margin - menu_height), Vector2(menu_width, menu_height))
	var objective_width := size.x - 2 * margin if portrait else minf(420 * scale_factor, size.x - 260 * scale_factor - 2 * margin)
	_rect(_objective_card, Vector2(margin, margin), Vector2(objective_width, 70 * scale_factor))
	var resource_width := 210 * scale_factor
	for gauge in [_base_gauge, _suit_gauge]:
		gauge.scale_factor = scale_factor
		gauge.custom_minimum_size = Vector2(85,92) * scale_factor
		gauge.queue_redraw()
	_rect(_resource_card, Vector2(margin if portrait else size.x - margin - resource_width, (100 * scale_factor if portrait else margin)), Vector2(resource_width, 160 * scale_factor))
	var actions_width := minf(size.x - margin * 2, 640 * scale_factor)
	_rect(_action_row, Vector2((size.x - actions_width) / 2, size.y - margin - 52 * scale_factor), Vector2(actions_width,52 * scale_factor))
	_rect(_hint, Vector2(margin, size.y - margin - 80 * scale_factor), Vector2(size.x - 2 * margin, 24 * scale_factor))
	_rect(_reticle, size * 0.5 - Vector2(10,16) * scale_factor, Vector2(20,32) * scale_factor)
	_rect(_prompt, Vector2(margin, size.y - margin - 135 * scale_factor), Vector2(size.x - 2 * margin, 48 * scale_factor))
	var details_width := minf(440 * scale_factor, size.x - 2 * margin)
	_radio_card.size.x = details_width
	var details_height := minf(220 * scale_factor, maxf(100 * scale_factor, size.y - 250 * scale_factor))
	_rect(_radio_card, Vector2(margin, size.y - margin - 145 * scale_factor - details_height), Vector2(details_width,details_height))
