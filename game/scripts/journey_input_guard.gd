extends Node
## A last-root-child input boundary. The controller owns all navigation rules.
## Return true from handle_global_input(event) to stop propagation, or handle
## the event there explicitly. False/null yields to the active scene's input.

var _controller_ref: WeakRef
var controller: Node:
	set(value):
		_controller_ref = weakref(value) if is_instance_valid(value) else null
	get:
		return _controller_ref.get_ref() as Node if _controller_ref != null else null

func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _input(event: InputEvent) -> void:
	var receiver := controller
	if not is_instance_valid(receiver) or not receiver.has_method("handle_global_input"):
		return
	var consumed: Variant = receiver.call("handle_global_input", event)
	if consumed is bool and consumed and is_inside_tree():
		get_viewport().set_input_as_handled()
