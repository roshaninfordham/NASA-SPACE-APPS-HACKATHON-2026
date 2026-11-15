extends SceneTree
## New main-scene update navigation. Fake only release availability/ready state;
## never performs HTTP, installs content, invokes OS restart or verifies crypto.
## Requires a fresh isolated XDG_DATA_HOME, as supplied by scripts/test_game.py.
const Progress = preload("res://scripts/journey_progress.gd")
var game: Node3D
var assertions := 0
var failures := 0

func _initialize() -> void: call_deferred("run")

func check(condition: bool, description: String) -> void:
	assertions += 1
	if condition: print("PASS: ", description)
	else:
		failures += 1
		push_error(description)

func frames(count := 5) -> void:
	for index in range(count): await process_frame

func create_game() -> void:
	game = load(str(ProjectSettings.get_setting("application/run/main_scene"))).instantiate()
	# Freeze only coordinator time, preserving real UI, model and deferred input.
	game.set_process(false)
	root.add_child(game)
	current_scene = game
	game.set_process(false)
	await frames()

func text_in(node: Node) -> String:
	if not is_instance_valid(node): return ""
	var text := str(node.text) + "\n" if node is Label or node is Button else ""
	for child in node.get_children(): text += text_in(child)
	return text

func button_named(parent: Node, title: String) -> Button:
	if not is_instance_valid(parent): return null
	for candidate in parent.find_children("*", "Button", true, false):
		if candidate.text == title: return candidate
	return null

func click_modal(title: String) -> void:
	var button := button_named(game.modal, title)
	check(is_instance_valid(button), "Reachable update navigation action: " + title)
	if is_instance_valid(button): button.pressed.emit()
	await frames()

func publish_state(client: Node, version: String) -> void:
	client.available_version = version
	client.status = "manual"
	client.manual_update_required = true
	client.message = "A new adventure can be reviewed."
	client.changed.emit()

func run() -> void:
	if DisplayServer.get_name() != "headless" or OS.get_environment("XDG_DATA_HOME").is_empty() or FileAccess.file_exists(Progress.DEFAULT_PATH):
		check(false, "Use --headless with a fresh isolated XDG_DATA_HOME; existing player profiles remain untouched")
		quit(1)
		return
	root.size = Vector2i(1280, 720)
	AudioServer.set_bus_mute(0, true)
	await create_game()
	var bootstrap := root.get_node("Updates")
	var client: Node = game.update_client
	check(is_instance_valid(client) and client.get_parent() == bootstrap and client.current_version == bootstrap.running_version, "Journey reuses the bootstrap's persistent client and running content version")
	check(not is_instance_valid(client._request), "Headless update navigation performs no HTTP discovery")
	publish_state(client, "0.8.1-alpha.1")
	await frames()
	check(game.stage == "story" and not is_instance_valid(game.modal) and not is_instance_valid(game.update_panel), "A discovered release never interrupts the opening story")
	game.show_preparation()
	# Interrupt the deferred offer with reading before the next idle cycle.
	game.shell.open_concept("dose")
	await frames()
	check(game.shell.concept_open and not is_instance_valid(game.modal), "A queued release offer yields when a science reading card opens")
	game.shell.handle_back()
	await frames()
	check(game.modal_kind == "update-offer" and text_in(game.modal).contains("0.8.1-alpha.1"), "Closing reading in preparation presents the deferred release exactly at a safe point")
	await click_modal("Later · keep playing")
	check(game.dismissed_update == "0.8.1-alpha.1" and not is_instance_valid(game.modal), "Explicit Later dismisses this release without opening installation")
	client.changed.emit()
	game.show_preparation()
	await frames()
	check(not is_instance_valid(game.modal), "Dismissed release stays quiet across repeated changes and preparation entry")
	publish_state(client, "0.8.2-alpha.1")
	game.show_updates()
	await frames()
	check(is_instance_valid(game.update_panel) and not is_instance_valid(game.modal), "Queued announcement cannot create a hidden offer underneath an already-open updater")
	game.update_panel.close()
	await frames()
	publish_state(client, "0.8.3-alpha.1")
	game.start_mission()
	game.launch_mission()
	await frames()
	check(game.stage == "mission" and not is_instance_valid(game.modal) and not is_instance_valid(game.update_panel), "Starting a mission cancels a queued release offer")
	game.show_updates()
	check(not is_instance_valid(game.update_panel), "An active mission cannot open download/install controls")
	game.open_concept("radiation")
	publish_state(client, "0.8.4-alpha.1")
	await frames()
	check(game.shell.concept_open and not is_instance_valid(game.modal) and not is_instance_valid(game.update_panel), "New availability does not interrupt an in-mission science explanation")
	game.shell.handle_back()
	await frames()
	check(game.modal_kind == "pause", "Closing an in-mission explanation returns to Pause, without substituting an update offer")
	game.resume_mission()
	game.model.advance(600.0)
	check(game.model.snapshot().status != "running", "Debrief fixture reaches an actual model outcome")
	game.finish_mission()
	await frames()
	check(game.stage == "debrief" and game.modal_kind == "update-offer" and text_in(game.modal).contains("0.8.4-alpha.1"), "Completed mission safely offers the newest deferred release in debrief")
	await click_modal("View update")
	check(is_instance_valid(game.update_panel) and game.update_panel.client == client and game.update_panel.layer == 30 and not is_instance_valid(game.modal), "View update opens the connected layer-30 updater and closes its offer")
	game.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	await frames()
	check(not is_instance_valid(game.update_panel) and game.modal_kind == "quit", "Window-close dismisses the higher updater before showing quit confirmation")
	game.show_home()
	client.ready_to_restart = true
	client.status = "ready"
	client.message = "The verified update is ready for restart."
	client.changed.emit()
	var original_store = client.store
	var original_version: String = client.current_version
	var recovery_message := "The saved update could not open. Your earlier adventure is running safely."
	bootstrap.startup_notice = recovery_message
	game.queue_free()
	await frames()
	check(is_instance_valid(client) and client.get_parent() == bootstrap and client.ready_to_restart, "Destroying the journey leaves the ready update and persistent bootstrap client intact")
	await create_game()
	check(game.update_client == client and client.store == original_store and client.current_version == original_version and client.ready_to_restart and client.status == "ready", "A new journey controller reuses the same client without resetting ready state or running version")
	var main_listeners := 0
	for connection in client.changed.get_connections():
		if connection.callable.get_object() == game: main_listeners += 1
	check(main_listeners == 1, "Reloaded controller has one live updater listener")
	check(game.stage == "story" and not is_instance_valid(game.modal), "Ready update and recovery notice both respect the new opening story")
	# Isolate recovery presentation from availability, without erasing ready state.
	client.available_version = ""
	game.show_preparation()
	await frames()
	check(is_instance_valid(game.modal) and text_in(game.modal).contains(recovery_message), "The bootstrap recovery explanation is visible at a safe preparation point")
	if is_instance_valid(game.modal) and text_in(game.modal).contains(recovery_message):
		var buttons: Array[Node] = game.modal.find_children("*", "Button", true, false)
		check(not buttons.is_empty(), "Recovery explanation provides a visible acknowledgement action")
		if not buttons.is_empty(): buttons[-1].pressed.emit()
		await frames()
		client.changed.emit()
		await frames()
		check(not is_instance_valid(game.modal), "Acknowledging recovery keeps the same notice from repeatedly interrupting preparation")
	game.show_home()
	game.show_updates()
	await frames()
	check(is_instance_valid(game.update_panel) and game.update_panel.restart_button.visible and not game.update_panel.install_button.visible, "A retained ready update offers Restart rather than another installation")
	game.update_panel.confirm_restart()
	check(game.update_panel.restart_button.text == "YES — RESTART NOW", "Restart requires a separate explicit final confirmation")
	game.update_panel.close()
	await frames()
	check(client.ready_to_restart and game.stage == "home", "Leaving restart confirmation retains the update and the Home screen")
	check(not is_instance_valid(client._request), "Availability/UI tests never started HTTP or update transport")
	game.queue_free()
	await frames()
	print("JOURNEY UPDATE UI ASSERTIONS: ", assertions, " FAILURES: ", failures)
	quit(1 if failures else 0)
