extends SceneTree
## Native visual QA of the actual main scene. This is a fixture, not a recording
## of real-time player input: ordinary screen intents are invoked, then the real
## mission model is advanced explicitly to reproducible capture points.
## Run through scripts/capture_journey.py to isolate all user data and Xvfb.
const Progress = preload("res://scripts/journey_progress.gd")
var output := "/tmp/komaku-journey-capture"
var game: Node
var captures: Array[Dictionary] = []
var failures: Array[String] = []
var fixture_actions: Array[String] = []
var dimensions := Vector2i(1280,720)

func _initialize() -> void: call_deferred("run")

func frames(count: int = 8) -> void:
	for index in range(count): await process_frame

func action(note: String) -> void:
	fixture_actions.append(note)
	print("JOURNEY_FIXTURE ",note)

func find_reading(node: Node, prefix: String) -> Label:
	if node is Label and node.text.begins_with(prefix): return node
	for child in node.get_children():
		var found := find_reading(child,prefix)
		if found: return found
	return null

func scroll_to_reading(prefix: String) -> void:
	var reading := find_reading(game.shell._debrief_content,prefix)
	if reading:
		game.shell._scroll.scroll_vertical = maxi(0,int(reading.get_global_rect().position.y-game.shell._debrief_content.get_global_rect().position.y)-20)

func check(condition: bool, note: String) -> void:
	if not condition:
		failures.append(note)
		push_error(note)

func walk_controls(node: Node, found: Array[Dictionary]) -> void:
	if node is Control and node.is_visible_in_tree() and (node is BaseButton or node is Label):
		var rect: Rect2 = node.get_global_rect()
		var copy := str(node.get("text"))
		found.append({"path":str(node.get_path()),"text":copy,"rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y]})
		# Vertical scrolling is intentional. Horizontal overflow is not, except
		# the live concept rail, which is explicitly a horizontal scroll area.
		var horizontal_rail := false
		var ancestor := node.get_parent()
		while ancestor:
			if ancestor is ScrollContainer and ancestor.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED: horizontal_rail = true
			ancestor = ancestor.get_parent()
		if not horizontal_rail and not copy.is_empty() and rect.intersects(Rect2(Vector2.ZERO,dimensions)):
			check(rect.position.x >= -1 and rect.end.x <= dimensions.x+1,"Horizontal overflow at %s in %s: %s" % [dimensions,fixture_actions[-1],copy.left(90)])
	for child in node.get_children(): walk_controls(child,found)

func capture(name: String) -> void:
	await frames()
	await RenderingServer.frame_post_draw
	var filename := "%s-%dx%d.png" % [name,dimensions.x,dimensions.y]
	var result := root.get_texture().get_image().save_png(output.path_join(filename))
	check(result == OK,"Could not save " + filename)
	var controls: Array[Dictionary] = []
	walk_controls(game.interface,controls)
	captures.append({"file":filename,"screen":name,"width":dimensions.x,"height":dimensions.y,"stage":game.stage,"shell_state":game.shell.state,"modal":game.modal_kind,"snapshot":game.model.snapshot(),"fixture_actions":fixture_actions.duplicate(),"visible_controls":controls})
	print("JOURNEY_CAPTURE ",filename)
	fixture_actions.clear()

func run_size(size: Vector2i) -> void:
	dimensions = size
	root.size = size
	game = load("res://main.tscn").instantiate()
	game.online_sources_enabled = false
	root.add_child(game)
	current_scene = game
	await frames(4)
	# Freeze coordinator time, not visual child nodes. All model changes below
	# use its real methods. The fixture never writes a forged result dictionary.
	game.set_process(false)
	game.focused = true
	game.progress = Progress.new("user://visual-qa-%dx%d.json" % [size.x,size.y])
	AudioServer.set_bus_mute(0,true)
	action("Load actual main.tscn; isolate profile; freeze coordinator clock; mute output for capture")
	game.shell.advance_story()
	action("Reveal first story beat using its Continue action")
	await capture("01-story")
	game.shell._story_skip.pressed.emit()
	await frames(2)
	check(game.stage == "mission" and not game.mission_started,"Intro must open the stationary preflight control room")
	game.show_preparation()
	for id in ["radiation","dust"]:
		game.shell.open_concept(id)
		game.shell.close_concept()
	action("Skip intro into stationary preflight; explicitly open the optional science library and explore Radiation/Dust cards")
	await capture("02-preparation")
	game.shell.open_concept("dose")
	action("Open the Microgray science card")
	await capture("03-concept")
	game.shell.close_concept()
	game.shell.open_concept("power")
	action("Open the Power and energy card to inspect its kW-versus-kWh teaching diagram")
	await capture("13-energy-concept")
	game.shell.close_concept()
	for idea: Dictionary in game.catalog:
		if not str(idea.id) in game.shell.reviewed_ids:
			game.shell.open_concept(str(idea.id))
			game.shell.close_concept()
	game.shell._ready_button.pressed.emit()
	await frames(3)
	check(game.stage == "mission" and not game.mission_started,"Ready must open preflight without advancing the mission")
	game.focused = true
	game.resume_mission()
	check(game.model.snapshot().sim_elapsed_seconds == 0 and not game.mission_started,"Preflight keeps mission time and work at zero")
	action("Enter the control room from the optional science library; START MISSION is still required")
	await capture("04-preflight")
	game.hud.start_button.pressed.emit()
	game._process(0.0)
	check(game.mission_started,"Explicit START MISSION enables the mission")
	game.model.advance(60.0)
	game.hud.refresh(game.model.snapshot())
	game._sync_world(game.model.snapshot())
	action("Press START MISSION; advance60active seconds at normal1x cleaning; game fatigue remains zero")
	await capture("16-steady")
	game.hud.faster_button.pressed.emit()
	game.model.advance(80.0)
	game.hud.refresh(game.model.snapshot())
	game._sync_world(game.model.snapshot())
	check(is_equal_approx(game.solar_panel.clean_fraction,float(game.model.snapshot().clean_fraction)),"Visible panel dust matches actual continuous cleaning work")
	var crew := game.world.get_node("CompanionAnchor") as Node3D
	var screen_center: Vector2 = game.camera.unproject_position(crew.global_position + Vector3(0,0.9,0))
	check(screen_center.x > 24 and screen_center.x < dimensions.x-24,"Stationary cleaning crew remains framed at " + str(dimensions))
	var screen_feet: Vector2 = game.camera.unproject_position(crew.global_position+Vector3(0,0.03,0))
	check(screen_feet.y < game.hud._bottom.get_global_rect().position.y,"Bottom controls must not cover the real astronaut or panel base at "+str(dimensions))
	check(is_equal_approx(float(game.model.snapshot().cleaned_work),1.9),"Final workflow fixture incorporates slower actual cleaning as fatigue grows")
	action("Press FASTER once to1.25x; advance80active seconds:1.9sections cleaned and16percent game fatigue, not the prior fatigue-free2section model")
	await capture("04-cleaning")
	game.open_concept("dose")
	action("Open Microgray during the active mission; actual controller pauses the clock")
	await capture("10-live-concept")
	game.shell.close_concept()
	await frames(2)
	game.hud.pause_button.pressed.emit()
	action("Press Pause during cleaning; actual model remains unchanged")
	await capture("05-pause")
	game.show_settings()
	action("Open Sound, motion and pace from pause")
	await capture("06-settings")
	game.resume_mission()
	game.hud.slower_button.pressed.emit()
	game.model.advance(159.0)
	game.hud.refresh(game.model.snapshot())
	game._sync_world(game.model.snapshot())
	action("Resume and press SLOWER to normal1x; advance159active seconds to6simulated seconds before the authored storm")
	await capture("07-storm-soon")
	game.model.advance(1.0)
	game.hud.refresh(game.model.snapshot())
	game._sync_world(game.model.snapshot())
	check(game.model.snapshot().status == "win" and game.model.snapshot().crew_sheltered,"Countdown automatically moves Ren inside and resolves the mixed-pace mission")
	check(is_equal_approx(float(game.model.snapshot().cleaned_work),3.58),"Mixed-pace mission ends with actual3.58sections")
	action("Advance the last active second; automatic shelter entry at the authored storm, no recall or walk")
	await capture("11-entry")
	game.finish_mission()
	game.shell._merge_skip.pressed.emit()
	action("Show the actual WIN result after automatic entry; invoke debrief equation-reveal skip action")
	await capture("08-debrief")
	scroll_to_reading("How the ideas join")
	action("Inspect worked pace, game-fatigue and cleaning equations from the actual mixed-rate run")
	await capture("14-worked-equations")
	scroll_to_reading("05  Energy made")
	action("Inspect actual generated-minus-supplied battery energy balance and absorbed-dose equation")
	await capture("15-energy-equation")
	if game.shell._scroll:
		game.shell._scroll.scroll_vertical = int(game.shell._debrief_charts.position.y)
	action("Scroll to graphs generated from actual PaceMission history")
	await capture("12-debrief-graphs")
	if game.shell._scroll:
		var quiz_card: Control = game.shell._debrief_quiz_feedback.get_parent().get_parent()
		game.shell._scroll.scroll_vertical = int(quiz_card.position.y)
	action("Scroll the actual debrief to the learning-transfer question")
	await capture("09-debrief-question")
	game.queue_free()
	await frames(3)
	game = null

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Capture requires a graphics display, not --headless.")
		quit(2)
		return
	var args := OS.get_cmdline_user_args()
	for index in range(args.size()-1):
		if args[index] == "--output": output = args[index+1]
	DirAccess.make_dir_recursive_absolute(output)
	for size in [Vector2i(1280,720),Vector2i(390,844),Vector2i(844,390)]: await run_size(size)
	var manifest := {"kind":"actual-main-native-visual-fixture","engine":Engine.get_version_info().string,"method":"Actual main.tscn, isolated profile, direct UI intents and deterministic PaceMission v4 advancement. Coordinator processing is frozen for repeatable timestamps. This is not evidence of real-time play, audio quality, OS installation, hardware performance, or updater success.","captures":captures,"layout_failures":failures}
	var file := FileAccess.open(output.path_join("capture-manifest.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest,"  ")+"\n")
	file.close()
	print("JOURNEY_CAPTURE_COMPLETE images=",captures.size()," layout_failures=",failures.size())
	quit(1 if not failures.is_empty() else 0)
