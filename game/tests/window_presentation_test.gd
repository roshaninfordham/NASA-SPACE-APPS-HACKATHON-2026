extends SceneTree
## Mode changes must hide infrastructure and physics together, then restore exactly.
const World = preload("res://scripts/world.gd")
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	if value: print("PASS: ", message)
	else:
		push_error(message)
		failures += 1
func settle() -> void:
	await process_frame
	await process_frame
	await physics_frame
func replacement_scene() -> PackedScene:
	var node := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	node.add_child(mesh)
	mesh.owner = node
	var packed := PackedScene.new()
	packed.pack(node)
	node.free()
	return packed
func category_nodes(world: Node, categories: PackedStringArray) -> Array[Node]:
	var result: Array[Node] = []
	for category in categories:
		var pending: Array[Node] = world.get_presentation_category_roots(category)
		while not pending.is_empty():
			var node: Node = pending.pop_back()
			if result.has(node): continue
			result.append(node)
			for child in node.get_children(): pending.append(child)
	return result
func record(nodes: Array[Node]) -> Dictionary:
	var result: Dictionary = {}
	for node in nodes:
		var state := {"node": node, "process_mode": node.process_mode}
		if node is Node3D: state.visible = node.visible
		if node is CollisionObject3D:
			state.layer = node.collision_layer
			state.mask = node.collision_mask
			state.pickable = node.input_ray_pickable
		if node is CollisionShape3D or node is CollisionPolygon3D: state.disabled = node.disabled
		result[node.get_instance_id()] = state
	return result
func matches_snapshot(snapshot: Dictionary) -> bool:
	for state: Dictionary in snapshot.values():
		if not is_instance_valid(state.node): return false
		var node: Node = state.node
		if node.process_mode != state.process_mode: return false
		if node is Node3D and node.visible != state.visible: return false
		if node is CollisionObject3D and (node.collision_layer != state.layer or node.collision_mask != state.mask or node.input_ray_pickable != state.pickable): return false
		if (node is CollisionShape3D or node is CollisionPolygon3D) and node.disabled != state.disabled: return false
	return true
func assert_suspended(nodes: Array[Node]) -> void:
	var no_render := true
	var no_collision := true
	var paused := true
	for node in nodes:
		if node is Node3D and node.is_visible_in_tree(): no_render = false
		if node is CollisionObject3D and (node.collision_layer != 0 or node.collision_mask != 0 or node.input_ray_pickable): no_collision = false
		if (node is CollisionShape3D or node is CollisionPolygon3D) and not node.disabled: no_collision = false
		if node.process_mode != Node.PROCESS_MODE_DISABLED: paused = false
	check(no_render, "Window categories hide meshes, labels and lights together")
	check(no_collision, "Hidden infrastructure has no active layers, masks, pickability or collision shapes")
	check(paused, "Hidden infrastructure does not keep processing")
func kiosk_hit(world: Node3D) -> Dictionary:
	var ray := PhysicsRayQueryParameters3D.create(Vector3(1, 0.6, -3), Vector3(1, 0.6, -6))
	return world.get_world_3d().direct_space_state.intersect_ray(ray)
func run() -> void:
	var profile = load("res://art/default_art.tres").duplicate()
	check(profile.start_in_window_presentation, "Default shared art profile starts in window presentation")
	profile.start_in_window_presentation = false
	# Replacement keeps real fallback solar colliders, whose meshes are authored
	# hidden. Returning to EVA must not accidentally reveal those fallback meshes.
	profile.solar_array_scene = replacement_scene()
	var world := World.new()
	world.art = profile
	root.add_child(world)
	await settle()
	var fixture := Node3D.new()
	fixture.visible = false
	fixture.process_mode = Node.PROCESS_MODE_ALWAYS
	world.add_child(fixture)
	var body := StaticBody3D.new()
	body.collision_layer = 4
	body.collision_mask = 16
	body.input_ray_pickable = false
	fixture.add_child(body)
	for disabled in [false, true]:
		var shape := CollisionShape3D.new()
		shape.shape = BoxShape3D.new()
		shape.disabled = disabled
		body.add_child(shape)
	world._register_presentation_node("power_control", fixture)
	await settle()
	var nodes := category_nodes(world, profile.window_hidden_categories)
	var original := record(nodes)
	var hidden_fallback := false
	for node in category_nodes(world, PackedStringArray(["solar_array"])):
		if node is MeshInstance3D and not node.visible: hidden_fallback = true
	check(hidden_fallback, "Fixture exercises intentionally hidden fallback solar meshes")
	check(not kiosk_hit(world).is_empty(), "EVA power kiosk has its authored solid collider")
	world.set_window_presentation(true)
	await settle()
	check(world.is_window_presentation(), "World exposes active window-mode state")
	check(world.sun.directional_shadow_max_distance == 22.0 and world.sun.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS, "Close work redistributes the existing shadow atlas around crew and equipment")
	check(world.get_node("MissionFloor").cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "Co-planar collision floor does not cast acne stripes onto its terrain skin")
	assert_suspended(nodes)
	check(kiosk_hit(world).is_empty(), "Hidden outside kiosk leaves no invisible obstacle")
	check(world.get_node("CompanionAnchor").is_visible_in_tree(), "Stranded astronaut remains visible outside")
	check(world.get_node("InteriorAnchor").is_visible_in_tree(), "Interior presentation stays available")
	check(world.get_node("LandscapeAnchor").is_visible_in_tree(), "Mars terrain stays visible")
	world.set_window_presentation(true)
	await settle()
	world.set_window_presentation(false)
	await settle()
	check(matches_snapshot(original), "Repeated enabled calls then EVA restore exact authored visibility, process and collision state")
	check(world.sun.directional_shadow_max_distance == 100.0 and world.sun.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS, "Returning to EVA restores broad shadow coverage")
	check(not kiosk_hit(world).is_empty(), "EVA restores physical kiosk collision")
	for enabled in [true, false, true, true, false]: world.set_window_presentation(enabled)
	await settle()
	check(matches_snapshot(original), "Rapid same-frame round trips preserve pre-disabled shapes and original masks")
	profile.window_hidden_categories.remove_at(profile.window_hidden_categories.find("solar_array"))
	world.set_window_presentation(true)
	await settle()
	check(world.get_node("SolarArrayAnchor").is_visible_in_tree(), "Live profile flags can retain an exterior category in window mode")
	var solar_collision_restored := true
	for node in category_nodes(world, PackedStringArray(["solar_array"])):
		if node is CollisionObject3D:
			var state: Dictionary = original[node.get_instance_id()]
			if node.collision_layer != state.layer or node.collision_mask != state.mask: solar_collision_restored = false
	check(solar_collision_restored, "Category visibility override also restores its physical layer/mask state")
	check(not world.get_node("RefugeAnchor").is_visible_in_tree(), "Changing one flag leaves other hidden categories suspended")
	world.set_window_presentation(false)
	await settle()
	check(matches_snapshot(original), "Runtime flag variations remain fully reversible")
	world.queue_free()
	await settle()
	var default_world := World.new()
	root.add_child(default_world)
	await settle()
	check(default_world.is_window_presentation(), "Real default world applies initial shared window-mode flag")
	check(not default_world.get_node("HabitatAnchor").is_visible_in_tree(), "Default window hides exterior habitat infrastructure")
	default_world.queue_free()
	await settle()
	quit(1 if failures else 0)
