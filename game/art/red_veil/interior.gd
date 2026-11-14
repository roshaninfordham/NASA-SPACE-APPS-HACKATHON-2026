extends Node3D
## Presentation-only Mars laboratory. Geometry is local to the habitat ground origin.
const VisualStyle = preload("res://scripts/visual_style.gd")
const Branding = preload("res://scripts/branding.gd")
const Hologram = preload("res://art/red_veil/interior_hologram.gd")
const Ornaments = preload("res://art/red_veil/exterior_ornaments.gd")
@export_range(0, 2) var ornament_detail: int = 1
@export var batch_static_geometry: bool = true
var CORAL: Color = VisualStyle.color("coral")
var CYAN: Color = VisualStyle.color("cyan")
var IVORY: Color = VisualStyle.color("pearl")
var GRAPHITE: Color = VisualStyle.color("wine")
var _materials: Dictionary = {}
var _power_label: Label3D
var _dust_label: Label3D
var _crew_label: Label3D
var _forecast_label: Label3D
var _tablet_labels: Array[Label3D] = []
var _elapsed := 0.0
var _mars: MeshInstance3D
var _orbit: Node3D
var _hologram_material: ShaderMaterial

func _ready() -> void:
	_materials.ivory = _material(IVORY, 0.3, 0.22)
	_materials.pearl = _material(VisualStyle.color("pearl_pink"), VisualStyle.number("floor_roughness"), 0.25)
	_materials.ruby = _material(VisualStyle.color("crimson"), VisualStyle.number("lacquer_roughness"), 0.35)
	_materials.dark = _material(GRAPHITE, 0.5, 0.25)
	_materials.chrome = _material(Color("93b9c3"), 0.22, 0.78)
	_materials.coral = _material(CORAL, 0.3, 0.1, 0.8)
	_materials.cyan = _material(CYAN, 0.3, 0.1, 0.7)
	_materials.soft_coral = _material(Color("ee7b96"), 0.35, 0.0, 0.35)
	_materials.cloth = _material(Color("f2e9e1"), 0.82, 0.0)
	_materials.leaf = _material(Color("2d6855"), 0.57, 0.0)
	_materials.leaf.cull_mode = BaseMaterial3D.CULL_DISABLED
	_materials.leaf_light = _material(Color("75b99a"), 0.52, 0.0)
	_materials.gold = _material(VisualStyle.color("rose_gold"), VisualStyle.number("gold_roughness"), VisualStyle.number("gold_metallic"), 0.18)
	_materials.amber = _material(VisualStyle.color("amber"), 0.6, 0.0, 0.55)
	_materials.bark = _material(Color("513d3a"), 0.8, 0.0)
	_materials.glass = _glass(Color(0.035, 0.16, 0.20, 0.88), 0.15)
	_materials.holo_line = _material(Color("ffd6dc"), 0.4, 0.0, 1.2)
	_materials.holo_line.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_materials.beam = _glass(Color(1.0, 0.19, 0.42, 0.045), 0.8)
	_build_floor()
	_build_projection()
	_build_canopy()
	_build_consoles()
	_build_chair(Vector3(-4.0, 0.05, 5.1), -0.05)
	_build_chair(Vector3(4.25, 0.05, 5.1), 0.12)
	_build_planter(Vector3(-7.5, 0.05, -3.9), 0.15)
	_build_planter(Vector3(7.4, 0.05, -4.5), 1.1)
	_build_planter(Vector3(8.25, 0.05, 1.65), 2.0)
	_build_side_details()
	if ornament_detail > 0: _build_ornaments()
	if batch_static_geometry: _batch_static_meshes()
	apply_mission_visuals({})

func _material(color: Color, roughness: float, metal: float, glow: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metal
	if glow > 0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = glow
	return material

func _glass(color: Color, glow: float) -> StandardMaterial3D:
	var material := _material(color, 0.17, 0.12, glow)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = false
	material.render_priority = 1
	return material

func _mesh(mesh: Mesh, material: Material, position: Vector3, parent: Node3D = self) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position
	parent.add_child(instance)
	return instance

func _cylinder(position: Vector3, bottom: float, top: float, height: float, material: Material, parent: Node3D = self) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = bottom
	mesh.top_radius = top
	mesh.height = height
	mesh.radial_segments = 40
	return _mesh(mesh, material, position, parent)

func _ellipsoid(position: Vector3, scale_value: Vector3, material: Material, parent: Node3D = self) -> MeshInstance3D:
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 20
	sphere.rings = 12
	var node := _mesh(sphere, material, position, parent)
	node.scale = scale_value
	return node

func _ring(position: Vector3, radius: float, thickness: float, material: Material, parent: Node3D = self) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - thickness
	mesh.outer_radius = radius + thickness
	mesh.rings = 64 if radius > 2.0 else 40
	mesh.ring_segments = 6
	var node := _mesh(mesh, material, position, parent)
	if material in [_materials.coral, _materials.cyan, _materials.soft_coral]: node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node

func _arc(radius: float, y: float, start: float, finish: float, count: int = 48) -> PackedVector3Array:
	var points := PackedVector3Array()
	for index in range(count + 1):
		var angle := lerpf(start, finish, float(index) / count)
		points.append(Vector3(sin(angle) * radius, y, cos(angle) * radius))
	return points

func _tube(points: PackedVector3Array, radius: float, material: Material, parent: Node3D = self, sides: int = 6) -> MeshInstance3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array = []
	var normals: Array = []
	for index in range(points.size()):
		var tangent := (points[mini(index + 1, points.size() - 1)] - points[maxi(index - 1, 0)]).normalized()
		var axis := Vector3.UP if absf(tangent.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
		var right := tangent.cross(axis).normalized()
		var up := right.cross(tangent).normalized()
		var ring := PackedVector3Array()
		var normal_ring := PackedVector3Array()
		for side in range(sides):
			var angle := TAU * side / sides
			var normal := right * cos(angle) + up * sin(angle)
			ring.append(points[index] + normal * radius)
			normal_ring.append(normal)
		rings.append(ring)
		normals.append(normal_ring)
	for index in range(points.size() - 1):
		for side in range(sides):
			var next := (side + 1) % sides
			for coordinate in [Vector2i(index, side), Vector2i(index + 1, side), Vector2i(index, next), Vector2i(index, next), Vector2i(index + 1, side), Vector2i(index + 1, next)]:
				surface.set_normal(normals[coordinate.x][coordinate.y])
				surface.add_vertex(rings[coordinate.x][coordinate.y])
	var node := _mesh(surface.commit(), material, Vector3.ZERO, parent)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node

func _quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for vertex in [a, b, c, a, c, d]: surface.add_vertex(vertex)

func _annular_segment(inner: float, outer: float, bottom: float, top: float, start: float, finish: float, material: Material, parent: Node3D = self) -> MeshInstance3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(48):
		var a := lerpf(start, finish, float(index) / 48.0)
		var b := lerpf(start, finish, float(index + 1) / 48.0)
		var ia := Vector3(sin(a) * inner, top, cos(a) * inner)
		var ib := Vector3(sin(b) * inner, top, cos(b) * inner)
		var oa := Vector3(sin(a) * outer, top, cos(a) * outer)
		var ob := Vector3(sin(b) * outer, top, cos(b) * outer)
		_quad(surface, ia, ib, ob, oa)
		_quad(surface, Vector3(ia.x, bottom, ia.z), Vector3(oa.x, bottom, oa.z), Vector3(ob.x, bottom, ob.z), Vector3(ib.x, bottom, ib.z))
		_quad(surface, oa, ob, Vector3(ob.x, bottom, ob.z), Vector3(oa.x, bottom, oa.z))
		_quad(surface, ib, ia, Vector3(ia.x, bottom, ia.z), Vector3(ib.x, bottom, ib.z))
	surface.generate_normals()
	return _mesh(surface.commit(), material, Vector3.ZERO, parent)

func _label(value: String, position: Vector3, size: int, pixel_size: float, color: Color, parent: Node3D = self) -> Label3D:
	var label := Label3D.new()
	label.text = value
	label.position = position
	label.font_size = size
	label.pixel_size = pixel_size
	label.modulate = color
	label.outline_size = 4
	label.outline_modulate = Color(0.04, 0.06, 0.10, 0.85)
	label.shaded = false
	label.no_depth_test = false
	label.render_priority = 3
	parent.add_child(label)
	return label

func _solid_cylinder(position: Vector3, radius: float, height: float, parent: Node3D = self) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = radius
	cylinder.height = height
	shape.shape = cylinder
	body.position = position
	body.add_child(shape)
	parent.add_child(body)

func _build_floor() -> void:
	var floor := _cylinder(Vector3(0, 0.015, 0), 9.6, 9.6, 0.07, _materials.pearl)
	floor.scale.z = 0.75
	var border := _ring(Vector3(0, 0.065, 0), 9.35, 0.11, _materials.ivory)
	border.scale.z = 0.75
	var perimeter := _ring(Vector3(0, 0.075, 0), 9.12, 0.023, _materials.coral)
	perimeter.scale.z = 0.75
	for radius in [2.25, 3.75, 6.15]:
		_ring(Vector3(0, 0.068, 0), radius, 0.028, _materials.ruby)
		_ring(Vector3(0, 0.079, 0), radius + 0.07, 0.012, _materials.soft_coral)
	for index in range(16):
		var a := TAU * index / 16.0
		_tube(_arc(3.88, 0.085, a, a + 0.045, 3), 0.018, _materials.cyan)
	for side: float in [-1.0, 1.0]:
		var route := PackedVector3Array([Vector3(side * 6.0, 0.09, 5.5), Vector3(side * 6.9, 0.09, 3.8), Vector3(side * 7.2, 0.09, 1.5), Vector3(side * 6.9, 0.09, -1.3)])
		_tube(route, 0.025, _materials.coral)

func _build_projection() -> void:
	_cylinder(Vector3(0, 0.19, 0), 1.42, 1.34, 0.28, _materials.ruby)
	_cylinder(Vector3(0, 0.40, 0), 1.30, 1.13, 0.26, _materials.ivory)
	_cylinder(Vector3(0, 0.59, 0), 1.12, 1.25, 0.14, _materials.chrome)
	_cylinder(Vector3(0, 0.69, 0), 1.24, 1.24, 0.055, _materials.dark)
	for radius in [0.65, 1.0, 1.23]: _ring(Vector3(0, 0.73, 0), radius, 0.022, _materials.coral)
	_solid_cylinder(Vector3(0, 0.36, 0), 1.34, 0.66)
	var column_material := ShaderMaterial.new()
	column_material.shader = load("res://art/red_veil/interior_column.gdshader")
	var beam := _cylinder(Vector3(0, 3.12, 0), 1.64, 1.64, 4.74, column_material)
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for index in range(12):
		var a := TAU * index / 12.0
		var p := Vector3(sin(a) * 1.66, 0.78, cos(a) * 1.66)
		_tube(PackedVector3Array([p, p + Vector3(0, 0.28, 0)]), 0.012, _materials.soft_coral)
		_tube(PackedVector3Array([p + Vector3(0, 4.0, 0), p + Vector3(0, 4.63, 0)]), 0.012, _materials.soft_coral)
	_ring(Vector3(0, 1.0, 0), 1.65, 0.012, _materials.soft_coral)
	_ring(Vector3(0, 4.78, 0), 1.65, 0.018, _materials.coral)
	_hologram_material = ShaderMaterial.new()
	_hologram_material.shader = load("res://art/red_veil/interior_mars.gdshader")
	var globe := SphereMesh.new()
	globe.radius = 1.38
	globe.height = 2.76
	globe.radial_segments = 96
	globe.rings = 48
	_mars = _mesh(globe, _hologram_material, Vector3(0, 3.05, 0))
	_mars.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_orbit = Node3D.new()
	_orbit.position = Vector3(0, 3.05, 0)
	add_child(_orbit)
	Hologram.build_network(_mars, 1.405, _materials.holo_line, 2 if ornament_detail > 0 else 1)
	var orbit := _ring(Vector3.ZERO, 1.93, 0.018, _materials.cyan, _orbit)
	orbit.rotation = Vector3(0.25, 0, -0.24)
	var satellite := _ellipsoid(Vector3(1.83, 0.45, 0.18), Vector3.ONE * 0.065, _materials.cyan, _orbit)
	satellite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_label("MARS  /  TRAINING MODEL", Vector3(0, 0.51, 1.22), 30, 0.004, Color("e8faff"))
	var light := OmniLight3D.new()
	light.position = Vector3(0, 2.2, 0)
	light.light_color = Color("ff789d")
	light.light_energy = 1.7
	light.omni_range = 5.5
	light.shadow_enabled = false
	add_child(light)

func _build_canopy() -> void:
	_ring(Vector3(0, 5.68, 0), 1.69, 0.10, _materials.ruby)
	_ring(Vector3(0, 5.78, 0), 1.87, 0.095, _materials.ivory)
	_annular_segment(1.8, 3.35, 6.08, 6.32, 0, TAU, _materials.ivory)
	_ring(Vector3(0, 6.06, 0), 3.25, 0.075, _materials.ruby)
	_ring(Vector3(0, 6.025, 0), 3.10, 0.025, _materials.coral)
	_ring(Vector3(0, 6.34, 0), 3.30, 0.055, _materials.chrome)
	# Nested ceremonial ceiling rings follow the room's existing low outer shell.
	for layer in range(3):
		var radius := 4.1 + layer * 1.1
		var level := 5.90 - layer * 0.40
		_annular_segment(radius - 0.31, radius + 0.31, level, level + 0.12, 0, TAU, _materials.ruby)
		_ring(Vector3(0, level - 0.02, 0), radius - 0.26, 0.025, _materials.holo_line)
		_ring(Vector3(0, level - 0.02, 0), radius + 0.26, 0.025, _materials.soft_coral)
		if ornament_detail > 0 and layer == 1:
			for index in range(8):
				var angle := TAU * index / 8.0
				var sprig := Ornaments.blossom_branch(self, "CeilingSakuraInlay", Vector3(sin(angle) * radius, level - 0.035, cos(angle) * radius), 0.60, _materials.gold, _materials.holo_line)
				sprig.rotation = Vector3(PI / 2, angle, 0)
	_ring(Vector3(0, 6.01, 0), 2.03, 0.035, _materials.cyan)
	for index in range(16):
		var a := TAU * index / 16.0
		_tube(_arc(2.61, 6.03, a + 0.06, a + 0.22, 6), 0.028, _materials.soft_coral)
	for angle in [PI * 0.25, PI * 0.75, PI * 1.25, PI * 1.75]:
		var points := PackedVector3Array()
		for index in range(16):
			var t := float(index) / 15.0
			var radius := lerpf(3.25, 8.2, t)
			points.append(Vector3(sin(angle) * radius, 6.25 - 3.0 * t * t, cos(angle) * radius * 0.75))
		_tube(points, 0.11, _materials.ivory)
	_annular_segment(2.58, 2.64, 5.32, 6.04, -1.45, 1.45, _materials.ruby)
	_label(Branding.title(), Vector3(0, 5.78, 2.70), 96, 0.005, IVORY)
	_label(Branding.subtitle().to_upper(), Vector3(0, 5.39, 2.72), 28, 0.0038, CORAL)

func _build_consoles() -> void:
	for limits in [[-1.25, -0.29], [0.29, 1.25]]:
		var start: float = limits[0]
		var finish: float = limits[1]
		_annular_segment(4.22, 5.05, 0.90, 1.10, start, finish, _materials.ivory)
		_tube(_arc(5.02, 1.02, start, finish), 0.055, _materials.ruby)
		_tube(_arc(5.06, 1.08, start, finish), 0.018, _materials.coral)
		_tube(_arc(4.28, 1.13, start, finish), 0.028, _materials.chrome)
		var body := StaticBody3D.new()
		add_child(body)
		for index in range(7):
			var angle := lerpf(start, finish, (index + 0.5) / 7.0)
			var collision := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size = Vector3(0.72, 1.05, 0.82)
			collision.shape = shape
			collision.position = Vector3(sin(angle) * 4.64, 0.56, cos(angle) * 4.64)
			collision.rotation.y = angle
			body.add_child(collision)
		for t in [0.12, 0.55, 0.9]:
			var angle := lerpf(start, finish, t)
			var points := PackedVector3Array()
			for index in range(10):
				var k := float(index) / 9.0
				var radius := 4.55 + 0.23 * sin(k * PI)
				points.append(Vector3(sin(angle) * radius, 0.10 + k * 0.83, cos(angle) * radius))
			_tube(points, 0.085, _materials.ivory)
			_cylinder(Vector3(sin(angle) * 4.55, 0.09, cos(angle) * 4.55), 0.30, 0.30, 0.08, _materials.ruby)
	# Four readable hero displays; no decorative percentage is mistaken for telemetry.
	_dust_label = _build_display(Vector3(-5.55, 2.35, 2.35), 0.40, 2.55, "MISSION CONTROL", "", "surface")
	_power_label = _build_display(Vector3(-2.95, 2.32, 3.25), 0.12, 2.38, "ENVIRONMENT CONTROL", "", "energy")
	_forecast_label = _build_display(Vector3(2.95, 2.32, 3.25), -0.12, 2.38, "RADIATION FORECAST", "", "forecast")
	_crew_label = _build_display(Vector3(5.55, 2.35, 2.35), -0.40, 2.55, "LIFE SUPPORT", "", "crew")
	for index in range(9):
		var angle := lerpf(-1.16, -0.34, index / 3.0) if index < 4 else lerpf(0.34, 1.16, (index - 4) / 4.0)
		_build_tablet(Vector3(sin(angle) * 4.55, 1.28, cos(angle) * 4.55), angle, index)

func _build_display(position: Vector3, yaw: float, width: float, title: String, initial: String, graphic: String) -> Label3D:
	var panel := Node3D.new()
	panel.name = "HeroPanel_" + graphic
	panel.position = position
	panel.rotation.y = yaw
	add_child(panel)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top := PackedVector3Array()
	var bottom := PackedVector3Array()
	for index in range(33):
		var x := lerpf(-width / 2.0, width / 2.0, index / 32.0)
		var z := x * x * 0.035
		top.append(Vector3(x, 0.82, z))
		bottom.append(Vector3(x, -0.82, z))
	for index in range(32): _quad(surface, bottom[index], bottom[index + 1], top[index + 1], top[index])
	surface.generate_normals()
	var glass := _mesh(surface.commit(), _materials.glass, Vector3.ZERO, panel)
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for path in [top, bottom, PackedVector3Array([top[0], bottom[0]]), PackedVector3Array([top[-1], bottom[-1]])]:
		_tube(path, 0.018, _materials.holo_line, panel)
	_label(title, Vector3(0, 0.64, 0.12), 30, 0.0035, CYAN, panel)
	var telemetry := _label(initial, Vector3(0, 0.16, 0.15), 28, 0.0034, Color("e4ffff"), panel)
	_label("LIVE TRAINING MODEL", Vector3(0, -0.70, 0.15), 20, 0.0027, CYAN, panel)
	if graphic == "surface":
		for row in range(5):
			var trace := PackedVector3Array()
			for index in range(25):
				var x := lerpf(-width * 0.42, width * 0.42, index / 24.0)
				var peak := exp(-pow((index - 16.0) / 5.0, 2.0)) * 0.23
				trace.append(Vector3(x, -0.56 + row * 0.035 + peak + sin(index * 0.8 + row * 0.6) * 0.025, 0.14))
			_tube(trace, 0.005, _materials.cyan, panel, 4)
	elif graphic == "energy":
		for index in range(7):
			var height := 0.10 + 0.18 * sin((index + 1) * PI / 8.0)
			_tube(PackedVector3Array([Vector3(-0.8 + index * 0.25, -0.54, 0.14), Vector3(-0.8 + index * 0.25, -0.54 + height, 0.14)]), 0.035, _materials.cyan, panel, 4)
		_label("SCHEMATIC / POWER BUDGET", Vector3(0, -0.17, 0.15), 18, 0.0027, CYAN, panel)
	elif graphic == "forecast":
		# Diagram of the existing mission's event window, explicitly a scenario.
		_tube(PackedVector3Array([Vector3(-0.95, -0.54, 0.14), Vector3(-0.34, -0.54, 0.14), Vector3(-0.32, -0.25, 0.14), Vector3(0.19, -0.25, 0.14), Vector3(0.21, -0.54, 0.14), Vector3(0.95, -0.54, 0.14)]), 0.013, _materials.coral, panel)
		_label("SCENARIO EVENT: HOURS 4–7", Vector3(0, -0.15, 0.15), 18, 0.0027, CYAN, panel)
	else:
		var head := _ring(Vector3(0.82, -0.23, 0.14), 0.07, 0.009, _materials.cyan, panel)
		head.rotation.x = PI / 2
		for path in [PackedVector3Array([Vector3(0.82, -0.30, 0.14), Vector3(0.82, -0.47, 0.14)]), PackedVector3Array([Vector3(0.64, -0.46, 0.14), Vector3(0.73, -0.32, 0.14), Vector3(0.91, -0.32, 0.14), Vector3(1.0, -0.46, 0.14)]), PackedVector3Array([Vector3(0.73, -0.62, 0.14), Vector3(0.82, -0.47, 0.14), Vector3(0.91, -0.62, 0.14)])]:
			_tube(path, 0.012, _materials.cyan, panel)
		_label("O₂ / H₂O: NOT SIMULATED", Vector3(-0.23, -0.40, 0.15), 18, 0.0027, CYAN, panel)
	return telemetry

func _build_tablet(position: Vector3, yaw: float, index: int) -> void:
	var tablet := Node3D.new()
	tablet.name = "ConsoleTablet_%02d" % index
	tablet.position = position
	tablet.rotation = Vector3(-1.10, yaw, 0)
	add_child(tablet)
	var screen := PlaneMesh.new()
	screen.orientation = PlaneMesh.FACE_Z
	screen.size = Vector2(0.78, 0.46)
	_mesh(screen, _materials.glass, Vector3.ZERO, tablet)
	_tube(PackedVector3Array([Vector3(-0.4, -0.24, 0.01), Vector3(0.4, -0.24, 0.01), Vector3(0.4, 0.24, 0.01), Vector3(-0.4, 0.24, 0.01), Vector3(-0.4, -0.24, 0.01)]), 0.011, _materials.holo_line, tablet)
	var titles := ["SOLAR", "HABITAT", "SUIT", "DOSE", "DUST", "REFUGE", "EVENT", "TIME", "POWER MODE"]
	_label(titles[index], Vector3(0, 0.14, 0.025), 24, 0.0025, CYAN, tablet)
	_tablet_labels.append(_label("--", Vector3(0, -0.02, 0.025), 26, 0.0027, IVORY, tablet))
	_tube(PackedVector3Array([Vector3(-0.30, -0.15, 0.025), Vector3(-0.12, -0.15, 0.025), Vector3(-0.08, -0.10, 0.025), Vector3(-0.02, -0.18, 0.025), Vector3(0.04, -0.13, 0.025), Vector3(0.3, -0.13, 0.025)]), 0.004, _materials.cyan, tablet, 4)

func _build_chair(position: Vector3, yaw: float) -> void:
	var chair := Node3D.new()
	chair.position = position
	chair.rotation.y = yaw
	add_child(chair)
	_cylinder(Vector3(0, 0.08, 0), 0.43, 0.38, 0.12, _materials.chrome, chair)
	_ring(Vector3(0, 0.13, 0), 0.37, 0.018, _materials.coral, chair)
	_tube(PackedVector3Array([Vector3(0, 0.12, 0), Vector3(0, 0.34, 0.04), Vector3(0, 0.57, 0.12)]), 0.09, _materials.ruby, chair)
	_ellipsoid(Vector3(0, 0.62, 0.03), Vector3(0.57, 0.15, 0.57), _materials.ivory, chair)
	_ellipsoid(Vector3(0, 0.72, -0.04), Vector3(0.49, 0.10, 0.46), _materials.cloth, chair)
	var shell := _ellipsoid(Vector3(0, 1.15, 0.43), Vector3(0.58, 0.61, 0.16), _materials.ivory, chair)
	shell.rotation.x = -0.13
	var pad := _ellipsoid(Vector3(0, 1.15, 0.29), Vector3(0.49, 0.49, 0.10), _materials.cloth, chair)
	pad.rotation.x = -0.13
	for side: float in [-1.0, 1.0]:
		_tube(PackedVector3Array([Vector3(side * 0.50, 0.72, 0.25), Vector3(side * 0.59, 0.94, 0.13), Vector3(side * 0.55, 0.96, -0.27)]), 0.055, _materials.ivory, chair)
	_tube(PackedVector3Array([Vector3(-0.38, 0.91, 0.57), Vector3(0, 0.85, 0.60), Vector3(0.38, 0.91, 0.57)]), 0.017, _materials.coral, chair)
	if ornament_detail > 0:
		Ornaments.wave_patch(chair, "CrimsonWaveUpholstery", func(u: float, v: float) -> Vector3:
			var x := lerpf(-0.40, 0.40, u)
			var y := lerpf(0.84, 1.20, v)
			var z := 0.43 + 0.16 * sqrt(maxf(0.0, 1.0 - pow(x / 0.58, 2) - pow((y - 1.15) / 0.61, 2))) - (y - 1.15) * 0.13
			return Vector3(x, y, z + 0.008)
		, 2 + ornament_detail, 5, _materials.ruby)
	_solid_cylinder(Vector3(0, 0.75, 0.03), 0.46, 1.45, chair)

func _build_planter(position: Vector3, phase: float) -> void:
	var plant := Node3D.new()
	plant.position = position
	add_child(plant)
	_cylinder(Vector3(0, 0.40, 0), 0.31, 0.48, 0.73, _materials.ivory, plant)
	_cylinder(Vector3(0, 0.78, 0), 0.46, 0.46, 0.04, _materials.dark, plant)
	_ring(Vector3(0, 0.67, 0), 0.455, 0.018, _materials.cyan, plant)
	for leaf in range(9):
		var angle := phase + TAU * leaf / 9.0
		var length := 0.78 + 0.13 * (leaf % 4)
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var vein := PackedVector3Array()
		var side := Vector3(cos(angle), 0, -sin(angle))
		var last_left := Vector3(0, 0.79, 0)
		var last_right := last_left
		for index in range(13):
			var t := index / 12.0
			var center := Vector3(sin(angle) * t * length, 0.79 + sin(t * PI * 0.72) * length * 1.1 + t * 0.15, cos(angle) * t * length)
			var width := sin(t * PI) * 0.20
			var left := center - side * width
			var right := center + side * width
			if index > 0: _quad(surface, last_left, last_right, right, left)
			last_left = left
			last_right = right
			vein.append(center + Vector3(0, 0.006, 0))
		surface.generate_normals()
		_mesh(surface.commit(), _materials.leaf, Vector3.ZERO, plant)
		_tube(vein, 0.009, _materials.leaf_light, plant, 5)
	_solid_cylinder(Vector3(0, 0.40, 0), 0.43, 0.78, plant)

func _build_side_details() -> void:
	for side: float in [-1.0, 1.0]:
		var arch := PackedVector3Array()
		for index in range(33):
			var angle := PI * index / 32.0
			arch.append(Vector3(side * (6.9 + sin(angle) * 0.45), 0.15 + sin(angle) * 3.5, -3.5 + cos(angle) * 1.4))
		_tube(arch, 0.11, _materials.ivory)
		var glow := _tube(arch, 0.026, _materials.coral)
		glow.position.x -= side * 0.09
		_label("LOCAL SYSTEMS", Vector3(side * 5.7, 2.4, -5.7), 28, 0.004, CYAN)

func apply_mission_visuals(snapshot: Dictionary) -> void:
	if not is_instance_valid(_power_label): return
	var solar := float(snapshot.get("solar_kw", 0.0))
	var habitat := float(snapshot.get("habitat_kwh", 8.0))
	var suit := float(snapshot.get("suit_kwh", 0.9))
	var dose := float(snapshot.get("dose_msv", 0.0))
	var dust := int(float(snapshot.get("panel_dust", 0.0)) * 100.0)
	var hours := float(snapshot.get("time_hours", 0.0))
	var sheltered := bool(snapshot.get("sheltered", false))
	var event := bool(snapshot.get("event_active", false))
	_power_label.text = "SOLAR  %.1f kW\nHABITAT  %.1f kWh" % [solar, habitat]
	_dust_label.text = "MISSION  %04.1f h\nPANEL DUST  %d%%\nSURFACE ≠ ATMOSPHERE" % [hours, dust]
	_crew_label.text = "SUIT  %.2f kWh\nDOSE  %.2f mSv\n%s" % [suit, dose, "REFUGE ACTIVE" if sheltered else "CREW OUTSIDE REFUGE"]
	_forecast_label.text = "%s\nILLUSTRATIVE SOLAR EVENT\nUSE MASS FOR SHIELDING" % ("EVENT ACTIVE" if event else ("EVENT AHEAD" if hours < 4.0 else "EVENT PASSED"))
	var values := ["%.1f kW" % solar, "%.1f kWh" % habitat, "%.2f kWh" % suit, "%.2f mSv" % dose, "%d%%" % dust, "ACTIVE" if sheltered else "STANDBY", "ACTIVE" if event else "QUIET", "%.1f h" % hours, "SAVE" if snapshot.get("conserving", false) else "NORMAL"]
	for index in range(_tablet_labels.size()): _tablet_labels[index].text = values[index]
	_hologram_material.set_shader_parameter("storm_level", clampf(float(snapshot.get("storm", 0.0)), 0.0, 1.0))

func _process(delta: float) -> void:
	_elapsed += delta
	if is_instance_valid(_mars):
		_mars.rotation.y += delta * deg_to_rad(2.0)
		_mars.position.y = 3.05 + sin(_elapsed * TAU * 0.2) * 0.05
	if is_instance_valid(_orbit): _orbit.rotation.y -= delta * 0.035

func _build_ornaments() -> void:
	# The authored wave/blossom vocabulary follows curved room surfaces. It is an
	# artistic layer, not a scientific diagram or a claim about Martian biology.
	for side: float in [-1.0, 1.0]:
		Ornaments.wave_patch(self, "GoldHeaderWaves", func(u: float, v: float) -> Vector3:
			var angle := side * lerpf(0.69, 1.37, u)
			return Vector3(sin(angle) * 2.66, lerpf(5.43, 5.91, v), cos(angle) * 2.66)
		, 2 + ornament_detail, 5 + ornament_detail, _materials.gold)
		var blossom := Ornaments.blossom_branch(self, "CanopyBlossomFiligree", Vector3(side * 2.5, 5.98, 0.0), 0.82, _materials.gold, _materials.amber)
		blossom.rotation = Vector3(PI / 2.0, 0, side * 0.35)
		var suspension := Vector3(side * 6.25, 5.7, -2.8)
		_tube(PackedVector3Array([suspension, suspension - Vector3(0, 1.25, 0)]), 0.014, _materials.gold)
		Ornaments.lantern(self, "SuspendedAmberLantern", suspension - Vector3(0, 1.55, 0), 0.63, _materials.amber, _materials.dark)
		_build_bonsai(Vector3(side * 6.6, 0.08, -1.4), side)
		# Side arch lattice is inset behind the routes; no extra collision.
		_lattice_panel(Vector3(side * 7.0, 1.15, -4.0), Vector2(0.66, 1.7), 0.0, false)
	_build_blossom_tree(Vector3(7.5, 0.08, -2.7))
	for angle in [-1.05, -0.65, 0.65, 1.05]:
		_lattice_panel(Vector3(sin(angle) * 4.64, 0.53, cos(angle) * 4.64 + 0.06), Vector2(0.48, 0.65), angle, true)

func _lattice_panel(center: Vector3, size: Vector2, yaw: float, illuminated: bool) -> void:
	var panel := Node3D.new()
	panel.name = "LanternLatticeSupport" if illuminated else "InsetArchLattice"
	panel.position = center
	panel.rotation.y = yaw
	add_child(panel)
	if illuminated:
		var backing := BoxMesh.new()
		backing.size = Vector3(size.x, size.y, 0.05)
		_mesh(backing, _materials.amber, Vector3(0, 0, -0.025), panel)
	var paths: Array = []
	var left := -size.x / 2.0
	var right := size.x / 2.0
	var low := -size.y / 2.0
	var high := size.y / 2.0
	paths.append(PackedVector3Array([Vector3(left, low, 0), Vector3(right, low, 0), Vector3(right, high, 0), Vector3(left, high, 0), Vector3(left, low, 0)]))
	var rows := 4 + ornament_detail * 2
	for index in range(rows + 1):
		var y := lerpf(low, high, float(index) / rows)
		paths.append(PackedVector3Array([Vector3(left, y, 0), Vector3(right, y, 0)]))
	for index in range(1, 4):
		var x := lerpf(left, right, index / 4.0)
		paths.append(PackedVector3Array([Vector3(x, low, 0), Vector3(x, high, 0)]))
	for row in range(rows):
		var y := lerpf(low, high, (row + 0.5) / rows)
		var half := size.y / rows * 0.45
		paths.append(PackedVector3Array([Vector3(-size.x * 0.22, y, 0.007), Vector3(0, y + half, 0.007), Vector3(size.x * 0.22, y, 0.007), Vector3(0, y - half, 0.007), Vector3(-size.x * 0.22, y, 0.007)]))
	Ornaments.strokes(panel, "GeometricLanternLattice", paths, 0.014, _materials.dark)

func _build_bonsai(position: Vector3, side: float) -> void:
	var plant := Node3D.new()
	plant.name = "CultivatedBonsai"
	plant.position = position
	add_child(plant)
	var bowl := _cylinder(Vector3(0, 0.23, 0), 0.34, 0.60, 0.36, _materials.ruby, plant)
	bowl.scale.z = 0.65
	var soil := _cylinder(Vector3(0, 0.42, 0), 0.57, 0.57, 0.03, _materials.dark, plant)
	soil.scale.z = 0.65
	_tube(PackedVector3Array([Vector3(0, 0.42, 0), Vector3(-0.13 * side, 0.77, 0), Vector3(0.10 * side, 1.12, 0.03), Vector3(0.32 * side, 1.49, 0.03)]), 0.065, _materials.bark, plant)
	for index in range(5):
		var tip := Vector3(side * (-0.53 + index * 0.23), 1.03 + index * 0.15, sin(index * 2.0) * 0.20)
		_tube(PackedVector3Array([Vector3(0, 0.75 + index * 0.13, 0), tip]), 0.025, _materials.bark, plant)
		_ellipsoid(tip, Vector3(0.40, 0.12, 0.31), _materials.leaf, plant)
		_ellipsoid(tip + Vector3(0.04, 0.045, 0), Vector3(0.32, 0.10, 0.26), _materials.leaf_light, plant)
	_solid_cylinder(Vector3(0, 0.23, 0), 0.55, 0.40, plant)

func _batch_static_meshes() -> void:
	# One mesh per shared opaque material keeps procedural ornament detail from
	# creating hundreds of draw calls. Keep alpha surfaces separate for sorting,
	# and exclude animated hologram/orbit meshes and all labels/collision nodes.
	var groups: Dictionary = {}
	var pending: Array[Node] = [self]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if node == _orbit or node == _mars: continue
		for child in node.get_children(): pending.append(child)
		if not node is MeshInstance3D: continue
		var instance := node as MeshInstance3D
		var material := instance.material_override as StandardMaterial3D
		if not material or material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED: continue
		if not groups.has(material): groups[material] = []
		groups[material].append(instance)
	for material in groups:
		var instances: Array = groups[material]
		if instances.size() < 2: continue
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for instance: MeshInstance3D in instances:
			var local_transform := global_transform.affine_inverse() * instance.global_transform
			for index in range(instance.mesh.get_surface_count()):
				var source := SurfaceTool.new()
				source.create_from(instance.mesh, index)
				source.index()
				surface.append_from(source.commit(), 0, local_transform)
			instance.visible = false
			instance.queue_free()
		var mesh := surface.commit()
		var combined := _mesh(mesh, material, Vector3.ZERO)
		combined.name = "BatchedInteriorMaterial"

func _build_blossom_tree(position: Vector3) -> void:
	var tree := Node3D.new()
	tree.name = "CultivatedSakura"
	tree.position = position
	add_child(tree)
	_cylinder(Vector3(0, 0.36, 0), 0.27, 0.41, 0.68, _materials.ivory, tree)
	_ring(Vector3(0, 0.67, 0), 0.40, 0.028, _materials.gold, tree)
	_tube(PackedVector3Array([Vector3(0, 0.67, 0), Vector3(-0.08, 1.12, 0), Vector3(0.15, 1.65, 0.05), Vector3(-0.10, 2.15, 0.03)]), 0.055, _materials.bark, tree)
	for index in range(5):
		var sprig := Ornaments.blossom_branch(tree, "SakuraBlossomSpray", Vector3(0.04, 1.45 + index * 0.20, 0), 0.47 + 0.09 * (index % 2), _materials.bark, _materials.soft_coral)
		sprig.rotation = Vector3(0, index * 1.1, -0.3 + index * 0.12)
	_solid_cylinder(Vector3(0, 0.35, 0), 0.40, 0.7, tree)
