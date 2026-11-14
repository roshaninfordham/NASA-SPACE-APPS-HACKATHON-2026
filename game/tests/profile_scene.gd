extends SceneTree
## Reproducible geometry inventory; headless counts are not a frame-rate benchmark.
var _output := "/tmp/komaku-scene-profile.json"
func _initialize() -> void: call_deferred("run")
func _triangles(mesh: Mesh) -> int:
	var total := 0
	for surface in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(surface)
		var count: int = arrays[Mesh.ARRAY_VERTEX].size()
		if arrays[Mesh.ARRAY_INDEX] != null and not arrays[Mesh.ARRAY_INDEX].is_empty(): count = arrays[Mesh.ARRAY_INDEX].size()
		var primitive: int = mesh.surface_get_primitive_type(surface) if mesh is ArrayMesh else Mesh.PRIMITIVE_TRIANGLES
		match primitive:
			Mesh.PRIMITIVE_TRIANGLES: total += count / 3
			Mesh.PRIMITIVE_TRIANGLE_STRIP: total += maxi(0, count - 2)
	return total
func _bytes(mesh: Mesh) -> int:
	var total := 0
	for surface in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(surface)
		for index in range(arrays.size()):
			var data: Variant = arrays[index]
			if data == null: continue
			match typeof(data):
				TYPE_PACKED_VECTOR3_ARRAY: total += data.size() * 12
				TYPE_PACKED_VECTOR2_ARRAY: total += data.size() * 8
				TYPE_PACKED_COLOR_ARRAY: total += data.size() * 16
				TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_FLOAT32_ARRAY: total += data.size() * 4
				TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_INT64_ARRAY: total += data.size() * 8
				TYPE_PACKED_BYTE_ARRAY: total += data.size()
	return total
func _frustum_candidate(node: GeometryInstance3D, camera: Camera3D) -> bool:
	var local := node.get_aabb()
	var corners: Array[Vector3] = []
	for index in range(8): corners.append(node.global_transform * local.get_endpoint(index))
	for plane in camera.get_frustum():
		var outside := true
		for point in corners:
			if plane.distance_to(point) <= 0.0:
				outside = false
				break
		if outside: return false
	return true
func run() -> void:
	var args := OS.get_cmdline_user_args()
	for index in range(args.size() - 1):
		if args[index] == "--output": _output = args[index + 1]
	root.size = Vector2i(1280, 720)
	var start := Time.get_ticks_msec()
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	for index in range(8): await process_frame
	var construction_ms := Time.get_ticks_msec() - start
	var nodes: Array[Node] = [game]
	var rows: Array = []
	var unique_meshes: Dictionary = {}
	var unique_materials: Dictionary = {}
	while not nodes.is_empty():
		var node: Node = nodes.pop_back()
		for child in node.get_children(): nodes.append(child)
		var mesh: Mesh
		var instances := 1
		if node is MeshInstance3D: mesh = node.mesh
		elif node is MultiMeshInstance3D and node.multimesh:
			mesh = node.multimesh.mesh
			instances = node.multimesh.instance_count if node.multimesh.visible_instance_count < 0 else node.multimesh.visible_instance_count
		else: continue
		if mesh == null: continue
		var bytes := _bytes(mesh)
		unique_meshes[mesh.get_instance_id()] = bytes
		for surface in range(mesh.get_surface_count()):
			var material: Material = node.material_override
			if material == null: material = mesh.surface_get_material(surface)
			if material != null: unique_materials[material.get_instance_id()] = material.get_class()
		rows.append({"path": str(game.get_path_to(node)), "mesh_triangles": _triangles(mesh), "instances": instances, "triangles": _triangles(mesh) * instances, "surfaces": mesh.get_surface_count(), "visible": node.is_visible_in_tree(), "shadow_caster": node.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "mesh_array_bytes": bytes, "node": node})
	var camera := Camera3D.new()
	game.add_child(camera)
	var views := [
		{"name": "title", "position": Vector3(-6, 3.4, 10), "target": Vector3(0, 3, -16), "fov": 45.0},
		{"name": "interior", "position": Vector3(0, 2.2, -8.2), "target": Vector3(0, 3.1, -16), "fov": 77.0},
		{"name": "player_start", "position": Vector3(0, 1.78, 14), "target": Vector3(0, 1.78, 0), "fov": 78.0}
	]
	var totals := {"unique_mesh_array_bytes": 0, "scene_triangles": 0, "visible_triangles": 0, "shadow_casting_triangles": 0, "mesh_instances": rows.size(), "unique_meshes": unique_meshes.size(), "unique_materials": unique_materials.size(), "views": []}
	for bytes in unique_meshes.values(): totals.unique_mesh_array_bytes += bytes
	for row in rows:
		totals.scene_triangles += row.triangles
		if row.visible:
			totals.visible_triangles += row.triangles
			if row.shadow_caster: totals.shadow_casting_triangles += row.triangles
	for view in views:
		camera.position = view.position
		camera.look_at(view.target)
		camera.fov = view.fov
		camera.make_current()
		camera.force_update_transform()
		for index in range(4): await process_frame
		var tri := 0
		var surfaces := 0
		for row in rows:
			if row.visible and _frustum_candidate(row.node, camera):
				tri += row.triangles
				surfaces += row.surfaces
		var result := {"name": view.name, "frustum_candidate_triangles": tri, "frustum_candidate_surfaces": surfaces}
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			result["rendered_primitives"] = Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
			result["rendered_draw_calls"] = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		totals.views.append(result)
	rows.sort_custom(func(a, b): return a.triangles > b.triangles)
	for row in rows: row.erase("node")
	var report := {"engine": Engine.get_version_info().string, "renderer": DisplayServer.get_name(), "construction_ms_diagnostic_only": construction_ms, "scope": "All retained mesh geometry including MultiMesh multiplicity. Frustum candidates use conservative AABB/plane rejection, not occlusion, shadow-pass or GPU LOD accounting. Array bytes estimate uncompressed CPU mesh channels, not full resident process/GPU memory. Software-cloud timing is not a target-device benchmark.", "totals": totals, "meshes": rows}
	var file := FileAccess.open(_output, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ") + "\n")
	file.close()
	print(JSON.stringify(totals))
	print("PROFILE_JSON ", _output)
	quit()
