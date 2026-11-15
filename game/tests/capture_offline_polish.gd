extends SceneTree
## Actual main scene, reproducible model fixture; not a human playtest or FPS benchmark.
var game: Node
var destination := "/tmp/komaku-offline-polish"
func _initialize() -> void: call_deferred("run")
func frames(n := 6) -> void:
	for i in range(n): await process_frame
func capture(label: String) -> void:
	await frames()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(destination.path_join(label + ".png"))
func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: destination = args[0]
	DirAccess.make_dir_recursive_absolute(destination)
	root.size = Vector2i(1280, 720)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await frames()
	# A fixed real preset makes the visual fixture independent of capture hardware.
	game.set_graphics_mode("balanced")
	await game.start_mission()
	game.set_process(false)
	game.launch_mission()
	game.model.advance(36.0)
	game.hud.refresh(game.model.snapshot())
	game._sync_world(game.model.snapshot())
	game.world.process_mode = Node.PROCESS_MODE_DISABLED
	await capture("mission-desktop")
	game.open_concept("power")
	var button: Button = game.shell.find_child("OfflineCoachToggle", true, false)
	button.button_pressed = true
	await capture("coach-desktop")
	game.shell.close_live_concept()
	game.show_settings()
	await capture("offline-settings")
	game._close_modal()
	root.size = Vector2i(390,844)
	game.hud.queue_redraw()
	await frames()
	game._frame_work_view()
	await capture("mission-mobile")
	game.open_concept("dust")
	button = game.shell.find_child("OfflineCoachToggle", true, false)
	button.button_pressed = true
	await capture("coach-mobile")
	print("OFFLINE POLISH CAPTURE COMPLETE")
	quit()
