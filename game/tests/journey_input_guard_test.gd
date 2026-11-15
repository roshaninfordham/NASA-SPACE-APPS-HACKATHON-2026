extends SceneTree
const Guard = preload("res://scripts/journey_input_guard.gd")
var failures := 0

class Controller extends Node:
	var received: Array[InputEvent] = []
	var consume := false
	var consume_directly := false
	func handle_global_input(event: InputEvent) -> bool:
		received.append(event)
		if consume_directly: get_viewport().set_input_as_handled()
		return consume

class Modal extends Node:
	var received: Array[InputEvent] = []
	func _input(event: InputEvent) -> void:
		received.append(event)
		get_viewport().set_input_as_handled()

class VoidController extends Node:
	var received := 0
	func handle_global_input(_event: InputEvent) -> void:
		received += 1

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	if value: print("PASS: ", label)
	else:
		push_error(label)
		failures += 1

func key(code: Key, echo := false) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	event.echo = echo
	return event

func run() -> void:
	var scene := Node.new()
	root.add_child(scene)
	var receiver := Controller.new()
	scene.add_child(receiver)
	var modal := Modal.new()
	modal.process_mode = Node.PROCESS_MODE_ALWAYS
	receiver.add_child(modal)
	var guard := Guard.new()
	guard.controller = receiver
	# Order matters: the guard must follow all main-scene children of the Window.
	root.add_child(guard)
	await process_frame
	check(guard.process_mode == Node.PROCESS_MODE_ALWAYS, "Global navigation remains available while the scene tree is paused")
	receiver.consume = true
	var escape := key(KEY_ESCAPE)
	root.push_input(escape)
	check(receiver.received.size() == 1 and receiver.received[0] == escape and modal.received.is_empty(), "Root-last guard forwards the original Escape and stops a nested consuming modal")
	receiver.consume = false
	root.push_input(key(KEY_ESCAPE))
	check(receiver.received.size() == 2 and modal.received.size() == 1, "Unconsumed windowed Escape reaches one existing modal")
	receiver.consume_directly = true
	root.push_input(key(KEY_F11))
	check(receiver.received.size() == 3 and modal.received.size() == 1, "Controller may also consume input directly without a true return")
	receiver.consume_directly = false
	receiver.consume = true
	paused = true
	root.push_input(key(KEY_ESCAPE))
	check(receiver.received.size() == 4 and modal.received.size() == 1, "Paused-scene Escape still reaches the controller before modal input")
	paused = false
	var repeated := key(KEY_F11, true)
	root.push_input(repeated)
	check(receiver.received.back() == repeated, "Key repeat filtering belongs to the controller rather than a second conflicting policy")
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	var before_mouse := receiver.received.size()
	root.push_input(mouse)
	var forwarded: InputEvent = receiver.received.back()
	check(receiver.received.size() == before_mouse + 1 and forwarded is InputEventMouseButton and forwarded.button_index == MOUSE_BUTTON_LEFT and forwarded.pressed, "Pointer events reach the controller for user-gesture audio and fullscreen handling")
	var replacement := VoidController.new()
	scene.add_child(replacement)
	guard.controller = replacement
	var previous_count := receiver.received.size()
	var modal_count := modal.received.size()
	root.push_input(key(KEY_ESCAPE))
	check(replacement.received == 1 and receiver.received.size() == previous_count and modal.received.size() == modal_count + 1, "Rebinding routes input to a void-return controller and safely yields")
	replacement.free()
	root.push_input(key(KEY_ESCAPE))
	check(guard.controller == null and modal.received.size() == modal_count + 2, "Freed controllers leave no dangling receiver and input yields safely")
	guard.controller = scene
	root.push_input(key(KEY_ESCAPE))
	check(modal.received.size() == modal_count + 3, "Nodes without the controller API do not trap input")
	guard.controller = null
	root.push_input(key(KEY_ESCAPE))
	check(modal.received.size() == modal_count + 4, "An unbound guard does not trap input")
	guard.controller = receiver
	receiver.tree_exiting.connect(guard.queue_free)
	receiver.queue_free()
	await process_frame
	await process_frame
	check(not is_instance_valid(guard), "Controller lifetime binding removes the root guard on scene exit")
	scene.queue_free()
	await process_frame
	print("JOURNEY INPUT GUARD FAILURES: ", failures)
	quit(1 if failures else 0)
