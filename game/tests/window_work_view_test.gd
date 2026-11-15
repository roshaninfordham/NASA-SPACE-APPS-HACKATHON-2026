extends SceneTree
const View = preload("res://scripts/window_work_view.gd")
const CREW := Vector3(-0.7, 0.0, -8.8)
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	if ok: print("PASS: ",label)
	else: failures += 1; push_error(label)
func run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.current = true
	var views := [
		[Vector2i(1280,720), Rect2(204,130,872,394)],
		[Vector2i(844,390), Rect2(168,88,508,154)],
		[Vector2i(390,844), Rect2(12,286,366,312)],
		[Vector2i(320,568), Rect2(10,228,300,118)],
		[Vector2i(1920,1080), Rect2(240,150,1440,710)]
	]
	for sample in views:
		root.size = sample[0]
		await process_frame
		var viewport_size := root.get_visible_rect().size
		var space: Rect2 = sample[1]
		check(View.frame(camera, CREW, viewport_size, space), "Window camera accepts " + str(sample[0]))
		var low := Vector2(INF,INF)
		var high := Vector2(-INF,-INF)
		for index in range(8):
			var point := camera.unproject_position(CREW + View.WORK_BOUNDS.get_endpoint(index))
			low = low.min(point)
			high = high.max(point)
		var projected := Rect2(low,high-low)
		check(space.encloses(projected), "Helmet, brush and complete array stay clear of controls at " + str(sample[0]))
		var fill := projected.size / space.size
		check(maxf(fill.x,fill.y) > 0.80, "Working scene fills the available view instead of distant empty desert at " + str(sample[0]))
		check(camera.position.z < -9.8 and CREW.z > -9.8, "Operator stays inside the glass and Ren remains outside")
		check(camera.projection == Camera3D.PROJECTION_FRUSTUM and camera.scale == Vector3.ONE, "Perspective framing never stretches character or panel geometry")
	var before := camera.transform
	check(not View.frame(camera,CREW,Vector2.ZERO,Rect2(0,0,100,100)) and camera.transform == before, "Zero-size resize leaves the previous valid camera intact")
	check(not View.frame(camera,CREW,Vector2(320,568),Rect2(0,0,5,5)), "An unavailable work region cannot create an invalid lens")
	check(not View.frame(camera,Vector3(NAN,0,0),Vector2(320,568),Rect2(0,0,200,200)), "Nonfinite scene coordinates cannot reach the camera")
	camera.queue_free()
	await process_frame
	print("WINDOW WORK VIEW FAILURES: ",failures)
	quit(1 if failures else 0)
