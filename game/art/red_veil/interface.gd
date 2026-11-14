extends Control
const Branding = preload("res://scripts/branding.gd")
## Presentation-only HUD. The game controller owns every action and reading.
@export var ivory := Color("f1e6d2")
@export var coral := Color("ff785f")
@export var cyan := Color("91e7e7")
@export var ruby := Color("4b1c2a")
var _supplied_theme: Theme
var _font := SystemFont.new()
var _semibold := SystemFont.new()
var _font_nodes: Dictionary = {}
var _spacing_nodes: Dictionary = {}
var _built := false
var _layout_pending := false
var _menu: Control
var _hud: Control
var _hero: VBoxContainer
var _menu_scroll: ScrollContainer
var _menu_card: PanelContainer
var _menu_content: VBoxContainer
var _menu_grid: GridContainer
var _menu_footer: Label
var _objective_card: PanelContainer
var _resource_card: PanelContainer
var _radio_card: PanelContainer
var _prompt: Label
var _reticle: Label
var _buttons: Array[Button] = []
var _menu_copy: Array[Label] = []
var _tagline: Label
var _title: Label

func configure(profile: Resource = null, supplied_theme: Theme = null) -> void:
	# Call before adding the scene to the tree. No gameplay values are read here.
	_supplied_theme = supplied_theme
	if profile != null:
		if profile.get("hull_color") is Color: ivory = profile.get("hull_color")
		if profile.get("route_color") is Color: coral = profile.get("route_color")
		if profile.get("instrument_color") is Color: cyan = profile.get("instrument_color")
		if profile.get("structure_color") is Color: ruby = profile.get("structure_color")

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font.font_names = PackedStringArray(["Inter", "Aptos", "Helvetica Neue", "Arial", "Noto Sans"])
	_font.font_weight = 400
	_semibold.font_names = _font.font_names
	_semibold.font_weight = 600
	theme = _supplied_theme if _supplied_theme else Theme.new()
	if _supplied_theme == null: theme.default_font = _font
	var visor := ColorRect.new()
	visor.color = Color(0.55, 0.3, 0.12, 0.0)
	visor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_named(visor, "Visor", self)
	visor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud = Control.new()
	_named(_hud, "HUD", self)
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_hud()
	for card in [_objective_card, _resource_card, _radio_card]:
		card.minimum_size_changed.connect(_schedule_layout)
	_menu = Control.new()
	_named(_menu, "Menu", self)
	_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_menu()
	_menu.visibility_changed.connect(queue_redraw)
	_built = true
	resized.connect(_schedule_layout)
	_apply_layout()
	_schedule_layout()
	queue_redraw()

func _draw() -> void:
	if not _built or not _menu.visible: return
	var top := Vector2(size.x - 88, 30)
	for row in range(2):
		for column in range(3):
			var center := top + Vector2(column * 18 + row * 9, row * 9)
			draw_arc(center, 8, PI, TAU, 20, Color(0.85, 0.71, 0.46, 0.45), 1.0, true)
			draw_arc(center, 5, PI, TAU, 20, Color(0.85, 0.71, 0.46, 0.35), 1.0, true)

func _named(node: Node, node_name: String, parent: Node) -> void:
	node.name = node_name
	parent.add_child(node)
	node.owner = self
	node.unique_name_in_owner = true

func _label(parent: Node, value: String, size_px: int, color: Color, bold: bool = false, unique_name: String = "") -> Label:
	var node := Label.new()
	node.text = value
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.add_theme_color_override("font_color", color)
	node.add_theme_font_override("font", _semibold if bold else _font)
	node.add_theme_font_size_override("font_size", size_px)
	_font_nodes[node] = size_px
	if unique_name.is_empty(): parent.add_child(node)
	else: _named(node, unique_name, parent)
	return node

func _column(parent: Node, separation: int = 8) -> VBoxContainer:
	var node := VBoxContainer.new()
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_constant_override("separation", separation)
	_spacing_nodes[node] = separation
	parent.add_child(node)
	return node

func _glass(parent: Node, tint: Color, opacity: float, border: Color) -> PanelContainer:
	var node := PanelContainer.new()
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(tint, opacity)
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(16)
	style.corner_detail = 8
	for side in ["left", "top", "right", "bottom"]: style.set("content_margin_" + side, 16.0)
	style.shadow_color = Color(0.02, 0.01, 0.02, 0.16)
	style.shadow_size = 8
	node.add_theme_stylebox_override("panel", style)
	parent.add_child(node)
	return node

func _button(parent: Node, node_name: String, value: String, primary: bool = false) -> Button:
	var node := Button.new()
	node.text = value
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	node.add_theme_font_override("font", _semibold if primary else _font)
	node.add_theme_font_size_override("font_size", 16)
	_font_nodes[node] = 16
	var style := StyleBoxFlat.new()
	style.bg_color = coral if primary else Color(ivory, 0.055)
	style.border_color = Color(coral if primary else ivory, 0.85 if primary else 0.24)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.corner_detail = 8
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	node.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = coral.lightened(0.12) if primary else Color(cyan, 0.16)
	hover.border_color = coral.lightened(0.2) if primary else Color(cyan, 0.7)
	node.add_theme_stylebox_override("hover", hover)
	var pressed := style.duplicate() as StyleBoxFlat
	pressed.bg_color = coral.darkened(0.12) if primary else Color(cyan, 0.24)
	node.add_theme_stylebox_override("pressed", pressed)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = cyan
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(10)
	node.add_theme_stylebox_override("focus", focus)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		node.add_theme_color_override(state, Color("291b22") if primary else ivory)
	_named(node, node_name, parent)
	_buttons.append(node)
	return node

func _build_menu() -> void:
	_hero = _column(_menu, 6)
	_label(_hero, "ELYSIUM OUTPOST  /  SOL 018", 13, Color("d9b475"), true)
	var title := _label(_hero, Branding.title(), 64, ivory, true)
	_title = title
	_label(_hero, Branding.subtitle(), 16, cyan, true)
	title.add_theme_color_override("font_shadow_color", Color(0.12, 0.04, 0.05, 0.28))
	title.add_theme_constant_override("shadow_offset_y", 2)
	_tagline = _label(_hero, "A little wonder. A world to protect.", 18, ivory)
	_menu_scroll = ScrollContainer.new()
	_menu_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_menu_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_menu_scroll.follow_focus = true
	_menu.add_child(_menu_scroll)
	_menu_card = _glass(_menu_scroll, Color("241d25"), 0.76, Color(coral, 0.38))
	_menu_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_menu_content = _column(_menu_card, 9)
	_menu_copy.append(_label(_menu_content, "YOUR FIRST MISSION", 12, cyan, true))
	_menu_copy.append(_label(_menu_content, "Bring the crew home.", 24, ivory, true))
	_menu_copy.append(_label(_menu_content, "Inspect the array. Protect your suit.\nFind shelter when the warning arrives.", 16, Color(ivory, 0.92)))
	_button(_menu_content, "Begin", "BEGIN MISSION", true)
	_button(_menu_content, "Explore", "EXPLORE THE HABITAT")
	_menu_grid = GridContainer.new()
	_menu_grid.columns = 2
	_menu_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_menu_grid.add_theme_constant_override("h_separation", 8)
	_menu_grid.add_theme_constant_override("v_separation", 8)
	_menu_content.add_child(_menu_grid)
	_button(_menu_grid, "Guide", "FIELD GUIDE")
	_button(_menu_grid, "Academy", "MIRA’S ACADEMY")
	_button(_menu_grid, "Updates", "UPDATES")
	_button(_menu_grid, "Sound", "SOUND: ON")
	_menu_footer = _label(_menu, "AGES 7–12   •   A FOUR-MINUTE MISSION   •   EXPLORE AT YOUR PACE", 11, Color(ivory, 0.85))

func _build_hud() -> void:
	_objective_card = _glass(_hud, Color("192429"), 0.63, Color(cyan, 0.26))
	var mission_column := _column(_objective_card, 5)
	_label(mission_column, "AEGIS  /  FIELD MISSION", 12, cyan, true)
	_label(mission_column, "Inspect the solar array", 21, ivory, true, "Objective")
	_label(mission_column, "SOL 018  •  00:00 / 12:00", 13, Color(ivory, 0.8), false, "Clock")
	_resource_card = _glass(_hud, Color("192429"), 0.63, Color(cyan, 0.26))
	var resource_column := _column(_resource_card, 5)
	_label(resource_column, "YOUR RESERVES", 12, cyan, true)
	_label(resource_column, "HABITAT  8.0 / 12 kWh\nSUIT          0.90 / 0.90 kWh\nDOSE       0.00 / 4 mSv*", 16, ivory, false, "Metrics")
	_reticle = _label(_hud, "+", 22, Color(ivory, 0.7))
	_reticle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt = _label(_hud, "", 18, ivory, true, "Prompt")
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_color_override("font_shadow_color", Color(0.01, 0.01, 0.01, 0.9))
	_prompt.add_theme_constant_override("shadow_offset_y", 2)
	_radio_card = _glass(_hud, Color("192429"), 0.68, Color(cyan, 0.26))
	var radio_column := _column(_radio_card, 5)
	_label(radio_column, "MIRA  /  CREW RADIO", 12, cyan, true)
	_label(radio_column, "Follow the lights to the solar array. I’ll stay on the radio.", 17, ivory, false, "Radio")

func _schedule_layout() -> void:
	if not _built or _layout_pending: return
	_layout_pending = true
	_apply_layout.call_deferred()

func _rect(control: Control, position_value: Vector2, size_value: Vector2) -> void:
	control.position = position_value
	control.size = size_value

func _apply_layout() -> void:
	_layout_pending = false
	if not _built: return
	queue_redraw()
	var bounds := size
	if bounds.x < 1 or bounds.y < 1: return
	var portrait := bounds.y > bounds.x
	var physical_size := Vector2(get_window().size)
	# Headless Godot uses a synthetic 64×64 window until a test sets its
	# viewport. It is not a physical display or a reason to magnify fonts 20×.
	if DisplayServer.get_name() == "headless" and physical_size == Vector2(64, 64):
		physical_size = bounds
	var compact := not portrait and physical_size.y < 520
	_tagline.visible = not compact
	for label in _menu_copy: label.visible = not compact
	var begin_button := get_node("%Begin") as Button
	var explore_button := get_node("%Explore") as Button
	if compact and begin_button.get_parent() != _menu_grid:
		begin_button.reparent(_menu_grid)
		explore_button.reparent(_menu_grid)
		_menu_grid.move_child(begin_button, 0)
		_menu_grid.move_child(explore_button, 1)
	elif not compact and begin_button.get_parent() != _menu_content:
		begin_button.reparent(_menu_content)
		explore_button.reparent(_menu_content)
		_menu_content.move_child(begin_button, 3)
		_menu_content.move_child(explore_button, 4)
	# Canvas-items stretching can keep a large logical width on a phone. Scaling
	# by portrait width preserves readable physical sizing without fixed offsets.
	var ui_scale := maxf(1.0, bounds.x / maxf(1.0, physical_size.x))
	var margin := 20.0 * ui_scale if portrait else 30.0 * ui_scale
	for node in _font_nodes:
		node.add_theme_font_size_override("font_size", maxi(11, roundi(float(_font_nodes[node]) * ui_scale)))
	for node in _spacing_nodes:
		node.add_theme_constant_override("separation", roundi(float(_spacing_nodes[node]) * ui_scale))
	for node in _buttons: node.custom_minimum_size.y = 44.0 * ui_scale
	_menu_grid.add_theme_constant_override("h_separation", roundi(8.0 * ui_scale))
	_menu_grid.add_theme_constant_override("v_separation", roundi(8.0 * ui_scale))
	for card in [_menu_card, _objective_card, _resource_card, _radio_card]:
		var style: StyleBoxFlat = card.get_theme_stylebox("panel")
		for side in ["left", "top", "right", "bottom"]: style.set("content_margin_" + side, 15.0 * ui_scale)
	var hero_width := bounds.x - margin * 2 if portrait else minf(550.0 * ui_scale, bounds.x - margin * 2)
	_title.add_theme_font_size_override("font_size", roundi((42.0 if compact else 64.0) * ui_scale))
	var hero_height := (80.0 if compact else 120.0) * ui_scale
	_rect(_hero, Vector2(margin, margin), Vector2(hero_width, hero_height))
	var card_width := bounds.x - margin * 2 if portrait else minf(420.0 * ui_scale, bounds.x - margin * 2)
	var footer_height := 26.0 * ui_scale
	var available := maxf(100.0, bounds.y - hero_height - margin * 3 - footer_height)
	var card_height := minf(365.0 * ui_scale, available)
	_menu_card.custom_minimum_size.x = 0
	_menu_card.size.x = card_width - 14.0 * ui_scale
	_rect(_menu_scroll, Vector2(margin, bounds.y - margin - footer_height - card_height), Vector2(card_width, card_height))
	_rect(_menu_footer, Vector2(margin, bounds.y - margin - footer_height + 8.0 * ui_scale), Vector2(card_width, footer_height))
	var mission_width := bounds.x - margin * 2 if portrait else minf(400.0 * ui_scale, bounds.x * 0.43)
	var resource_width := bounds.x - margin * 2 if portrait else minf(290.0 * ui_scale, bounds.x * 0.34)
	_rect(_objective_card, Vector2(margin, margin), Vector2(mission_width, 106.0 * ui_scale))
	_rect(_resource_card, Vector2(margin if portrait else bounds.x - margin - resource_width, margin + _objective_card.size.y + 14.0 * ui_scale if portrait else margin), Vector2(resource_width, 116.0 * ui_scale))
	_rect(_reticle, bounds * 0.5 - Vector2(12, 16) * ui_scale, Vector2(24, 32) * ui_scale)
	_rect(_prompt, Vector2(margin, bounds.y * 0.61), Vector2(bounds.x - margin * 2, 74.0 * ui_scale))
	var radio_width := bounds.x - margin * 2 if portrait else minf(650.0 * ui_scale, bounds.x * 0.6)
	_radio_card.size.x = radio_width
	var radio_height := maxf(102.0 * ui_scale, _radio_card.get_combined_minimum_size().y)
	_rect(_radio_card, Vector2(margin, bounds.y - margin - radio_height), Vector2(radio_width, radio_height))
