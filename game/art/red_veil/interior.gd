extends Node3D
## Calm mission workspace. +Z is the unobstructed forward dune-view aperture.
## Presentation changes never alter mission science, energy, dose or collision routes.
const VisualStyle = preload("res://scripts/visual_style.gd")
const Branding = preload("res://scripts/branding.gd")
const Ornaments = preload("res://art/red_veil/exterior_ornaments.gd")
@export_range(0, 2) var ornament_detail: int = 1
@export var batch_static_geometry: bool = true
var CYAN: Color = VisualStyle.color("cyan")
var IVORY: Color = VisualStyle.color("pearl").lerp(VisualStyle.color("white"), 0.72)
var GRAPHITE: Color = VisualStyle.color("teal_panel").darkened(0.24)
var _materials: Dictionary = {}
var _power_label: Label3D
var _dust_label: Label3D
var _crew_label: Label3D
var _forecast_label: Label3D
var _mars: MeshInstance3D
var _window_mode := false
var _legacy_content: Array[Node3D] = []
var _window_enclosure: Node3D
var _outer_airlock_door: Node3D
var _inner_airlock_door: Node3D
var _airlock_status: Label3D
var _airlock_phase := "idle"
var _collision_settings: Dictionary = {}
var _presentation_ready := false
var _legacy_built := false
var _last_mission_snapshot: Dictionary = {}

func prepare_presentation(window_mode: bool, _hidden_categories: PackedStringArray = PackedStringArray()) -> void:
	# World calls this before add_child triggers _ready. Standalone scenes retain
	# legacy EVA by default; a mode request must never allocate geometry early.
	_window_mode = window_mode
	if _presentation_ready: set_window_presentation(window_mode)

func _ready() -> void:
	# Only these shared finishes are needed for the lightweight window enclosure.
	_materials.navy = _material(GRAPHITE, 0.80, 0.0)
	_materials.chrome = _material(VisualStyle.color("steel").darkened(0.22), 0.65, 0.10)
	_materials.cyan = _material(CYAN, 0.80, 0.0, 0.08)
	_presentation_ready = true
	set_window_presentation(_window_mode)

func _ensure_legacy_content() -> void:
	if _legacy_built: return
	_legacy_built = true
	_materials.ivory = _material(IVORY, 0.78, 0.0)
	_materials.pearl = _material(IVORY.darkened(0.12), 0.86, 0.0)
	_materials.dark = _material(GRAPHITE, 0.86, 0.0)
	_materials.cloth = _material(IVORY.darkened(0.05), 0.95, 0.0)
	_materials.leaf = _material(Color("576d59"), 0.95, 0.0)
	_materials.leaf.cull_mode = BaseMaterial3D.CULL_DISABLED
	_materials.leaf_light = _material(Color("8b987b"), 0.95, 0.0)
	_materials.gold = _material(VisualStyle.color("rose_gold").darkened(0.28), 0.85, 0.0)
	_materials.planet = _material(VisualStyle.color("amber").darkened(0.30), 0.92, 0.0)
	# Opaque panels avoid transparent sorting artifacts and bright glass clutter.
	_materials.panel = _material(GRAPHITE, 0.90, 0.0)
	_materials.panel.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_build_floor()
	_build_teaching_model()
	_build_structure()
	_build_consoles()
	_build_chair(Vector3(-4.0, 0.05, 5.1), PI - 0.05)
	_build_chair(Vector3(4.25, 0.05, 5.1), PI + 0.12)
	_build_planter(Vector3(-7.5, 0.05, -3.9), 0.15)
	_build_planter(Vector3(7.4, 0.05, -4.5), 1.1)
	if batch_static_geometry: _batch_static_meshes()
	_refresh_mission_labels()
	for child in get_children():
		if child is Node3D and child != _window_enclosure and not child.is_queued_for_deletion():
			_legacy_content.append(child)

func _ensure_window_enclosure() -> void:
	if is_instance_valid(_window_enclosure): return
	_build_window_enclosure()

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
	if material == _materials.cyan: node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
	var border := _ring(Vector3(0, 0.065, 0), 9.35, 0.035, _materials.chrome)
	border.scale.z = 0.75

func _build_teaching_model() -> void:
	# The teaching object lives beside the workspace, leaving the central walking
	# line and the main window completely open. Its collider moves with the plinth.
	var station := Node3D.new()
	station.name = "SideTeachingPlinth"
	station.position = Vector3(6.3, 0, -1.6)
	add_child(station)
	_cylinder(Vector3(0, 0.25, 0), 0.78, 0.78, 0.45, _materials.ivory, station)
	_cylinder(Vector3(0, 0.51, 0), 0.78, 0.76, 0.07, _materials.navy, station)
	_solid_cylinder(Vector3(0, 0.36, 0), 0.78, 0.66, station)
	var globe := SphereMesh.new()
	globe.radius = 0.32
	globe.height = 0.64
	globe.radial_segments = 32
	globe.rings = 16
	_mars = _mesh(globe, _materials.planet, Vector3(0, 0.96, 0), station)
	_mars.name = "QuietMarsModel"
	_label("MARS / TRAINING MODEL", Vector3(0, 0.37, 0.79), 20, 0.0030, GRAPHITE, station)

func _build_structure() -> void:
	# The habitat shell supplies the ceiling. Two quiet structural ribs replace
	# the previous concentric neon rings and ornamental hanging sign drum.
	for side: float in [-1.0, 1.0]:
		_tube(PackedVector3Array([Vector3(side * 7.4, 0.2, -4.3), Vector3(side * 6.2, 3.5, -4.7), Vector3(side * 3.8, 5.7, -5.0)]), 0.055, _materials.chrome)
	var sign := _label(Branding.title(), Vector3(0, 4.85, -5.45), 72, 0.0045, IVORY)
	sign.name = "SharedBrandSign"
	_label(Branding.subtitle().to_upper(), Vector3(0, 4.50, -5.43), 28, 0.0045, CYAN)
	var view := Marker3D.new()
	view.name = "ForwardWindowView"
	view.position = Vector3(0, 2.1, -5.4)
	add_child(view)

func _build_consoles() -> void:
	for limits in [[-1.25, -0.29], [0.29, 1.25]]:
		var start: float = limits[0]
		var finish: float = limits[1]
		_annular_segment(4.22, 5.05, 0.90, 1.10, start, finish, _materials.ivory)
		_tube(_arc(5.02, 1.02, start, finish), 0.032, _materials.navy)
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
		for fraction in [0.2, 0.8]:
			var angle := lerpf(start, finish, fraction)
			_cylinder(Vector3(sin(angle) * 4.55, 0.50, cos(angle) * 4.55), 0.08, 0.08, 0.86, _materials.chrome)
	# Two separated workstations leave a wide central sightline to the dunes.
	var resources := _build_display(Vector3(-3.4, 1.95, 3.55), PI + 0.12, "RESOURCES", "energy")
	_power_label = resources[0]
	_dust_label = resources[1]
	var safety := _build_display(Vector3(3.4, 1.95, 3.55), PI - 0.12, "CREW SAFETY", "crew")
	_crew_label = safety[0]
	_forecast_label = safety[1]
	if ornament_detail > 0:
		# A single seigaiha inset preserves craft identity without all-over filigree.
		Ornaments.wave_patch(self, "QuietSeigaihaInset", func(u: float, v: float) -> Vector3:
			return Vector3(lerpf(5.95, 6.65, u), lerpf(0.15, 0.30, v), -2.385)
		, 1, 3, _materials.gold)

func _build_display(position: Vector3, yaw: float, title: String, key: String) -> Array[Label3D]:
	var panel := Node3D.new()
	panel.name = "HeroPanel_" + key
	panel.position = position
	panel.rotation.y = yaw
	add_child(panel)
	var screen := BoxMesh.new()
	screen.size = Vector3(3.2, 1.74, 0.08)
	_mesh(screen, _materials.ivory, Vector3.ZERO, panel)
	var face := PlaneMesh.new()
	face.orientation = PlaneMesh.FACE_Z
	face.size = Vector2(3.1, 1.64)
	_mesh(face, _materials.panel, Vector3(0, 0, 0.045), panel)
	_tube(PackedVector3Array([Vector3(-1.34, 0.38, 0.051), Vector3(1.34, 0.38, 0.051)]), 0.006, _materials.cyan, panel, 4)
	_label(title, Vector3(0, 0.61, 0.14), 36, 0.0050, CYAN, panel)
	var primary := _label("", Vector3(0, 0.08, 0.14), 32, 0.0053, VisualStyle.color("white"), panel)
	var secondary := _label("", Vector3(0, -0.49, 0.14), 26, 0.0045, VisualStyle.color("white"), panel)
	primary.name = "PrimaryTelemetry"
	secondary.name = "SecondaryTelemetry"
	return [primary, secondary]

func apply_mission_visuals(snapshot: Dictionary) -> void:
	# Keep detached state even before a branch exists. Later construction must
	# never reset displayed resources to the scenario's initial defaults.
	_last_mission_snapshot = snapshot.duplicate(true)
	_refresh_mission_labels()

func _refresh_mission_labels() -> void:
	if not is_instance_valid(_power_label): return
	var snapshot := _last_mission_snapshot
	var solar := float(snapshot.get("solar_kw", 0.0))
	var habitat := float(snapshot.get("habitat_kwh", 8.0))
	var suit := float(snapshot.get("suit_kwh", 0.9))
	var dose := float(snapshot.get("dose_msv", 0.0))
	var dust := int(float(snapshot.get("panel_dust", 0.0)) * 100.0)
	var hours := float(snapshot.get("time_hours", 0.0))
	var sheltered := bool(snapshot.get("sheltered", false))
	var event := bool(snapshot.get("event_active", false))
	_power_label.text = "Solar  %.1f kW\nHabitat  %.1f kWh" % [solar, habitat]
	_dust_label.text = "Panel dust  %d%%  ·  %04.1f h\nPower mode  %s" % [dust, hours, "SAVE" if snapshot.get("conserving", false) else "NORMAL"]
	_crew_label.text = "Suit  %.2f kWh  ·  Dose  %.2f mSv\n%s" % [suit, dose, "REFUGE ACTIVE" if sheltered else "Outside refuge"]
	_forecast_label.text = "%s\nTraining event · hours 4–7" % ("EVENT ACTIVE" if event else ("EVENT AHEAD" if hours < 4.0 else "EVENT PASSED"))

func _process(delta: float) -> void:
	if not _window_mode and is_instance_valid(_mars): _mars.rotation.y += delta * deg_to_rad(2.0)

func _build_chair(position: Vector3, yaw: float) -> void:
	var chair := Node3D.new()
	chair.position = position
	chair.rotation.y = yaw
	add_child(chair)
	_cylinder(Vector3(0, 0.08, 0), 0.43, 0.38, 0.12, _materials.chrome, chair)
	_tube(PackedVector3Array([Vector3(0, 0.12, 0), Vector3(0, 0.34, 0.04), Vector3(0, 0.57, 0.12)]), 0.09, _materials.navy, chair)
	_ellipsoid(Vector3(0, 0.62, 0.03), Vector3(0.57, 0.15, 0.57), _materials.ivory, chair)
	_ellipsoid(Vector3(0, 0.72, -0.04), Vector3(0.49, 0.10, 0.46), _materials.cloth, chair)
	var shell := _ellipsoid(Vector3(0, 1.15, 0.43), Vector3(0.58, 0.61, 0.16), _materials.ivory, chair)
	shell.rotation.x = -0.13
	var pad := _ellipsoid(Vector3(0, 1.15, 0.29), Vector3(0.49, 0.49, 0.10), _materials.cloth, chair)
	pad.rotation.x = -0.13
	for side: float in [-1.0, 1.0]:
		_tube(PackedVector3Array([Vector3(side * 0.50, 0.72, 0.25), Vector3(side * 0.59, 0.94, 0.13), Vector3(side * 0.55, 0.96, -0.27)]), 0.055, _materials.ivory, chair)
	_solid_cylinder(Vector3(0, 0.75, 0.03), 0.46, 1.45, chair)

func _build_planter(position: Vector3, phase: float) -> void:
	var plant := Node3D.new()
	plant.position = position
	add_child(plant)
	_cylinder(Vector3(0, 0.40, 0), 0.31, 0.48, 0.73, _materials.ivory, plant)
	_cylinder(Vector3(0, 0.78, 0), 0.46, 0.46, 0.04, _materials.dark, plant)
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

func _batch_static_meshes() -> void:
	# One mesh per shared opaque material keeps procedural ornament detail from
	# creating hundreds of draw calls. Keep alpha surfaces separate for sorting,
	# and exclude the rotating teaching model and all labels/collision nodes.
	var groups: Dictionary = {}
	var pending: Array[Node] = [self]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		# A late EVA build must not merge/free the already-built window and its
		# attached door colliders, nor capture it as legacy content.
		if node == _mars or node == _window_enclosure: continue
		for child in node.get_children(): pending.append(child)
		if not node is MeshInstance3D: continue
		var instance := node as MeshInstance3D
		var material := instance.material_override as StandardMaterial3D
		if not material or material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED: continue
		var key := "%s:%s" % [material.get_instance_id(), instance.cast_shadow]
		if not groups.has(key): groups[key] = {"material": material, "shadow": instance.cast_shadow, "instances": []}
		groups[key].instances.append(instance)
	for group in groups.values():
		var material: Material = group.material
		var instances: Array = group.instances
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
		combined.cast_shadow = group.shadow


func _window_box(title: String, size: Vector3, position: Vector3, material: Material, solid: bool = true) -> Node3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var visual := _mesh(mesh, material, position, _window_enclosure)
	visual.name = title
	if solid:
		var body := StaticBody3D.new()
		body.name = "Barrier"
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		body.add_child(collision)
		visual.add_child(body)
	return visual

func _build_window_enclosure() -> void:
	# This room is an actual enclosed first-person space, independent of the
	# exterior habitat model. Door animation is presentation, not pressure physics.
	_window_enclosure = Node3D.new()
	_window_enclosure.name = "OperatorWindowRoom"
	add_child(_window_enclosure)
	var wall := _material(IVORY.darkened(0.20), 0.92, 0.0)
	var floor := _material(IVORY.darkened(0.30), 0.96, 0.0)
	_window_box("RoomFloor", Vector3(18.4, 0.12, 14.6), Vector3(0, 0.0, -1.0), floor)
	_window_box("RoomCeiling", Vector3(18.4, 0.18, 14.6), Vector3(0, 6.85, -1.0), wall)
	_window_box("RearWall", Vector3(18.4, 6.9, 0.18), Vector3(0, 3.4, -8.2), wall)
	for side: float in [-1.0, 1.0]:
		_window_box("SideWall", Vector3(0.18, 6.9, 14.6), Vector3(side * 9.1, 3.4, -1.0), wall)
	# Panoramic glazing is genuinely clear; only thin edge frames identify it.
	# Left side contains a separate crew entry, never a path through the pane.
	var pane_left := -5.70
	var pane_right := 8.95
	var pane_bottom := 0.22
	var pane_top := 6.65
	var pane_center := Vector3((pane_left + pane_right) * 0.5, (pane_bottom + pane_top) * 0.5, 6.2)
	var pane_size := Vector3(pane_right - pane_left, pane_top - pane_bottom, 0.10)
	var glass := _material(Color(0.72, 0.87, 0.91, 0.016), 0.95, 0.0)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	glass.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var window := _window_box("ClearPanoramicWindow", pane_size, pane_center, glass)
	window.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_window_box("WindowSill", Vector3(pane_size.x + 0.16, 0.22, 0.18), Vector3(pane_center.x, 0.11, 6.2), wall)
	_window_box("WindowHeader", Vector3(pane_size.x + 0.16, 0.18, 0.18), Vector3(pane_center.x, 6.74, 6.2), wall)
	for x in [pane_left - 0.045, pane_right + 0.045]:
		_window_box("WindowEdge", Vector3(0.09, 6.65, 0.18), Vector3(x, 3.35, 6.2), _materials.chrome)
	# An off-centre, two-door vestibule: outer threshold z=6.2, receiver z=4.6,
	# inner door z=3.7. Both doors remain shut during the timed cycle.
	_window_box("EntryLeftJamb", Vector3(0.85, 6.85, 0.20), Vector3(-8.675, 3.425, 6.2), wall)
	_window_box("EntryRightJamb", Vector3(0.35, 6.85, 0.20), Vector3(-5.875, 3.425, 6.2), wall)
	_window_box("EntryHeader", Vector3(2.20, 4.25, 0.20), Vector3(-7.15, 4.725, 6.2), wall)
	for x in [-8.30, -6.00]:
		_window_box("AirlockSide", Vector3(0.10, 2.72, 2.65), Vector3(x, 1.36, 4.95), wall)
	_window_box("AirlockRoof", Vector3(2.40, 0.10, 2.65), Vector3(-7.15, 2.72, 4.95), wall)
	_outer_airlock_door = _window_box("OuterAirlockDoor", Vector3(2.18, 2.60, 0.12), Vector3(-7.15, 1.30, 6.2), _materials.navy)
	_inner_airlock_door = _window_box("InnerAirlockDoor", Vector3(2.18, 2.60, 0.12), Vector3(-7.15, 1.30, 3.7), _materials.navy)
	_airlock_status = _label("CREW ENTRY / CLOSED", Vector3(-7.15, 2.97, 3.60), 25, 0.004, CYAN, _window_enclosure)
	_airlock_status.rotation.y = PI
	_airlock_status.double_sided = false
	var sign := _label(Branding.title(), Vector3(0, 2.7, -8.08), 58, 0.005, IVORY, _window_enclosure)
	sign.double_sided = false
	_label(Branding.subtitle(), Vector3(0, 2.32, -8.07), 25, 0.004, CYAN, _window_enclosure)
	var camera_anchor := Marker3D.new()
	camera_anchor.name = "WindowOperatorView"
	camera_anchor.position = Vector3(0, 1.78, 3.4)
	camera_anchor.set_meta("vertical_fov_degrees", 52.0)
	_window_enclosure.add_child(camera_anchor)

func _set_branch_enabled(branch: Node3D, enabled: bool) -> void:
	branch.visible = enabled
	var bodies := branch.find_children("*", "CollisionObject3D", true, false)
	if branch is CollisionObject3D: bodies.append(branch)
	for body: CollisionObject3D in bodies:
		if not _collision_settings.has(body):
			_collision_settings[body] = Vector2i(body.collision_layer, body.collision_mask)
		var original: Vector2i = _collision_settings[body]
		body.collision_layer = original.x if enabled else 0
		body.collision_mask = original.y if enabled else 0

func set_window_presentation(enabled: bool) -> void:
	_window_mode = enabled
	if not _presentation_ready: return
	if enabled: _ensure_window_enclosure()
	else: _ensure_legacy_content()
	for branch in _legacy_content:
		if is_instance_valid(branch): _set_branch_enabled(branch, not enabled)
	if is_instance_valid(_window_enclosure): _set_branch_enabled(_window_enclosure, enabled)
	if enabled: set_airlock_phase(_airlock_phase)
	set_process(not enabled and is_instance_valid(_mars))

func set_airlock_phase(phase: String) -> void:
	# The orchestrator alone decides crew travel, cycle time and shelter state.
	# Showing an open door never changes Mission.shelter or scientific equations.
	if phase not in ["idle", "approach", "cycling", "complete"]: return
	_airlock_phase = phase
	if not _window_mode or not is_instance_valid(_window_enclosure): return
	_set_branch_enabled(_outer_airlock_door, phase != "approach")
	_set_branch_enabled(_inner_airlock_door, phase != "complete")
	var messages := {"idle": "CREW ENTRY / CLOSED", "approach": "CREW ENTRY / RECEIVING", "cycling": "CREW ENTRY / CYCLING", "complete": "CREW ENTRY / READY"}
	_airlock_status.text = messages[phase]
