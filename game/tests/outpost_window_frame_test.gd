extends SceneTree
const WindowFrame = preload("res://ui/outpost_window_frame.gd")
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if ok: print("PASS: ", message)
	else:
		failures += 1
		push_error(message)
func polygon_area(points: PackedVector2Array) -> float:
	var total := 0.0
	for index in range(points.size()): total += points[index].cross(points[(index + 1) % points.size()])
	return absf(total) * 0.5
func run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var frame := WindowFrame.new()
	root.add_child(frame)
	check(frame.mouse_filter == Control.MOUSE_FILTER_IGNORE and frame.focus_mode == Control.FOCUS_NONE, "Interior trim cannot steal pointer input or keyboard focus")
	check(not frame.is_processing() and frame.get_child_count() == 0, "Static trim has no animation loop, labels or duplicated controls")
	for sample in [
		[Vector2i(1280,720),Rect2(202,140,876,376)],
		[Vector2i(390,844),Rect2(12,286,366,312)],
		[Vector2i(844,390),Rect2(168,88,508,154)],
		[Vector2i(320,568),Rect2(10,228,300,118)],
		[Vector2i(1920,1080),Rect2(240,150,1440,710)]]:
		root.size = sample[0]
		await process_frame
		frame.set_opening(sample[1])
		var opening: Rect2 = sample[1]
		var safe_polygon := PackedVector2Array([opening.position,Vector2(opening.end.x,opening.position.y),opening.end,Vector2(opening.position.x,opening.end.y)])
		var area_inside := 0.0
		for wall in frame._wall_polygons:
			for overlap in Geometry2D.intersect_polygons(wall,safe_polygon): area_inside += polygon_area(overlap)
		check(area_inside < 0.01, "Entire camera work rectangle stays unpainted at " + str(sample[0]))
		# The new physical bevels are painted separately from the opaque wall;
		# verify their complete faces, not just the original aperture outline.
		var bevel_overlap := 0.0
		for bounds in [Vector2(0,7),Vector2(7,12),Vector2(12,22),Vector2(22,26),Vector2(26,45)]:
			var inner: PackedVector2Array = frame._rounded_path(frame._window.grow(bounds.x),frame._radius+bounds.x)
			var outer: PackedVector2Array = frame._rounded_path(frame._window.grow(bounds.y),frame._radius+bounds.y)
			for index in range(inner.size()):
				var next := (index+1)%inner.size()
				var face := PackedVector2Array([inner[index],outer[index],outer[next],inner[next]])
				for overlap in Geometry2D.intersect_polygons(face,safe_polygon): bevel_overlap += polygon_area(overlap)
		check(bevel_overlap < 0.01,"Every new physical bevel stays outside the camera-safe rectangle at "+str(sample[0]))
		var corners_clear := true
		for corner in safe_polygon: corners_clear = corners_clear and Geometry2D.is_point_in_polygon(corner,frame._inner_edge)
		check(corners_clear, "Rounded frame leaves all four work-area corners clear at " + str(sample[0]))
		var perimeter_covered := true
		for corner in [Vector2(1,1),Vector2(frame.size.x-1,1),frame.size-Vector2.ONE,Vector2(1,frame.size.y-1)]:
			var covered := false
			for wall in frame._wall_polygons: covered = covered or Geometry2D.is_point_in_polygon(corner,wall)
			perimeter_covered = perimeter_covered and covered
		check(perimeter_covered, "Opaque inner wall closes the outside perimeter at " + str(sample[0]))
		check(frame._wall_polygons.size() > 0 and frame._wall_polygons.size() <= 36, "Resize keeps a bounded fixed trim geometry count")
	var before := frame.get_opening()
	frame.set_opening(Rect2(Vector2(NAN,0),Vector2(100,100)))
	check(frame.get_opening() == before, "Invalid layout input retains the last valid aperture")
	frame.set_opening(Rect2())
	check(frame._wall_polygons.is_empty() and frame._inner_edge.is_empty(), "Unavailable work area clears trim without hiding the scene")
	frame.queue_free()
	await process_frame
	print("OUTPOST WINDOW FRAME FAILURES: ", failures)
	quit(1 if failures else 0)
