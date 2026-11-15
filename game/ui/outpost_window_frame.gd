extends Control
## Procedural interior trim around the live 3D view. This is presentation only;
## the existing room owns physical walls/glass and the camera remains indoors.
## The complete supplied work rectangle stays transparent and input passes through.
const Style = preload("res://ui/journey_style.gd")
var _requested_opening := Rect2()
var _opening := Rect2()
var _window := Rect2()
var _radius := 24.0
var _wall_polygons: Array[PackedVector2Array] = []
var _inner_edge := PackedVector2Array()
var _recess := StyleBoxFlat.new()
var _rim := StyleBoxFlat.new()
var _seam := StyleBoxFlat.new()

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	clip_contents = true
	for trim in [_recess, _rim, _seam]:
		trim.draw_center = false
		trim.anti_aliasing = true
	_recess.border_color = Style.FLOOR
	_recess.set_border_width_all(14)
	_rim.border_color = Style.MUTED.darkened(0.32)
	_rim.set_border_width_all(4)
	_seam.border_color = Color(Style.PEARL, 0.30)
	_seam.set_border_width_all(1)

func _ready() -> void:
	name = "OutpostWindowFrame"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(_rebuild)
	set_process(false)
	_rebuild()

func set_opening(rect: Rect2) -> void:
	if not rect.position.is_finite() or not rect.size.is_finite(): return
	if _requested_opening == rect: return
	_requested_opening = rect
	_rebuild()

func get_opening() -> Rect2:
	return _opening

func _rounded_path(rect: Rect2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var centers := [rect.position + Vector2(radius, radius), Vector2(rect.end.x - radius, rect.position.y + radius), rect.end - Vector2(radius, radius), Vector2(rect.position.x + radius, rect.end.y - radius)]
	for corner in range(4):
		for sample in range(9):
			var angle := PI + float(corner) * PI * 0.5 + float(sample) * PI / 16.0
			points.append(centers[corner] + Vector2(cos(angle), sin(angle)) * radius)
	return points

func _outside_half_plane(a: Vector2, b: Vector2) -> PackedVector2Array:
	# The complement of a convex aperture is a union of outside half-planes.
	# Clipping each one to the viewport avoids crossing polygon edges at corners.
	var viewport := PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)])
	var result := PackedVector2Array()
	var direction := b - a
	for index in range(viewport.size()):
		var current := viewport[index]
		var previous := viewport[(index + viewport.size() - 1) % viewport.size()]
		var current_side := direction.cross(current - a)
		var previous_side := direction.cross(previous - a)
		if (current_side <= 0.0) != (previous_side <= 0.0):
			result.append(previous.lerp(current, previous_side / (previous_side - current_side)))
		if current_side <= 0.0: result.append(current)
	return result

func _rebuild() -> void:
	_wall_polygons.clear()
	_inner_edge.clear()
	_opening = _requested_opening.intersection(Rect2(Vector2.ZERO, size))
	if not _opening.has_area() or size.x <= 0.0 or size.y <= 0.0:
		queue_redraw()
		return
	_radius = clampf(minf(_opening.size.x, _opening.size.y) * 0.10, 12.0, 30.0)
	# Expand the aperture before rounding: even its rounded corners cannot cover
	# a corner of the requested rectangular work area (including the actor).
	var clearance := maxf(8.0, _radius * 0.35 + 2.0)
	_window = _opening.grow(clearance)
	_inner_edge = _rounded_path(_window, _radius)
	for index in range(_inner_edge.size()):
		var polygon := _outside_half_plane(_inner_edge[index], _inner_edge[(index + 1) % _inner_edge.size()])
		if polygon.size() >= 3 and not Geometry2D.triangulate_polygon(polygon).is_empty():
			_wall_polygons.append(polygon)
	_recess.set_corner_radius_all(roundi(_radius + 14.0))
	_rim.set_corner_radius_all(roundi(_radius + 17.0))
	_seam.set_corner_radius_all(roundi(_radius + 20.0))
	queue_redraw()

func _wall_tint(point: Vector2) -> Color:
	return Style.PEARL.lerp(Style.RAISED, 0.44 + 0.34 * clampf(point.y / maxf(1.0, size.y), 0.0, 1.0))

func _draw() -> void:
	if _inner_edge.is_empty(): return
	for polygon in _wall_polygons:
		var colors := PackedColorArray()
		for point in polygon: colors.append(_wall_tint(point))
		draw_polygon(polygon, colors)
	draw_style_box(_recess, _window.grow(14.0))
	draw_style_box(_rim, _window.grow(17.0))
	draw_style_box(_seam, _window.grow(20.0))
	var edge := _inner_edge.duplicate()
	edge.append(edge[0])
	draw_polyline(edge, Color(Style.CYAN, 0.46), 1.5, true)
	# Two quiet horizontal inlays echo Japanese joinery without a busy lattice.
	# Every stroke stays below the clear aperture; no marks cross the live scene.
	var sill_y := _window.end.y + 23.0
	if sill_y + 7.0 < size.y:
		var left := maxf(22.0, _window.position.x + _radius)
		var right := minf(size.x - 22.0, _window.end.x - _radius)
		if right > left:
			draw_line(Vector2(left, sill_y), Vector2(right, sill_y), Color(Style.PEARL, 0.32), 2.0, true)
			for side in [left + 18.0, right - 18.0]:
				draw_line(Vector2(side, sill_y - 4.0), Vector2(side, sill_y + 7.0), Color(Style.MUTED, 0.42), 1.0, true)
