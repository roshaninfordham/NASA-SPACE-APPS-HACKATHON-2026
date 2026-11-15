extends SceneTree
## Deferred assets must preserve mode semantics, custom scenes and live science data.
const World = preload("res://scripts/world.gd")
const Mission = preload("res://scripts/mission.gd")
class SnapshotMission:
	extends "res://scripts/mission.gd"
	func visual_snapshot() -> Dictionary:
		var snapshot := super.visual_snapshot()
		snapshot.nested_probe = {"samples": [1, 2, 3]}
		return snapshot
class VisualProbe:
	extends Node3D
	@export var mutates_snapshot := false
	var prepared := false
	var prepared_before_tree := false
	var ready_was_prepared := false
	var initial_window := false
	var latest: Dictionary = {}
	var deliveries := 0
	func prepare_presentation(window_mode: bool, categories: PackedStringArray) -> void:
		prepared = true
		prepared_before_tree = not is_inside_tree()
		initial_window = window_mode
		categories.append("probe-must-not-mutate-profile")
	func _ready() -> void:
		ready_was_prepared = prepared
		add_to_group("mission_visual_adapters")
	func apply_mission_visuals(snapshot: Dictionary) -> void:
		deliveries += 1
		latest = snapshot.duplicate(true)
		if mutates_snapshot:
			snapshot.habitat_kwh = -999.0
			if snapshot.has("nested_probe"): snapshot.nested_probe.samples[0] = -999
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	if value: print("PASS: ", message)
	else:
		push_error(message)
		failures += 1
func settle() -> void:
	await process_frame
	await process_frame
	await physics_frame
func probe_scene(mutates: bool) -> PackedScene:
	var probe := VisualProbe.new()
	probe.mutates_snapshot = mutates
	var packed := PackedScene.new()
	packed.pack(probe)
	probe.free()
	return packed
func nested_probe_scene() -> PackedScene:
	var container := Node3D.new()
	var probe := VisualProbe.new()
	probe.name = "NestedVisualProbe"
	container.add_child(probe)
	probe.owner = container
	var packed := PackedScene.new()
	packed.pack(container)
	container.free()
	return packed
func count_nodes(node: Node) -> int:
	var count := 1
	for child in node.get_children(): count += count_nodes(child)
	return count
func unhide(profile: Resource, category: String) -> void:
	var index: int = profile.window_hidden_categories.find(category)
	if index >= 0: profile.window_hidden_categories.remove_at(index)
func run() -> void:
	var world := World.new()
	world.art = load("res://art/default_art.tres").duplicate(true)
	root.add_child(world)
	await settle()
	check(world.is_window_presentation(), "Default lazy world keeps the released window mode")
	for category in ["habitat", "refuge", "solar_array", "power_control", "route", "rocks"]:
		check(not world.is_presentation_category_constructed(category), "Hidden category has not been constructed: " + category)
	for name in ["HabitatAnchor", "RefugeAnchor", "SolarArrayAnchor"]:
		check(world.get_node(name).get_child_count() == 0, "Stable anchor stays empty until needed: " + name)
	check(world.panel_material == null, "Solar panel material is absent before the array is needed")
	check(world.get_presentation_category_roots("route").is_empty() and world.get_presentation_category_roots("rocks").is_empty(), "Landscape builds neither hidden route nor rock meshes")
	var landscape := world.get_node("LandscapeAnchor").get_child(0)
	var initial_nodes := count_nodes(world)
	unhide(world.art, "rocks")
	world.set_window_presentation(true)
	await settle()
	check(world.is_presentation_category_constructed("rocks") and not world.get_presentation_category_roots("rocks").is_empty(), "Unhiding rocks constructs their independent landscape category")
	check(not world.is_presentation_category_constructed("route") and world.get_presentation_category_roots("route").is_empty(), "Rock clearance does not force route geometry into memory")
	check(landscape._path.size() == 97, "Deferred route still supplies its original clearance samples")
	world.art.window_hidden_categories.append("rocks")
	world.set_window_presentation(true)
	await settle()
	var hidden_rocks := true
	for node: Node3D in world.get_presentation_category_roots("rocks"):
		if node.is_visible_in_tree(): hidden_rocks = false
	check(hidden_rocks, "Newly registered landscape descendants hide again correctly")
	var anchor_id: int = world.get_node("HabitatAnchor").get_instance_id()
	world.set_window_presentation(false)
	await settle()
	check(world.get_node("HabitatAnchor").get_instance_id() == anchor_id and world.get_node("HabitatAnchor").get_child_count() == 1, "First EVA populates the same named habitat anchor")
	var full_nodes := count_nodes(world)
	check(full_nodes > initial_nodes, "Optional EVA geometry is constructed on demand")
	var habitat_id: int = world.get_node("HabitatAnchor").get_child(0).get_instance_id()
	for enabled in [true, false, false, true, false]: world.set_window_presentation(enabled)
	await settle()
	check(count_nodes(world) == full_nodes and world.get_node("HabitatAnchor").get_child(0).get_instance_id() == habitat_id, "Repeated mode switches reuse assets without duplicate nodes")
	check(landscape._path.size() == 97, "Deferred route construction does not duplicate clearance samples")
	world.queue_free()
	await settle()

	var profile = load("res://art/default_art.tres").duplicate(true)
	profile.habitat_scene = probe_scene(true)
	profile.solar_array_scene = probe_scene(false)
	profile.refuge_scene = nested_probe_scene()
	var custom := World.new()
	custom.art = profile
	root.add_child(custom)
	await settle()
	var mission := SnapshotMission.new()
	mission.time = 5.25
	mission.energy = 6.4
	mission.dust = 0.61
	mission.cleaning = true
	var science_before := mission.visual_snapshot().duplicate(true)
	custom.update_weather(mission)
	unhide(profile, "habitat")
	custom.set_window_presentation(true)
	var mutator: Node = custom.get_node("HabitatAnchor").get_child(0)
	check(mutator.prepared_before_tree and mutator.ready_was_prepared and mutator.initial_window, "Custom replacement receives initial presentation before its ready callback")
	check(not "probe-must-not-mutate-profile" in profile.window_hidden_categories, "Prepare hook receives detached category configuration")
	check(mutator.latest.habitat_kwh == 6.4 and mutator.latest.time_hours == 5.25, "Late-built visual immediately receives latest mission values")
	unhide(profile, "solar_array")
	custom.set_window_presentation(true)
	await settle()
	var observer: Node = custom.get_node("SolarArrayAnchor").get_child(0)
	check(observer.latest.habitat_kwh == 6.4 and observer.latest.nested_probe.samples[0] == 1, "Mutating adapter cannot corrupt cached or later-adapter nested snapshots")
	var expected_color := Color("293b53").lerp(Color("b67c59"), 0.61 * 0.7)
	check(custom.panel_material.albedo_color.is_equal_approx(expected_color) and custom.panel_material.emission_enabled, "Late-built solar material uses current dust and cleaning state")
	custom.update_weather(mission)
	check(observer.latest.habitat_kwh == 6.4 and observer.latest.nested_probe.samples[0] == 1, "Every live adapter update receives a detached nested snapshot")
	check(mission.visual_snapshot() == science_before, "Presentation and loading never mutate mission science")
	var deliveries_before: int = observer.deliveries
	unhide(profile, "refuge")
	custom.set_window_presentation(true)
	var nested: Node = custom.get_node("RefugeAnchor").get_child(0).get_node("NestedVisualProbe")
	check(nested.latest.habitat_kwh == 6.4 and nested.latest.nested_probe.samples[0] == 1, "Nested-only custom adapter receives cached snapshot on demand loading")
	check(observer.deliveries == deliveries_before, "Late adapter construction does not redeliver unchanged snapshots to existing adapters")
	var external := VisualProbe.new()
	custom.add_child(external)
	var foreign_root := Node3D.new()
	root.add_child(foreign_root)
	var foreign := VisualProbe.new()
	foreign_root.add_child(foreign)
	custom.update_weather(mission)
	check(external.latest.habitat_kwh == 6.4 and nested.deliveries == 2, "Normal updates discover externally attached and nested group adapters")
	check(foreign.latest.is_empty() and foreign.deliveries == 0, "World updates do not mutate adapters belonging to another world or sibling tree")
	foreign_root.queue_free()
	var hidden_fallback := false
	var fallback_collision := false
	for node in custom.get_presentation_category_roots("solar_array"):
		for mesh in node.find_children("*", "MeshInstance3D", true, false):
			if not mesh.visible: hidden_fallback = true
		for body in node.find_children("*", "CollisionObject3D", true, false):
			if body.collision_layer != 0: fallback_collision = true
	check(hidden_fallback and fallback_collision, "Custom replacement retains hidden fallback meshes and authoritative collider proxies")
	custom.queue_free()
	await settle()

	var fallback := World.new()
	fallback.art = load("res://art/default_art.tres").duplicate(true)
	for slot in ["landscape_scene", "habitat_scene", "refuge_scene", "solar_array_scene", "companion_scene", "interior_scene"]: fallback.art.set(slot, null)
	root.add_child(fallback)
	await settle()
	check(not fallback.is_presentation_category_constructed("habitat") and fallback.get_node("HabitatAnchor").get_child_count() == 0, "Fallback profile also defers hidden infrastructure")
	fallback.set_window_presentation(false)
	await settle()
	check(fallback.get_presentation_category_roots("habitat").size() > 1 and fallback.get_presentation_category_roots("refuge").size() > 1, "Fallback habitat and refuge geometry remain available for EVA")
	check(fallback.beacons.size() == 4 and not fallback.get_presentation_category_roots("rocks").is_empty(), "Fallback approach lights and deterministic rock field are built on demand")
	var fallback_count := count_nodes(fallback)
	fallback.set_window_presentation(true)
	fallback.set_window_presentation(false)
	await settle()
	check(count_nodes(fallback) == fallback_count and fallback.beacons.size() == 4, "Fallback switching builds each category exactly once")
	fallback.queue_free()
	await settle()
	quit(1 if failures else 0)
