extends Node3D
## Cosmetic camera-mounted field instrument. Mission interactions stay in player.gd.
## Original parametric geometry; labels name the instrument, not fabricated telemetry.
const Branding = preload("res://scripts/branding.gd")
var _pearl: StandardMaterial3D
var _ruby: StandardMaterial3D
var _joint: StandardMaterial3D
var _glass: StandardMaterial3D

func _ready() -> void:
	_pearl = _material(Color("e4ded9"), 0.30, 0.22)
	_ruby = _material(Color("67293c"), 0.28, 0.48)
	_joint = _material(Color("2b3040"), 0.74, 0.1)
	_glass = _material(Color("39636a"), 0.18, 0.36)
	_glass.emission_enabled = true
	_glass.emission = Color("57949b")
	_glass.emission_energy_multiplier = 0.32
	_build_instrument()
	_build_gloves()

func _material(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	return mat

func _shape(mesh: Mesh, mat: Material, position_local: Vector3, parent: Node3D) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.position = position_local
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node

func _ellipsoid(size: Vector3, position_local: Vector3, mat: Material, parent: Node3D) -> MeshInstance3D:
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 24
	sphere.rings = 12
	var node := _shape(sphere, mat, position_local, parent)
	node.scale = size
	return node

func _rounded_outline(width: float, height: float, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for corner in range(4):
		var center := Vector2(width * 0.5 - radius, height * 0.5 - radius)
		if corner == 1 or corner == 2: center.x *= -1.0
		if corner >= 2: center.y *= -1.0
		for step in range(9):
			var angle := float(corner) * PI * 0.5 + float(step) * PI / 16.0
			points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points

func _shell(width: float, height: float, depth: float, radius: float) -> ArrayMesh:
	var outline := _rounded_outline(width, height, radius)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Four contours create a soft chamfer, not a sharp cuboid body.
	var profiles := [Vector3(0.91, 0.91, -depth * 0.5), Vector3(1, 1, -depth * 0.25), Vector3(1, 1, depth * 0.25), Vector3(0.94, 0.94, depth * 0.5)]
	for band in range(3):
		for i in range(outline.size()):
			var next := (i + 1) % outline.size()
			var a := Vector3(outline[i].x * profiles[band].x, outline[i].y * profiles[band].y, profiles[band].z)
			var b := Vector3(outline[next].x * profiles[band].x, outline[next].y * profiles[band].y, profiles[band].z)
			var c := Vector3(outline[i].x * profiles[band + 1].x, outline[i].y * profiles[band + 1].y, profiles[band + 1].z)
			var d := Vector3(outline[next].x * profiles[band + 1].x, outline[next].y * profiles[band + 1].y, profiles[band + 1].z)
			for vertex in [a, c, b, b, c, d]: st.add_vertex(vertex)
	for i in range(outline.size()):
		var next := (i + 1) % outline.size()
		for vertex in [Vector3(0, 0, depth * 0.5), Vector3(outline[next].x * 0.94, outline[next].y * 0.94, depth * 0.5), Vector3(outline[i].x * 0.94, outline[i].y * 0.94, depth * 0.5)]: st.add_vertex(vertex)
		for vertex in [Vector3(0, 0, -depth * 0.5), Vector3(outline[i].x * 0.91, outline[i].y * 0.91, -depth * 0.5), Vector3(outline[next].x * 0.91, outline[next].y * 0.91, -depth * 0.5)]: st.add_vertex(vertex)
	st.generate_normals()
	return st.commit()

func _label(text: String, pos: Vector3, size: int, scale_pixels: float, color: Color, parent: Node3D) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = pos
	label.font_size = size
	label.pixel_size = scale_pixels
	label.modulate = color
	label.outline_size = 0
	label.no_depth_test = false
	parent.add_child(label)

func _build_instrument() -> void:
	var instrument := Node3D.new()
	instrument.name = "PearlFieldInstrument"
	instrument.position = Vector3(0.34, -0.32, -0.66)
	instrument.rotation = Vector3(-0.20, -0.12, -0.07)
	add_child(instrument)
	_shape(_shell(0.255, 0.315, 0.045, 0.05), _pearl, Vector3.ZERO, instrument)
	_shape(_shell(0.263, 0.267, 0.009, 0.055), _ruby, Vector3(0, 0.005, 0.006), instrument)
	# Rounded dark-cyan optical surface sits within a pearl bezel.
	_shape(_shell(0.226, 0.245, 0.009, 0.043), _joint, Vector3(0, 0.012, 0.025), instrument)
	_shape(_shell(0.212, 0.232, 0.008, 0.038), _glass, Vector3(0, 0.014, 0.030), instrument)
	_label("FIELD SCAN", Vector3(0, 0.073, 0.036), 38, 0.00057, Color("dcf3ed"), instrument)
	_label(Branding.title(), Vector3(0, -0.078, 0.036), 25, 0.00045, Color("b5d8d6"), instrument)
	# Fine etched optical reticle: no invented numerical readings or AI status.
	var etching := _material(Color("8ec5c8"), 0.4, 0.15)
	etching.emission_enabled = true
	etching.emission = Color("75bfc4")
	etching.emission_energy_multiplier = 0.5
	var ring := TorusMesh.new()
	ring.inner_radius = 0.033
	ring.outer_radius = 0.034
	ring.rings = 36
	ring.ring_segments = 6
	var reticle := _shape(ring, etching, Vector3(0, 0.005, 0.037), instrument)
	reticle.rotation.x = PI * 0.5
	for axis in range(2):
		var line := BoxMesh.new()
		line.size = Vector3(0.015 if axis == 0 else 0.001, 0.001 if axis == 0 else 0.015, 0.0008)
		_shape(line, etching, Vector3(0, 0.005, 0.037), instrument)
	var button := CylinderMesh.new()
	button.top_radius = 0.012
	button.bottom_radius = 0.012
	button.height = 0.003
	button.radial_segments = 24
	var tactile := _shape(button, _ruby, Vector3(0, -0.137, 0.023), instrument)
	tactile.rotation.x = PI * 0.5

func _build_gloves() -> void:
	var glove_fabric := _material(Color("e4ded9"), 0.64, 0.035)
	for side in [-1.0, 1.0]:
		var glove := Node3D.new()
		glove.name = "PearlGloveLeft" if side < 0.0 else "PearlGloveRight"
		glove.position = Vector3(0.34 + side * 0.12, -0.438, -0.585)
		glove.rotation = Vector3(-0.34, side * 0.14, side * -0.15)
		add_child(glove)
		_ellipsoid(Vector3(0.103, 0.14, 0.067), Vector3.ZERO, glove_fabric, glove)
		_ellipsoid(Vector3(0.088, 0.105, 0.06), Vector3(0, -0.088, -0.018), glove_fabric, glove)
		# Flexible under-cuff plus thin ruby pressure-seal rings.
		for y in [-0.065, -0.079]:
			var cuff := TorusMesh.new()
			cuff.inner_radius = 0.036
			cuff.outer_radius = 0.043
			cuff.rings = 32
			cuff.ring_segments = 8
			var seal := _shape(cuff, _ruby, Vector3(0, y, -0.007), glove)
			seal.scale.z = 0.73
		# Individual padded finger segments curl around the instrument's lower edge.
		for finger in range(4):
			var x: float = side * (0.024 - finger * 0.017)
			var y := 0.052 + sin(float(finger) / 3.0 * PI) * 0.008
			var pad := _ellipsoid(Vector3(0.019, 0.046, 0.031), Vector3(x, y, -0.014), glove_fabric, glove)
			pad.rotation.x = -0.45
			_ellipsoid(Vector3(0.019, 0.027, 0.025), Vector3(x, y + 0.017, -0.034), glove_fabric, glove)
		var thumb := _ellipsoid(Vector3(0.031, 0.075, 0.038), Vector3(-side * 0.041, 0.023, 0.021), glove_fabric, glove)
		thumb.rotation.z = side * -0.5
