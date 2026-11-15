class_name VeilWorld
extends Node3D
## Scene assembly and mission presentation. Art modules never own mission equations.
const ARRAY_POSITION := Vector3(16, 0, -8)
const SHELTER_POSITION := Vector3(-14, 0, -7)
const POWER_POSITION := Vector3(1, 0, -5)
@export var art: VeilArtProfile = preload("res://art/default_art.tres")
var env: Environment
var panel_material: StandardMaterial3D
var dust_particles: CPUParticles3D
var sun: DirectionalLight3D
var beacons: Array[MeshInstance3D] = []
var _presentation_categories: Dictionary = {}
var _presentation_snapshot: Dictionary = {}
var _presentation_adapters: Array[Node] = []
var _window_presentation := false
var _presentation_ready := false
var _requested_window_presentation: Variant = null
var _pending_shape_states: Dictionary = {}
var _shape_change_serial := 0
var _world_materials: Dictionary = {}
var _category_builders: Dictionary = {}
var _built_categories: Dictionary = {}
var _fallback_rock_specs: Array[Dictionary] = []
var _last_mission_snapshot: Dictionary = {}
var _snapshot_generation := 0
var _visual_snapshot_deliveries: Dictionary = {}
var _last_panel_dust := 0.0
var _last_panel_cleaning := false

func material(color: Color, emission: float = 0.0) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.38
	if emission > 0:
		result.emission_enabled = true
		result.emission = color
		result.emission_energy_multiplier = emission
	return result

func shape(mesh: Mesh, mat: Material, pos: Vector3, parent: Node3D = self, solid: bool = false) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.position = pos
	parent.add_child(node)
	if solid: node.create_trimesh_collision()
	return node

func box(size: Vector3, mat: Material, pos: Vector3, parent: Node3D = self, solid: bool = false) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return shape(mesh, mat, pos, parent, solid)

func sphere(radius: float, mat: Material, pos: Vector3, parent: Node3D = self) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2
	mesh.radial_segments = 16
	mesh.rings = 8
	return shape(mesh, mat, pos, parent)

func cylinder(radius: float, height: float, mat: Material, pos: Vector3, parent: Node3D = self, solid: bool = false) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	return shape(mesh, mat, pos, parent, solid)

func text3d(value: String, pos: Vector3, size: int = 50, color: Color = Color("c4e5de")) -> Label3D:
	var label := Label3D.new()
	label.text = value
	label.position = pos
	label.font_size = size
	label.pixel_size = 0.006
	label.visibility_range_end = 12.0
	label.modulate = color
	label.outline_size = 2
	add_child(label)
	_register_presentation_node("wayfinding", label)
	return label

func _ready() -> void:
	var sand := material(art.terrain_color)
	var dark_sand := material(art.distant_terrain_color)
	var pale := material(art.hull_color)
	var trim := material(art.structure_color)
	var glow := material(art.instrument_color, 0.8)
	var gold := material(art.route_color)
	_world_materials = {"sand": sand, "dark_sand": dark_sand, "pale": pale, "trim": trim, "glow": glow, "gold": gold}
	_window_presentation = art.start_in_window_presentation if _requested_window_presentation == null else bool(_requested_window_presentation)
	_category_builders = {"habitat": _build_habitat, "refuge": _build_refuge, "solar_array": _build_solar_array, "power_control": _build_power_control, "route": _build_route, "rocks": _build_rocks}
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky_mat: Material
	if art.landscape_scene:
		var shader_sky := ShaderMaterial.new()
		shader_sky.shader = preload("res://art/red_veil/mars_sky.gdshader")
		# An art-directed dusty Martian sky, not a calibrated atmosphere model.
		shader_sky.set_shader_parameter("zenith", Color("718caa"))
		shader_sky.set_shader_parameter("horizon", Color("eab5a0"))
		shader_sky.set_shader_parameter("sunset", Color("ffe0ae"))
		sky_mat = shader_sky
	else:
		var procedural_sky := ProceduralSkyMaterial.new()
		procedural_sky.sky_top_color = Color("49303f")
		procedural_sky.sky_horizon_color = Color("dc8e87")
		procedural_sky.ground_bottom_color = Color("803d39")
		procedural_sky.ground_horizon_color = Color("dc8e87")
		procedural_sky.energy_multiplier = 0.6
		sky_mat = procedural_sky
	var sky := Sky.new()
	sky.sky_material = sky_mat
	# Static 128px sky radiance gives alloy/visor surfaces a real environment
	# reflection in Compatibility, without screen-space effects or extra probes.
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	sky.process_mode = Sky.PROCESS_MODE_QUALITY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("a3b8d4")
	env.ambient_light_energy = 0.38
	# Cool diffuse fill separates shaded forms from the low warm dawn key.
	# These are art-direction values, never inputs to mission solar/dose maths.
	env.ambient_light_sky_contribution = 0.22
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.95
	env.fog_enabled = true
	env.fog_sky_affect = 0.12
	env.fog_light_color = Color("deb3aa")
	env.fog_density = 0.0035
	var atmosphere := WorldEnvironment.new()
	atmosphere.environment = env
	add_child(atmosphere)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-24, -55, 0)
	sun.light_color = Color("ffdbb8")
	sun.light_energy = 0.82
	sun.shadow_enabled = art.shadows_enabled
	add_child(sun)
	box(Vector3(180, 1, 180), sand, Vector3(0, -0.5, 0), self, true)
	# Named anchors stay stable for consumers while their expensive contents wait.
	_ensure_slot_anchor("habitat", art.habitat_origin)
	_ensure_slot_anchor("refuge", SHELTER_POSITION)
	_ensure_slot_anchor("solar_array", ARRAY_POSITION)
	_build_landscape()
	if art.interior_scene:
		apply_art_slot("interior", art.interior_scene, art.habitat_origin, get_child_count())
		_built_categories["interior"] = true
	_build_companion()
	dust_particles = CPUParticles3D.new()
	dust_particles.amount = maxi(1, art.dust_particle_count)
	dust_particles.lifetime = 5
	dust_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust_particles.emission_box_extents = Vector3(30, 4, 30)
	dust_particles.position.y = 3
	dust_particles.direction = Vector3(1, -0.1, 0)
	dust_particles.spread = 12
	dust_particles.initial_velocity_min = 7
	dust_particles.initial_velocity_max = 10
	dust_particles.gravity = Vector3.ZERO
	var speck := SphereMesh.new()
	speck.radius = 0.015
	speck.height = 0.03
	speck.radial_segments = 4
	speck.rings = 2
	speck.material = gold
	dust_particles.mesh = speck
	dust_particles.emitting = false
	add_child(dust_particles)
	_presentation_ready = true
	set_window_presentation(_window_presentation)

func _build_landscape() -> void:
	var dark_sand: StandardMaterial3D = _world_materials.dark_sand
	var landscape_start := get_child_count()
	if art.landscape_scene == null:
		# Authored silhouettes frame the outpost and keep the walkable area legible.
		var rng := RandomNumberGenerator.new()
		rng.seed = 2053018
		for i in range(48):
			var angle := i * TAU / 48.0
			var radius := rng.randf_range(68, 88)
			var mountain := CylinderMesh.new()
			mountain.top_radius = rng.randf_range(1, 3)
			mountain.bottom_radius = rng.randf_range(8, 18)
			mountain.height = rng.randf_range(8, 24)
			mountain.radial_segments = 5
			shape(mountain, dark_sand, Vector3(cos(angle) * radius, mountain.height * 0.35, sin(angle) * radius)).rotation.y = angle
		# Retain the original RNG sequence without constructing hidden rock meshes.
		for i in range(65):
			var pos := Vector3(rng.randf_range(-55, 55), 0, rng.randf_range(-55, 55))
			if absf(pos.x) < 25 and absf(pos.z) < 25: continue
			var radius := rng.randf_range(0.3, 1.8)
			_fallback_rock_specs.append({"position": pos, "radius": radius, "rotation": rng.randf() * TAU})
	apply_art_slot("landscape", art.landscape_scene, Vector3.ZERO, landscape_start)
	_built_categories["landscape"] = true

func _build_route() -> void:
	var trim: StandardMaterial3D = _world_materials.trim
	var glow: StandardMaterial3D = _world_materials.glow
	var gold: StandardMaterial3D = _world_materials.gold
	var route_start := get_child_count()
	if art.landscape_scene == null:
		# Walking routes: warm guide lamps and a marked central approach.
		for i in range(12):
			for side in [-1, 1]:
				box(Vector3(0.16, 0.04, 0.7), gold, Vector3(side * 2.3, 0.02, 18 - i * 2.5))
		for point in [Vector3(-7, 0, 2), Vector3(7, 0, 2), Vector3(-7, 0, -13), Vector3(7, 0, -13)]:
			cylinder(0.08, 2.5, trim, point + Vector3(0, 1.25, 0))
			var lamp := sphere(0.18, glow, point + Vector3(0, 2.55, 0))
			beacons.append(lamp)
	_register_presentation_range("route", route_start)

func _build_habitat() -> void:
	var pale: StandardMaterial3D = _world_materials.pale
	var trim: StandardMaterial3D = _world_materials.trim
	var glow: StandardMaterial3D = _world_materials.glow
	var habitat_start := get_child_count()
	if art.habitat_scene == null:
		# Laboratory: cylindrical pressure vessel with ribs, windows and landing feet.
		var lab := Node3D.new()
		lab.position = Vector3(0, 2.4, -16)
		add_child(lab)
		var body := cylinder(2.5, 12, pale, Vector3.ZERO, lab, true)
		body.rotation.z = PI / 2
		for x in [-5, -3, -1, 1, 3, 5]:
			var torus := TorusMesh.new()
			torus.inner_radius = 2.48
			torus.outer_radius = 2.60
			var rib := shape(torus, trim, Vector3(x, 0, 0), lab)
			rib.rotation.z = PI / 2
		for x in [-4, 0, 4]:
			box(Vector3(1.25, 0.8, 0.15), glow, Vector3(x, 0.2, 2.4), lab)
			box(Vector3(0.2, 2, 2), trim, Vector3(x, -1.7, 0), lab)
		text3d("ELYSIUM  /  FIELD LAB", Vector3(0, 4.8, -13), 48)
	apply_art_slot("habitat", art.habitat_scene, art.habitat_origin, habitat_start)
	var antenna_start := get_child_count()
	if art.habitat_scene == null:
		# Antenna and horizon silhouettes give orientation without a full-screen map.
		cylinder(0.12, 9, trim, Vector3(-7, 4.5, -20))
		var dish := sphere(1.4, pale, Vector3(-7, 9, -20))
		dish.scale.y = 0.22
		dish.rotation.z = 0.5
	_register_presentation_range("habitat", antenna_start)

func _build_refuge() -> void:
	var sand: StandardMaterial3D = _world_materials.sand
	var pale: StandardMaterial3D = _world_materials.pale
	var trim: StandardMaterial3D = _world_materials.trim
	var glow: StandardMaterial3D = _world_materials.glow
	var refuge_start := get_child_count()
	if art.refuge_scene == null:
		# Sheltered refuge has an actual walk-in doorway and readable interior.
		var shelter := Node3D.new()
		shelter.position = SHELTER_POSITION
		add_child(shelter)
		box(Vector3(7.5, 0.15, 7.5), pale, Vector3(0, 0.075, 0), shelter, true)
		box(Vector3(8, 0.6, 8), sand, Vector3(0, 3.7, 0), shelter, true)
		for x in [-3.7, 3.7]: box(Vector3(0.6, 3.6, 8), sand, Vector3(x, 1.8, 0), shelter, true)
		box(Vector3(8, 3.6, 0.6), sand, Vector3(0, 1.8, -3.7), shelter, true)
		for x in [-2.6, 2.6]: box(Vector3(2.2, 3.6, 0.6), sand, Vector3(x, 1.8, 3.7), shelter, true)
		box(Vector3(3.0, 0.2, 0.25), glow, Vector3(0, 3.1, 3.95), shelter)
		for x in [-2.3, 2.3]:
			box(Vector3(0.08, 2.7, 0.08), glow, Vector3(x, 1.5, -3.2), shelter)
			box(Vector3(1, 0.5, 3), trim, Vector3(x, 0.3, 0), shelter, true)
		text3d("REFUGE  /  WALK INSIDE", SHELTER_POSITION + Vector3(0, 4.3, 4.1), 42)
		text3d("PREINSTALLED SHIELDING\nPASSIVE PROTECTION", SHELTER_POSITION + Vector3(0, 2.2, -3.3), 30)
	apply_art_slot("refuge", art.refuge_scene, SHELTER_POSITION, refuge_start)

func _build_solar_array() -> void:
	var pale: StandardMaterial3D = _world_materials.pale
	var trim: StandardMaterial3D = _world_materials.trim
	var solar_array_start := get_child_count()
	# Solar field and tactile inspection point.
	panel_material = material(Color("293b53"))
	panel_material.metallic = 0.35
	_apply_panel_visual_state()
	for row in range(2):
		for col in range(3):
			var pos := ARRAY_POSITION + Vector3(col * 3.0 - 3, 1.4, row * -3.8)
			cylinder(0.12, 1.3, trim, pos - Vector3(0, 0.75, 0))
			var array := Node3D.new()
			array.position = pos
			array.rotation.x = -0.3
			add_child(array)
			box(Vector3(2.6, 0.15, 3.3), trim, Vector3.ZERO, array, true)
			box(Vector3(2.45, 0.04, 3.1), panel_material, Vector3(0, 0.1, 0), array)
			for grid in range(-2, 3): box(Vector3(0.02, 0.01, 3.1), pale, Vector3(grid * 0.45, 0.13, 0), array)
			for grid in range(-2, 3): box(Vector3(2.45, 0.01, 0.02), pale, Vector3(0, 0.13, grid * 0.5), array)
	text3d("SOLAR ARRAY", ARRAY_POSITION + Vector3(0, 3.8, 1), 48)
	apply_art_slot("solar_array", art.solar_array_scene, ARRAY_POSITION, solar_array_start)

func _build_power_control() -> void:
	var trim: StandardMaterial3D = _world_materials.trim
	var glow: StandardMaterial3D = _world_materials.glow
	var power_control_start := get_child_count()
	# Control kiosk can be reached on foot, with a duplicate remote inside refuge.
	for point in [POWER_POSITION, SHELTER_POSITION + Vector3(0, 0, -2.7)]:
		box(Vector3(1.2, 1.2, 0.6), trim, point + Vector3(0, 0.6, 0), self, true)
		box(Vector3(1.05, 0.45, 0.05), glow, point + Vector3(0, 1.02, 0.33))
	text3d("POWER CONTROL", POWER_POSITION + Vector3(0, 2.1, 0.4), 32)
	_register_presentation_range("power_control", power_control_start)

func _build_companion() -> void:
	var pale: StandardMaterial3D = _world_materials.pale
	var trim: StandardMaterial3D = _world_materials.trim
	var gold: StandardMaterial3D = _world_materials.gold
	var companion_start := get_child_count()
	if art.companion_scene == null:
		# Companion astronaut Mira. Character visuals are cosmetic, not mission rules.
		var mira := Node3D.new()
		mira.position = Vector3(-4, 0, 7)
		add_child(mira)
		box(Vector3(0.65, 0.8, 0.4), pale, Vector3(0, 1.1, 0), mira)
		sphere(0.4, pale, Vector3(0, 1.85, 0), mira)
		var visor := sphere(0.33, material(Color("e7b370")), Vector3(0, 1.88, 0.2), mira)
		visor.scale.z = 0.6
		for x in [-0.22, 0.22]:
			box(Vector3(0.24, 0.7, 0.3), pale, Vector3(x, 0.45, 0), mira)
			box(Vector3(0.3, 0.2, 0.45), trim, Vector3(x, 0.1, 0.08), mira)
		for x in [-0.48, 0.48]: box(Vector3(0.22, 0.7, 0.24), pale, Vector3(x, 1.15, 0), mira)
		box(Vector3(0.5, 0.6, 0.3), gold, Vector3(0, 1.2, -0.3), mira)
		text3d("MIRA / YOUR CREWMATE", Vector3(-4, 2.6, 7), 28)
	apply_art_slot("companion", art.companion_scene, Vector3(-4, 0, 7), companion_start)
	_built_categories["companion"] = true

func _build_rocks() -> void:
	if art.landscape_scene != null: return
	var start := get_child_count()
	for spec: Dictionary in _fallback_rock_specs:
		var rock := SphereMesh.new()
		rock.radius = spec.radius
		rock.height = spec.radius * 1.1
		rock.radial_segments = 5
		rock.rings = 3
		shape(rock, _world_materials.dark_sand, spec.position).rotation.y = spec.rotation
	_register_presentation_range("rocks", start)

func update_weather(mission: VeilMission) -> void:
	var weather := mission.environment()
	_last_mission_snapshot = mission.visual_snapshot().duplicate(true)
	_snapshot_generation += 1
	_deliver_visual_snapshots()
	env.fog_density = 0.0035 + weather.storm * 0.025
	sun.light_energy = 0.82 - weather.storm * 0.62
	_last_panel_dust = mission.dust
	_last_panel_cleaning = mission.cleaning
	_apply_panel_visual_state()
	dust_particles.emitting = art.dust_particle_count > 0 and weather.storm > 0.3

func _deliver_visual_snapshots() -> void:
	if _snapshot_generation == 0: return
	var active: Dictionary = {}
	# Preserve the public group contract for nested and externally attached
	# adapters, while keeping each world isolated from sibling world instances.
	for visual in get_tree().get_nodes_in_group("mission_visual_adapters"):
		if not is_instance_valid(visual) or not is_ancestor_of(visual) or not visual.has_method("apply_mission_visuals"): continue
		var id: int = visual.get_instance_id()
		active[id] = true
		if _visual_snapshot_deliveries.get(id, -1) == _snapshot_generation: continue
		_visual_snapshot_deliveries[id] = _snapshot_generation
		visual.apply_mission_visuals(_last_mission_snapshot.duplicate(true))
	for id in _visual_snapshot_deliveries.keys():
		if not active.has(id): _visual_snapshot_deliveries.erase(id)

func _apply_panel_visual_state() -> void:
	if not is_instance_valid(panel_material): return
	panel_material.albedo_color = Color("293b53").lerp(Color("b67c59"), _last_panel_dust * 0.7)
	panel_material.emission_enabled = _last_panel_cleaning
	panel_material.emission = Color("478c91")
	panel_material.emission_energy_multiplier = 0.35

func _ensure_slot_anchor(slot_name: String, origin: Vector3) -> Marker3D:
	var anchor_name := slot_name.capitalize().replace(" ", "") + "Anchor"
	var anchor := get_node_or_null(anchor_name) as Marker3D
	if anchor == null:
		anchor = Marker3D.new()
		anchor.name = anchor_name
		anchor.position = origin
		add_child(anchor)
	_register_presentation_node(slot_name, anchor)
	return anchor

func apply_art_slot(slot_name: String, replacement: PackedScene, origin: Vector3, start_index: int) -> void:
	# Capture only this builder's fallback nodes, never another reserved anchor.
	var fallback_nodes := get_children().slice(start_index)
	var anchor := _ensure_slot_anchor(slot_name, origin)
	for node: Node in fallback_nodes: _register_presentation_node(slot_name, node)
	if replacement == null: return
	# Fallback collision proxies remain authoritative when a replacement supplies
	# only visuals, matching the released custom-scene behavior.
	for node: Node in fallback_nodes: hide_visuals(node)
	var visual := replacement.instantiate()
	if visual.has_method("prepare_presentation"):
		visual.prepare_presentation(_window_presentation, art.window_hidden_categories.duplicate())
	anchor.add_child(visual)
	_refresh_adapter_categories(visual)
	if visual.has_method("set_window_presentation") or visual.has_method("ensure_presentation"):
		_presentation_adapters.append(visual)
	if visual.has_method("apply_mission_visuals"):
		visual.add_to_group("mission_visual_adapters")
	_deliver_visual_snapshots()

func _refresh_adapter_categories(visual: Node) -> void:
	if not visual.has_method("get_presentation_categories"): return
	var categories: Dictionary = visual.get_presentation_categories()
	for category in categories:
		for node: Node in categories[category]: _register_presentation_node(category, node)

func is_presentation_category_constructed(category: String) -> bool:
	return _built_categories.get(category, false)

func _ensure_visible_categories() -> void:
	for category in _category_builders:
		if _built_categories.get(category, false): continue
		if _window_presentation and category in art.window_hidden_categories: continue
		_built_categories[category] = true
		_category_builders[category].call()
	for adapter in _presentation_adapters:
		if not is_instance_valid(adapter): continue
		if adapter.has_method("ensure_presentation"):
			adapter.ensure_presentation(_window_presentation, art.window_hidden_categories.duplicate())
		_refresh_adapter_categories(adapter)

func hide_visuals(node: Node) -> void:
	if node is GeometryInstance3D: node.hide()
	for child in node.get_children(): hide_visuals(child)

func _register_presentation_node(category: String, node: Node) -> void:
	if not _presentation_categories.has(category): _presentation_categories[category] = []
	if not _presentation_categories[category].has(node): _presentation_categories[category].append(node)

func _register_presentation_range(category: String, start_index: int) -> void:
	for index in range(start_index, get_child_count()):
		_register_presentation_node(category, get_child(index))

func get_presentation_category_roots(category: String) -> Array[Node]:
	var result: Array[Node] = []
	for node in _presentation_categories.get(category, []):
		if is_instance_valid(node) and not node.is_queued_for_deletion(): result.append(node)
	return result

func is_window_presentation() -> bool:
	return _window_presentation

func set_window_presentation(enabled: bool) -> void:
	_window_presentation = enabled
	if not _presentation_ready:
		_requested_window_presentation = enabled
		return
	# Restore the authored state first, including already-hidden fallback meshes.
	# This also makes live profile edits + repeated true/false calls reversible.
	for entry: Dictionary in _presentation_snapshot.values():
		if not is_instance_valid(entry.node): continue
		var node: Node = entry.node
		node.process_mode = entry.process_mode
		if node is Node3D: node.visible = entry.visible
		if node is CollisionObject3D:
			node.collision_layer = entry.layer
			node.collision_mask = entry.mask
			node.input_ray_pickable = entry.pickable
		if node is CollisionShape3D or node is CollisionPolygon3D:
			_schedule_shape_state(node, entry.disabled)
	_presentation_snapshot.clear()
	_ensure_visible_categories()
	if enabled:
		for category in art.window_hidden_categories:
			for node in get_presentation_category_roots(category): _suspend_presentation_tree(node)
	# An interior-only enclosure can follow this mode without being mixed into
	# the exterior asset or changing mission equations/companion movement.
	for adapter in _presentation_adapters:
		if is_instance_valid(adapter) and adapter.has_method("set_window_presentation"):
			adapter.set_window_presentation(enabled)
	_deliver_visual_snapshots()

func _suspend_presentation_tree(root_node: Node) -> void:
	var pending: Array[Node] = [root_node]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if node.is_queued_for_deletion(): continue
		for child in node.get_children(): pending.append(child)
		var id := node.get_instance_id()
		if _presentation_snapshot.has(id): continue
		var entry := {"node": node, "process_mode": node.process_mode}
		if node is Node3D:
			entry.visible = node.visible
			node.hide()
		if node is CollisionObject3D:
			entry.layer = node.collision_layer
			entry.mask = node.collision_mask
			entry.pickable = node.input_ray_pickable
			node.collision_layer = 0
			node.collision_mask = 0
			node.input_ray_pickable = false
		if node is CollisionShape3D or node is CollisionPolygon3D:
			entry.disabled = _pending_shape_states.get(id, {"disabled": node.disabled}).disabled
			_schedule_shape_state(node, true)
		_presentation_snapshot[id] = entry
		node.process_mode = Node.PROCESS_MODE_DISABLED

func _schedule_shape_state(node: Node, disabled: bool) -> void:
	# Changes requested during input/physics use the idle queue. Keep their logical
	# state available so repeated toggles before that queue drains remain exact.
	_shape_change_serial += 1
	_pending_shape_states[node.get_instance_id()] = {"disabled": disabled, "serial": _shape_change_serial}
	_apply_shape_state.call_deferred(node, disabled, _shape_change_serial)

func _apply_shape_state(node: Node, disabled: bool, serial: int) -> void:
	if not is_instance_valid(node): return
	node.disabled = disabled
	var id := node.get_instance_id()
	if _pending_shape_states.has(id) and _pending_shape_states[id].serial == serial:
		_pending_shape_states.erase(id)
