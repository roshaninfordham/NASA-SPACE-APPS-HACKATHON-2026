extends SceneTree
## Native display acceptance for the actual main scene. Requires a fresh isolated
## XDG_DATA_HOME and KOMAKU_NATIVE_NAVIGATION_TEST=1. Never uses a mocked display.
## Run with an authenticated Xvfb display on Linux; not a physical Mac test.
const Progress = preload("res://scripts/journey_progress.gd")
const X11_FOCUS = """
import ctypes as C, sys, time
x = C.CDLL('libX11.so.6')
x.XOpenDisplay.argtypes = [C.c_char_p]; x.XOpenDisplay.restype = C.c_void_p
x.XDefaultRootWindow.argtypes = [C.c_void_p]; x.XDefaultRootWindow.restype = C.c_ulong
x.XCreateSimpleWindow.argtypes = [C.c_void_p,C.c_ulong,C.c_int,C.c_int,C.c_uint,C.c_uint,C.c_uint,C.c_ulong,C.c_ulong]
x.XCreateSimpleWindow.restype = C.c_ulong
x.XMapRaised.argtypes = [C.c_void_p,C.c_ulong]
x.XSetInputFocus.argtypes = [C.c_void_p,C.c_ulong,C.c_int,C.c_ulong]
x.XFlush.argtypes = [C.c_void_p]
x.XDestroyWindow.argtypes = [C.c_void_p,C.c_ulong]
x.XCloseDisplay.argtypes = [C.c_void_p]
d = x.XOpenDisplay(None)
if not d: raise SystemExit('Cannot open isolated X11 display')
main = int(sys.argv[1])
if sys.argv[2] == 'focus':
    x.XSetInputFocus(d,main,2,0); x.XFlush(d)
else:
    other = x.XCreateSimpleWindow(d,x.XDefaultRootWindow(d),1,1,40,40,0,0,0)
    x.XMapRaised(d,other); x.XSetInputFocus(d,other,2,0); x.XFlush(d)
    time.sleep(3)
    x.XSetInputFocus(d,main,2,0); x.XDestroyWindow(d,other); x.XFlush(d)
x.XCloseDisplay(d)
"""
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

func frames(count := 6) -> void:
	for index in range(count): await process_frame

func key(code: Key, physical_only := false) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_NONE if physical_only else code
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event)
	await frames()

func button_named(parent: Node, title: String) -> Button:
	if not is_instance_valid(parent): return null
	for candidate in parent.find_children("*", "Button", true, false):
		if candidate.text == title: return candidate
	return null

func click_button(button: Button) -> void:
	check(is_instance_valid(button) and button.is_visible_in_tree(), "Native viewport contains a visible navigation button")
	if not is_instance_valid(button): return
	var position: Vector2 = button.get_global_transform_with_canvas() * (button.size / 2.0)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = position
		event.global_position = position
		root.push_input(event, true)
	await frames()

func focus_check() -> void:
	if DisplayServer.get_name() != "X11":
		print("SKIP: Real external focus transfer requires the X11 fixture")
		return
	var handle := DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE)
	var process_id := OS.create_process("python3", ["-c", X11_FOCUS, str(handle), "transfer"])
	check(process_id > 0, "Start a separate X11 client to transfer real application focus")
	if process_id <= 0: return
	var deadline := Time.get_ticks_msec() + 8000
	while game.focused and Time.get_ticks_msec() < deadline: await process_frame
	check(not game.focused and game.paused, "Real application focus loss pauses the mission")
	var frozen: Dictionary = game.model.snapshot()
	await frames(3)
	check(game.model.snapshot() == frozen, "Mission equations and clock remain frozen while another application has focus")
	deadline = Time.get_ticks_msec() + 8000
	while not game.focused and Time.get_ticks_msec() < deadline: await process_frame
	check(game.focused and game.paused and game.modal_kind == "pause", "Returning native focus leaves the mission paused for explicit Resume")
	if OS.is_process_running(process_id): OS.kill(process_id)

func run() -> void:
	if DisplayServer.get_name() == "headless" or OS.has_feature("web"):
		check(false, "This suite requires a real native graphical DisplayServer")
		quit(1)
		return
	if OS.get_environment("KOMAKU_NATIVE_NAVIGATION_TEST") != "1" or OS.get_environment("XDG_DATA_HOME").is_empty() or FileAccess.file_exists(Progress.DEFAULT_PATH):
		check(false, "Use KOMAKU_NATIVE_NAVIGATION_TEST=1 and a fresh isolated XDG_DATA_HOME; existing profiles remain untouched")
		quit(1)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(900, 600))
	DisplayServer.window_set_position(Vector2i(60, 40))
	await frames()
	var original_size := DisplayServer.window_get_size()
	var original_position := DisplayServer.window_get_position()
	game = load(str(ProjectSettings.get_setting("application/run/main_scene"))).instantiate()
	game.online_sources_enabled = false
	root.add_child(game)
	current_scene = game
	# Disable only unrelated network discovery; retain real bootstrap/client/UI.
	game.update_client._checked_this_session = true
	AudioServer.set_bus_mute(0, true)
	await frames()
	if DisplayServer.get_name() == "X11":
		check(OS.execute("python3", ["-c", X11_FOCUS, str(DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE)), "focus"]) == 0, "Focus the native game window through X11")
		await frames()
	check(not game.navigation.is_fullscreen() and DisplayServer.window_get_size() == original_size, "Actual main scene preserves the initial windowed geometry")
	check(root.get_child(root.get_child_count() - 1) == game._guard, "Actual main scene installs its input guard last on the root Window")
	game.start_mission()
	game.launch_mission()
	await frames()
	await key(KEY_F11, true)
	check(game.navigation.is_fullscreen() and not game.paused, "Real F11 input enters fullscreen without pausing active play")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await key(KEY_ESCAPE, true)
	check(not game.navigation.is_fullscreen() and game.paused and game.modal_kind == "pause", "First physical-only Escape leaves native fullscreen and opens Pause")
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Fullscreen Escape releases the native captured pointer")
	check(DisplayServer.window_get_size() == original_size and DisplayServer.window_get_position() == original_position, "Fullscreen Escape restores the actual prior window size and position")
	var frozen: Dictionary = game.model.snapshot()
	await frames()
	check(game.model.snapshot() == frozen, "Paused native mission does not charge time, dose or cleaning progress")
	await key(KEY_ESCAPE, true)
	check(not game.paused and not is_instance_valid(game.modal), "Second Escape resumes exactly one pause layer")
	await focus_check()
	await key(KEY_ESCAPE)
	check(not game.paused, "Explicit Escape resumes after real focus returns")
	await key(KEY_F11)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	await frames()
	check(game.paused and game.modal_kind == "pause", "External native fullscreen exit without a game key also pauses")
	game.show_home()
	game.show_updates()
	await frames()
	check(is_instance_valid(game.update_panel) and game.update_panel.layer > game.interface.get_parent().layer, "The native updater is above the Home interface")
	await key(KEY_ESCAPE)
	check(not is_instance_valid(game.update_panel) and game.modal_kind == "home", "Escape closes only the native updater and retains Home")
	game.show_updates()
	await frames()
	game.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	await frames()
	var quit_above_update: bool = not is_instance_valid(game.update_panel) or game.interface.get_parent().layer > game.update_panel.layer
	check(game.modal_kind == "quit" and quit_above_update, "Native window-close confirmation is visible above or after closing the updater")
	if quit_above_update:
		await click_button(button_named(game.modal, "Stay here"))
		check(game.stage == "home" and game.modal_kind == "home", "Native pointer cancels quit and returns to Home")
	else:
		game.update_panel.close()
		game.show_home()
	game.open_legacy()
	await frames()
	check(not auto_accept_quit, "Opening the advanced lab cannot re-enable unconfirmed window-close")
	game.legacy.show_academy()
	await frames()
	game.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	await frames()
	check(game.modal_kind == "quit" and game.interface.get_parent().layer > game.legacy.academy.layer, "Quit confirmation is above the legacy academy overlay")
	await click_button(button_named(game.modal, "Stay here"))
	check(game.stage == "legacy" and not is_instance_valid(game.modal) and is_instance_valid(game.legacy.academy), "Native pointer cancels quit without closing the advanced lab's academy")
	game.legacy.academy.close()
	await frames()
	game.legacy.begin()
	await frames()
	game.request_close_legacy()
	await frames()
	check(game.modal_kind == "legacy-confirm" and game.legacy.paused, "Leaving a running advanced-lab attempt pauses and asks before discarding")
	await key(KEY_ESCAPE)
	check(game.stage == "legacy" and game.legacy.paused and not is_instance_valid(game.modal), "Escape cancels only the discard confirmation and retains the paused legacy attempt")
	game.request_close_legacy()
	await frames()
	await click_button(button_named(game.modal, "Return to the new journey"))
	check(game.stage == "home" and not is_instance_valid(game.legacy) and not auto_accept_quit, "Confirmed advanced-lab exit returns Home with window-close protection intact")
	var guard: Node = game._guard
	game.queue_free()
	await frames()
	check(not is_instance_valid(guard), "Closing the main controller frees its native root input guard")
	print("JOURNEY NATIVE NAVIGATION ASSERTIONS: ", assertions, " FAILURES: ", failures)
	quit(1 if failures else 0)
