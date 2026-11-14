extends SceneTree
## Regression: material batching must retain intentional shadow participation.
const Geometry = preload("res://art/red_veil/exterior_geometry.gd")
const Interior = preload("res://art/red_veil/interior.gd")
# Capture the exact CPU transforms passed to GPU instancing. The headless dummy
# renderer returns identity for MultiMesh transform readback, so do not use it.
class InspectedLandscape:
	extends "res://art/red_veil/landscape.gd"
	var authored_stone_transforms: Array[Transform3D] = []
	func _build_stone_batch(variant: int, small: bool, transforms: Array[Transform3D], mat: Material) -> void:
		authored_stone_transforms.append_array(transforms)
		super._build_stone_batch(variant, small, transforms, mat)
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	if value: print("PASS: ", message)
	else:
		push_error(message)
		failures += 1
func _triangles(mesh: Mesh) -> int:
	var total := 0
	for surface in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(surface)
		var count: int = arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX] != null and not arrays[Mesh.ARRAY_INDEX].is_empty() else arrays[Mesh.ARRAY_VERTEX].size()
		total += count / 3
	return total
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
		triangles += _triangles(child.mesh)
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
	var landscape := InspectedLandscape.new()
	root.add_child(landscape)
	await process_frame
	var pebbles := 0
	var boulders := 0
	var stone_triangles := 0
	var dune_triangles := 0
	var dune_count := 0
	for child in landscape.get_children():
		if child is MeshInstance3D and child.name.begins_with("QuietDuneBelt"):
			dune_count += 1
			dune_triangles += _triangles(child.mesh)
			var arrays: Array = child.mesh.surface_get_arrays(0)
			check(arrays[Mesh.ARRAY_INDEX] != null and not arrays[Mesh.ARRAY_INDEX].is_empty(), "Dune belt shares vertices through an index buffer")
			var clear_core := true
			for vertex: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
				if Vector2(vertex.x, vertex.z).length() < 70.0: clear_core = false
			check(clear_core, "Dune geometry stays outside the flat mission-route core")
			check(child.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "Distant dunes do not add shadow passes")
		if not child is MultiMeshInstance3D: continue
		if child.name.begins_with("Scattered"):
			stone_triangles += _triangles(child.multimesh.mesh) * child.multimesh.instance_count
		if child.name.begins_with("ScatteredPebbleBatch"):
			pebbles += child.multimesh.instance_count
		elif child.name.begins_with("ScatteredBoulderBatch"):
			boulders += child.multimesh.instance_count
			check(child.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON, "Sparse distant boulders retain shadows")
	var clear_window := true
	for transform: Transform3D in landscape.authored_stone_transforms:
		var point := transform.origin
		if Vector2(point.x, point.z).length() < 48.0 or (absf(point.x) < 22.0 and point.z > -28.0): clear_window = false
	check(landscape.authored_stone_transforms.size() == boulders and clear_window, "CPU-authored distant stones leave the core and forward window corridor clear")
	check(pebbles == 0 and boulders > 0 and boulders <= 12, "Calm default landscape removes the pebble field and retains sparse distant rocks")
	check(stone_triangles <= 2000, "Sparse stone geometry stays below 2,000 triangles")
	check(dune_count == 3 and dune_triangles <= 12000, "Three broad dune belts stay below 12,000 triangles")
	landscape.queue_free()
	await process_frame
	quit(1 if failures else 0)
