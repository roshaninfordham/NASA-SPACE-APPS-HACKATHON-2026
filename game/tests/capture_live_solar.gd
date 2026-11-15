extends SceneTree
## Opt-in native viewer capture using the real fixed NASA HTTPS endpoint.
## The probe's proxy adapter retains TLS validation; it changes no feed policy.
const Probe = preload("res://tests/probe_live_solar_feed.gd")
const SolarView = preload("res://live/solar_panel.gd")
var output := "/tmp/komaku-live-solar-capture"
var feed: Node
var viewer: CanvasLayer
var completed := false
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if DisplayServer.get_name() == "headless" or OS.get_environment("KOMAKU_SOLAR_LIVE_PROBE") != "1" or OS.get_environment("XDG_DATA_HOME").is_empty():
		push_error("Native display, explicit opt-in and isolated data directory are required")
		quit(1)
		return
	var arguments := OS.get_cmdline_user_args()
	for index in range(arguments.size()-1):
		if arguments[index] == "--output": output = arguments[index+1]
	DirAccess.make_dir_recursive_absolute(output)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1280,720)
	feed = Probe.ProxyFeed.new("user://live-solar-capture")
	root.add_child(feed)
	viewer = SolarView.new()
	viewer.client = feed
	root.add_child(viewer)
	feed.changed.connect(received)
	feed.refresh(false)
	create_timer(16.0).timeout.connect(func():
		if not completed:
			push_error("NASA capture did not complete within its bounded request deadline")
			quit(1)
	,CONNECT_ONE_SHOT)
func received() -> void:
	if completed: return
	var snapshot: Dictionary = feed.snapshot()
	if snapshot.busy or snapshot.status == "loading": return
	completed = true
	if not snapshot.is_live or snapshot.http_status != 200 or snapshot.width != 512 or snapshot.height != 512:
		push_error("NASA did not provide a validated live image: " + str(snapshot.message))
		quit(1)
		return
	capture.call_deferred()
func capture() -> void:
	var files: Array[String] = []
	for size in [Vector2i(1280,720),Vector2i(390,844),Vector2i(844,390)]:
		root.size = size
		for index in range(12): await process_frame
		await RenderingServer.frame_post_draw
		var filename := "live-sun-%dx%d.png" % [size.x,size.y]
		var result := root.get_texture().get_image().save_png(output.path_join(filename))
		if result != OK: push_error("Could not save the native solar viewer capture"); quit(1); return
		files.append(filename)
	var snapshot: Dictionary = feed.snapshot()
	snapshot.erase("texture")
	snapshot["tls_verification"] = "enabled"
	snapshot["capture_method"] = "Real Godot HTTPRequest to fixed NASA HTTPS source, displayed by the production solar_panel.gd component under a native Linux graphics display. No mission model, synthetic image or fabricated NASA timestamp. This does not establish other-device networking or real-time solar observation."
	snapshot["screenshots"] = files
	var record := FileAccess.open(output.path_join("live-sun-provenance.json"),FileAccess.WRITE)
	record.store_string(JSON.stringify(snapshot,"  ")+"\n")
	record.close()
	print("NASA_NATIVE_CAPTURE status=",snapshot.status," http=",snapshot.http_status," width=",snapshot.width," height=",snapshot.height," sha256=",snapshot.sha256)
	viewer.queue_free()
	feed.queue_free()
	await process_frame
	quit()
