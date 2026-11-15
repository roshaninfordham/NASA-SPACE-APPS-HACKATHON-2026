extends SceneTree
## Calm-room contract: an open forward sightline and honest shared live telemetry.
const Interior = preload("res://art/red_veil/interior.gd")
const Branding = preload("res://scripts/branding.gd")
var failures := 0
func check(value: bool, message: String) -> void:
	if value: print("PASS: ", message)
	else:
		push_error(message)
		failures += 1
func _initialize() -> void: call_deferred("run")
func subtree_ids(node: Node) -> Array[int]:
	var ids: Array[int] = [node.get_instance_id()]
	for child in node.get_children(): ids.append_array(subtree_ids(child))
	ids.sort()
	return ids

func lazy_window_construction() -> void:
	var room := Interior.new()
	room.prepare_presentation(true, PackedStringArray(["habitat", "route"]))
	room.set_airlock_phase("complete")
	var before_tree := {"solar_kw": 2.8, "habitat_kwh": 7.4, "suit_kwh": 0.6, "dose_msv": 0.3}
	room.apply_mission_visuals(before_tree)
	before_tree.solar_kw = 999.0
	check(room.get_child_count() == 0, "Pre-tree presentation, airlock and telemetry requests allocate no scene nodes")
	root.add_child(room)
	await process_frame
	check(room.has_node("OperatorWindowRoom") and not room._legacy_built and room.find_children("HeroPanel_*", "Node3D", true, false).is_empty(), "Prepared window startup builds only the required enclosure, with no legacy furniture")
	check(not is_instance_valid(room._mars) and not room._materials.has("leaf") and not room._materials.has("panel"), "Window startup defers legacy globe and legacy-only materials")
	check(not room.is_processing(), "Window-only room has no idle globe animation callback")
	check(room._outer_airlock_door.visible and not room._inner_airlock_door.visible, "Airlock state requested before construction is replayed on the first window")
	var original_window_ids := subtree_ids(room._window_enclosure)
	var original_pane_id := room._window_enclosure.get_node("ClearPanoramicWindow").get_instance_id()
	room.set_window_presentation(false)
	await process_frame
	check("2.8 kW" in room._power_label.text and "7.4 kWh" in room._power_label.text, "First late-built telemetry uses the detached pre-tree snapshot, not mutated caller data or defaults")
	check(subtree_ids(room._window_enclosure) == original_window_ids, "Late EVA batching preserves every already-created window and door node")
	check(room.is_processing() and room._legacy_built, "First EVA activation enables its newly built teaching-model animation")
	room.set_window_presentation(true)
	var later := {"solar_kw": 6.2, "habitat_kwh": 4.1, "suit_kwh": 0.22, "dose_msv": 1.7, "sheltered": true, "time_hours": 8.0}
	room.apply_mission_visuals(later)
	later.habitat_kwh = 999.0
	var complete_ids := subtree_ids(room)
	for i in range(4):
		room.set_window_presentation(true)
		room.set_window_presentation(false)
		room.set_window_presentation(false)
		room.set_window_presentation(true)
	await process_frame
	check(subtree_ids(room) == complete_ids, "Repeated same-mode and alternating switches reuse both branches without allocating or leaking nodes")
	check(room._window_enclosure.get_node("ClearPanoramicWindow").get_instance_id() == original_pane_id and subtree_ids(room._window_enclosure) == original_window_ids, "Window identity remains stable across all legacy switches")
	await physics_frame
	var space := room.get_world_3d().direct_space_state
	check(not space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0,1,8), Vector3(0,1,4))).is_empty(), "Lazily restored glazing keeps its real crossing barrier after EVA batching")
	check(room._outer_airlock_door.get_node("Barrier").collision_layer != 0 and room._inner_airlock_door.get_node("Barrier").collision_layer == 0, "Restored window retains completed-cycle door collision state")
	room.set_window_presentation(false)
	check("6.2 kW" in room._power_label.text and "4.1 kWh" in room._power_label.text and "1.70 mSv" in room._crew_label.text and "EVENT PASSED" in room._forecast_label.text, "Later window-mode snapshots update all telemetry correctly on EVA return")
	room.queue_free()
	await process_frame

func run() -> void:
	var room := Interior.new()
	root.add_child(room)
	await process_frame
	check(not is_instance_valid(room._window_enclosure) and not room.has_node("OperatorWindowRoom"), "Standalone no-hook EVA startup preserves legacy behavior without constructing an unused enclosure")
	var hero_panels := room.find_children("HeroPanel_*", "Node3D", true, false)
	var tablets := room.find_children("ConsoleTablet_*", "Node3D", true, false)
	check(hero_panels.size() == 2 and tablets.is_empty(), "Two focused workstations replace overlapping panels and miniature tablets")
	check(room.has_node("ForwardWindowView"), "Interior exposes a consistent forward dune-view camera anchor")
	check(room.get_node("HeroPanel_energy").position.x < -3.0 and room.get_node("HeroPanel_crew").position.x > 3.0, "Workstations preserve the central view to the forward aperture")
	check(room._materials.pearl.roughness > 0.7 and room._materials.panel.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED, "Matte floor and opaque panels avoid glare and alpha sorting")
	var brand_found := false
	var obsolete_found := false
	for node in room.find_children("*", "Label3D", true, false):
		if node.text == Branding.title(): brand_found = true
		if "RED VEIL" in node.text.to_upper(): obsolete_found = true
	check(not obsolete_found, "Current interior labels contain no obsolete product name")
	check(brand_found, "Room sign uses the shared product title")
	room.apply_mission_visuals({"solar_kw": 3.2, "habitat_kwh": 6.4, "suit_kwh": 0.5, "dose_msv": 0.72, "panel_dust": 0.42, "time_hours": 5.0, "event_active": true, "sheltered": true, "conserving": true})
	check("3.2 kW" in room._power_label.text and "6.4 kWh" in room._power_label.text, "Power panel uses live energy snapshot")
	check("42%" in room._dust_label.text and "05.0 h" in room._dust_label.text, "Mission panel uses live elapsed time and panel dust")
	check("0.72 mSv" in room._crew_label.text and "REFUGE ACTIVE" in room._crew_label.text, "Life-support panel uses actual crew dose and refuge state")
	check("EVENT ACTIVE" in room._forecast_label.text and "18%" not in room._forecast_label.text, "Forecast reflects the scenario event without invented probability")
	check("SAVE" in room._dust_label.text, "Resource panel reflects the shared conservation mode")
	room.apply_mission_visuals({"time_hours": 8.0})
	check("EVENT PASSED" in room._forecast_label.text, "Event presentation progresses after its scenario window")
	check(room._mars.position.y < 1.2 and room._mars.mesh.radius < 0.5, "Low teaching model stays below the eye line")
	check(absf(room._mars.global_position.x) > 6.0, "Teaching plinth stays outside the central dune-view corridor")
	var angle: float = room._mars.rotation.y
	room._process(1.0)
	check(is_equal_approx(room._mars.rotation.y - angle, deg_to_rad(2.0)), "Globe rotates at the specified two degrees per second")
	# The indoor operator scene must be a real enclosure, not an outside view
	# with its old habitat hidden. Verify barriers, the separate entry and restore.
	var legacy_body := room.find_children("*", "StaticBody3D", true, false)[0] as StaticBody3D
	var saved_layer := legacy_body.collision_layer
	room.set_window_presentation(true)
	room.set_window_presentation(true)
	await physics_frame
	check(room._window_enclosure.visible and not room.get_node("HeroPanel_energy").visible, "Window mode hides legacy furniture and reveals the dedicated indoor shell")
	check(legacy_body.collision_layer == 0, "Hidden legacy furniture does not leave invisible obstacles")
	var space := room.get_world_3d().direct_space_state
	var window_ray := PhysicsRayQueryParameters3D.create(Vector3(0, 1, 8), Vector3(0, 1, 4))
	check(not space.intersect_ray(window_ray).is_empty(), "The clear panoramic window has a real crossing barrier")
	var outer_ray := PhysicsRayQueryParameters3D.create(Vector3(-7.15, 1, 7), Vector3(-7.15, 1, 4.6))
	var inner_ray := PhysicsRayQueryParameters3D.create(Vector3(-7.15, 1, 4.6), Vector3(-7.15, 1, 3.0))
	check(not space.intersect_ray(outer_ray).is_empty(), "Idle side-airlock outer door is closed")
	room.set_airlock_phase("approach")
	await physics_frame
	check(space.intersect_ray(outer_ray).is_empty() and not space.intersect_ray(inner_ray).is_empty(), "Crew approach enters through the outer door while the inner door stays closed")
	room.set_airlock_phase("cycling")
	await physics_frame
	check(not space.intersect_ray(outer_ray).is_empty() and not space.intersect_ray(inner_ray).is_empty(), "Both airlock doors remain closed during the timed cycle")
	room.set_airlock_phase("complete")
	await physics_frame
	check(not space.intersect_ray(outer_ray).is_empty() and space.intersect_ray(inner_ray).is_empty(), "Completed cycle opens only the inner path into the room")
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.75
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	var operator_area_clear := true
	for x in [-3.0, 0.0, 3.0]:
		for z in [0.0, 3.4, 4.8]:
			query.transform = Transform3D(Basis.IDENTITY, Vector3(x, 1.1, z))
			if not space.intersect_shape(query, 1).is_empty(): operator_area_clear = false
	check(operator_area_clear, "Near-window operator spawn and world-z[-16,-11.2] bounds fit the actual capsule")
	var window_anchor := room._window_enclosure.get_node("WindowOperatorView") as Marker3D
	check(window_anchor.position == Vector3(0,1.78,3.4) and window_anchor.get_meta("vertical_fov_degrees") == 52.0, "Window camera anchor records approved near-pane eye position and FOV")
	room.set_window_presentation(false)
	room.set_window_presentation(true)
	room.set_window_presentation(false)
	check(legacy_body.collision_layer == saved_layer and room.get_node("HeroPanel_energy").visible, "Rapid mode toggles restore legacy visibility and collision layers")
	check(not room._window_enclosure.visible and room._outer_airlock_door.get_node("Barrier").collision_layer == 0, "Inactive window enclosure leaves no door barriers in EVA mode")
	room.queue_free()
	await process_frame
	await lazy_window_construction()
	quit(1 if failures else 0)
