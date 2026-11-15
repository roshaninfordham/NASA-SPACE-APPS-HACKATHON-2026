extends SceneTree
## Actual main-scene training journal, coaching and completed-run persistence.
## The runner must supply a fresh XDG_DATA_HOME; this suite never uses networking.
const Progress = preload("res://scripts/journey_progress.gd")
var game: Node3D
var assertions := 0
var failures := 0

func _initialize() -> void: run.call_deferred()

func check(condition: bool, message: String) -> void:
	assertions += 1
	if condition: print("PASS: ", message)
	else:
		failures += 1
		push_error(message)

func frames(count := 6) -> void:
	for index in range(count): await process_frame

func button_text(title: String) -> Button:
	if not is_instance_valid(game.modal): return null
	for button in game.modal.find_children("*", "Button", true, false):
		if button.text == title: return button
	return null

func click(title: String) -> void:
	var button := button_text(title)
	check(button != null and button.is_visible_in_tree() and not button.disabled, "Reachable training navigation: " + title)
	if button: button.pressed.emit()
	await frames()

func journal_action(node_name: String) -> void:
	var button: Button = game.modal.find_child(node_name, true, false) if is_instance_valid(game.modal) else null
	check(button != null and button.is_visible_in_tree() and not button.disabled, "Reachable journal action: " + node_name)
	if button: button.pressed.emit()
	await frames()

func finish_radio() -> void:
	# Advance only presentation time. The real mission never runs while tests
	# inspect a caption; its clock is advanced explicitly below.
	game.hud.set_feedback_paused(false)
	game.hud.set_process(false)
	for index in range(21): game.hud._process(0.25)
	check(not game.hud.get_radio_exchange().active, "The previous radio exchange finishes before coaching speaks")

func run() -> void:
	if DisplayServer.get_name() != "headless" or OS.get_environment("XDG_DATA_HOME").is_empty() or FileAccess.file_exists(Progress.DEFAULT_PATH):
		check(false, "Run headless with a fresh isolated XDG_DATA_HOME; existing player data remains untouched")
		quit(1)
		return
	root.size = Vector2i(1280, 720)
	game = load(str(ProjectSettings.get_setting("application/run/main_scene"))).instantiate()
	game.online_sources_enabled = false
	game.set_process(false)
	root.add_child(game)
	game.set_process(false)
	await frames(10)
	game.progress.set_setting("music_enabled", false)
	game.progress.set_setting("effects_enabled", false)
	game.progress.set_setting("reduced_motion", true)
	game._apply_preferences()
	game.show_home()
	await frames()
	var empty_training: Dictionary = game.progress.training_summary()
	await click("Your training")
	check(game.stage == "home" and game.modal_kind == "training-log", "Home opens the real training journal")
	check(game.progress.training_summary() == empty_training, "Opening the journal creates no completed missions or learning credit")
	await click("Back to Home")
	check(game.modal_kind == "home", "The journal has a working Home return")
	await click("Your training")
	await journal_action("TrainingPractice")
	check(game.stage == "preparation" and game.shell.state == "preparation", "Home journal practice opens the optional Science screen")
	game.shell.open_concept("dust")
	await frames()
	check(game.progress.training_summary() == empty_training, "Merely opening a science idea does not credit reading, practice or mastery")
	game.shell._dialog_done.pressed.emit()
	await frames()
	var explored: Dictionary = game.progress.training_summary()
	check(explored.reviewed_count == 1 and explored.completed_runs == 0 and explored.practice_attempts == 0 and explored.correct_first_unassisted == 0, "Finishing a science card records exploration only, never a passed skill test")
	game.show_home()
	await frames()
	await click("Your training")
	await journal_action("TrainingPlay")
	check(game.stage == "mission" and not game.mission_started and game.model.snapshot().elapsed_seconds == 0, "Home journal play opens a fresh unstarted mission")
	game.launch_mission()
	game.hud.set_process(false)
	game.model.advance(6.0)
	var opening_radio: Dictionary = game.hud.get_radio_exchange()
	game._process(0.0)
	check(game._coach_cues.is_empty() and game.hud.get_radio_exchange() == opening_radio, "An eligible control tip cannot interrupt the opening radio exchange")
	finish_radio()
	game._process(0.0)
	check(game._coach_cues.has("controls") and game.hud.get_radio_exchange().player == "Try the pace slider.", "An idle radio offers the control tip after six actual play seconds")
	finish_radio()
	game._process(0.0)
	check(not game.hud.get_radio_exchange().active and game._coach_cues.size() == 1, "The same control tip is not repeated every frame")
	game.model.advance(4.0)
	game._process(0.0)
	var unfinished: Dictionary = game.model.snapshot()
	var model_id: int = game.model.get_instance_id()
	game.show_pause()
	await frames()
	await click("Your training")
	check(game.modal_kind == "training-log" and game.paused, "Mission training journal pauses the current attempt")
	game._process(3600.0)
	check(game.model.snapshot() == unfinished, "Reading training history spends no time, work, battery or dose")
	await click("Back to menu")
	check(game.modal_kind == "pause" and game.paused and game.model.snapshot() == unfinished, "Training Back returns to the paused mission menu")
	await click("Your training")
	await journal_action("TrainingPlay")
	check(game.stage == "mission" and game.mission_started and not game.paused and game.model.get_instance_id() == model_id and game.model.snapshot() == unfinished, "Journal play resumes the same unfinished run instead of replacing it")
	game.show_training_log()
	await frames()
	await journal_action("TrainingPractice")
	check(game.modal_kind == "notebook" and game.paused and game.model.snapshot() == unfinished, "In-mission practice opens paused Science without resetting the attempt")
	check(game.progress.training_summary() == explored, "Browsing mission practice awards no fake completed run or skill credit")
	await click("Back to mission")
	game.set_cleaning_speed(1.75)
	game.hud.set_process(false)
	var player_radio: Dictionary = game.hud.get_radio_exchange()
	game.model.advance(66.0)
	game._process(0.0)
	var urgent: Dictionary = game.model.snapshot()
	check(urgent.remaining_seconds <= 15 and urgent.fatigue >= 0.4 and urgent.clean_fraction >= 0.25, "The real mission simultaneously reaches storm, effort and cleaning coaching triggers")
	check(game.hud.get_radio_exchange() == player_radio and game._coach_cues.size() == 1, "The player's pace command takes priority over all eligible coaching")
	game.show_training_log()
	game._process(0.0)
	var paused_radio: Dictionary = game.hud.get_radio_exchange()
	game.hud._process(10.0)
	game._process(3600.0)
	check(game._coach_cues.size() == 1 and game.hud.get_radio_exchange() == paused_radio and game.model.snapshot() == urgent, "A paused journal consumes neither captions nor pending coaching cues")
	await journal_action("TrainingPlay")
	finish_radio()
	game._process(0.0)
	check(game._coach_cues.has("storm") and not game._coach_cues.has("effort") and game.hud.get_radio_exchange().player == "Storm soon. Stay ready.", "Storm coaching wins priority over effort and power after the player finishes speaking")
	finish_radio()
	game._process(0.0)
	check(game._coach_cues.has("effort") and not game._coach_cues.has("power") and game.hud.get_radio_exchange().reply == "Try slower. I’m getting tired.", "Effort coaching follows the one-time storm cue")
	finish_radio()
	game._process(0.0)
	check(game._coach_cues.has("power") and game.hud.get_radio_exchange().reply == "More light means more power.", "Power coaching explains actual completed cleaning after higher-priority cues")
	finish_radio()
	game._process(0.0)
	check(game._coach_cues.size() == 4 and not game.hud.get_radio_exchange().active and game.model.snapshot() == urgent, "All four cues are one-time observations and never change the mission model")
	game.set_cleaning_speed(0.25)
	game.model.advance(14.0)
	game._process(0.0)
	await frames()
	var completed: Dictionary = game.model.result()
	check(game.stage == "debrief" and game.shell._result == completed and game.progress.runs.is_empty(), "The debrief remains an exact model result pending one completed-run save")
	check(completed.fatigue < 0.9 and completed.command_count == 2, "The test run recovers after its peak and records two genuine pace changes")
	game.show_home()
	await frames()
	var reloaded := Progress.new()
	check(reloaded.last_error.is_empty() and reloaded.runs.size() == 1, "Home saves one completed mission that reloads without validation errors")
	if reloaded.runs.size() == 1:
		var saved: Dictionary = reloaded.runs[0]
		check(is_equal_approx(saved.clean_fraction, completed.clean_fraction) and is_equal_approx(saved.battery_kwh, completed.battery_kwh), "Stored cleaning and battery values equal the completed model measurements")
		check(is_equal_approx(saved.max_fatigue, 0.9) and saved.max_fatigue > completed.fatigue and saved.pace_changes == 2, "Stored peak fatigue is the actual maximum, not the recovered final value, with actual command count")
		check(saved.ended_at != null and saved.ended_at > 0, "A completed result records its real completion timestamp")
	check(reloaded.training_summary().completed_runs == 1 and reloaded.training_summary().practice_attempts == 0, "Mission completion does not invent a quiz attempt")
	game.show_home()
	await frames()
	await click("Your training")
	await click("Back to Home")
	game._save_result()
	check(Progress.new().runs == reloaded.runs and Progress.new().training_summary().completed_runs == 1, "Repeated Home, journal and save actions cannot duplicate the completed run")
	check(not game.solar_feed.snapshot().busy and game.solar_feed._last_attempt_ticks == -1 and (not is_instance_valid(game.update_client) or not game.update_client._checked_this_session), "The complete training journey remains offline")
	game.queue_free()
	await frames(10)
	print("TRAINING JOURNEY FLOW ASSERTIONS: ", assertions, " FAILURES: ", failures)
	quit(1 if failures else 0)
