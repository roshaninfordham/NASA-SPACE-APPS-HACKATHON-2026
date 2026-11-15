extends SceneTree
## Reproducible, actual rendered scene capture. Run with a graphics display.
## godot --path game --script res://tests/capture_visuals.gd -- --view interior --output /tmp/interior.png
func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var args := OS.get_cmdline_user_args()
	var view := "exterior"
	var output := "/tmp/red-veil-view.png"
	for i in range(args.size() - 1):
		if args[i] == "--view": view = args[i + 1]
		if args[i] == "--output": output = args[i + 1]
	root.size = Vector2i(1670, 941)
	var game = load("res://legacy_mission.tscn").instantiate()
	root.add_child(game)
	await process_frame
	if view != "title":
		for child in game.get_children():
			if child is CanvasLayer: child.hide()
	game.player.hide()
	var camera := Camera3D.new()
	game.add_child(camera)
	camera.fov = 45
	match view:
		"interior":
			camera.position = Vector3(0, 2.3, -4.3)
			camera.look_at(Vector3(0, 3.1, -16))
			camera.fov = 60
		"astronaut":
			camera.position = Vector3(-2.7, 1.35, 9.5)
			camera.look_at(Vector3(-4, 0.95, 7))
			camera.fov = 46
		_:
			camera.position = Vector3(-6, 3.4, 10)
			camera.look_at(Vector3(0, 3, -16))
	camera.current = true
	for i in range(12): await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png(output)
	print("VISUAL_CAPTURE ", view, " result=", result, " path=", output, " draw_calls=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), " primitives=", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	quit(result)
