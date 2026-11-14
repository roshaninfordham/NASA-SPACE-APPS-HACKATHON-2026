extends RefCounted
## Authored parametric surface helpers. No global script class or mission logic.

static func material(color: Color, metallic: float = 0.0, roughness: float = 0.45, emission: float = 0.0) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.metallic = metallic
	result.roughness = roughness
	result.cull_mode = BaseMaterial3D.CULL_DISABLED
	if color.a < 1.0:
		result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emission > 0.0:
		result.emission_enabled = true
		result.emission = Color(color.r, color.g, color.b)
		result.emission_energy_multiplier = emission
	return result

static func surface(parent: Node3D, title: String, nu: int, nv: int, sample: Callable, mat: Material, invert: bool = false) -> MeshInstance3D:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for j in range(nv + 1):
		var v := float(j) / nv
		for i in range(nu + 1):
			var u := float(i) / nu
			var p: Vector3 = sample.call(u, v)
			var du: Vector3 = sample.call(minf(u + 0.001, 1.0), v) - sample.call(maxf(u - 0.001, 0.0), v)
			var dv: Vector3 = sample.call(u, minf(v + 0.001, 1.0)) - sample.call(u, maxf(v - 0.001, 0.0))
			var normal := du.cross(dv).normalized()
			if normal.length_squared() < 0.1: normal = Vector3.UP
			if invert: normal = -normal
			vertices.append(p)
			normals.append(normal)
			uvs.append(Vector2(u, v))
	for j in range(nv):
		for i in range(nu):
			var a := j * (nu + 1) + i
			var b := a + 1
			var c := a + nu + 1
			var d := c + 1
			if invert: indices.append_array(PackedInt32Array([a, b, c, b, d, c]))
			else: indices.append_array(PackedInt32Array([a, c, b, b, c, d]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var node := MeshInstance3D.new()
	node.name = title
	node.mesh = mesh
	node.material_override = mat
	parent.add_child(node)
	return node

static func tube(parent: Node3D, title: String, points: PackedVector3Array, radius: float, mat: Material, sides: int = 10) -> MeshInstance3D:
	var count := points.size()
	return surface(parent, title, count - 1, sides, func(u: float, v: float) -> Vector3:
		var along := u * (count - 1)
		var index := mini(int(along), count - 2)
		var blend := along - index
		var tangent_a := (points[mini(index + 1, count - 1)] - points[maxi(index - 1, 0)]).normalized()
		var tangent_b := (points[mini(index + 2, count - 1)] - points[index]).normalized()
		var tangent := tangent_a.lerp(tangent_b, blend).normalized()
		var reference := Vector3.UP if absf(tangent.dot(Vector3.UP)) < 0.92 else Vector3.FORWARD
		var side := tangent.cross(reference).normalized()
		var normal := tangent.cross(side).normalized()
		var angle := TAU * v
		return points[index].lerp(points[index + 1], blend) + radius * (cos(angle) * side + sin(angle) * normal)
	, mat, true)

static func oval_points(center: Vector3, rx: float, ry: float, count: int = 96, slant: float = 0.0) -> PackedVector3Array:
	var points := PackedVector3Array()
	for index in range(count + 1):
		var angle := TAU * index / count
		points.append(center + Vector3(rx * cos(angle), ry * sin(angle) + slant * cos(angle), 0))
	return points

static func bar(parent: Node3D, title: String, start: Vector3, finish: Vector3, radius: float, mat: Material) -> MeshInstance3D:
	var points := PackedVector3Array([start, start.lerp(finish, 0.5), finish])
	return tube(parent, title, points, radius, mat, 10)

static func collision_box(parent: Node3D, title: String, center: Vector3, size: Vector3, yaw: float = 0.0) -> void:
	var body := StaticBody3D.new()
	body.name = title
	body.position = center
	body.rotation.y = yaw
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)

static func label(parent: Node3D, title: String, value: String, position: Vector3, size: int, color: Color) -> Label3D:
	var node := Label3D.new()
	node.name = title
	node.text = value
	node.position = position
	node.font_size = size
	node.pixel_size = 0.003
	node.modulate = color
	node.outline_size = 1
	node.no_depth_test = false
	parent.add_child(node)
	return node

static func batch_static_meshes(parent: Node3D) -> void:
	# All art is static. Merge shared-material surfaces after construction so every
	# engraved line or lantern cage does not require its own renderer submission.
	var groups: Dictionary = {}
	var pending: Array[Node] = [parent]
	while not pending.is_empty():
		var current: Node = pending.pop_back()
		for child in current.get_children(): pending.append(child)
		if not current is MeshInstance3D or current.mesh == null or current.material_override == null: continue
		if current.material_override is BaseMaterial3D and current.material_override.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED: continue
		var key := "%s_%s" % [current.material_override.get_instance_id(), current.cast_shadow]
		if not groups.has(key): groups[key] = {"material": current.material_override, "shadow": current.cast_shadow, "nodes": []}
		groups[key]["nodes"].append(current)
	for key in groups:
		var group: Dictionary = groups[key]
		if group["nodes"].size() < 2: continue
		var vertices := PackedVector3Array()
		var normals := PackedVector3Array()
		var indices := PackedInt32Array()
		for node: MeshInstance3D in group["nodes"]:
			var transform := parent.global_transform.affine_inverse() * node.global_transform
			for surface_index in range(node.mesh.get_surface_count()):
				var data := node.mesh.surface_get_arrays(surface_index)
				var offset := vertices.size()
				for vertex: Vector3 in data[Mesh.ARRAY_VERTEX]: vertices.append(transform * vertex)
				for normal: Vector3 in data[Mesh.ARRAY_NORMAL]: normals.append((transform.basis * normal).normalized())
				if data[Mesh.ARRAY_INDEX] != null and not data[Mesh.ARRAY_INDEX].is_empty():
					for index: int in data[Mesh.ARRAY_INDEX]: indices.append(offset + index)
				else:
					for index in range(data[Mesh.ARRAY_VERTEX].size()): indices.append(offset + index)
			node.queue_free()
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_INDEX] = indices
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var batch := MeshInstance3D.new()
		batch.name = "StaticMaterialBatch_%s" % key
		batch.mesh = mesh
		batch.material_override = group["material"]
		batch.cast_shadow = group["shadow"]
		parent.add_child(batch)
