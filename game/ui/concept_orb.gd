extends Button
## One science concept, always identified by readable words and a vector glyph.
## Ring levels describe a model quantity or reading progress, never medical risk.
const Style = preload("res://ui/journey_style.gd")
const TITLES := {"radiation":"Radiation","dose":"Microgray","sievert":"Sievert","dust":"Dust","power":"Energy","time":"Time","speed":"Clean pace","shelter":"Shelter"}
var concept_id := ""
var title := ""
var level := 0.0
var status_text := "Explore"
var tone := "normal"
var reviewed := false
var reduced_motion := false
var measurement_scale := false
var _caption: Label
var _status: Label
var _backdrop: StyleBoxFlat

static func short_title(id: String, fallback: String = "Science") -> String:
	return TITLES.get(id,fallback)

func _ready() -> void:
	custom_minimum_size = Vector2(80, 104)
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_backdrop = Style.panel()
	_backdrop.bg_color = Color(Style.GLASS,0.97)
	_backdrop.border_color = Color(Style.CYAN,0.40)
	_backdrop.set_corner_radius_all(26)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_caption = Style.label(title, 20, Style.PEARL, "display_bold")
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(_caption)
	_status = Style.label(status_text, 16, Style.CYAN, "body_bold")
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(_status)
	resized.connect(_layout)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	_layout()

func configure(id: String, value: String, short_label: String = "") -> void:
	concept_id = id
	title = value
	if not short_label.is_empty(): status_text = short_label
	if is_instance_valid(_caption): _caption.text = title
	if is_instance_valid(_status): _status.text = status_text
	_update_accessible_description()
	queue_redraw()

func set_level(value: float, description: String, state: String = "normal") -> void:
	level = clampf(value, 0.0, 1.0)
	status_text = description
	tone = state
	if is_instance_valid(_status):
		_status.text = status_text
		_status.add_theme_color_override("font_color", _accent() if tone != "normal" else Style.CYAN)
	_update_accessible_description()
	queue_redraw()

func set_reviewed(value: bool) -> void:
	reviewed = value
	set_level(1.0 if value else 0.0, "Reviewed" if value else "Explore", "normal")

func set_measurement_scale(value: bool) -> void:
	measurement_scale = value
	queue_redraw()

func set_reduced_motion(value: bool) -> void:
	# No continuous motion is required for understanding any orb state.
	reduced_motion = value

func _update_accessible_description() -> void:
	tooltip_text = title + ": " + status_text + ". Open the science card."
	accessibility_name = title
	accessibility_description = status_text + ". Open the science card."

func _accent() -> Color:
	if tone == "caution": return Style.AMBER
	if tone == "danger": return Style.CORAL
	return Style.CYAN

func _layout() -> void:
	if not is_instance_valid(_caption): return
	var compact := size.y < 90.0
	var text_x := 48.0 if compact else 6.0
	var title_size := 15 if compact else (21 if size.x >= 155 else 18)
	var status_size := 13 if compact else (17 if size.x >= 155 else 15)
	_caption.add_theme_font_size_override("font_size",title_size)
	_status.add_theme_font_size_override("font_size",status_size)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if compact else HORIZONTAL_ALIGNMENT_CENTER
	_status.horizontal_alignment = _caption.horizontal_alignment
	_caption.position = Vector2(text_x, size.y*0.5-23.0 if compact else size.y-49.0)
	_caption.size = Vector2(maxf(1,size.x-text_x-8.0),25.0)
	_status.position = Vector2(text_x, size.y*0.5+1.0 if compact else size.y-25.0)
	_status.size = Vector2(maxf(1,size.x-text_x-8.0),22.0)
	queue_redraw()

func _draw() -> void:
	if _backdrop: draw_style_box(_backdrop,Rect2(Vector2.ZERO,size))
	var compact := size.y < 90.0
	var radius := 17.0 if compact else maxf(12.0,minf(size.x-20.0,size.y-58.0)*0.5)
	var center := Vector2(25.0,size.y*0.5) if compact else Vector2(size.x*0.5,(size.y-49.0)*0.5)
	var accent := _accent()
	draw_circle(center, radius, Color(Style.GLASS, 0.96), true, -1.0, true)
	draw_circle(center, radius - 3, Color(accent, 0.07 + level * 0.10), true, -1.0, true)
	draw_arc(center, radius, 0, TAU, 64, Color(accent, 0.23), 2.0, true)
	if level > 0.0:
		draw_arc(center, radius, -PI * 0.5, -PI * 0.5 + TAU * level, 64, accent, 4.0, true)
	if has_focus() or is_hovered():
		draw_arc(center, radius + 4.0, 0, TAU, 64, Style.PEARL if has_focus() else accent, 2.0, true)
	_draw_glyph(center, radius * 0.48, accent)
	if measurement_scale and not compact:
		var x := size.x - 8.0
		var top := maxf(8.0,center.y-radius)
		var bottom := minf(size.y-49.0,center.y+radius)
		draw_line(Vector2(x,top),Vector2(x,bottom),Color(accent,0.28),2.0,true)
		draw_line(Vector2(x,bottom),Vector2(x,lerpf(bottom,top,level)),accent,2.0,true)
		for index in range(5):
			var y := lerpf(bottom,top,index/4.0)
			draw_line(Vector2(x-5,y),Vector2(x,y),Color(accent,0.5),1.0,true)
	if reviewed:
		var badge := center + Vector2(radius * 0.72, radius * 0.70)
		draw_circle(badge, 8.0, Style.CYAN, true, -1.0, true)
		draw_polyline(PackedVector2Array([badge + Vector2(-4,0),badge + Vector2(-1,3),badge + Vector2(4,-3)]), Style.FLOOR, 1.8, true)
	elif tone == "caution" or tone == "danger":
		var badge := center + Vector2(radius * 0.73, radius * 0.70)
		draw_colored_polygon(PackedVector2Array([badge + Vector2(0,-8),badge + Vector2(8,7),badge + Vector2(-8,7)]), accent)
		draw_line(badge + Vector2(0,-3),badge + Vector2(0,2), Style.FLOOR, 2.0, true)
		draw_circle(badge + Vector2(0,4), 1.0, Style.FLOOR)

func _draw_glyph(center: Vector2, scale: float, tint: Color) -> void:
	var points := PackedVector2Array()
	match concept_id:
		"radiation":
			draw_circle(center, scale * 0.16, tint, true, -1.0, true)
			for index in range(3):
				var angle := index * TAU / 3.0 - PI * 0.5
				draw_arc(center, scale * 0.65, angle - 0.34, angle + 0.34, 12, tint, scale * 0.35, true)
		"dose":
			for index in range(4):
				var x := center.x - scale * 0.65 + index * scale * 0.44
				draw_line(Vector2(x,center.y + scale * 0.65), Vector2(x,center.y + scale * (0.25 - index * 0.4)), tint, 3.0, true)
		"sievert":
			points = PackedVector2Array([Vector2(0,-1),Vector2(0.8,-0.6),Vector2(0.7,0.4),Vector2(0,1),Vector2(-0.7,0.4),Vector2(-0.8,-0.6),Vector2(0,-1)])
		"dust":
			for offset in [Vector2(-0.7,-0.45),Vector2(0.3,-0.7),Vector2(0.75,0.1),Vector2(-0.45,0.5),Vector2(0.25,0.65),Vector2(0,0)]:
				draw_circle(center + offset * scale, scale * 0.13, tint, true, -1.0, true)
		"power":
			points = PackedVector2Array([Vector2(0.2,-1),Vector2(-0.6,0.15),Vector2(-0.05,0.15),Vector2(-0.2,1),Vector2(0.7,-0.2),Vector2(0.1,-0.2),Vector2(0.2,-1)])
		"time":
			draw_arc(center,scale * 0.84,0,TAU,40,tint,2.0,true)
			draw_polyline(PackedVector2Array([center + Vector2(0,-scale * 0.55),center,center + Vector2(scale * 0.45,scale * 0.18)]),tint,2.0,true)
		"speed":
			draw_arc(center,scale * 0.9,PI,TAU,30,tint,2.0,true)
			draw_line(center,center + Vector2(scale * 0.62,-scale * 0.62),tint,2.4,true)
			draw_line(center + Vector2(-scale * 0.8,scale * 0.5),center + Vector2(scale * 0.8,scale * 0.5),tint,2.0,true)
		"shelter":
			points = PackedVector2Array([Vector2(-1,0),Vector2(0,-0.85),Vector2(1,0),Vector2(0.7,0),Vector2(0.7,0.9),Vector2(-0.7,0.9),Vector2(-0.7,0),Vector2(-1,0)])
		_:
			draw_arc(center,scale * 0.8,0.3,TAU - 0.3,32,tint,2.0,true)
	if not points.is_empty():
		for index in range(points.size()): points[index] = center + points[index] * scale
		draw_polyline(points,tint,2.0,true)
