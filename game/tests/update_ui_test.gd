extends SceneTree
var failures := 0

func check(condition: bool, message: String) -> void:
	if condition: print("PASS: ", message)
	else:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene = load("res://legacy_mission.tscn")
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	var client = game.update_client
	check(is_instance_valid(client) and client.get_parent() == root.get_node("Updates"), "Updater lives across mission scene reloads")
	game.show_updates()
	await process_frame
	check(is_instance_valid(game.update_panel) and not game.player.enabled, "Update screen opens between missions without enabling movement")
	game.update_panel.close()
	await process_frame
	client.available_version = "0.4.0-alpha.2"
	client.manual_update_required = true
	client.changed.emit()
	check(game.update_notice.visible, "A newer release produces a small title notification")
	check(game.update_notice.global_position.x >= 0 and game.update_notice.global_position.x + game.update_notice.size.x <= 1280, "Update notification stays inside the viewport")
	game.begin()
	check(not game.update_notice.visible, "Notification is deferred while the astronaut is playing")
	game.show_updates()
	check(not is_instance_valid(game.update_panel), "Active mission cannot be interrupted by installation UI")
	# Simulate the transport's already-verified ready state; no OS restart is invoked.
	client.ready_to_restart = true
	client.status = "ready"
	client.changed.emit()
	game.action_audio.stop()
	game.player.footsteps.stop()
	game.queue_free()
	await process_frame
	game = scene.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	check(game.update_client == client and client.ready_to_restart, "Ready update survives starting another mission scene")
	game.show_updates()
	await process_frame
	check(game.update_panel.restart_button.visible, "Deferred update still offers restart in the game")
	game.update_panel.confirm_restart()
	check(game.update_panel.restart_button.text == "YES — RESTART NOW", "Restart requires an explicit final click")
	game.update_panel.close()
	await process_frame
	check(not game.player.enabled, "Leaving update confirmation preserves title-screen controls")
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
