extends RefCounted
## Reusable authored ornament geometry: curved seigaiha engraving, blossom filigree,
## and warm shielded lanterns. Decorative only; never changes simulation or collision.
const G = preload("res://art/red_veil/exterior_geometry.gd")

static func strokes(parent: Node3D, title: String, paths: Array, radius: float, mat: Material, casts_shadow: bool = false) -> MeshInstance3D:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	const SIDES := 4
	for points: PackedVector3Array in paths:
		var base := vertices.size()
		for index in range(points.size()):
			var tangent := (points[mini(index + 1, points.size() - 1)] - points[maxi(index - 1, 0)]).normalized()
			var reference := Vector3.UP if absf(tangent.y) < 0.92 else Vector3.FORWARD
			var side := tangent.cross(reference).normalized()
			var up := tangent.cross(side).normalized()
			for spoke in range(SIDES):
				var angle := TAU * spoke / SIDES
				var normal := side * cos(angle) + up * sin(angle)
				vertices.append(points[index] + normal * radius)
				normals.append(normal)
			if index > 0:
				for spoke in range(SIDES):
					var a := base + (index - 1) * SIDES + spoke
					var b := base + (index - 1) * SIDES + (spoke + 1) % SIDES
					indices.append_array(PackedInt32Array([a, a + SIDES, b, b, a + SIDES, b + SIDES]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var node := MeshInstance3D.new()
	node.name = title
	node.mesh = mesh
	node.material_override = mat
	# These millimetre-scale decorative strokes do not need repeated shadow
	# map submissions. Callers can explicitly opt in for a structural stroke.
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if casts_shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node

static func wave_patch(parent: Node3D, title: String, sample_uv: Callable, rows: int, columns: int, mat: Material) -> Node3D:
	var paths: Array = []
	for row in range(rows):
		for column in range(columns + 1):
			var cx := (column + (0.5 if row % 2 == 0 else 0.0)) / columns
			var cy := float(row) / rows
			for ring in range(3):
				var points := PackedVector3Array()
				var radius := 0.48 - ring * 0.13
				for step in range(13):
					var angle := PI * step / 12
					var u := cx + radius * cos(angle) / columns
					var v := cy + radius * 1.65 * sin(angle) / rows
					if u >= 0.0 and u <= 1.0 and v <= 1.0:
						points.append(sample_uv.call(u, v))
				if points.size() > 1: paths.append(points)
	return strokes(parent, title, paths, 0.008, mat)

static func blossom_branch(parent: Node3D, title: String, origin: Vector3, scale: float, branch_mat: Material, petal_mat: Material) -> Node3D:
	var node := Node3D.new()
	node.name = title
	node.position = origin
	parent.add_child(node)
	var paths: Array = []
	var flowers: Array = []
	var trunk := PackedVector3Array()
	for index in range(17):
		var u := index / 16.0
		trunk.append(Vector3(lerpf(-1.3, 1.25, u), 0.24 * sin(u * PI) + 0.42 * u - 0.2, 0) * scale)
	paths.append(trunk)
	for index in range(6):
		var u := 0.16 + index * 0.14
		var base := Vector3(lerpf(-1.3, 1.25, u), 0.24 * sin(u * PI) + 0.42 * u - 0.2, 0) * scale
		var tip := base + Vector3(0.22, 0.34 if index % 2 == 0 else -0.30, 0) * scale
		paths.append(PackedVector3Array([base, base.lerp(tip, 0.5) + Vector3(0.04, 0, 0) * scale, tip]))
		for petal in range(5):
			var petal_path := PackedVector3Array()
			var center_angle := TAU * petal / 5
			for step in range(13):
				var angle := TAU * step / 12
				var direction := Vector3(cos(center_angle), sin(center_angle), 0)
				var across := Vector3(-sin(center_angle), cos(center_angle), 0)
				petal_path.append(tip + scale * (direction * (0.06 + 0.055 * cos(angle)) + across * 0.035 * sin(angle)))
			flowers.append(petal_path)
	strokes(node, "GoldBranches", paths, 0.012 * scale, branch_mat)
	strokes(node, "FivePetalBlossoms", flowers, 0.009 * scale, petal_mat)
	return node

static func lantern(parent: Node3D, title: String, center: Vector3, height: float, glow_mat: Material, frame_mat: Material) -> Node3D:
	var node := Node3D.new()
	node.name = title
	node.position = center
	parent.add_child(node)
	var radius := height * 0.17
	G.surface(node, "WarmDiffuser", 32, 12, func(u: float, v: float) -> Vector3:
		var r := radius * (0.78 + 0.22 * sin(PI * v))
		return Vector3(r * cos(TAU * u), (v - 0.5) * height, r * sin(TAU * u))
	, glow_mat)
	var paths: Array = []
	for spoke in range(8):
		var points := PackedVector3Array()
		var angle := TAU * spoke / 8
		for step in range(13):
			var v := step / 12.0
			var r := radius * (0.79 + 0.22 * sin(PI * v))
			points.append(Vector3(r * cos(angle), (v - 0.5) * height, r * sin(angle)))
		paths.append(points)
	for y in [-height * 0.5, height * 0.5]:
		var points := PackedVector3Array()
		for step in range(33):
			var angle := TAU * step / 32
			points.append(Vector3(radius * 0.8 * cos(angle), y, radius * 0.8 * sin(angle)))
		paths.append(points)
	strokes(node, "AmberLanternCage", paths, height * 0.018, frame_mat)
	return node

## Square kumiko lamp: four independently legible lattice faces and a pearl diffuser.
## Same signature as lantern(), so art variants can be swapped without caller changes.
static func square_lantern(parent: Node3D, title: String, center: Vector3, height: float, glow_mat: Material, frame_mat: Material) -> Node3D:
	var node := Node3D.new()
	node.name = title
	node.position = center
	parent.add_child(node)
	var half_width := height * 0.31
	var diffuser := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(half_width * 1.84, height * 0.88, half_width * 1.84)
	diffuser.mesh = box
	diffuser.material_override = glow_mat
	node.add_child(diffuser)
	var paths: Array = []
	for side in range(4):
		var angle := side * PI * 0.5
		var outward := Vector3(sin(angle), 0, cos(angle))
		var across := Vector3(cos(angle), 0, -sin(angle))
		for x in [-1.0, -0.33, 0.33, 1.0]:
			paths.append(PackedVector3Array([outward * half_width + across * x * half_width + Vector3.DOWN * height * 0.5, outward * half_width + across * x * half_width + Vector3.UP * height * 0.5]))
		for y in [-0.5, -0.26, 0.0, 0.26, 0.5]:
			paths.append(PackedVector3Array([outward * half_width + across * half_width + Vector3.UP * y * height, outward * half_width - across * half_width + Vector3.UP * y * height]))
		# Offset rectangular keys make the grid read as joinery rather than bars.
		for sign_value in [-1.0, 1.0]:
			var key := PackedVector3Array()
			for p in [Vector2(-0.16, -0.10), Vector2(0.16, -0.10), Vector2(0.16, 0.10), Vector2(0, 0.10)]:
				key.append(outward * (half_width + 0.002) + across * p.x * height + Vector3.UP * (p.y + sign_value * 0.22) * height)
			paths.append(key)
	strokes(node, "SquareKumikoJoinery", paths, height * 0.018, frame_mat)
	return node
