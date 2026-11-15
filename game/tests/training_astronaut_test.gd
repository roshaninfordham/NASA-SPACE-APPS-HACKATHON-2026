extends SceneTree
## Cosmetic cleaning rig: attachment, plane contact, reversibility and rate bounds.
const Astronaut = preload("res://art/red_veil/astronaut.gd")
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	if ok: print("PASS: ", label)
	else:
		push_error(label)
		failures += 1
func ids(node: Node) -> Array:
	var result: Array = [node.get_instance_id()]
	for child in node.get_children(): result.append_array(ids(child))
	return result
func pose(actor) -> Array:
	return [actor._upper.transform, actor._head.transform, actor._training_shoulder.transform, actor._training_elbow.transform, actor._training_wand.transform, actor._training_brush.transform]
func run() -> void:
	var actor := Astronaut.new()
	root.add_child(actor)
	actor.set_process(false)
	check(actor._training_rig == null and actor._training_tools == null, "Idle/exhibit sculpture allocates no cleaning rig or tool")
	var original_nodes := ids(actor)
	var original_meshes: Dictionary = {}
	for node in actor.find_children("*", "MeshInstance3D", true, false): original_meshes[node] = node.mesh
	actor._process(0.1)
	var old_upper: Transform3D = actor._upper.transform
	var old_head: Transform3D = actor._head.transform
	actor.set_training_cleaning(false)
	check(ids(actor) == original_nodes and actor._upper.transform == old_upper and actor._head.transform == old_head, "Inactive call preserves original idle pose and creates no nodes")
	actor.set_training_cleaning(true)
	var allocated_nodes := ids(actor)
	check(actor._training_rig.visible and actor._training_tools.visible, "First cleaning request creates attached articulated arms and tool")
	var brush_min := Vector3(INF, INF, INF)
	var brush_max := Vector3(-INF, -INF, -INF)
	var palm_min := Vector3(INF, INF, INF)
	var palm_max := Vector3(-INF, -INF, -INF)
	var bounded := true
	var connected := true
	var contacting := true
	var planted := true
	for index in range(180):
		actor._process(0.017)
		var elbow: Vector3 = actor._upper.to_local(actor._training_elbow.global_position)
		var shoulder: Vector3 = actor._upper.to_local(actor._training_shoulder.global_position)
		connected = connected and shoulder.is_equal_approx(actor.WORK_SHOULDER) and is_equal_approx(shoulder.distance_to(elbow), actor.WORK_SHOULDER.distance_to(actor.WORK_ELBOW))
		var forearm: Transform3D = actor._training_shoulder.transform * actor._training_elbow.transform
		var wrist := forearm * (actor.WORK_WRIST - actor.WORK_ELBOW)
		connected = connected and is_equal_approx(elbow.distance_to(wrist), actor.WORK_ELBOW.distance_to(actor.WORK_WRIST))
		var palm: Vector3 = actor._upper.transform * (forearm * (actor.WORK_WRIST - actor.WORK_ELBOW + (actor.WORK_WRIST - actor.WORK_ELBOW).normalized() * 0.045))
		palm_min = palm_min.min(palm)
		palm_max = palm_max.max(palm)
		var handle_start: Vector3 = actor._training_wand.transform * Vector3(0, -0.5, 0)
		connected = connected and palm.distance_to(handle_start) < 0.0001
		var contact: Vector3 = actor._training_brush.position - actor._training_brush.basis.y * 0.0175
		brush_min = brush_min.min(contact)
		brush_max = brush_max.max(contact)
		var tilt := deg_to_rad(-35.0)
		var expected_y := 1.08 + 0.04 / cos(tilt) - tan(tilt) * contact.z
		contacting = contacting and absf(contact.y - expected_y) < 0.0001 and contact.x > 0.63 and contact.x < 3.0
		bounded = bounded and absf(contact.z) <= actor.BRUSH_SWEEP_METERS + 0.001 and contact.y > 0.83 and contact.y < 1.42 and actor._training_phase >= 0 and actor._training_phase < TAU
		planted = planted and actor.transform == Transform3D.IDENTITY and (actor._upper.transform * Vector3(0, 0.795, -0.005)).distance_to(Vector3(0, 0.795, -0.005)) < 0.0001
	check(connected, "Shoulder/elbow lengths remain fixed and the brush handle stays in the glove")
	check(contacting and bounded, "Brush stays on the actual tilted panel plane within a bounded sweep")
	check(brush_max.z - brush_min.z > 0.75 and brush_max.y - brush_min.y > 0.5, "Visible brush traverses a broad panel strip instead of a tiny wrist twitch")
	check(palm_max.z - palm_min.z > 0.14, "Ren’s working glove visibly moves with the brush rather than holding a static arm")
	check(planted, "Training pose pivots at the hip and never translates the actor or feet")
	check(ids(actor) == allocated_nodes, "Continuous work reuses existing geometry without node accumulation")
	actor.set_training_cleaning(true, 1.0, true)
	var still := pose(actor)
	for index in range(40): actor._process(0.25)
	check(pose(actor) == still, "Reduced motion holds the whole working pose still, including head and tool")
	actor.set_training_cleaning(false)
	var restored := true
	for mesh in original_meshes: restored = restored and mesh.mesh == original_meshes[mesh]
	check(restored and not actor._training_rig.visible and not actor._training_tools.visible, "Stopping restores exact original mesh resources and hides work geometry")
	check(actor._upper.position.x == 0 and actor._upper.position.z == 0 and actor._upper.rotation.x == 0 and actor._upper.rotation.y == 0, "Stopping removes working incline without accumulating offsets")
	actor.set_training_cleaning(true, 1.0)
	actor._process(0.1)
	var regular: float = actor._training_phase
	actor.set_training_cleaning(false)
	actor.set_training_cleaning(true, 2.0)
	actor._process(0.1)
	check(is_equal_approx(actor._training_phase, regular * 2), "Caller work-rate multiplier scales sweep rate")
	var phase: float = actor._training_phase
	actor.set_training_cleaning(true, 0.0)
	actor._process(10.0)
	check(actor._training_phase == phase, "Zero work rate freezes phase instead of inventing cleaning progress")
	actor.set_training_cleaning(true, INF)
	check(actor._training_multiplier == 1.0, "Nonfinite work rate safely uses default presentation speed")
	actor.set_training_cleaning(true, -2)
	check(actor._training_multiplier == 0.0, "Negative work rate cannot reverse the cleaning motion")
	actor.set_training_cleaning(true, 100)
	check(actor._training_multiplier == 4.0, "Extreme caller rate is bounded for readable motion")
	var before_invalid := pose(actor)
	actor._process(NAN)
	actor._process(-1)
	check(pose(actor) == before_invalid, "Invalid elapsed time cannot contaminate transforms")
	for index in range(25):
		actor.set_training_cleaning(false)
		actor.set_training_cleaning(true, 1.0)
	check(ids(actor) == allocated_nodes, "Repeated mode transitions build the rig only once")
	actor.free()
	var prepared := Astronaut.new()
	prepared.set_training_cleaning(true, 1.5, true)
	check(prepared.get_child_count() == 0, "Pre-tree cleaning request creates no premature geometry")
	root.add_child(prepared)
	prepared.set_process(false)
	check(prepared._training_active and prepared._training_multiplier == 1.5 and prepared._training_tools.visible, "Pre-tree cleaning state is replayed after model construction")
	prepared.free()
	print("TRAINING ASTRONAUT FAILURES: ", failures)
	quit(1 if failures else 0)
