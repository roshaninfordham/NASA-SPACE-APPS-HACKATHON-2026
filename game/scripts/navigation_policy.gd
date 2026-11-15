extends Node
## Explicit window-mode actions. The owning controller decides how Escape pauses
## or closes UI and is responsible for consuming the input event exactly once.
signal window_mode_requested(fullscreen: bool)

class DesktopWindowBackend extends RefCounted:
	func mode() -> int:
		return DisplayServer.window_get_mode()
	func set_mode(value: int) -> void:
		DisplayServer.window_set_mode(value)
	func size() -> Vector2i:
		return DisplayServer.window_get_size()
	func position() -> Vector2i:
		return DisplayServer.window_get_position()
	func usable_rect() -> Rect2i:
		return DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
	func set_geometry(window_size: Vector2i, window_position: Vector2i) -> void:
		# Browsers own canvas sizing and monitor position. Godot's web display
		# backend implements window_set_mode; do not fight responsive CSS here.
		if OS.has_feature("web"): return
		DisplayServer.window_set_size(window_size)
		DisplayServer.window_set_position(window_position)
	func release_pointer() -> void:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	func supported() -> bool:
		return DisplayServer.get_name() != "headless"

var _backend: Object
var _saved_size := Vector2i(1280, 720)
var _saved_position := Vector2i.ZERO
var _has_saved_geometry := false
var _restore_serial := 0
var _suspend_geometry_capture := false
var _last_observed_fullscreen := false

func _ready() -> void:
	_ensure_backend()
	remember_windowed_geometry()
	_last_observed_fullscreen = is_fullscreen()
	# Resizes while windowed update the remembered size, including portrait.
	# Entering fullscreen does not replace it with the monitor's dimensions.
	var window := get_window()
	if is_instance_valid(window) and not window.size_changed.is_connected(remember_windowed_geometry):
		window.size_changed.connect(remember_windowed_geometry)

func configure_backend(backend: Object) -> void:
	# Injectable display boundary for deterministic tests, never a game setting.
	_backend = backend
	_restore_serial += 1
	_has_saved_geometry = false
	_suspend_geometry_capture = false
	_last_observed_fullscreen = false

func _ensure_backend() -> void:
	if not is_instance_valid(_backend): _backend = DesktopWindowBackend.new()

func remember_windowed_geometry() -> void:
	_ensure_backend()
	if _suspend_geometry_capture or not _backend.supported() or _backend.mode() != DisplayServer.WINDOW_MODE_WINDOWED: return
	var measured_size: Vector2i = _backend.size()
	if measured_size.x <= 0 or measured_size.y <= 0: return
	_saved_size = measured_size
	_saved_position = _backend.position()
	_has_saved_geometry = true

func is_fullscreen() -> bool:
	_ensure_backend()
	if not _backend.supported(): return false
	return _backend.mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]

func toggle_fullscreen() -> bool:
	_ensure_backend()
	if not _backend.supported(): return false
	if is_fullscreen(): return exit_fullscreen()
	remember_windowed_geometry()
	_restore_serial += 1
	_suspend_geometry_capture = true
	_backend.set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	_last_observed_fullscreen = is_fullscreen()
	_settle_transition(_restore_serial)
	window_mode_requested.emit(true)
	return true

func exit_fullscreen() -> bool:
	if not is_fullscreen(): return false
	_restore_serial += 1
	var serial := _restore_serial
	_suspend_geometry_capture = true
	_backend.set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	_backend.release_pointer()
	_last_observed_fullscreen = false
	_restore_geometry(serial)
	# Native window managers may finish their mode transition asynchronously.
	# A serial guard prevents this queued restore from undoing a newer F11 press.
	if is_inside_tree(): _restore_geometry.call_deferred(serial)
	_settle_transition(serial)
	window_mode_requested.emit(false)
	return true

func _settle_transition(serial: int) -> void:
	if is_inside_tree():
		await get_tree().process_frame
		await get_tree().process_frame
	if serial != _restore_serial: return
	_suspend_geometry_capture = false
	remember_windowed_geometry()

func poll_external_exit() -> bool:
	# Browser Escape and native window decorations can change fullscreen without
	# delivering a key to the game. The controller polls before advancing time
	# and pauses if this returns true. It never recaptures the pointer here.
	var current := is_fullscreen()
	var exited := _last_observed_fullscreen and not current
	_last_observed_fullscreen = current
	if exited: _backend.release_pointer()
	return exited

func _restore_geometry(serial: int) -> void:
	if serial != _restore_serial or not is_instance_valid(_backend): return
	if _backend.mode() != DisplayServer.WINDOW_MODE_WINDOWED: return
	var bounds: Rect2i = _backend.usable_rect()
	if bounds.size.x <= 0 or bounds.size.y <= 0: return
	# Keep a visible frame/title bar. Never impose a desktop minimum that breaks
	# portrait displays or a player's intentionally narrow window.
	var available := Vector2i(maxi(1, bounds.size.x - 32), maxi(1, bounds.size.y - 48))
	var target_size := Vector2i(clampi(_saved_size.x, 1, available.x), clampi(_saved_size.y, 1, available.y))
	var target_position := _saved_position if _has_saved_geometry else bounds.position + (bounds.size - target_size) / 2
	target_position.x = clampi(target_position.x, bounds.position.x, bounds.end.x - target_size.x)
	target_position.y = clampi(target_position.y, bounds.position.y, bounds.end.y - target_size.y)
	_backend.set_geometry(target_size, target_position)

func handle_escape() -> bool:
	# First Escape exits fullscreen and frees the pointer. In windowed mode the
	# caller handles one contextual Back/pause action; this policy never quits.
	return exit_fullscreen()

func handle_key(event: InputEvent) -> bool:
	if not event is InputEventKey or not event.pressed or event.echo: return false
	var key: Key = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
	if key == KEY_ESCAPE: return handle_escape()
	if key == KEY_F11: return toggle_fullscreen()
	return false
