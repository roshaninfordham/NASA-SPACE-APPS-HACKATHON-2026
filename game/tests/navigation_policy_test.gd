extends SceneTree
const Navigation = preload("res://scripts/navigation_policy.gd")
var failures := 0
class FakeDisplay extends RefCounted:
	var current_mode := DisplayServer.WINDOW_MODE_WINDOWED
	var current_size := Vector2i(1280,720)
	var current_position := Vector2i(110,70)
	var bounds := Rect2i(0,0,1920,1040)
	var enabled := true
	var pointer_releases := 0
	var mode_requests: Array[int] = []
	var geometry_requests: Array[Dictionary] = []
	var on_mode_request: Callable
	func mode() -> int: return current_mode
	func set_mode(value: int) -> void:
		current_mode = value
		mode_requests.append(value)
		if on_mode_request.is_valid(): on_mode_request.call(value)
	func size() -> Vector2i: return current_size
	func position() -> Vector2i: return current_position
	func usable_rect() -> Rect2i: return bounds
	func set_geometry(window_size: Vector2i, window_position: Vector2i) -> void:
		current_size = window_size
		current_position = window_position
		geometry_requests.append({"size":window_size,"position":window_position})
	func release_pointer() -> void: pointer_releases += 1
	func supported() -> bool: return enabled
class InputProbe extends Node:
	var action: Callable
	func _input(event: InputEvent) -> void:
		if action.is_valid(): action.call(event)
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	if value: print("PASS: ",label)
	else:
		push_error(label)
		failures += 1
func keyboard(code: Key, pressed := true, echo := false, physical := true) -> InputEventKey:
	var event := InputEventKey.new()
	if physical: event.physical_keycode = code
	else: event.keycode = code
	event.pressed = pressed
	event.echo = echo
	return event
func frames(count := 4) -> void:
	for i in range(count): await process_frame
func verify_native_display() -> void:
	if DisplayServer.get_name() == "headless" or OS.has_feature("web"):
		push_error("Native window checks require a desktop graphical display")
		failures += 1
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(900,600))
	DisplayServer.window_set_position(Vector2i(70,40))
	await frames()
	var navigation := Navigation.new()
	root.add_child(navigation)
	check(not navigation.is_fullscreen(), "Actual display starts in a normal window")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	navigation.toggle_fullscreen()
	await frames()
	check(navigation.is_fullscreen(), "Actual display enters requested fullscreen")
	navigation.handle_escape()
	await frames()
	check(not navigation.is_fullscreen(), "Actual display leaves fullscreen on Escape policy")
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Actual captured pointer is released")
	check(DisplayServer.window_get_size() == Vector2i(900,600), "Actual prior desktop window size is restored")
	navigation.toggle_fullscreen()
	await frames()
	navigation.poll_external_exit()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	await frames()
	check(navigation.poll_external_exit(), "Actual external window-mode exit is observed")
	check(not navigation.poll_external_exit(), "Actual external exit is reported once")
	navigation.queue_free()
	await frames()
func run() -> void:
	var policy := Navigation.new()
	var display := FakeDisplay.new()
	policy.configure_backend(display)
	root.add_child(policy)
	await process_frame
	check(display.mode_requests.is_empty() and display.geometry_requests.is_empty(), "Navigation initialization never forces fullscreen or changes window geometry")
	check(not policy.handle_escape() and display.pointer_releases == 0, "Windowed Escape yields to one contextual controller action")
	check(not policy.handle_key(keyboard(KEY_F11,false)) and not policy.handle_key(keyboard(KEY_F11,true,true)), "Key releases and repeats cannot toggle fullscreen")
	check(not policy.handle_key(keyboard(KEY_F10)) and not policy.handle_key(InputEventMouseButton.new()), "Unrelated input is not consumed")
	check(policy.handle_key(keyboard(KEY_F11)) and policy.is_fullscreen(), "Physical F11 requests fullscreen through explicit dispatch")
	display.current_size = Vector2i(1920,1080)
	display.current_position = Vector2i.ZERO
	policy.remember_windowed_geometry()
	display.on_mode_request = func(_value): policy.remember_windowed_geometry()
	check(policy.handle_escape() and not policy.is_fullscreen() and display.pointer_releases == 1, "First fullscreen Escape requests windowed mode and releases pointer")
	check(display.current_size == Vector2i(1280,720) and display.current_position == Vector2i(110,70), "Fullscreen monitor size cannot overwrite prior window geometry")
	display.on_mode_request = Callable()
	await process_frame
	await process_frame
	check(not policy.handle_escape() and display.pointer_releases == 1, "Second Escape yields without repeated window or cursor side effects")
	display.current_mode = DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	check(policy.handle_escape() and display.current_mode == DisplayServer.WINDOW_MODE_WINDOWED, "Exclusive fullscreen follows the same Escape exit policy")
	await process_frame
	await process_frame
	display.current_size = Vector2i(390,844)
	display.current_position = Vector2i(200,40)
	policy.remember_windowed_geometry()
	check(policy.handle_key(keyboard(KEY_F11,true,false,false)), "Logical F11 remains supported when no physical keycode is supplied")
	policy.exit_fullscreen()
	check(display.current_size == Vector2i(390,844), "Portrait window size is preserved rather than forced to a desktop minimum")
	await process_frame
	await process_frame
	policy.toggle_fullscreen()
	display.bounds = Rect2i(-800,30,800,600)
	policy.exit_fullscreen()
	check(display.current_size.x <= 768 and display.current_size.y <= 552 and display.bounds.encloses(Rect2i(display.current_position,display.current_size)), "Restoration fits a smaller or relocated monitor's usable rectangle")
	await process_frame
	await process_frame
	policy.toggle_fullscreen()
	policy.exit_fullscreen()
	var restored_before := display.geometry_requests.size()
	policy.toggle_fullscreen()
	await process_frame
	check(policy.is_fullscreen() and display.geometry_requests.size() == restored_before, "Queued restoration cannot undo a newer same-frame fullscreen request")
	policy.exit_fullscreen()
	await process_frame
	await process_frame
	display.current_mode = DisplayServer.WINDOW_MODE_FULLSCREEN
	check(not policy.poll_external_exit(), "Polling observes an externally entered fullscreen mode without pausing")
	display.current_mode = DisplayServer.WINDOW_MODE_WINDOWED
	var release_count := display.pointer_releases
	check(policy.poll_external_exit() and display.pointer_releases == release_count + 1, "Browser or native fullscreen exit without a key event releases pointer and requests a pause")
	check(not policy.poll_external_exit(), "External fullscreen exit is reported once")
	display.enabled = false
	var request_count := display.mode_requests.size()
	check(not policy.handle_escape() and not policy.toggle_fullscreen() and display.mode_requests.size() == request_count, "Unsupported/headless displays do not receive window changes")
	display.enabled = true
	# Verify Godot's real event traversal, not only a direct function call. The
	# last root child must see fullscreen Escape before a nested modal consumes it.
	var parent := Node.new()
	root.add_child(parent)
	var counts := {"modal":0,"context":0,"paused":false}
	var modal := InputProbe.new()
	modal.action = func(event):
		if event is InputEventKey and event.pressed:
			counts.modal += 1
			root.set_input_as_handled()
	parent.add_child(modal)
	var guard := InputProbe.new()
	guard.process_mode = Node.PROCESS_MODE_ALWAYS
	guard.action = func(event):
		if policy.handle_key(event):
			if event.physical_keycode == KEY_ESCAPE: counts.paused = true
			root.set_input_as_handled()
		elif event is InputEventKey and event.physical_keycode == KEY_ESCAPE and event.pressed:
			counts.context += 1
	root.add_child(guard)
	policy.toggle_fullscreen()
	root.push_input(keyboard(KEY_ESCAPE))
	check(not policy.is_fullscreen() and counts.paused and counts.modal == 0 and counts.context == 0, "Last-root guard exits fullscreen and pauses before a child modal handles Escape")
	root.push_input(keyboard(KEY_ESCAPE))
	check(counts.context == 1 and counts.modal == 1, "Windowed Escape can reach the existing child modal without a second fullscreen action")
	guard.queue_free()
	parent.queue_free()
	policy.queue_free()
	await process_frame
	if "--native-window-check" in OS.get_cmdline_user_args(): await verify_native_display()
	print("NAVIGATION POLICY FAILURES: ",failures)
	quit(1 if failures else 0)
