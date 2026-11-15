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
const PEARL_METAL := Color("ebd9ca")
const ROSE_GOLD := Color("c9957e")

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	clip_contents = true

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
	queue_redraw()

func _wall_tint(point: Vector2) -> Color:
	# A warm, opaque room enclosure. Specular variation is drawn, not animated,
	# so the glass instruments stay legible with reduced motion or while paused.
	var vertical := clampf(point.y / maxf(1.0,size.y),0.0,1.0)
	# A linear field interpolates identically across overlapping convex wall
	# faces, so it cannot leave accidental triangle-shaped lighting seams.
	return Color("422b35").lerp(Color("24141f"),vertical)

func _metal_tint(point: Vector2, light: Color, shade: Color) -> Color:
	var height := clampf((point.y-_window.position.y)/maxf(1.0,_window.size.y),0.0,1.0)
	return light.lerp(shade,height*0.72)

func _band(inner_distance: float, outer_distance: float, top: Color, bottom: Color) -> void:
	# All bevel geometry lies OUTSIDE the aperture, including rounded corners.
	var inner := _rounded_path(_window.grow(inner_distance),_radius+inner_distance)
	var outer := _rounded_path(_window.grow(outer_distance),_radius+outer_distance)
	for index in range(inner.size()):
		var next := (index+1)%inner.size()
		var quad := PackedVector2Array([inner[index],outer[index],outer[next],inner[next]])
		var colors := PackedColorArray()
		for point in quad: colors.append(_metal_tint(point,top,bottom))
		draw_polygon(quad,colors)

func _contour(distance: float, tint: Color, width: float = 1.0) -> void:
	var points := _rounded_path(_window.grow(distance),_radius+distance)
	points.append(points[0])
	draw_polyline(points,tint,width,true)

func _draw() -> void:
	if _inner_edge.is_empty(): return
	for polygon in _wall_polygons:
		var colors := PackedColorArray()
		for point in polygon: colors.append(_wall_tint(point))
		draw_polygon(polygon,colors)
	# Broad structural pearl rim, wine recess, rose-gold seam, then a black
	# pressure gasket. These layers give the observation window real depth.
	_band(26.0,45.0,Color("f3e6d8"),Color("9c8176"))
	_band(22.0,26.0,Color("bd846c"),Color("6a4141"))
	_band(12.0,22.0,Color("5c2539"),Color("260f20"))
	_band(7.0,12.0,Color("e6c2ae"),Color("9b6c61"))
	_band(0.0,7.0,Color("132631"),Color("0a131e"))
	_contour(44.0,Color(PEARL_METAL,0.65),1.0)
	_contour(25.0,Color(ROSE_GOLD,0.8),1.0)
	_contour(11.0,Color("ffe1ca"),1.3)
	# A restrained fixed halo, never a flashing warning or decorative loop.
	_contour(2.0,Color(Style.CYAN,0.10),7.0)
	_contour(2.0,Color(Style.CYAN,0.20),3.0)
	_contour(2.0,Color("a2e4e4"),0.9)
	# The sill uses a warm chamfer with inset joinery. Dense layouts omit its
	# secondary seams rather than consuming any part of the actor's safe view.
	var sill_y := _window.end.y+27.0
	if size.x >= 600.0 and size.y >= 500.0 and sill_y+18.0 < size.y:
		var left := maxf(24.0,_window.position.x+_radius)
		var right := minf(size.x-24.0,_window.end.x-_radius)
		if right > left:
			draw_line(Vector2(left,sill_y),Vector2(right,sill_y),Color(PEARL_METAL,0.6),1.0,true)
			for x in [left+18.0,right-18.0]:
				draw_line(Vector2(x,sill_y-4.0),Vector2(x,sill_y+12.0),Color(ROSE_GOLD,0.75),1.0,true)
	# Sparse perimeter seams connect the window to the room. No overlay,
	# ornaments or reflections are drawn across the actual game scene.
	for x in [8.0,size.x-8.0]:
		draw_line(Vector2(x,24.0),Vector2(x,maxf(24.0,size.y-24.0)),Color(ROSE_GOLD,0.28),1.0,true)
