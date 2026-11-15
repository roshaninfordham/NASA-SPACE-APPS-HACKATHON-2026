extends SceneTree
## Source main-scene integration. Run with a fresh, isolated XDG_DATA_HOME.
## The real model, world, shell, HUD, progress and input guard are all retained.
## Fullscreen uses an injected OS boundary. Browser callbacks are disconnected
## only while probing the real panel source signal; no network or browser is used.
const Progress = preload("res://scripts/journey_progress.gd")
var assertions := 0
var failures := 0
var game: Node3D
var nasa_source_events: Array[String] = []
class FakeDisplay extends RefCounted:
	var current_mode := DisplayServer.WINDOW_MODE_WINDOWED
	var current_size := Vector2i(1280,720)
	var current_position := Vector2i(80,60)
	var pointer_releases := 0
	func mode() -> int: return current_mode
	func set_mode(value: int) -> void: current_mode = value
	func size() -> Vector2i: return current_size
	func position() -> Vector2i: return current_position
	func usable_rect() -> Rect2i: return Rect2i(0,0,1920,1080)
	func set_geometry(value: Vector2i, location: Vector2i) -> void:
		current_size = value
		current_position = location
	func release_pointer() -> void: pointer_releases += 1
	func supported() -> bool: return true
func _initialize() -> void: call_deferred("run")
func check(value: bool, description: String) -> void:
	assertions += 1
	if value: print("PASS: ", description)
	else:
		failures += 1
		push_error(description)
func frames(count := 6) -> void:
	for index in range(count): await process_frame
func key(code: Key, physical_only := false, backwards := false) -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new()
		event.keycode = KEY_NONE if physical_only else code
		event.physical_keycode = code
		event.pressed = pressed
		event.shift_pressed = backwards
		root.push_input(event)
	await frames()
func button_named(parent: Node, text: String) -> Button:
	if not is_instance_valid(parent): return null
	for candidate in parent.find_children("*", "Button", true, false):
		if candidate.text == text: return candidate
	return null
func click_modal(text: String) -> void:
	var button := button_named(game.modal,text)
	check(button != null, "Reachable navigation action: " + text)
	if button: button.pressed.emit()
	await frames()
func assert_same_run(before: Dictionary, label: String) -> void:
	check(game.model.snapshot() == before,label)
func assert_solar_offline(label: String) -> void:
	var current: Dictionary = game.solar_feed.snapshot()
	check(not current.busy and not current.is_live and current.last_checked_utc.is_empty() and game.solar_feed._last_attempt_ticks == -1, label)

func verify_solar_focus(label: String) -> void:
	for index in range(6):
		await key(KEY_TAB,false,index >= 3)
		check(game.solar_data_panel.is_ancestor_of(root.gui_get_focus_owner()), label + " · " + str(index+1))

func probe_nasa_source(label: String) -> void:
	# The production panel remains intact. Replace only its controller's OS
	# browser callback so the emitted fixed NASA URL can be checked offline.
	var panel: CanvasLayer = game.solar_data_panel
	for connection in panel.get_signal_connection_list("source_requested"):
		panel.disconnect("source_requested",connection.callable)
	panel.source_requested.connect(func(url: String): nasa_source_events.append(url))
	var before := nasa_source_events.size()
	panel.source_button.pressed.emit()
	check(nasa_source_events.size() == before+1 and nasa_source_events.back() == "https://sdo.gsfc.nasa.gov/data/",label)
	assert_solar_offline("Opening a NASA source action did not start the image transport")

func run() -> void:
	if DisplayServer.get_name() != "headless":
		check(false,"This deterministic integration suite requires --headless")
		quit(1)
		return
	# Refuse to overwrite an actual player profile. The runner supplies isolation.
	if FileAccess.file_exists(Progress.DEFAULT_PATH):
		check(false,"Use a fresh isolated XDG_DATA_HOME; an existing journey profile was left untouched")
		quit(1)
		return
	root.size = Vector2i(1280,720)
	var scene_path := str(ProjectSettings.get_setting("application/run/main_scene"))
	var packed := load(scene_path) as PackedScene
	check(packed != null and scene_path == "res://main.tscn","Load the project's actual source main scene")
	if packed == null:
		quit(1)
		return
	game = packed.instantiate()
	game.online_sources_enabled = false
	check(game.get_script().resource_path == "res://scripts/journey_game.gd","The source entrypoint selects the new journey controller")
	game.set_process(false)
	root.add_child(game)
	game.set_process(false)
	await frames(10)
	game.progress.set_setting("music_enabled",false)
	game.progress.set_setting("effects_enabled",false)
	game.progress.set_setting("reduced_motion",true)
	game._apply_preferences()
	check(game.stage == "story" and game.paused and game.shell.visible and not game.hud.visible,"A first launch opens the story with a paused mission")
	check(not is_instance_valid(game.world) and root.disable_3d,"Story does not construct or render the 3D world")
	check(game.catalog.size() == 8 and game.progress.reviewed_ids.is_empty(),"Fresh profile starts with eight unreviewed science concepts")
	check(is_instance_valid(game._guard) and root.get_child(root.get_child_count()-1) == game._guard,"The global input guard runs before nested UI input")
	check(not is_instance_valid(game.update_client) or (game.update_client.status == "idle" and not game.update_client._checked_this_session),"Headless source flow does not initiate update network traffic")
	game.shell._story_skip.pressed.emit()
	await frames()
	check(game.stage == "mission" and not game.mission_started and game.hud.start_button.visible, "Story Skip reaches control-room preflight without mandatory reading")
	game.show_preparation()
	await frames()
	check(game.stage == "preparation" and game.shell.state == "preparation", "Science constellation remains an optional learning screen")
	var before_nasa_preparation: Dictionary = game.model.snapshot()
	game.shell._live_sun_button.pressed.emit()
	await frames()
	check(is_instance_valid(game.solar_data_panel) and game.solar_data_panel.layer == 31 and game.solar_data_panel.client == game.solar_feed,"Preparation Live Sun opens the actual shared NASA viewer above the journey")
	check(game.solar_data_panel.current_snapshot.source_kind == "bundled" and game.solar_data_panel.current_snapshot.status == "fallback", "Offline viewer identifies bundled NASA imagery honestly")
	assert_solar_offline("Disabled online sources never auto-fetch NASA imagery on launch or panel open")
	await key(KEY_ESCAPE)
	check(not is_instance_valid(game.solar_data_panel) and game.stage == "preparation" and game.shell.readiness == 0,"Escape returns from Live Sun to the unchanged preparation gate")
	assert_same_run(before_nasa_preparation,"Browsing NASA imagery does not alter the unstarted mission model")
	check(game.stage == "preparation" and root.disable_3d, "Optional reading keeps the mission world render disabled")
	game.shell.open_concept("radiation")
	await frames()
	var underlying_card_id: int = game.shell._dialog.get_instance_id()
	game.shell._dialog.find_child("RadiationLiveSun",true,false).pressed.emit()
	await frames()
	check(is_instance_valid(game.solar_data_panel) and game.shell.concept_open and game.shell._dialog.get_instance_id() == underlying_card_id and game.shell.readiness == 0,"NASA viewer keeps the exact underlying radiation card and review progress")
	await verify_solar_focus("Tab and Shift-Tab remain in the highest NASA layer above the science card")
	await key(KEY_ESCAPE)
	check(not is_instance_valid(game.solar_data_panel) and game.shell.concept_open and game.shell._dialog.get_instance_id() == underlying_card_id,"First windowed Escape closes NASA while preserving the radiation card")
	await key(KEY_ESCAPE)
	check(not game.shell.concept_open and game.progress.reviewed_ids.is_empty(),"Global Escape closes a card without falsely recording exploration")
	for orb in game.shell._orbs:
		orb.pressed.emit()
		game.shell._dialog_done.pressed.emit()
	await frames()
	var saved_before := Progress.new()
	check(game.shell.readiness == 1.0 and saved_before.reviewed_ids.size() == 8,"All eight acknowledged concepts persist through the real progress store")
	check(game.progress.runs.is_empty(),"Reading concepts does not invent a completed mission")
	game.shell._ready_button.pressed.emit()
	await frames(10)
	check(game.stage == "mission" and not game.paused and game.hud.visible and not game.shell.visible,"Ready launches the real mission and changes visible UI")
	check(is_instance_valid(game.world) and is_instance_valid(game.camera) and game.world.is_window_presentation(),"First launch lazily constructs the inside-window world and camera")
	var world_id: int = game.world.get_instance_id()
	check(not root.disable_3d and game.camera.current,"Only active play enables the world camera")
	check(game.hud.snapshot == game.model.snapshot(),"The HUD begins with an exact detached model snapshot")
	check(not game.mission_started and game.hud.start_button.visible, "Ready opens an unstarted control room with an explicit Start control")
	var preflight: Dictionary = game.model.snapshot()
	game._process(90.0)
	assert_same_run(preflight, "Preflight inspection cannot spend time, energy, work or dose")
	game.hud.faster_button.pressed.emit()
	check(game.model.snapshot().cleaning_multiplier == 1.25 and game.model.snapshot().sim_elapsed_seconds == 0.0, "Preflight can select a starting pace without starting time")
	game.hud.slower_button.pressed.emit()
	await key(KEY_ENTER)
	check(game.mission_started and not game.hud.start_button.visible, "Enter explicitly starts the mission from preflight")
	var work_anchor: Node3D = game.world.get_node("CompanionAnchor")
	var initial_work_position := work_anchor.position
	game._process(90.0)
	check(is_equal_approx(float(game.model.snapshot().elapsed_seconds),0.25),"A stalled frame cannot skip ninety seconds of player decisions")
	game.model.advance(59.75)
	game._process(0.0)
	check(is_equal_approx(float(game.model.snapshot().cleaned_work),0.75) and game.hud.snapshot == game.model.snapshot(),"Continuous partial cleaning propagates from the model to the HUD")
	game.hud.faster_button.pressed.emit()
	check(game.model.snapshot().cleaning_multiplier == 1.25 and game.model.snapshot().cleaning,"The faster-cleaning control changes task rate without toggling work off")
	check(game.model.snapshot().fatigue == 0.0, "Changing pace does not instantly fabricate fatigue")
	game.model.advance(80.0)
	game._process(0.0)
	check(is_equal_approx(float(game.model.snapshot().cleaned_work),1.9),"Actual mixed-rate work includes both steady and faster segments")
	check(is_equal_approx(game.solar_panel.clean_fraction, 1.9 / 4.0) and is_equal_approx(game.model.snapshot().fatigue, 0.16), "Actual panel clearing and fatigue follow the integrated mixed pace")
	check(work_anchor.position == initial_work_position,"Changing cleaning pace leaves the astronaut stationary at the panel array")
	check(game.hud.snapshot.battery_kwh == game.model.snapshot().battery_kwh and not game.hud.snapshot.has("projected_battery_at_warning_kwh"), "HUD displays actual battery energy without a discarded reserve forecast")
	var before_reading: Dictionary = game.model.snapshot()
	game.hud.orbs.radiation.pressed.emit()
	await frames()
	check(game.paused and game.shell.concept_open and game.shell.state == "live","Clicking a live concept opens a reading card and pauses the controller")
	game._process(3600.0)
	game.hud.faster_button.pressed.emit()
	assert_same_run(before_reading,"Reading and ignored background controls cannot change time, work, dose or location")
	game.shell._dialog.find_child("RadiationLiveSun",true,false).pressed.emit()
	await frames()
	check(is_instance_valid(game.solar_data_panel) and game.shell.concept_open and game.paused,"NASA viewer opens above a live radiation card while mission time remains paused")
	game._process(3600)
	assert_same_run(before_reading,"Live NASA browsing cannot change battery, dose, timing, cleaning or mission history")
	assert_solar_offline("Opening NASA during a mission respects the offline test policy")
	var display := FakeDisplay.new()
	game.navigation.configure_backend(display)
	await key(KEY_F11)
	check(game.navigation.is_fullscreen() and game.shell.concept_open,"Global fullscreen action remains reachable above a live science modal")
	await key(KEY_ESCAPE)
	check(not game.navigation.is_fullscreen() and is_instance_valid(game.solar_data_panel) and game.shell.concept_open and game.paused and display.pointer_releases == 1,"First Escape exits fullscreen without dismissing the science card or resuming time")
	await key(KEY_ESCAPE)
	check(not is_instance_valid(game.solar_data_panel) and game.shell.concept_open and game.paused,"Windowed Escape closes NASA first without dismissing the live card or resuming")
	game._process(1000)
	assert_same_run(before_reading,"Closing NASA still leaves the underlying live card and model frozen")
	await key(KEY_ESCAPE)
	check(not game.shell.concept_open and game.modal_kind == "pause" and game.paused,"The next Escape closes reading and offers an explicit Resume")
	game._process(1.0)
	assert_same_run(before_reading,"Closing a reading card still leaves the mission frozen")
	await click_modal("Resume mission")
	check(not game.paused and not is_instance_valid(game.modal),"Resume is a deliberate navigation action")
	check(root.gui_get_focus_owner() == game.hud.faster_button,"Resume restores keyboard focus to a live mission control")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await frames()
	check(not game.focused and game.paused and game.modal_kind == "pause","Losing window focus creates a paused mission")
	game._process(100.0)
	assert_same_run(before_reading,"Background focus loss does not advance the model")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	await frames()
	check(game.focused and game.paused,"Returning to the window does not silently resume")
	await click_modal("Resume mission")
	await key(KEY_ESCAPE,true)
	check(game.paused and game.modal_kind == "pause","A physical-only Escape event reaches contextual Pause")
	if game.modal_kind != "pause": game.show_pause()
	var pause_id: int = game.modal.get_instance_id()
	await click_modal("Live Sun · NASA observation")
	check(is_instance_valid(game.solar_data_panel) and game.modal.get_instance_id() == pause_id and game.paused,"Pause menu opens NASA without replacing the underlying Resume menu")
	probe_nasa_source("Pause NASA source action emits only the fixed official data-page URL")
	await key(KEY_ESCAPE)
	check(not is_instance_valid(game.solar_data_panel) and game.modal_kind == "pause" and game.paused,"Closing NASA from Pause keeps Resume explicit")
	assert_same_run(before_reading,"NASA from Pause cannot spend mission time")
	await click_modal("Resume mission")
	game.hud.slower_button.pressed.emit()
	check(is_equal_approx(game.model.snapshot().cleaning_multiplier, 1.0), "Slower lowers the requested cleaning effort")
	game.model.advance(159.0)
	game._process(0.0)
	check(game.model.snapshot().status == "running" and not game.model.snapshot().crew_sheltered, "Ren stays by the panel until the fixed countdown expires")
	check(work_anchor.position == initial_work_position, "No walking distance or return route is invented")
	game.model.advance(1.0)
	game._process(0.0)
	await frames()
	check(game.stage == "debrief" and game.paused and game.model.result().status == "win" and game.model.result().crew_sheltered, "Countdown expiry automatically shelters Ren and opens a winning debrief")
	check(game.shell.visible and not game.hud.visible and root.disable_3d,"Debrief disables the world render and presents reflection UI")
	check(game.shell._result == game.model.result() and game.shell._debrief_charts.get_child(0).samples == game.model.result().history,"Debrief equations and graphs use the exact completed run")
	check(is_equal_approx(float(game.model.result().cleaned_work), 3.58) and is_equal_approx(float(game.model.result().dose_ugy), 10.9375), "Mixed effort yields3.58sections and the fixed-duration scenario dose10.9375microgray")
	check(game.shell._debrief_charts.get_child(0).channel == "battery_kwh", "Debrief charts actual stored energy")
	check(game.progress.runs.is_empty() and not game._pending_result.is_empty(),"Quiz remains answerable before the pending run is saved")
	game.shell.answer_quiz(1)
	game.shell.answer_quiz(0)
	check(game._quiz.first_answer == 1 and not game._quiz.correct and game._quiz.question_id == "pace-fatigue-transfer-1","Controller retains the first cleaning-rate transfer answer despite a practice retry")
	game.shell.retry_requested.emit()
	await frames()
	var after_run := Progress.new()
	check(game.stage == "mission" and not game.mission_started and game.progress.reviewed_ids.size() == 8,"Retry returns directly to preflight with previously explored ideas")
	check(after_run.runs.size() == 1 and after_run.runs[0].status == "win" and after_run.runs[0].quiz.first_answer == 1 and after_run.runs[0].quiz.question_id == "pace-fatigue-transfer-1","Completed outcome and first quiz evidence survive a disk reload")
	check(is_equal_approx(after_run.runs[0].dose_ugy, 10.9375),"Saved dose is the actual completed model dose")
	check(game.world.get_instance_id() == world_id and game.model.snapshot().elapsed_seconds == 0,"A new attempt reuses the world while resetting mission state")
	game.show_live_sun()
	await frames()
	check(is_instance_valid(game.solar_data_panel) and game.paused and not is_instance_valid(game.modal),"NASA can pause active play directly before a quit request")
	game.show_quit()
	await frames()
	check(not is_instance_valid(game.solar_data_panel) and game.modal_kind == "quit" and game.paused,"Quit request closes the higher NASA viewer and preserves the quit dialog")
	if game.modal_kind != "quit": game.show_quit()
	await click_modal("Stay here")
	await click_modal("Resume mission")
	game.model.advance(10.0)
	game._process(0.0)
	game.request_home()
	await frames()
	check(game.modal_kind == "confirm" and game.stage == "mission" and game.paused,"Home during play asks before ending the unfinished attempt")
	await click_modal("Keep this mission")
	check(game.modal_kind == "pause" and game.model.snapshot().elapsed_seconds == 10.0,"Cancelling Home preserves the current attempt")
	game.confirm_restart()
	await frames()
	await click_modal("Restart mission")
	check(game.stage == "mission" and not game.mission_started and game.model.snapshot().elapsed_seconds == 0,"Confirmed restart resets to preflight for an explicit fresh Start")
	check(game.progress.runs.size() == 1,"Restarting an unfinished attempt does not fabricate a completed record")
	game.request_home()
	await frames()
	await click_modal("Leave mission")
	check(game.stage == "home" and game.modal_kind == "home" and root.disable_3d,"Confirmed Home leads to a reachable menu without advancing the world")
	var home_id: int = game.modal.get_instance_id()
	await click_modal("Live Sun · NASA observation")
	check(is_instance_valid(game.solar_data_panel) and game.solar_data_panel.layer == 31 and game.modal.get_instance_id() == home_id,"Home launches the same NASA viewer above its retained menu")
	probe_nasa_source("Home NASA source action emits the same fixed official data-page URL")
	await key(KEY_ESCAPE)
	check(game.modal_kind == "home" and not is_instance_valid(game.solar_data_panel),"Escape from NASA restores the existing Home menu")
	await click_modal("Sound, motion & pace")
	await click_modal("Back")
	check(game.stage == "home" and game.modal_kind == "home" and is_instance_valid(game.modal),"Settings Back restores Home rather than leaving a blank screen")
	game.show_settings()
	await frames()
	await key(KEY_ESCAPE)
	check(game.modal_kind == "home" and is_instance_valid(game.modal),"Settings Escape also restores Home")
	game.show_preparation()
	await frames()
	check(game.shell.readiness == 1.0 and game.progress.runs.size() == 1,"Home round trip preserves explored ideas and exactly one completed run")
	check(not is_instance_valid(game.update_client) or not game.update_client._checked_this_session,"The entire integration flow stayed offline")
	assert_solar_offline("NASA image transport remained unused throughout the complete integration flow")
	var guard: Node = game._guard
	game.queue_free()
	await frames(10)
	check(not is_instance_valid(guard),"Leaving the source scene removes its global input guard")
	print("JOURNEY INTEGRATION ASSERTIONS: ",assertions," FAILURES: ",failures)
	quit(1 if failures else 0)
