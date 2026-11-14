extends RefCounted
const VisualStyle = preload("res://scripts/visual_style.gd")
## Reference-led exterior details, separate from the shell's navigable aperture contract.
const G = preload("res://art/red_veil/exterior_geometry.gd")
const O = preload("res://art/red_veil/exterior_ornaments.gd")
const FINISH = preload("res://art/red_veil/exterior_shell.gdshader")
const REGOLITH = preload("res://art/red_veil/landscape_regolith.gdshader")

static func shell_material(color: Color, lacquer: bool) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = FINISH
	material.set_shader_parameter("shell_color", color)
	material.set_shader_parameter("lacquer", lacquer)
	material.set_shader_parameter("surface_roughness", VisualStyle.number("lacquer_roughness" if lacquer else "pearl_roughness"))
	return material

static func ellipsoid(parent: Node3D, name: String, center: Vector3, scale: Vector3, material: Material) -> MeshInstance3D:
	var shape := SphereMesh.new()
	shape.radius = 1.0
	shape.height = 2.0
	shape.radial_segments = 20
	shape.rings = 12
	var node := MeshInstance3D.new()
	node.name = name
	node.mesh = shape
	node.material_override = material
	node.position = center
	node.scale = scale
	parent.add_child(node)
	return node

static func build(parent: Node3D, pearl: Material, ruby: Material, metal: Material, coral: Material, collisions_enabled: bool) -> void:
	var rose_gold := G.material(VisualStyle.color("rose_gold"), VisualStyle.number("gold_metallic"), VisualStyle.number("gold_roughness"), 0.18)
	var amber := G.material(VisualStyle.color("amber"), 0.08, 0.48, 0.7)
	_build_airlock_joinery(parent, rose_gold, metal)
	_build_lounge(parent, pearl, ruby, coral, amber, collisions_enabled)
	_build_berm(parent, collisions_enabled)
	# Slim structural seams are curved to the shell; no oversized spherical grid.
	var seams: Array = []
	for segment in range(12):
		var path := PackedVector3Array()
		for step in range(22):
			var theta := lerpf(-2.9, 2.9, segment / 11.0)
			var phi := lerpf(0.91, 1.39, step / 21.0)
			path.append(parent.shell(theta + 0.025 * sin(phi * 3.0), phi, 0.018))
		seams.append(path)
	O.strokes(parent, "PearlPanelExpansionSeams", seams, 0.007, metal)

static func _build_airlock_joinery(parent: Node3D, gold: Material, metal: Material) -> void:
	var center := Vector3(-7.15, 1.95, 5.95)
	var ring_paths: Array = []
	for z in [-0.98, -0.38, 0.25]:
		ring_paths.append(G.oval_points(center + Vector3(0, 0, z), 1.68, 1.95, 64))
	O.strokes(parent, "AirlockThreeSegmentSeams", ring_paths, 0.018, metal)
	# Small fastening heads placed on the trim, not across the traversable opening.
	var fasteners := MultiMesh.new()
	fasteners.transform_format = MultiMesh.TRANSFORM_3D
	var head := SphereMesh.new()
	head.radius = 0.023
	head.height = 0.046
	head.radial_segments = 8
	head.rings = 4
	fasteners.mesh = head
	fasteners.instance_count = 72
	for index in range(72):
		var angle := TAU * (index % 24) / 24
		var z := -0.98 + (index / 24) * 0.62
		fasteners.set_instance_transform(index, Transform3D(Basis.IDENTITY, center + Vector3(1.69 * cos(angle), 1.96 * sin(angle), z)))
	var rivets := MultiMeshInstance3D.new()
	rivets.name = "AirlockFastenerInstances"
	rivets.multimesh = fasteners
	rivets.material_override = gold
	parent.add_child(rivets)
	# Continuous over-under geometric knot on the lintel: original line geometry.
	var paths: Array = []
	var knot := PackedVector3Array()
	for step in range(161):
		var t := TAU * step / 160
		knot.append(Vector3(-7.15 + 0.34 * sin(2.0 * t), 3.88 + 0.22 * sin(3.0 * t), 6.86 + 0.035 * cos(5.0 * t)))
	paths.append(knot)
	O.strokes(parent, "InterwovenAirlockKnot", paths, 0.018, gold)
	G.label(parent, "AirlockOperationLabel", "AIRLOCK", Vector3(-7.15, 3.29, 6.82), 46, Color("fff0df"))
	# Guard rails stop short of the main front route and never cross the path.
	for side in [-1.0, 1.0]:
		var x: float = -7.15 + side * 2.10
		for z in [7.0, 8.2]:
			G.bar(parent, "EntryRailUpright", Vector3(x, 0.05, z), Vector3(x, 0.95, z), 0.026, metal)
		G.bar(parent, "EntrySafetyRail", Vector3(x, 0.95, 7.0), Vector3(x, 0.95, 8.2), 0.03, metal)

static func _build_lounge(parent: Node3D, pearl: Material, ruby: Material, coral: Material, amber: Material, collisions_enabled: bool) -> void:
	# Real low-cost geometry behind the starboard almond opening, not a painted image.
	var lounge := Node3D.new()
	lounge.name = "ObservationLounge"
	lounge.position = Vector3(8.0, 0.0, -1.0)
	lounge.rotation.y = PI * 0.5
	parent.add_child(lounge)
	var cushion := G.material(Color("d9bcb4"), 0.08, 0.60)
	ellipsoid(lounge, "PearlLoungePlinth", Vector3(0, 0.24, 0), Vector3(1.62, 0.20, 0.65), pearl)
	ellipsoid(lounge, "CurvedSofaBack", Vector3(0, 0.78, -0.36), Vector3(1.53, 0.58, 0.21), cushion)
	for seat in [-1.0, 0.0, 1.0]:
		ellipsoid(lounge, "SoftSeat", Vector3(seat * 0.92, 0.51, 0.04), Vector3(0.47, 0.20, 0.49), cushion)
	for sign_value in [-1.0, 1.0]:
		ellipsoid(lounge, "SofaArm", Vector3(sign_value * 1.48, 0.63, 0), Vector3(0.17, 0.32, 0.58), pearl)
	# A globe pendant and stylized flowering bonsai read clearly from the exterior.
	G.bar(lounge, "PendantStem", Vector3(-1.15, 2.6, -0.4), Vector3(-1.15, 3.7, -0.4), 0.012, ruby)
	ellipsoid(lounge, "WarmPendantGlobe", Vector3(-1.15, 2.47, -0.4), Vector3.ONE * 0.20, amber)
	ellipsoid(lounge, "BlossomCeramicVase", Vector3(1.67, 0.34, -0.45), Vector3(0.30, 0.34, 0.30), pearl)
	var wood := G.material(Color("653737"), 0.04, 0.77)
	var bark_paths: Array = []
	var blossom_transforms: Array[Transform3D] = []
	for branch in range(7):
		var start := Vector3(1.67, 0.50, -0.45)
		var angle := branch * 2.399
		var tip := Vector3(1.67 + cos(angle) * 0.62, 1.78 + 0.16 * sin(branch * 1.7), -0.45 + sin(angle) * 0.49)
		bark_paths.append(PackedVector3Array([start, start.lerp(tip, 0.5) + Vector3(0.08, 0.13, 0), tip]))
		for blossom in range(7):
			var cluster := tip + Vector3(sin(blossom * 2.4) * 0.17, cos(blossom * 1.8) * 0.13, sin(blossom * 1.2) * 0.15)
			for petal in range(5):
				var a := TAU * petal / 5
				var transform := Transform3D(Basis(Vector3.FORWARD, a).scaled(Vector3(0.045, 0.025, 0.025)), cluster + Vector3(cos(a), sin(a), 0) * 0.04)
				blossom_transforms.append(transform)
	O.strokes(lounge, "FloweringTreeBranches", bark_paths, 0.026, wood)
	var petal_mesh := SphereMesh.new()
	petal_mesh.radius = 1.0
	petal_mesh.height = 2.0
	petal_mesh.radial_segments = 6
	petal_mesh.rings = 4
	var blooms := MultiMesh.new()
	blooms.transform_format = MultiMesh.TRANSFORM_3D
	blooms.mesh = petal_mesh
	blooms.instance_count = blossom_transforms.size()
	for i in range(blossom_transforms.size()): blooms.set_instance_transform(i, blossom_transforms[i])
	var flowers := MultiMeshInstance3D.new()
	flowers.name = "InstancedFivePetalBlossoms"
	flowers.multimesh = blooms
	flowers.material_override = coral
	lounge.add_child(flowers)
	if collisions_enabled: G.collision_box(lounge, "LoungeSeatingCollider", Vector3(0, 0.6, 0), Vector3(3.1, 1.2, 1.05))

static func _build_berm(parent: Node3D, collisions_enabled: bool) -> void:
	var material := ShaderMaterial.new()
	material.shader = REGOLITH
	# A smooth rear/right bank: its toe stays outside the façade/airlock approach.
	var berm := G.surface(parent, "PartialRegolithBerm", 96, 16, func(u: float, v: float) -> Vector3:
		var theta := lerpf(1.05, 4.25, u)
		var edge_fade := pow(maxf(0.0, sin(PI * u)), 0.32)
		var ridge := pow(maxf(0.0, sin(PI * v)), 1.15)
		var rough := sin(theta * 23.0 + v * 14.0) * 0.045 + sin(theta * 51.0 - v * 12.0) * 0.025
		var height := maxf(0.0, 2.20 * ridge * edge_fade + rough * ridge)
		return Vector3((10.5 + 5.2 * v) * sin(theta), 0.02 + height, (7.1 + 4.0 * v) * cos(theta))
	, material, true)
	if collisions_enabled:
		var body := StaticBody3D.new()
		body.name = "RegolithSlopeCollider"
		var shape := CollisionShape3D.new()
		shape.shape = berm.mesh.create_trimesh_shape()
		body.add_child(shape)
		parent.add_child(body)
