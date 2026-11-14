extends Control
## Data-driven architecture tour. This overlay never changes mission physics.
signal closed
const VisualStyle = preload("res://scripts/visual_style.gd")
var _closed := false
var camera: Camera3D
var points: Array = []
var selected := 0
var _card: PanelContainer
var _heading: Label
var _body: Label
var _feedback: Label
var _question: Label
var _answers: VBoxContainer
var _tabs: HFlowContainer
var _done: Button
var _scale := 1.0
const LESSONS := {
	"habitat_dome": {"question": "What keeps breathable air around the crew?", "answers": ["A sealed pressure structure", "The glowing red paint"], "correct": 0, "explanation": "A pressure structure and seals hold air. Insulation slows heat flow. The lacquer and patterns are visual design; they do not make oxygen or block all radiation."},
	"observation_windows": {"question": "During a particle warning, what is the safest plan in this mission?", "answers": ["Stay beside the pretty glass", "Go to the marked shielded refuge"], "correct": 1, "explanation": "Transparent windows need engineered protection. Move to the marked refuge before the event. The viewing opening in this alpha is not a sealed, certified window or a working radiation shutter."},
	"regolith_shielding": {"question": "Why might a habitat use a mound of local soil?", "answers": ["Its colour cancels radiation", "Material adds shielding mass"], "correct": 1, "explanation": "Regolith is loose surface material. Added mass can reduce exposure and moderate temperature changes. Protection depends on depth, composition and particle energy; there is no universal percent per shovel."},
	"airlock": {"question": "How should an airlock connect two different pressures?", "answers": ["Open both doors together", "Seal one door before cycling pressure"], "correct": 1, "explanation": "An airlock isolates a small chamber. Seal one door, change chamber pressure, then open the other. This architectural tour does not simulate pressure or operate an airlock cycle."}
}

func _ready() -> void:
	name = "HabitatInspector"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_card = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(VisualStyle.color("wine"), 0.94)
	style.border_color = VisualStyle.color("rose_gold")
	style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	for side in ["left", "top", "right", "bottom"]: style.set("content_margin_" + side, 16)
	_card.add_theme_stylebox_override("panel", style)
	add_child(_card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_card.add_child(column)
	_heading = _label(column, "HABITAT FIELD NOTES", 23)
	var scroll := ScrollContainer.new()
	scroll.name = "LessonScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	column.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 14)
	scroll.add_child(content)
	_tabs = HFlowContainer.new()
	content.add_child(_tabs)
	for index in range(points.size()):
		var short_names := {"habitat_dome": "Shell", "observation_windows": "Windows", "regolith_shielding": "Regolith", "airlock": "Airlock"}
		var tab := _button(_tabs, str(index + 1) + " · " + str(short_names.get(points[index].id, points[index].title)))
		tab.pressed.connect(select.bind(index))
	_body = _label(content, "", 18)
	_question = _label(content, "", 19)
	_answers = VBoxContainer.new()
	content.add_child(_answers)
	_feedback = _label(content, "Choose an answer to explore the science.", 17)
	_done = _button(column, "BACK TO EXPLORING")
	_done.name = "Close"
	_done.pressed.connect(close)
	resized.connect(_layout)
	_layout()
	if not points.is_empty(): select(0)
	_done.grab_focus.call_deferred()

func _label(parent: Node, value: String, pixels: int) -> Label:
	var result := Label.new()
	result.text = value
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result.add_theme_font_size_override("font_size", pixels)
	result.add_theme_color_override("font_color", VisualStyle.color("white"))
	parent.add_child(result)
	return result

func _button(parent: Node, value: String) -> Button:
	var result := Button.new()
	result.text = value
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.custom_minimum_size.y = 48
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result.add_theme_font_size_override("font_size", 17)
	parent.add_child(result)
	return result

func _layout() -> void:
	if not is_instance_valid(_card): return
	_scale = maxf(1.0, size.x / maxf(1.0, get_window().size.x))
	var margin := 16.0 * _scale
	var portrait := size.y > size.x
	_card.size = Vector2(minf(size.x - margin * 2, 440.0 * _scale), size.y - margin * 2)
	if portrait: _card.size.y = size.y * 0.62
	_card.position = Vector2(size.x - _card.size.x - margin, size.y - _card.size.y - margin)
	for control in find_children("*", "Button", true, false):
		control.custom_minimum_size.y = 48 * _scale
		control.add_theme_font_size_override("font_size", roundi(16 * _scale))
	for control in [_body, _question, _feedback]: control.add_theme_font_size_override("font_size", roundi(17 * _scale))
	_heading.add_theme_font_size_override("font_size", roundi(21 * _scale))
	queue_redraw()

func select(index: int) -> void:
	if index < 0 or index >= points.size(): return
	selected = index
	var point: Dictionary = points[index]
	_heading.text = str(point.title)
	_body.text = str(point.text)
	var lesson: Dictionary = LESSONS.get(point.id, {})
	_question.text = str(lesson.get("question", ""))
	_feedback.text = "Choose an answer to explore the science."
	for child in _answers.get_children():
		_answers.remove_child(child)
		child.queue_free()
	for answer in range(lesson.get("answers", []).size()):
		var choice := _button(_answers, lesson.answers[answer])
		choice.pressed.connect(answer_question.bind(answer))
	_layout()

func answer_question(answer: int) -> void:
	var lesson: Dictionary = LESSONS.get(points[selected].id, {})
	if lesson.is_empty(): return
	_feedback.text = ("Exactly. " if answer == int(lesson.correct) else "Try this idea: ") + str(lesson.explanation)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(camera) or not is_instance_valid(_card): return
	for index in range(points.size()):
		var world_point: Vector3 = points[index].position
		if camera.is_position_behind(world_point): continue
		var screen := camera.unproject_position(world_point)
		if not Rect2(Vector2.ZERO, size).has_point(screen) or _card.get_rect().has_point(screen): continue
		var tint := Color("ffe1c0") if index == selected else Color(1, 1, 1, 0.5)
		draw_circle(screen, 5 * _scale, tint)
		if index == selected:
			var end := _card.position + Vector2(0, 32 * _scale)
			var elbow := Vector2(end.x - 24 * _scale, end.y)
			draw_line(screen, elbow, tint, 1.5 * _scale, true)
			draw_line(elbow, end, tint, 1.5 * _scale, true)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and is_instance_valid(camera):
		for index in range(points.size()):
			var point: Vector3 = points[index].position
			if not camera.is_position_behind(point) and camera.unproject_position(point).distance_to(event.position) < 24 * _scale:
				select(index)
				accept_event()
	if event is InputEventScreenTouch and event.pressed and is_instance_valid(camera):
		for index in range(points.size()):
			var point: Vector3 = points[index].position
			if not camera.is_position_behind(point) and camera.unproject_position(point).distance_to(event.position) < 24 * _scale:
				select(index)
				accept_event()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()

func close() -> void:
	if _closed: return
	_closed = true
	closed.emit()
	queue_free()
