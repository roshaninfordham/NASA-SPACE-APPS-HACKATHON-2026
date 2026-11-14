extends Node3D
## Cosmetic, deterministic terrain. Mission collision and coordinates stay in world.gd.
## Central y=0 mission surface is clear; terrain relief begins beyond player bounds.
## No external textures: original procedural meshes and mineral shaders.
@export var landscape_seed: int = 2053018
@export_range(0, 2400, 100) var pebble_count: int = 1400
@export_range(0, 400, 20) var boulder_count: int = 200
@export var walkway_width: float = 3.7
@export var coral_color: Color = Color("ff705d")
const REGOLITH = preload("res://art/red_veil/landscape_regolith.gdshader")
const STONE = preload("res://art/red_veil/landscape_rock.gdshader")
const ORNAMENT = preload("res://art/red_veil/exterior_ornaments.gd")
var _rng := RandomNumberGenerator.new()
var _path: PackedVector3Array = PackedVector3Array()

func _ready() -> void:
	_rng.seed = landscape_seed
	_build_ground()
	_build_horizon()
	_build_approach()
	_scatter_stones()

func _material(color: Color, roughness: float = 0.8, metal: float = 0.0, glow: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metal
	if glow > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = glow
	return mat

func _mesh(mesh: Mesh, mat: Material, label: String) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name = label
	visual.mesh = mesh
	visual.material_override = mat
	add_child(visual)
	return visual

func _build_ground() -> void:
	var ground := PlaneMesh.new()
	ground.size = Vector2(600, 600)
	var mat := ShaderMaterial.new()
	mat.shader = REGOLITH
	# Existing flat floor remains the authoritative collider beneath this skin.
	var visual := _mesh(ground, mat, "FineRegolith")
	visual.position.y = 0.006
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _build_horizon() -> void:
	# Three complete ridge belts avoid billboard edges as the player turns.
	# Continuous eroded profiles replace repeated cone silhouettes.
	for layer in range(3):
		var radius := 86.0 + layer * 52.0
		var height := 9.0 + layer * 6.0
		var noise := FastNoiseLite.new()
		noise.seed = landscape_seed + layer * 137
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.frequency = 0.036
		noise.fractal_octaves = 4
		noise.fractal_gain = 0.56
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var segments := 384
		var bands := 18
		var vertices := PackedVector3Array()
		for band in range(bands + 1):
			var t := float(band) / bands
			for i in range(segments + 1):
				var angle := TAU * float(i) / segments
				var radial := Vector2(cos(angle), sin(angle))
				var ridge_noise := noise.get_noise_2d(radial.x * radius, radial.y * radius)
				var jagged := sin(angle * 31.0 + layer) * sin(angle * 19.0 - layer) * 0.12
				var peak := height * (0.67 + ridge_noise * 0.9 + jagged)
				var envelope := pow(maxf(0.0, sin(t * PI)), 1.5)
				var r := radius - 15.0 + t * 43.0 + ridge_noise * 4.0 * envelope
				var y := maxf(0.0, peak * envelope)
				# Small channels break the radial regularity of the slope.
				y += noise.get_noise_2d(radial.x * r * 3.3, radial.y * r * 3.3) * 2.4 * envelope
				vertices.append(Vector3(radial.x * r, y - 0.04, radial.y * r))
		for band in range(bands):
			for i in range(segments):
				var a := band * (segments + 1) + i
				var b := a + 1
				var c := a + segments + 1
				var d := c + 1
				for index in [a, c, b, b, c, d]:
					surface.add_vertex(vertices[index])
		surface.generate_normals()
		var mat := ShaderMaterial.new()
		mat.shader = STONE
		mat.set_shader_parameter("stone_color", Color("49383b").lerp(Color("71636b"), layer / 2.0))
		mat.set_shader_parameter("strata_color", Color("75544e").lerp(Color("88777d"), layer / 2.0))
		var ridge := _mesh(surface.commit(), mat, "ErodedRidge%d" % layer)
		ridge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _approach_point(t: float) -> Vector3:
	# Flush service apron curves toward the left/front habitat airlock.
	var a := Vector3(0, 0.045, 18)
	var b := Vector3(3, 0.045, 7)
	var c := Vector3(-7, 0.045, 1)
	var d := Vector3(-7, 0.045, -9)
	var u := 1.0 - t
	return a * u * u * u + b * 3.0 * u * u * t + c * 3.0 * u * t * t + d * t * t * t

func _ribbon(points: PackedVector3Array, offset: float, width: float, lift: float, mat: Material, label: String) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(points.size() - 1):
		var direction := (points[mini(i + 1, points.size() - 1)] - points[maxi(i - 1, 0)]).normalized()
		var next_direction := (points[mini(i + 2, points.size() - 1)] - points[i]).normalized()
		var side := Vector3(-direction.z, 0, direction.x)
		var next_side := Vector3(-next_direction.z, 0, next_direction.x)
		var a := points[i] + side * (offset - width * 0.5) + Vector3.UP * lift
		var b := points[i] + side * (offset + width * 0.5) + Vector3.UP * lift
		var c := points[i + 1] + next_side * (offset - width * 0.5) + Vector3.UP * lift
		var d := points[i + 1] + next_side * (offset + width * 0.5) + Vector3.UP * lift
		for vertex in [a, c, b, b, c, d]:
			surface.set_normal(Vector3.UP)
			surface.add_vertex(vertex)
	var visual := _mesh(surface.commit(), mat, label)
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _box(size: Vector3, pos: Vector3, mat: Material, label: String) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	var node := _mesh(box, mat, label)
	node.position = pos
	return node

func _build_approach() -> void:
	for i in range(97):
		_path.append(_approach_point(float(i) / 96.0))
	var rim := _material(Color("514149"), 0.34, 0.65)
	var paving := _material(Color("ab9997"), 0.19, 0.68)
	var joint := _material(Color("65545b"), 0.6, 0.4)
	var luminous := _material(coral_color, 0.35, 0.15, 0.75)
	var lantern_frame := _material(Color("4b1b2b"), 0.30, 0.58)
	var lantern_glow := _material(Color("e8a758"), 0.40, 0.05, 0.60)
	_ribbon(_path, 0.0, walkway_width + 0.46, -0.01, rim, "WalkwayInsetRim")
	_ribbon(_path, 0.0, walkway_width, 0.0, paving, "PolishedApproachPanels")
	for side in [-1.0, 1.0]:
		_ribbon(_path, side * (walkway_width * 0.5 + 0.09), 0.055, 0.009, luminous, "CoralEdgeLight")
		_ribbon(_path, side * (walkway_width * 0.5 - 0.13), 0.018, 0.003, joint, "ApproachFineInlay")
	for i in range(4, 96, 7):
		var t := float(i) / 96.0
		var position_on_path := _approach_point(t)
		var tangent := (_approach_point(t + 0.005) - _approach_point(t - 0.005)).normalized()
		var seam := _box(Vector3(walkway_width, 0.003, 0.024), position_on_path + Vector3.UP * 0.002, joint, "PanelExpansionJoint")
		seam.rotation.y = atan2(-tangent.x, -tangent.z)
	# Low, shaded bollards are cosmetic and sit outside the unobstructed lane.
	for i in range(8, 96, 16):
		var t := float(i) / 96.0
		var tangent := (_approach_point(t + 0.005) - _approach_point(t - 0.005)).normalized()
		var sideways := Vector3(-tangent.z, 0, tangent.x)
		for side in [-1.0, 1.0]:
			var base: Vector3 = _approach_point(t) + sideways * side * (walkway_width * 0.5 + 0.62)
			base.y = 0.0
			_box(Vector3(0.18, 0.035, 0.22), base + Vector3.UP * 0.018, lantern_frame, "LanternFoot")
			var post := CylinderMesh.new()
			post.bottom_radius = 0.047
			post.top_radius = 0.034
			post.height = 0.43
			post.radial_segments = 12
			_mesh(post, lantern_frame, "RubyLanternPost").position = base + Vector3.UP * 0.235
			ORNAMENT.lantern(self, "WarmRouteLantern", base + Vector3.UP * 0.66, 0.42, lantern_glow, lantern_frame)
			# Three small actual lights give the polished alloy a physical highlight.
			# No painted reflection or extra shadow maps; all remaining lamps are emissive.
			if i % 32 == 8 and side > 0.0:
				var light := OmniLight3D.new()
				light.name = "LanternApronLight"
				light.position = base + Vector3.UP * 0.65
				light.light_color = Color("ffc98b")
				light.light_energy = 0.4
				light.omni_range = 3.1
				light.omni_attenuation = 1.5
				light.shadow_enabled = false
				add_child(light)

func _rock_mesh(variant: int) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var noise := FastNoiseLite.new()
	noise.seed = landscape_seed + variant * 43
	noise.frequency = 2.3
	var rings := 7
	var segments := 11
	var vertices := PackedVector3Array()
	for ring in range(rings + 1):
		var latitude := PI * float(ring) / rings
		for i in range(segments + 1):
			var angle := TAU * float(i) / segments
			var p := Vector3(sin(latitude) * cos(angle), cos(latitude), sin(latitude) * sin(angle))
			var displacement := 1.0 + noise.get_noise_3dv(p * 2.0) * 0.38
			p *= displacement
			p.y *= 0.68
			vertices.append(p)
	for ring in range(rings):
		for i in range(segments):
			var a := ring * (segments + 1) + i
			var b := a + 1
			var c := a + segments + 1
			var d := c + 1
			for index in [a, c, b, b, c, d]:
				surface.add_vertex(vertices[index])
	surface.generate_normals()
	return surface.commit()

func _clear_for_rock(p: Vector3, radius: float) -> bool:
	# Keep mission objects and direct travel corridors clear, plus the full apron.
	if absf(p.x) < 12.5 and p.z < -6.0 and p.z > -25.0: return false
	for landmark in [Vector3(16, 0, -8), Vector3(-14, 0, -7), Vector3(1, 0, -5), Vector3(-4, 0, 7)]:
		if p.distance_to(landmark) < 5.0 + radius: return false
	for point in _path:
		if p.distance_to(point) < walkway_width * 0.5 + 1.2 + radius: return false
	if radius > 0.2 and absf(p.x) < 24.0 and p.z > -19.0 and p.z < 25.0: return false
	return true

func _scatter_stones() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = STONE
	mat.set_shader_parameter("stone_color", Color("62443f"))
	mat.set_shader_parameter("strata_color", Color("aa7865"))
	for variant in range(4):
		var transforms: Array[Transform3D] = []
		var count := (pebble_count + boulder_count) / 4
		for i in range(count):
			var large := i < boulder_count / 4
			var radius := _rng.randf_range(0.4, 2.3) if large else _rng.randf_range(0.035, 0.17)
			var pos := Vector3(_rng.randf_range(-66, 66), 0, _rng.randf_range(-66, 66))
			if not _clear_for_rock(pos, radius): continue
			pos.y = radius * 0.10
			var scale_vector := Vector3(radius * _rng.randf_range(0.8, 1.6), radius, radius * _rng.randf_range(0.8, 1.4))
			var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(scale_vector)
			transforms.append(Transform3D(basis, pos))
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = _rock_mesh(variant)
		multi.instance_count = transforms.size()
		for i in range(transforms.size()): multi.set_instance_transform(i, transforms[i])
		var stones := MultiMeshInstance3D.new()
		stones.name = "ScatteredStoneBatch%d" % variant
		stones.multimesh = multi
		stones.material_override = mat
		add_child(stones)
