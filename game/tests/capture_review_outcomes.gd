extends SceneTree
## Review-only visual fixtures. Real model outcomes, not forged result summaries.
var output := "/tmp/komaku-review-outcomes"
var game: Node
var captures: Array[Dictionary] = []
var failures: Array[String] = []
var actions: Array[String] = []

func _initialize() -> void: call_deferred("run")

func frames(count: int = 8) -> void:
	for index in range(count): await process_frame

func check(condition: bool, note: String) -> void:
	if not condition:
		failures.append(note)
		push_error(note)

func capture(id: String) -> void:
	await frames()
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(id+".png")) == OK, "Save " + id)
	captures.append({"id":id,"file":id+".png","width":root.size.x,"height":root.size.y,"stage":game.stage,"shell_state":game.shell.state,"modal":game.modal_kind,"update_panel_open":is_instance_valid(game.update_panel),"snapshot":game.model.snapshot(),"fixture_actions":actions.duplicate()})
	actions.clear()
	print("REVIEW_CAPTURE ",id)

func run_outcome(pace: float, status: String, work: float, energy: float, id: String) -> void:
	game.start_mission()
	for frame in range(120):
		if game.stage != "loading": break
		await process_frame
	await frames(2)
	check(game.stage == "mission" and not game.mission_started, "Preflight for " + id)
	game.focused = true
	game.resume_mission()
	game.hud.speed_slider.value = pace
	game.hud.start_button.pressed.emit()
	check(game.mission_started, "Actual Start action for " + id)
	game.model.advance(90.0)
	var snapshot: Dictionary = game.model.snapshot()
	check(snapshot.status == status, "Actual expected outcome: " + status)
	check(is_equal_approx(float(snapshot.cleaned_work),work), "Closed-form work for " + id)
	check(is_equal_approx(float(snapshot.battery_kwh),energy), "Closed-form stored energy for " + id)
	check(snapshot.crew_sheltered and is_equal_approx(float(snapshot.dose_ugy),10.9375), "Sheltered with actual integrated dose for " + id)
	game._process(0.0)
	check(game.stage == "debrief" and game.shell._debrief_view == "results", "Actual immediate results for " + id)
	actions.append("Open actual preflight; set the visible cleaning slider to %.2f×; press Start; advance the real PaceMission by 90 active seconds; let the coordinator show its actual %s result. This is deterministic model advancement, not real-time input recording." % [pace,status.to_upper()])
	await capture(id)

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Native review captures need a graphics display.")
		quit(2)
		return
	var args := OS.get_cmdline_user_args()
	for index in range(args.size()-1):
		if args[index] == "--output": output = args[index+1]
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280,720)
	game = load("res://main.tscn").instantiate()
	game.online_sources_enabled = false
	root.add_child(game)
	current_scene = game
	await frames(4)
	game.set_process(false)
	game.focused = true
	AudioServer.set_bus_mute(0,true)
	actions.append("Load actual main.tscn in isolated user data with online requests disabled, coordinator processing frozen and audio muted.")
	await run_outcome(0.5,"pass",1.875,1.703125,"mission-pass")
	await run_outcome(0.25,"lose",0.9375,1.3515625,"mission-try-again")
	game.shell._footer.get_node("Finish").pressed.emit()
	await frames(2)
	var updates: Button
	for candidate in game.modal.find_children("*","Button",true,false):
		if candidate.text == "Updates & downloads": updates = candidate
	check(updates != null and updates.is_visible_in_tree(), "Actual Home has Updates & downloads")
	if updates != null:
		updates.pressed.emit()
		await frames(2)
		check(is_instance_valid(game.update_panel), "Actual update panel opens")
		actions.append("Press Home from the actual result, then Updates & downloads. No update check, download or install is requested; this is the isolated idle update interface, not update-success evidence.")
		await capture("updates")
	var file := FileAccess.open(output.path_join("capture-manifest.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"kind":"actual-main-review-outcomes","engine":Engine.get_version_info().string,"method":"Actual main.tscn, isolated user data, no network requests, muted audio, real slider and Start intents, deterministic advancement of the unmodified mission model. These native screenshots document the UI and actual computed outcomes; they do not establish real-time play, audio, OS installation or updater success.","captures":captures,"failures":failures},"  ")+"\n")
	file.close()
	print("REVIEW_CAPTURE_COMPLETE images=",captures.size()," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
