extends SceneTree
const Connections = preload("res://scripts/connection_policy.gd")
const Feed = preload("res://live/solar_feed.gd")
const Client = preload("res://updater/client.gd")
var failed := 0
var count := 0
class ProbeFeed extends "res://live/solar_feed.gd":
	var requests := 0
	func _make_request() -> HTTPRequest:
		requests += 1
		return HTTPRequest.new()
func check(ok: bool, message: String) -> void:
	count += 1
	print("CHECK ", count, ": ", message)
	if not ok: failed += 1; push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	check(not Connections.load_enabled(), "A fresh profile defaults to offline")
	check(Connections.save_enabled(true) == OK, "Optional online choice saves locally")
	check(Connections.load_enabled(), "Optional online choice restores")
	Connections.save_enabled(false)
	var feed := ProbeFeed.new()
	root.add_child(feed)
	feed.set_network_enabled(false)
	feed.refresh(true)
	check(feed.requests == 0, "Manual NASA refresh cannot create a request while offline")
	check(feed.snapshot().texture != null, "Bundled NASA image remains available offline")
	check(not feed.snapshot().is_live, "Offline image is never labelled live")
	var updater := Client.new()
	root.add_child(updater)
	updater.set_network_enabled(false)
	updater.check_for_updates(true)
	check(not updater.busy and updater._request == null, "Manual update check is blocked offline")
	var blocked: Dictionary = await updater._fetch(Client.RELEASES_URL, 1024)
	check(not blocked.ok and blocked.error == "offline", "Transport itself enforces offline mode")
	updater.install_update()
	check(updater._request == null, "Offline install cannot begin a download")
	var game: Node = load("res://main.tscn").instantiate()
	root.add_child(game)
	for i in range(5): await process_frame
	check(not game.online_sources_enabled, "Game restores offline default")
	check(not game.solar_feed.network_enabled and not game.update_client.network_enabled, "Game applies policy to both optional clients")
	game.show_preparation()
	game.shell.open_concept("power")
	var toggle: Button = game.shell.find_child("OfflineCoachToggle", true, false)
	var content: Control = game.shell.find_child("OfflineCoachContent", true, false)
	check(toggle != null and content != null, "Coach is reachable from an existing science card")
	toggle.button_pressed = true
	check(content.visible, "Coach expands by normal button interaction")
	var question: Label = content.find_child("OfflineCoachQuestion", true, false)
	check(question != null and not question.text.is_empty(), "Coach supplies an investigation question offline")
	game.shell.close_concept()
	game.show_settings()
	var connection: CheckButton = game.modal.find_child("OnlineSources", true, false)
	check(connection != null and not connection.button_pressed, "Optional connectivity is visible and off in Settings")
	game.queue_free();feed.queue_free();updater.queue_free()
	for i in range(3): await process_frame
	print("OFFLINE MODE: ", count, " checks; ", failed, " failures")
	quit(1 if failed else 0)
