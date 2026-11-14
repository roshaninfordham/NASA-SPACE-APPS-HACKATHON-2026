class_name VeilWorld
extends Node3D
## Procedural placeholder art is replaceable independently of mission rules.
const ARRAY_POSITION := Vector3(16, 0, -8)
const SHELTER_POSITION := Vector3(-14, 0, -7)
const POWER_POSITION := Vector3(1, 0, -5)
@export var art: VeilArtProfile = preload("res://art/default_art.tres")
var env: Environment
var panel_material: StandardMaterial3D
var dust_particles: CPUParticles3D
var sun: DirectionalLight3D
var beacons: Array[MeshInstance3D] = []

func material(color: Color, emission: float = 0.0) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.85
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
	label.pixel_size = 0.008
	label.modulate = color
	label.outline_size = 8
	add_child(label)
	return label

func _ready() -> void:
	var sand := material(art.terrain_color)
	var dark_sand := material(art.distant_terrain_color)
	var pale := material(art.hull_color)
	var trim := material(art.structure_color)
	var glow := material(art.instrument_color, 0.8)
	var gold := material(art.route_color)
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("342f46")
	sky_mat.sky_horizon_color = Color("c58368")
	sky_mat.ground_bottom_color = Color("9c5041")
	sky_mat.ground_horizon_color = Color("c58368")
	sky_mat.sun_angle_max = 5.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b1b7c1")
	env.ambient_light_energy = 0.4
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color("b78673")
	env.fog_density = 0.003
	var atmosphere := WorldEnvironment.new()
	atmosphere.environment = env
	add_child(atmosphere)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-25, -40, 0)
	sun.light_color = Color("ffddb1")
	sun.light_energy = 1.15
	sun.shadow_enabled = art.shadows_enabled
	add_child(sun)
	box(Vector3(180, 1, 180), sand, Vector3(0, -0.5, 0), self, true)
	var landscape_start := get_child_count()
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
	for i in range(65):
		var pos := Vector3(rng.randf_range(-55, 55), 0, rng.randf_range(-55, 55))
		if absf(pos.x) < 25 and absf(pos.z) < 25: continue
		var rock := SphereMesh.new()
		rock.radius = rng.randf_range(0.3, 1.8)
		rock.height = rock.radius * 1.1
		rock.radial_segments = 5
		rock.rings = 3
		shape(rock, dark_sand, pos).rotation.y = rng.randf() * TAU
	apply_art_slot("landscape", art.landscape_scene, Vector3.ZERO, landscape_start)
	# Walking routes: warm guide lamps and a marked central approach.
	for i in range(12):
		for side in [-1, 1]:
			box(Vector3(0.16, 0.04, 0.7), gold, Vector3(side * 2.3, 0.02, 18 - i * 2.5))
	for point in [Vector3(-7, 0, 2), Vector3(7, 0, 2), Vector3(-7, 0, -13), Vector3(7, 0, -13)]:
		cylinder(0.08, 2.5, trim, point + Vector3(0, 1.25, 0))
		var lamp := sphere(0.18, glow, point + Vector3(0, 2.55, 0))
		beacons.append(lamp)
	var habitat_start := get_child_count()
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
	apply_art_slot("habitat", art.habitat_scene, Vector3(0, 2.4, -16), habitat_start)
	var refuge_start := get_child_count()
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
	var solar_array_start := get_child_count()
	# Solar field and tactile inspection point.
	panel_material = material(Color("264960"))
	panel_material.metallic = 0.35
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
	# Control kiosk can be reached on foot, with a duplicate remote inside refuge.
	for point in [POWER_POSITION, SHELTER_POSITION + Vector3(0, 0, -2.7)]:
		box(Vector3(1.2, 1.2, 0.6), trim, point + Vector3(0, 0.6, 0), self, true)
		box(Vector3(1.05, 0.45, 0.05), glow, point + Vector3(0, 1.02, 0.33))
	text3d("POWER CONTROL", POWER_POSITION + Vector3(0, 2.1, 0.4), 32)
	var companion_start := get_child_count()
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
	# Antenna and horizon silhouettes give orientation without a full-screen map.
	cylinder(0.12, 9, trim, Vector3(-7, 4.5, -20))
	var dish := sphere(1.4, pale, Vector3(-7, 9, -20))
	dish.scale.y = 0.22
	dish.rotation.z = 0.5
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

func update_weather(mission: VeilMission) -> void:
	var weather := mission.environment()
	for visual in get_tree().get_nodes_in_group("mission_visual_adapters"):
		visual.apply_mission_visuals(mission.visual_snapshot())
	env.fog_density = 0.003 + weather.storm * 0.025
	sun.light_energy = 1.15 - weather.storm * 1.1
	panel_material.albedo_color = Color("264960").lerp(Color("b67c59"), mission.dust * 0.7)
	panel_material.emission_enabled = mission.cleaning
	panel_material.emission = Color("478c91")
	panel_material.emission_energy_multiplier = 0.35
	dust_particles.emitting = art.dust_particle_count > 0 and weather.storm > 0.3

func apply_art_slot(slot_name: String, replacement: PackedScene, origin: Vector3, start_index: int) -> void:
	var anchor := Marker3D.new()
	anchor.name = slot_name.capitalize().replace(" ", "") + "Anchor"
	anchor.position = origin
	add_child(anchor)
	if replacement == null: return
	# Rendering can change without silently deleting physics or interaction bounds.
	for i in range(start_index, get_child_count() - 1):
		hide_visuals(get_child(i))
	var visual := replacement.instantiate()
	anchor.add_child(visual)
	if visual.has_method("apply_mission_visuals"):
		visual.add_to_group("mission_visual_adapters")

func hide_visuals(node: Node) -> void:
	if node is GeometryInstance3D: node.hide()
	for child in node.get_children(): hide_visuals(child)
