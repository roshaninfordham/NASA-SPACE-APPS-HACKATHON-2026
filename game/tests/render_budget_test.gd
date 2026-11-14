extends SceneTree
## Regression: material batching must retain intentional shadow participation.
const Geometry = preload("res://art/red_veil/exterior_geometry.gd")
const Interior = preload("res://art/red_veil/interior.gd")
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	if value: print("PASS: ", message)
	else:
		push_error(message)
		failures += 1
func _fixture() -> Node3D:
	var parent := Node3D.new()
	root.add_child(parent)
	var material := StandardMaterial3D.new()
	for mode in range(4):
		for index in range(2):
			var mesh := MeshInstance3D.new()
			mesh.mesh = BoxMesh.new()
			mesh.material_override = material
			mesh.cast_shadow = mode
			mesh.position = Vector3(index * 3, mode * 3, 0)
			parent.add_child(mesh)
	return parent
func _check_batch(parent: Node3D, label: String) -> void:
	var modes: Dictionary = {}
	var triangles := 0
	for child in parent.get_children():
		if not child is MeshInstance3D: continue
		modes[child.cast_shadow] = modes.get(child.cast_shadow, 0) + 1
		for surface in range(child.mesh.get_surface_count()):
			var arrays: Array = child.mesh.surface_get_arrays(surface)
			var count: int = arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX] != null and not arrays[Mesh.ARRAY_INDEX].is_empty() else arrays[Mesh.ARRAY_VERTEX].size()
			triangles += count / 3
	check(modes.size() == 4 and modes.values().all(func(count): return count == 1), label + " preserves all four shadow modes while merging shared-material geometry")
	check(triangles == 96, label + " retains all input box faces")
	parent.queue_free()
func run() -> void:
	var exterior := _fixture()
	Geometry.batch_static_meshes(exterior)
	await process_frame
	_check_batch(exterior, "Exterior batching")
	var interior := _fixture()
	# Attach the real batching implementation after fixture entry so room _ready
	# does not generate unrelated artwork. Its mesh helper needs no room state.
	interior.set_script(Interior)
	interior._batch_static_meshes()
	await process_frame
	_check_batch(interior, "Interior batching")
	var landscape = load("res://art/red_veil/landscape.gd").new()
	root.add_child(landscape)
	await process_frame
	var pebbles := 0
	var boulders := 0
	for child in landscape.get_children():
		if not child is MultiMeshInstance3D: continue
		if child.name.begins_with("ScatteredPebbleBatch"):
			pebbles += child.multimesh.instance_count
			check(child.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "Tiny pebbles do not enter shadow passes")
		elif child.name.begins_with("ScatteredBoulderBatch"):
			boulders += child.multimesh.instance_count
			check(child.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON, "Large boulders retain shadows")
	check(pebbles > 0 and boulders > 0, "Landscape retains both instanced pebble and boulder populations")
	landscape.queue_free()
	await process_frame
	quit(1 if failures else 0)
