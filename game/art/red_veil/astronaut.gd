extends Node3D
const VisualStyle = preload("res://scripts/visual_style.gd")
const Branding = preload("res://scripts/branding.gd")
const Ornaments = preload("res://art/red_veil/exterior_ornaments.gd")
## Original stylized Mira sculpture: cosmetic character, not an engineered suit.
## Feet at y=0, height about 1.65 m, facing +Z. Geometry is built once and batched.
@export var suit_color := VisualStyle.color("pearl")
@export var crimson_color := VisualStyle.color("crimson")
@export var gold_color := VisualStyle.color("rose_gold")
@export_range(0.0, 1.0, 0.05) var idle_amount := 0.65
var _elapsed := 0.0
var _upper: Node3D
var _head: Node3D
var _glow: StandardMaterial3D
var _batches: Dictionary = {}
var _sphere: SphereMesh
var _detail: SphereMesh
var _soft: ShaderMaterial
var _shell: StandardMaterial3D
var _red: StandardMaterial3D
var _gold: StandardMaterial3D
var _joint: StandardMaterial3D
# The released idle sculpture keeps its original batches. Articulated geometry
# is allocated only on first use, then reused across work/idle transitions.
var _arm_ranges: Dictionary = {}
var _legacy_arm_meshes: Dictionary = {}
var _working_body_meshes: Dictionary = {}
var _training_rig: Node3D
var _training_shoulder: Node3D
var _training_elbow: Node3D
var _training_tools: Node3D
var _training_wand: MeshInstance3D
var _training_brush: MeshInstance3D
var _training_active := false
var _training_multiplier := 1.0
var _training_reduced_motion := false
var _training_phase := 0.0
const WORK_SHOULDER := Vector3(0.211, 1.155, 0)
const WORK_ELBOW := Vector3(0.286, 0.987, 0.025)
const WORK_WRIST := Vector3(0.164, 0.925, 0.182)

func _ready() -> void:
	set_meta("product_name", Branding.display_name())
	_sphere = SphereMesh.new()
	_sphere.radius = 1.0
	_sphere.height = 2.0
	_sphere.radial_segments = 16
	_sphere.rings = 6
	_detail = SphereMesh.new()
	_detail.radius = 1.0
	_detail.height = 2.0
	_detail.radial_segments = 10
	_detail.rings = 3
	_soft = ShaderMaterial.new()
	_soft.resource_name = "IridescentPearlFabric"
	_soft.shader = preload("res://art/red_veil/suit_fabric.gdshader")
	_soft.set_shader_parameter("pearl", suit_color)
	_shell = _material("PearlArmor", suit_color.lightened(0.045), 0.25, 0.22)
	_red = _material("CrimsonHarness", crimson_color, VisualStyle.number("lacquer_roughness"), 0.23)
	_gold = _material("WarmGold", gold_color, 0.28, 0.63)
	_joint = _material("FlexWeave", Color("453443"), 0.72, 0.0)
	_glow = _material("WarmInstrumentLight", Color("ffdc96"), 0.28, 0.15)
	_glow.emission_enabled = true
	_glow.emission = Color("ffe3ac")
	_glow.emission_energy_multiplier = 0.85
	_upper = Node3D.new()
	_upper.name = "BreathingUpperBody"
	add_child(_upper)
	_build_legs()
	_build_torso()
	_build_craft_details()
	_build_arms()
	_build_head()
	_flush_batches()
	if _training_active: set_training_cleaning(true, _training_multiplier, _training_reduced_motion)

func _material(label: String, color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.resource_name = label
	result.albedo_color = color
	result.roughness = roughness
	result.metallic = metallic
	return result

func _add(mesh: Mesh, mat: Material, transform: Transform3D, parent: Node3D) -> void:
	# Articulated batches retain the exact authored vertices around joint pivots.
	if parent.has_meta("geometry_origin"):
		transform.origin -= Vector3(parent.get_meta("geometry_origin"))
	var groups: Dictionary = _batches.get(parent, {})
	var batch: Dictionary = groups.get(mat, {"vertices": [], "normals": [], "indices": []})
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	var offset: int = batch.vertices.size()
	var normal_basis := transform.basis.inverse().transposed()
	for index in range(vertices.size()):
		batch.vertices.append(transform * vertices[index])
		batch.normals.append((normal_basis * normals[index]).normalized())
	if indices.is_empty():
		for index in range(vertices.size()): batch.indices.append(offset + index)
	else:
		for index in indices: batch.indices.append(offset + index)
	groups[mat] = batch
	_batches[parent] = groups

func _ellipsoid(parent: Node3D, pos: Vector3, size: Vector3, mat: Material, rotation: Vector3 = Vector3.ZERO, detail: bool = false) -> void:
	_add(_detail if detail else _sphere, mat, Transform3D(Basis.from_euler(rotation).scaled(size), pos), parent)

func _ring(parent: Node3D, pos: Vector3, radius: float, tube: float, mat: Material, rotation: Vector3 = Vector3.ZERO, scale_shape: Vector3 = Vector3.ONE) -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - tube
	mesh.outer_radius = radius + tube
	mesh.rings = 24
	mesh.ring_segments = 5
	_add(mesh, mat, Transform3D(Basis.from_euler(rotation).scaled(scale_shape), pos), parent)

func _axis_basis(direction: Vector3) -> Basis:
	var up := direction.normalized()
	var side := up.cross(Vector3.FORWARD)
	if side.length_squared() < 0.001: side = up.cross(Vector3.RIGHT)
	side = side.normalized()
	return Basis(side, up, side.cross(up).normalized())

func _limb(parent: Node3D, from: Vector3, to: Vector3, radius: float, mat: Material) -> void:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = from.distance_to(to) + radius * 2.0
	mesh.radial_segments = 8 if radius < 0.02 else 12
	mesh.rings = 2 if radius < 0.02 else 4
	_add(mesh, mat, Transform3D(_axis_basis(to - from), (from + to) * 0.5), parent)

func _mesh(vertices: PackedVector3Array, normals: PackedVector3Array, indices: PackedInt32Array) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return result

func _loft(profile: Array, segments: int = 28) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for row in range(profile.size()):
		var p: Vector3 = profile[row]
		var previous: Vector3 = profile[maxi(row - 1, 0)]
		var following: Vector3 = profile[mini(row + 1, profile.size() - 1)]
		var dy := maxf(following.x - previous.x, 0.001)
		var dx := (following.y - previous.y) / dy
		var dz := (following.z - previous.z) / dy
		for column in range(segments + 1):
			var angle := TAU * column / segments
			var s := sin(angle)
			var c := cos(angle)
			vertices.append(Vector3(s * p.y, p.x, c * p.z))
			normals.append(Vector3(s / p.y, -(s * s * dx / p.y + c * c * dz / p.z), c / p.z).normalized())
			if row < profile.size() - 1 and column < segments:
				var a := row * (segments + 1) + column
				var b := a + segments + 1
				indices.append_array(PackedInt32Array([a, b, a + 1, a + 1, b, b + 1]))
	return _mesh(vertices, normals, indices)

func _curve(parent: Node3D, points: PackedVector3Array, radius: float, mat: Material, sides: int = 5) -> void:
	if points.size() < 2: return
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for row in range(points.size()):
		var tangent := (points[mini(row + 1, points.size() - 1)] - points[maxi(row - 1, 0)]).normalized()
		var u := tangent.cross(Vector3.FORWARD)
		if u.length_squared() < 0.001: u = tangent.cross(Vector3.UP)
		u = u.normalized()
		var v := tangent.cross(u).normalized()
		for column in range(sides):
			var angle := TAU * column / sides
			var normal := u * cos(angle) + v * sin(angle)
			vertices.append(points[row] + normal * radius)
			normals.append(normal)
			if row < points.size() - 1:
				var a := row * sides + column
				var b := row * sides + (column + 1) % sides
				indices.append_array(PackedInt32Array([a, a + sides, b, b, a + sides, b + sides]))
	_add(_mesh(vertices, normals, indices), mat, Transform3D.IDENTITY, parent)

func _sphere_patch(size: Vector3, rows: int, columns: int, maximum_angle: float, hair: bool = false) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for row in range(rows + 1):
		for column in range(columns + 1):
			var around := TAU * column / columns
			var end := maximum_angle
			if hair: end = lerpf(2.5, 1.2, pow((cos(around) + 1.0) * 0.5, 2.0))
			var down := float(row) / rows * end
			var vertex := Vector3(sin(down) * sin(around) * size.x, cos(down) * size.y, sin(down) * cos(around) * size.z)
			vertices.append(vertex)
			normals.append(Vector3(vertex.x / (size.x * size.x), vertex.y / (size.y * size.y), vertex.z / (size.z * size.z)).normalized())
			if row < rows and column < columns:
				var a := row * (columns + 1) + column
				var b := a + columns + 1
				indices.append_array(PackedInt32Array([a, a + 1, b, a + 1, b + 1, b]))
	return _mesh(vertices, normals, indices)

func _build_legs() -> void:
	for side in [-1.0, 1.0]:
		var x: float = side * 0.112
		_ellipsoid(self, Vector3(x, 0.036, 0.046), Vector3(0.106, 0.036, 0.164), _joint)
		_ellipsoid(self, Vector3(x, 0.105, 0.080), Vector3(0.105, 0.084, 0.145), _shell)
		_ellipsoid(self, Vector3(x, 0.17, -0.008), Vector3(0.085, 0.11, 0.102), _shell)
		_ring(self, Vector3(x, 0.055, 0.043), 0.095, 0.008, _glow, Vector3.ZERO, Vector3(1.0, 1.0, 1.55))
		_ring(self, Vector3(x, 0.24, 0.0), 0.079, 0.012, _red)
		_limb(self, Vector3(x, 0.30, 0.0), Vector3(x * 1.06, 0.43, 0.015), 0.080, _soft)
		_limb(self, Vector3(x * 1.06, 0.54, 0.01), Vector3(x * 0.96, 0.73, 0.0), 0.099, _soft)
		_ellipsoid(self, Vector3(x * 1.06, 0.49, 0.018), Vector3(0.083, 0.064, 0.082), _joint)
		_ellipsoid(self, Vector3(x * 1.06, 0.50, 0.078), Vector3(0.070, 0.066, 0.027), _shell)
		for y in [0.458, 0.480, 0.520]:
			_ring(self, Vector3(x * 1.06, y, 0.013), 0.078, 0.0032, _gold)
		_curve(self, PackedVector3Array([Vector3(x - 0.043, 0.12, 0.205), Vector3(x, 0.14, 0.218), Vector3(x + 0.043, 0.12, 0.205)]), 0.004, _red)
	_ellipsoid(self, Vector3(0, 0.795, -0.005), Vector3(0.18, 0.105, 0.125), _soft)
	_blossom(self, Vector3(-0.115, 0.648, 0.101), 0.026, _gold)

func _build_torso() -> void:
	var profile := [Vector3(0.79, 0.168, 0.126), Vector3(0.85, 0.178, 0.132), Vector3(0.93, 0.15, 0.12), Vector3(1.03, 0.204, 0.143), Vector3(1.14, 0.21, 0.135), Vector3(1.205, 0.171, 0.115), Vector3(1.23, 0.105, 0.091)]
	_add(_loft(profile), _soft, Transform3D.IDENTITY, _upper)
	var obi := [Vector3(0.84, 0.192, 0.145), Vector3(0.875, 0.187, 0.145), Vector3(0.92, 0.171, 0.143), Vector3(0.947, 0.174, 0.143)]
	_add(_loft(obi), _red, Transform3D.IDENTITY, _upper)
	for y in [0.848, 0.938]:
		var trim := PackedVector3Array()
		for i in range(25):
			var angle := TAU * i / 24.0
			trim.append(Vector3(sin(angle) * 0.19, y, cos(angle) * 0.148))
		_curve(_upper, trim, 0.0025, _gold)
	for side in [-1.0, 1.0]:
		_curve(_upper, PackedVector3Array([Vector3(side * 0.15, 1.20, 0.078), Vector3(side * 0.17, 1.15, 0.092), Vector3(side * 0.14, 1.08, 0.116), Vector3(side * 0.11, 0.97, 0.126)]), 0.014, _red, 6)
		_curve(_upper, PackedVector3Array([Vector3(side * 0.152, 1.19, 0.091), Vector3(side * 0.165, 1.14, 0.106), Vector3(side * 0.135, 1.065, 0.132)]), 0.0022, _gold)
	# Compact rounded backpack; a cosmetic device, not a claim about life support.
	_ellipsoid(_upper, Vector3(0, 1.035, -0.177), Vector3(0.166, 0.183, 0.082), _shell)
	_ellipsoid(_upper, Vector3(0, 1.05, -0.253), Vector3(0.038, 0.153, 0.022), _red)
	for side in [-1.0, 1.0]:
		_limb(_upper, Vector3(side * 0.13, 0.94, -0.23), Vector3(side * 0.13, 1.14, -0.23), 0.032, _shell)
		_ring(_upper, Vector3(side * 0.13, 1.08, -0.23), 0.033, 0.004, _red)
	# Segmented collar around a pressure-seal-inspired silhouette.
	_ring(_upper, Vector3(0, 1.215, 0), 0.176, 0.024, _shell)
	for segment in range(12):
		var points := PackedVector3Array()
		for step in range(4):
			var angle := TAU * (segment + 0.11 + 0.78 * step / 3.0) / 12.0
			points.append(Vector3(sin(angle) * 0.177, 1.235, cos(angle) * 0.177))
		_curve(_upper, points, 0.016, _red, 6)
	_ring(_upper, Vector3(0, 1.249, 0), 0.181, 0.003, _gold)
	# Circular chest badge with a crimson surround, raised gold bezel and warm core.
	_ellipsoid(_upper, Vector3(0, 1.08, 0.148), Vector3(0.063, 0.063, 0.024), _red)
	_ring(_upper, Vector3(0, 1.08, 0.173), 0.048, 0.005, _gold, Vector3(PI / 2.0, 0, 0))
	_ellipsoid(_upper, Vector3(0, 1.08, 0.175), Vector3(0.040, 0.040, 0.009), _glow)
	for angle in [0.0, PI / 2.0, PI, PI * 1.5]:
		_ellipsoid(_upper, Vector3(sin(angle) * 0.053, 1.08 + cos(angle) * 0.053, 0.176), Vector3.ONE * 0.003, _shell, Vector3.ZERO, true)
	_wave_motif(_upper, Vector3(0.065, 0.887, 0.148), 0.080)
	_blossom(_upper, Vector3(-0.09, 0.894, 0.138), 0.020, _gold)
	_curve(_upper, PackedVector3Array([Vector3(-0.16, 1.20, 0.078), Vector3(-0.20, 1.19, 0.082), Vector3(-0.25, 1.17, 0.078)]), 0.0022, _gold)
	_blossom(_upper, Vector3(-0.213, 1.191, 0.084), 0.015, _gold)

func _build_arms() -> void:
	for mat in _batches.get(_upper, {}):
		_arm_ranges[mat] = {"start": _batches[_upper][mat].indices.size()}
	for side in [-1.0, 1.0]: _build_arm(side, _upper, _upper)
	for mat in _batches.get(_upper, {}):
		if not _arm_ranges.has(mat): _arm_ranges[mat] = {"start": 0}
		_arm_ranges[mat].end = _batches[_upper][mat].indices.size()
	for mat in _arm_ranges.keys():
		if _arm_ranges[mat].start == _arm_ranges[mat].end: _arm_ranges.erase(mat)

func _build_arm(side: float, upper_parent: Node3D, forearm_parent: Node3D) -> void:
	var shoulder := Vector3(side * 0.211, 1.155, 0)
	var elbow := Vector3(side * 0.286, 0.987, 0.025)
	var wrist := Vector3(-0.259, 0.808, 0.085) if side < 0 else Vector3(0.164, 0.925, 0.182)
	_ellipsoid(upper_parent, shoulder, Vector3(0.084, 0.098, 0.083), _shell)
	_limb(upper_parent, shoulder + Vector3(0, -0.035, 0), elbow + Vector3(0, 0.032, 0), 0.070, _soft)
	_ellipsoid(forearm_parent, elbow, Vector3(0.064, 0.059, 0.064), _joint)
	_limb(forearm_parent, elbow + (wrist - elbow).normalized() * 0.043, wrist, 0.059, _soft)
	var direction := (wrist - elbow).normalized()
	var hand_basis := _axis_basis(-direction)
	var cuff := TorusMesh.new()
	cuff.inner_radius = 0.049
	cuff.outer_radius = 0.062
	cuff.rings = 20
	cuff.ring_segments = 6
	_add(cuff, _red, Transform3D(hand_basis, wrist), forearm_parent)
	var palm := wrist + direction * 0.045
	_add(_sphere, _shell, Transform3D(hand_basis.scaled(Vector3(0.043, 0.051, 0.032)), palm), forearm_parent)
	for finger in range(4):
		var offset := hand_basis.x * ((finger - 1.5) * 0.018)
		var start := palm + direction * 0.031 + offset
		var finish := start + direction * (0.040 if finger == 0 or finger == 3 else 0.052)
		_limb(forearm_parent, start, finish, 0.0085, _shell)
	_limb(forearm_parent, palm + hand_basis.x * 0.038, palm + hand_basis.x * 0.057 + direction * 0.029, 0.011, _shell)
	# Fine original shoulder fan arcs, kept away from the face.
	_wave_motif(upper_parent, shoulder + Vector3(0, 0.024, 0.081), 0.047)


func _blossom(parent: Node3D, center: Vector3, radius: float, mat: Material) -> void:
	for petal in range(5):
		var angle := TAU * petal / 5.0
		var pos := center + Vector3(sin(angle), cos(angle), 0) * radius * 0.50
		_ellipsoid(parent, pos, Vector3(radius * 0.29, radius * 0.52, 0.0018), mat, Vector3(0, 0, -angle), true)
	_ellipsoid(parent, center + Vector3(0, 0, 0.002), Vector3.ONE * 0.003, _red, Vector3.ZERO, true)

func _wave_motif(parent: Node3D, center: Vector3, size: float) -> void:
	var paths: Array = []
	for row in range(3):
		for column in range(2):
			var points := PackedVector3Array()
			var origin := center + Vector3((column - 0.5) * size * 0.43, (row - 1.0) * size * 0.22, 0.001 * row)
			for point in range(9):
				var angle := PI * point / 8.0
				points.append(origin + Vector3(cos(angle), sin(angle), 0) * size * 0.25)
			paths.append(points)
	var engraving := Ornaments.strokes(parent, "FineSuitWaveEngraving", paths, 0.0013, _gold)
	_add(engraving.mesh, _gold, Transform3D.IDENTITY, parent)
	parent.remove_child(engraving)
	engraving.free()

func _build_head() -> void:
	_head = Node3D.new()
	_head.name = "MiraHeadAndHelmet"
	_head.position = Vector3(0, 1.40, 0)
	_upper.add_child(_head)
	var skin := _material("WarmSkin", Color("c88d72"), 0.76, 0.0)
	var hair := _material("BraidedHair", Color("281f2b"), 0.40, 0.08)
	var eyes := _material("EyeIvory", Color("f2e9df"), 0.24, 0.0)
	var iris := _material("ChestnutEyes", Color("53383a"), 0.22, 0.0)
	var pupil := _material("Pupils", Color("171a29"), 0.21, 0.0)
	var lips := _material("SoftLipLine", Color("9f555e"), 0.70, 0.0)
	var sparkle := _material("EyeCatchlight", Color("fff5e4"), 0.25, 0.0)
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 1.0
	head_mesh.height = 2.0
	head_mesh.radial_segments = 28
	head_mesh.rings = 12
	_add(head_mesh, skin, Transform3D(Basis.IDENTITY.scaled(Vector3(0.14, 0.17, 0.133)), Vector3(0, 0, 0.008)), _head)
	_ellipsoid(_head, Vector3(0, -0.15, -0.005), Vector3(0.055, 0.055, 0.052), skin)
	_ellipsoid(_head, Vector3(0, -0.005, 0.140), Vector3(0.019, 0.027, 0.017), skin, Vector3.ZERO, true)
	for side in [-1.0, 1.0]:
		_ellipsoid(_head, Vector3(side * 0.14, -0.01, 0), Vector3(0.019, 0.035, 0.022), skin, Vector3.ZERO, true)
		_ellipsoid(_head, Vector3(side * 0.054, 0.022, 0.131), Vector3(0.027, 0.017, 0.008), eyes, Vector3.ZERO, true)
		_ellipsoid(_head, Vector3(side * 0.053, 0.021, 0.138), Vector3(0.012, 0.013, 0.004), iris, Vector3.ZERO, true)
		_ellipsoid(_head, Vector3(side * 0.053, 0.021, 0.142), Vector3(0.006, 0.009, 0.002), pupil, Vector3.ZERO, true)
		_ellipsoid(_head, Vector3(side * 0.053 - 0.004, 0.026, 0.144), Vector3.ONE * 0.0031, sparkle, Vector3.ZERO, true)
		var brow := PackedVector3Array()
		for point in range(7):
			var t := float(point) / 6.0
			brow.append(Vector3(side * (0.029 + t * 0.053), 0.052 + sin(t * PI) * 0.004, 0.136 - t * 0.006))
		_curve(_head, brow, 0.0025, hair)
		for link in range(6):
			var y := -0.032 - link * 0.020
			var x: float = side * (0.119 - link * 0.003)
			_ellipsoid(_head, Vector3(x + side * (0.004 if link % 2 == 0 else -0.004), y, 0.071), Vector3(0.019, 0.017, 0.018), hair, Vector3(0, 0, side * (0.5 if link % 2 == 0 else -0.5)), true)
		_ring(_head, Vector3(side * 0.102, -0.144, 0.071), 0.014, 0.0024, _gold)
		_ellipsoid(_head, Vector3(side * 0.178, -0.006, -0.012), Vector3(0.018, 0.036, 0.038), _red, Vector3.ZERO, true)
		_ring(_head, Vector3(side * 0.196, -0.006, -0.012), 0.026, 0.0035, _gold, Vector3(0, 0, PI / 2.0))
	_add(_sphere_patch(Vector3(0.147, 0.178, 0.149), 12, 32, 1.2, true), hair, Transform3D(Basis.IDENTITY, Vector3(0, 0.003, 0.008)), _head)
	var mouth := PackedVector3Array()
	for point in range(11):
		var t := float(point) / 10.0
		mouth.append(Vector3(lerpf(-0.026, 0.026, t), -0.058 - sin(t * PI) * 0.006, 0.135 + sin(t * PI) * 0.005))
	_curve(_head, mouth, 0.0021, lips)
	var glass := _material("ClearHelmet", Color(0.82, 0.87, 1.0, 0.10), 0.11, 0.05)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.cull_mode = BaseMaterial3D.CULL_BACK
	_add(_sphere_patch(Vector3(0.245, 0.245, 0.257), 14, 36, 2.28), glass, Transform3D(Basis.IDENTITY, Vector3(0, 0.005, 0)), _head)
	# A continuous thin luminous rim makes the clear dome readable outdoors.
	var rim := _material("VisorRim", Color(0.62, 0.88, 1.0, 0.65), 0.28, 0.0)
	rim.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rim.emission_enabled = true
	rim.emission = Color(0.45, 0.72, 0.90)
	rim.emission_energy_multiplier = 0.35
	var outline := PackedVector3Array()
	for point in range(33):
		var angle := TAU * point / 32.0
		var x := sin(angle) * 0.218
		var y := 0.040 + cos(angle) * 0.188
		var z := sqrt(maxf(1.0 - x * x / 0.060025 - (y - 0.005) * (y - 0.005) / 0.060025, 0.01)) * 0.257
		outline.append(Vector3(x, y, z + 0.002))
	_curve(_head, outline, 0.0018, rim, 3)
	var reflection := _material("VisorReflection", Color(1.0, 0.96, 0.87, 0.19), 0.12, 0.0)
	reflection.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for x in [-0.103, 0.173]:
		var streak := PackedVector3Array()
		for point in range(9):
			var y := 0.055 + point * 0.012
			var z := sqrt(maxf(0.245 * 0.245 - x * x - y * y, 0.001)) * 1.05
			streak.append(Vector3(x, y + 0.005, z + 0.001))
		_curve(_head, streak, 0.0038 if x < 0 else 0.0016, reflection)


	var cyan := _material("VisorData",Color("7be8f2"),0.3,0.0)
	cyan.emission_enabled = true
	cyan.emission = Color("7be8f2")
	cyan.emission_energy_multiplier = 0.4
	for row in range(3):
		_curve(_head,PackedVector3Array([Vector3(0.11,0.015+row*0.018,0.205),Vector3(0.15,0.015+row*0.018,0.19)]),0.0015,cyan,3)
	_ring(_head,Vector3(0.14,0.084,0.192),0.014,0.0014,cyan,Vector3(PI/2.0,0,0))
	# Freckles and pearl studs remain original stylized geometry.
	for side in [-1.0,1.0]:
		_ellipsoid(_head,Vector3(side*0.147,-0.032,0.018),Vector3.ONE*0.004,_shell,Vector3.ZERO,true)
		for spot in range(4):
			_ellipsoid(_head,Vector3(side*(0.025+spot*0.012),-0.014-float(spot%2)*0.009,0.139-float(spot)*0.002),Vector3(0.0018,0.0016,0.001),lips,Vector3.ZERO,true)
	_ellipsoid(_head,Vector3(0,0.11,-0.12),Vector3(0.07,0.065,0.06),hair)

func _flush_batches() -> void:
	var triangles := 0
	var surfaces := 0
	for parent in _batches:
		var groups: Dictionary = _batches[parent]
		for mat in groups:
			var batch: Dictionary = groups[mat]
			var visual := MeshInstance3D.new()
			visual.name = mat.resource_name
			visual.mesh = _mesh(PackedVector3Array(batch.vertices), PackedVector3Array(batch.normals), PackedInt32Array(batch.indices))
			visual.material_override = mat
			if mat.resource_name in ["ClearHelmet", "VisorReflection", "VisorRim"]: visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			parent.add_child(visual)
			if parent == _upper and _arm_ranges.has(mat): _legacy_arm_meshes[visual] = visual.mesh
			triangles += batch.indices.size() / 3
			surfaces += 1
	set_meta("triangle_count", int(get_meta("triangle_count", 0)) + triangles)
	set_meta("material_surfaces", int(get_meta("material_surfaces", 0)) + surfaces)
	_batches.clear()

func _process(delta: float) -> void:
	if not is_finite(delta) or delta < 0.0: return
	_elapsed += minf(delta, 0.1)
	if not is_instance_valid(_upper) or not is_instance_valid(_head): return
	if _training_active:
		if not _training_reduced_motion:
			# A stalled render frame cannot produce an unbounded visual jump.
			_training_phase = fposmod(_training_phase + minf(delta, 0.25) * 2.4 * _training_multiplier, TAU)
		_apply_training_pose()
		return
	_apply_idle_pose()

func _apply_idle_pose() -> void:
	_upper.transform = Transform3D.IDENTITY
	_head.rotation = Vector3.ZERO
	_upper.position.y = sin(_elapsed * 1.25) * 0.0026 * idle_amount
	_upper.rotation.z = sin(_elapsed * 0.55) * 0.003 * idle_amount
	_head.rotation.z = -0.035 + sin(_elapsed * 0.43) * 0.012 * idle_amount
	_head.rotation.y = sin(_elapsed * 0.37) * 0.016 * idle_amount
	_glow.emission_energy_multiplier = 0.78 + sin(_elapsed * 1.25) * 0.07 * idle_amount

## Cosmetic work animation. The caller owns work rate and mission progression.
## Local +X faces the panel; its deck is centered at (1.8,1.08,0), tilt X=-35°.
## The model stays planted at its existing origin; this never moves the actor.
func set_training_cleaning(active: bool, multiplier: float = 1.0, reduced_motion: bool = false) -> void:
	_training_active = active
	_training_multiplier = clampf(multiplier, 0.0, 4.0) if is_finite(multiplier) else 1.0
	_training_reduced_motion = reduced_motion
	if not is_instance_valid(_upper): return
	if active: _ensure_training_rig()
	if is_instance_valid(_training_rig):
		_training_rig.visible = active
		_training_tools.visible = active
		for visual: MeshInstance3D in _legacy_arm_meshes:
			visual.mesh = _working_body_meshes[visual] if active else _legacy_arm_meshes[visual]
	if active: _apply_training_pose()
	else:
		_training_phase = 0.0
		_apply_idle_pose()

func _ensure_training_rig() -> void:
	if is_instance_valid(_training_rig): return
	# Remove only arm index ranges in the working copy. Keep every original mesh
	# resource for an exact rest/exhibit restoration, with no idle draw-call cost.
	for visual: MeshInstance3D in _legacy_arm_meshes:
		var original: Mesh = _legacy_arm_meshes[visual]
		var arrays := original.surface_get_arrays(0)
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var span: Dictionary = _arm_ranges[visual.material_override]
		var kept := indices.slice(0, int(span.start))
		kept.append_array(indices.slice(int(span.end)))
		_working_body_meshes[visual] = _mesh(arrays[Mesh.ARRAY_VERTEX], arrays[Mesh.ARRAY_NORMAL], kept)
	_training_rig = Node3D.new()
	_training_rig.name = "TrainingArticulatedArms"
	_upper.add_child(_training_rig)
	for side in [-1.0, 1.0]:
		var shoulder_point := Vector3(side * 0.211, 1.155, 0)
		var elbow_point := Vector3(side * 0.286, 0.987, 0.025)
		var shoulder := Node3D.new()
		shoulder.name = "RightShoulder" if side > 0 else "LeftShoulder"
		shoulder.position = shoulder_point
		shoulder.set_meta("geometry_origin", shoulder_point)
		_training_rig.add_child(shoulder)
		var elbow := Node3D.new()
		elbow.name = "Elbow"
		elbow.position = elbow_point - shoulder_point
		elbow.set_meta("geometry_origin", elbow_point)
		shoulder.add_child(elbow)
		_build_arm(side, shoulder, elbow)
		if side > 0:
			_training_shoulder = shoulder
			_training_elbow = elbow
	_flush_batches()
	_training_tools = Node3D.new()
	_training_tools.name = "TrainingCleaningTool"
	add_child(_training_tools)
	_training_wand = MeshInstance3D.new()
	_training_wand.name = "LightweightBrushHandle"
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.012
	shaft.bottom_radius = 0.012
	shaft.height = 1.0
	shaft.radial_segments = 8
	_training_wand.mesh = shaft
	_training_wand.material_override = _shell
	_training_tools.add_child(_training_wand)
	_training_brush = MeshInstance3D.new()
	_training_brush.name = "SoftPanelBrush"
	var brush := BoxMesh.new()
	brush.size = Vector3(0.22, 0.035, 0.08)
	_training_brush.mesh = brush
	_training_brush.material_override = _joint
	_training_tools.add_child(_training_brush)

func _apply_training_pose() -> void:
	var sweep := 0.0 if _training_reduced_motion else sin(_training_phase)
	# Rotate around the hips, not the feet, so the waist and boots stay connected.
	var lean := Basis(Vector3.FORWARD, 0.085)
	var hip := Vector3(0, 0.795, -0.005)
	_upper.transform = Transform3D(lean, hip - lean * hip)
	_head.rotation = Vector3(0.12, 0.45, -0.04)
	_glow.emission_energy_multiplier = 0.78
	var wrist_target := _upper.transform.affine_inverse() * Vector3(0.48, 1.055, 0.085 + sweep * 0.035)
	var upper_length := WORK_SHOULDER.distance_to(WORK_ELBOW)
	var fore_length := WORK_ELBOW.distance_to(WORK_WRIST)
	var direction := (wrist_target - WORK_SHOULDER).normalized()
	var distance := clampf(WORK_SHOULDER.distance_to(wrist_target), absf(upper_length - fore_length) + 0.001, upper_length + fore_length - 0.001)
	var along := (upper_length * upper_length - fore_length * fore_length + distance * distance) / (2.0 * distance)
	var bend := (Vector3.DOWN - direction * Vector3.DOWN.dot(direction)).normalized()
	var elbow := WORK_SHOULDER + direction * along + bend * sqrt(maxf(0.0, upper_length * upper_length - along * along))
	var wrist := WORK_SHOULDER + direction * distance
	var upper_basis := Basis(Quaternion((WORK_ELBOW - WORK_SHOULDER).normalized(), (elbow - WORK_SHOULDER).normalized()))
	var fore_basis := Basis(Quaternion((WORK_WRIST - WORK_ELBOW).normalized(), (wrist - elbow).normalized()))
	_training_shoulder.basis = upper_basis
	_training_elbow.basis = upper_basis.inverse() * fore_basis
	var palm := _upper.transform * (wrist + (wrist - elbow).normalized() * 0.045)
	# Match the companion panel's actual top plane, including its 4cm skin.
	var z := sweep * 0.18
	var tilt := deg_to_rad(-35.0)
	var plane_y := 1.08 + 0.04 / cos(tilt) - tan(tilt) * z
	_training_brush.basis = Basis(Vector3.RIGHT, tilt)
	_training_brush.position = Vector3(0.80, plane_y, z) + _training_brush.basis.y * 0.0175
	var tip := _training_brush.position + _training_brush.basis.y * 0.025
	var shaft := tip - palm
	_training_wand.transform = Transform3D(_axis_basis(shaft).scaled_local(Vector3(1, shaft.length(), 1)), (tip + palm) * 0.5)

## Pure presentation presets. They never change mission protection or resources.
func apply_theme(index: int) -> void:
	var accents := [Color("a8102a"), Color("3ce6f0"), Color("472538"), Color("b18b43")]
	var fabrics := [Color("efd9da"), Color("dfebed"), Color("ada3b7"), Color("f2e5cb")]
	var pick := clampi(index, 0, 3)
	_red.albedo_color = accents[pick]
	_soft.set_shader_parameter("pearl", fabrics[pick])
	_shell.albedo_color = fabrics[pick].lightened(0.08)
	set_meta("cosmetic_theme", pick)

func _build_craft_details() -> void:
	# Wrap jacket crossing and woven obi are geometry, so they read in silhouette.
	_curve(_upper, PackedVector3Array([Vector3(-0.13,1.20,0.113),Vector3(-0.04,1.105,0.155),Vector3(0.12,0.95,0.142)]),0.008,_red,5)
	_curve(_upper, PackedVector3Array([Vector3(0.12,1.20,0.113),Vector3(0.04,1.105,0.156),Vector3(-0.11,0.96,0.144)]),0.006,_gold,5)
	var sash_mat := _material("LavenderSash",Color("b28bc9"),0.47,0.12)
	# Sash hangs on the rear, tapering toward the knee; original crane line motif.
	var sash := _loft([Vector3(0.49,0.052,0.010),Vector3(0.57,0.064,0.012),Vector3(0.76,0.073,0.014),Vector3(0.86,0.063,0.012)],16)
	_add(sash,sash_mat,Transform3D(Basis.IDENTITY,Vector3(0.085,0,-0.143)),_upper)
	for y in [0.55,0.60,0.65]:
		for x in [-0.02,0.02]:
			var arc := PackedVector3Array()
			for step in range(9):
				var a := PI*step/8.0
				arc.append(Vector3(0.085+x+cos(a)*0.025,y+sin(a)*0.025,-0.161))
			_curve(_upper,arc,0.0017,_gold,4)
	var crane := [Vector3(0.024,0.76,-0.162),Vector3(0.063,0.726,-0.166),Vector3(0.085,0.719,-0.166),Vector3(0.118,0.74,-0.166),Vector3(0.146,0.79,-0.162)]
	_curve(_upper,PackedVector3Array(crane),0.003,_shell,4)
	_curve(_upper,PackedVector3Array([Vector3(0.085,0.72,-0.168),Vector3(0.079,0.757,-0.168),Vector3(0.095,0.773,-0.168),Vector3(0.109,0.769,-0.168)]),0.0025,_gold,4)
	for side in [-1.0,1.0]:
		for level in range(3):
			var x: float = side*0.112
			var y := 0.10+level*0.045
			_curve(self,PackedVector3Array([Vector3(x-0.07,y,0.14),Vector3(x,y+0.012,0.17),Vector3(x+0.07,y,0.14)]),0.009,_red,5)
			_ellipsoid(self,Vector3(x+0.045,y+0.007,0.16),Vector3(0.012,0.012,0.006),_gold,Vector3.ZERO,true)
		_wave_motif(self,Vector3(side*0.115,0.335,0.079),0.078)
		_curve(_upper,PackedVector3Array([Vector3(side*0.15,0.83,-0.12),Vector3(side*0.20,0.91,-0.13),Vector3(side*0.18,1.03,-0.20)]),0.008,_joint,6)
	# Backpack crescents and name are shared identity, never baked old wordmarks.
	_ring(_upper,Vector3(0.0,1.12,-0.262),0.029,0.004,_glow,Vector3(PI/2.0,0,0))
	var crescent := PackedVector3Array()
	for step in range(17):
		var a := lerpf(-0.7,3.85,step/16.0)
		crescent.append(Vector3(cos(a)*0.023,1.01+sin(a)*0.023,-0.28))
	_curve(_upper,crescent,0.003,_gold,5)
	var label := Label3D.new()
	label.text = Branding.title()
	label.font_size = 30
	label.pixel_size = 0.00065
	label.position = Vector3(0,0.958,-0.275)
	label.rotation.y = PI
	label.modulate = Color("f7e8df")
	label.outline_size = 0
	_upper.add_child(label)
