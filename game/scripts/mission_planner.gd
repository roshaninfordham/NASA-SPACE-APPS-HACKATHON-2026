extends Control
## Pure report presentation. The game controller owns any accepted switch changes.
signal closed
signal plan_selected(conserving: bool, cleaning: bool)
const Branding = preload("res://scripts/branding.gd")
const VisualStyle = preload("res://scripts/visual_style.gd")
var report: Dictionary = {}
var allow_apply := false
var selected := 0
var back_button: Button
var apply_button: Button
var details_button: Button
var option_buttons: Array[Button] = []
var chart: BatteryChart
var _margin: MarginContainer
var _scroll: ScrollContainer
var _options_grid: GridContainer
var _outcome: Label
var _detail: Label
var _closed := false
var _layout_pending := false

class BatteryChart extends Control:
	var options: Array = []
	var selected := 0
	var starting_energy := -1.0
	var capacity := 12.0
	var ui_scale := 1.0
	func _draw() -> void:
		var left := 42.0 * ui_scale
		var top := 18.0 * ui_scale
		var bottom := size.y - 34.0 * ui_scale
		var height := maxf(1, bottom - top)
		var width := maxf(1, size.x - left - 14 * ui_scale)
		var font := ThemeDB.fallback_font
		var font_size := roundi(13 * ui_scale)
		for energy in [0.0, capacity / 2.0, capacity]:
			var y: float = bottom - float(energy) / capacity * height
			draw_line(Vector2(left, y), Vector2(left + width, y), Color("66505b"), ui_scale)
			draw_string(font, Vector2(0, y + 5 * ui_scale), str(energy), HORIZONTAL_ALIGNMENT_LEFT, left, font_size, Color("f5e7e4"))
		if options.is_empty(): return
		var cell := width / options.size()
		for index in range(options.size()):
			var energy := clampf(float(options[index].get("habitat_kwh", 0)), 0, capacity)
			var bar_height := energy / capacity * height
			var x := left + cell * index + cell * 0.18
			var rect := Rect2(Vector2(x, bottom - bar_height), Vector2(cell * 0.64, bar_height))
			draw_rect(rect, Color("67e8f0") if index == selected else Color("ad6f86"))
			draw_string(font, Vector2(left + cell * index, bottom + 23 * ui_scale), "Plan " + str(index + 1) + ("*" if not bool(options[index].get("reaches_horizon", true)) else ""), HORIZONTAL_ALIGNMENT_CENTER, cell, font_size, Color("f5e7e4"))
		if starting_energy >= 0:
			var y := bottom - clampf(starting_energy, 0, capacity) / capacity * height
			draw_dashed_line(Vector2(left, y), Vector2(left + width, y), Color("ffb067"), 2 * ui_scale, 5 * ui_scale)

func _ready() -> void:
	name = "MissionPlanner"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_style()
	var background := ColorRect.new()
	background.color = VisualStyle.color("wine").darkened(0.5)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	_margin = MarginContainer.new()
	_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	_margin.add_child(layout)
	var header := HBoxContainer.new()
	layout.add_child(header)
	var heading := _label(header, Branding.display_name() + "\nAEGIS · MISSION PLANNER", 21)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back_button = _button(header, "Back", close)
	back_button.name = "Back"
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	_scroll = ScrollContainer.new()
	_scroll.name = "PlannerScroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(_scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 12)
	_scroll.add_child(column)
	_label(column, "Choose how your base uses power", 23)
	_label(column, "Try a plan. Compare battery and research, then choose. Essential life support still needs power in every plan.", 18)
	var safety_note := str(report.get("safety_note", "Refuge and suit safety need separate decisions."))
	if not safety_note.is_empty(): _label(column, safety_note, 18)
	_label(column, "SCENARIO PREVIEW · %.1f simulated hour(s). Your mission is paused." % float(report.get("horizon_hours", 1.0)), 15)
	_options_grid = GridContainer.new()
	_options_grid.columns = 2
	_options_grid.add_theme_constant_override("h_separation", 10)
	_options_grid.add_theme_constant_override("v_separation", 10)
	column.add_child(_options_grid)
	var options: Array = report.get("options", [])
	for index in range(options.size()):
		var option: Dictionary = options[index]
		var control := _button(_options_grid, "Plan %d · %s" % [index + 1, str(option.get("label", "Compare")) + (" (current)" if bool(option.get("current", false)) else "")], select_option.bind(index))
		control.name = "Plan%d" % index
		control.toggle_mode = true
		option_buttons.append(control)
	_label(column, "Habitat battery after the preview · kWh", 19)
	chart = BatteryChart.new()
	chart.name = "BatteryChart"
	chart.options = report.get("options", [])
	chart.starting_energy = float(report.get("initial_habitat_kwh", -1.0))
	chart.capacity = maxf(0.01, float(report.get("habitat_capacity_kwh", 12.0)))
	column.add_child(chart)
	_label(column, "Each bar is one plan. Taller means more stored energy, not a better score. A * marks a plan that stops early." + (" Amber dashes show the starting battery." if chart.starting_energy >= 0 else ""), 15)
	details_button = _button(column, "Show the maths and assumptions", toggle_details)
	details_button.name = "Details"
	_detail = _label(column, "", 16)
	_detail.name = "DetailText"
	_detail.hide()
	_outcome = _label(layout, "Choose a plan to see its trade-offs.", 16)
	_outcome.name = "Outcome"
	apply_button = _button(layout, "Use this plan", apply_selected)
	apply_button.name = "Apply"
	apply_button.disabled = not allow_apply or options.is_empty()
	if not allow_apply: apply_button.text = "Preview only · start a mission to use a plan"
	resized.connect(_schedule_layout)
	get_window().size_changed.connect(_schedule_layout)
	_schedule_layout()
	if not options.is_empty():
		var current_index := 0
		for index in range(options.size()):
			if bool(options[index].get("current", false)): current_index = index
		select_option(current_index)
	back_button.grab_focus.call_deferred()

func _label(parent: Node, value: String, pixels: int) -> Label:
	var result := Label.new()
	result.text = value
	result.set_meta("base_font", pixels)
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result.add_theme_color_override("font_color", VisualStyle.color("white"))
	parent.add_child(result)
	return result

func _button(parent: Node, value: String, action: Callable) -> Button:
	var result := Button.new()
	result.text = value
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result.custom_minimum_size = Vector2(44, 44)
	result.pressed.connect(action)
	parent.add_child(result)
	return result

func _schedule_layout() -> void:
	if _layout_pending: return
	_layout_pending = true
	_layout.call_deferred()

func _layout() -> void:
	_layout_pending = false
	if not is_instance_valid(_margin): return
	var ui_scale := maxf(1.0, size.x / maxf(1.0, get_window().size.x))
	for edge in ["left", "right", "top", "bottom"]: _margin.add_theme_constant_override("margin_" + edge, roundi(16 * ui_scale))
	for control in _margin.find_children("*", "Control", true, false):
		if control is Label: control.add_theme_font_size_override("font_size", roundi(float(control.get_meta("base_font", 16)) * ui_scale))
		if control is Button:
			control.custom_minimum_size = Vector2(44, 48) * ui_scale
			control.add_theme_font_size_override("font_size", roundi(16 * ui_scale))
	back_button.custom_minimum_size.x = 70 * ui_scale
	_options_grid.columns = 1 if size.x / ui_scale < 620 else 2
	chart.ui_scale = ui_scale
	chart.custom_minimum_size.y = 180 * ui_scale
	chart.queue_redraw()

func select_option(index: int) -> void:
	var options: Array = report.get("options", [])
	if index < 0 or index >= options.size(): return
	selected = index
	for option_index in range(option_buttons.size()): option_buttons[option_index].set_pressed_no_signal(option_index == index)
	var option: Dictionary = options[index]
	var work := "no field work in this preview" if float(option.get("research_gained", 0)) == 0 else "%.2f work-hours (game estimate)" % float(option.get("research_gained", 0))
	var status := str(option.get("status", "running"))
	var status_labels := {"running": "still running", "suit-abort": "suit battery empty", "power-abort": "habitat battery empty", "dose-abort": "dose limit reached", "success": "mission complete", "partial": "low reserve at finish"}
	_outcome.text = "Plan %d · Battery left: %.2f kWh\nResearch: %s\nPreview: %.2f / %.2f hours · %s" % [index + 1, float(option.get("habitat_kwh", 0)), work, float(option.get("elapsed_hours", 0)), float(report.get("horizon_hours", 1.0)), status_labels.get(status, status)]
	var assumptions: Variant = report.get("assumptions", [])
	var assumption_text := "\n".join(assumptions) if assumptions is Array or assumptions is PackedStringArray else str(assumptions)
	_detail.text = "Research work: %.2f hour-equivalents\n%s suit battery: %.2f kWh\nCumulative dose: %.3f mSv\nAdded dose: %.3f mSv\nSolar energy generated: %.2f kWh\nEnergy used: %.2f kWh\nBattery change: %+.2f kWh\n\n" % [float(option.get("research_gained", 0)), str(report.get("suit_subject", "Astronaut")), float(option.get("suit_kwh", 0)), float(option.get("dose_msv", 0)), float(option.get("dose_added_msv", 0)), float(option.get("generated_kwh", 0)), float(option.get("consumed_kwh", 0)), float(option.get("habitat_change_kwh", 0))] + str(report.get("summary", "")) + "\n\nAt each small time step: battery = previous battery + (solar power − electrical load) × time, limited to zero and the capacity shown on the chart.\nDose change = dose rate × time.\n\nThe power forecast runs the same scenario equations for every plan. It is not a real Mars forecast or a trained AI. Conserving power slows optional research while outdoors. No field research is counted while sheltered. Cleaning cannot remove airborne dust. The visor and refuge still need your separate attention.\n\n" + assumption_text
	chart.selected = selected
	chart.queue_redraw()

func toggle_details() -> void:
	_detail.visible = not _detail.visible
	details_button.text = "Hide the maths and assumptions" if _detail.visible else "Show the maths and assumptions"

func apply_selected() -> void:
	if _closed or not allow_apply or apply_button.disabled: return
	var options: Array = report.get("options", [])
	if selected < 0 or selected >= options.size(): return
	var option: Dictionary = options[selected]
	plan_selected.emit(bool(option.get("conserving", false)), bool(option.get("cleaning", false)))
	close()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()

func close() -> void:
	if _closed: return
	_closed = true
	closed.emit()
	queue_free()

func _apply_style() -> void:
	theme = Theme.new()
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box := StyleBoxFlat.new()
		box.bg_color = VisualStyle.color("teal_panel") if state == "normal" else VisualStyle.color("wine").lightened(0.12)
		box.border_color = VisualStyle.color("cyan") if state in ["hover", "focus", "pressed"] else VisualStyle.color("rose_gold").darkened(0.35)
		box.set_border_width_all(2 if state == "focus" else 1)
		box.set_corner_radius_all(8)
		box.content_margin_left = 12
		box.content_margin_right = 12
		theme.set_stylebox(state, "Button", box)
	for property in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]: theme.set_color(property, "Button", VisualStyle.color("white"))
