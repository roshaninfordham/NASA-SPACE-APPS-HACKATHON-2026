extends SceneTree
## Integration checks for movable inspection metadata and the walkable regolith slope.
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	if value: print("PASS: ", message)
	else:
		push_error(message)
		failures += 1
func run() -> void:
	var exterior = load("res://art/red_veil/exterior.tscn").instantiate()
	root.add_child(exterior)
	await process_frame
	await physics_frame
	var anchors: Array = exterior.get_inspection_points()
	var ids: Array[String] = []
	for entry in anchors:
		ids.append(entry.id)
		check(entry.position.is_finite() and not entry.text.is_empty(), "Inspection anchor has finite position and learning explanation: " + entry.id)
	check(ids.size() == 4 and ids.has("habitat_dome") and ids.has("observation_windows") and ids.has("regolith_shielding") and ids.has("airlock"), "All four habitat learning surfaces are discoverable")
	exterior.position = Vector3(2, 0, -16)
	exterior.rotation.y = 0.24
	var moved: Array = exterior.get_inspection_points()
	for i in range(anchors.size()):
		check(moved[i].position.is_equal_approx(exterior.to_global(anchors[i].position)), "Inspection anchor follows habitat transform: " + ids[i])
	await physics_frame
	await physics_frame
	await process_frame
	await physics_frame
	var theta := 2.65
	var local_sample := Vector3(13.1 * sin(theta), 0, 9.1 * cos(theta))
	var global_sample: Vector3 = exterior.to_global(local_sample)
	var ray := PhysicsRayQueryParameters3D.create(global_sample + Vector3.UP * 6, global_sample - Vector3.UP)
	var hit: Dictionary = exterior.get_world_3d().direct_space_state.intersect_ray(ray)
	check(not hit.is_empty() and hit.collider.name == "RegolithSlopeCollider" and hit.position.y > 1.8 and hit.position.y < 2.4, "Regolith artwork has a matching physical slope near its 2.2 m crest")
	var glass_count := 0
	for child in exterior.get_children():
		if child.name.begins_with("RecessedRubyGlazing"): glass_count += 1
	check(glass_count >= 3, "Transparent observation glazing survives opaque geometry batching")
	exterior.queue_free()
	await process_frame
	quit(1 if failures else 0)
