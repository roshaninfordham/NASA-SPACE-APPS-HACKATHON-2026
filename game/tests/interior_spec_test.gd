extends SceneTree
## Observable presentation contract for the control-room reference integration.
const Interior = preload("res://art/red_veil/interior.gd")
const Branding = preload("res://scripts/branding.gd")
var failures := 0
func check(value: bool, message: String) -> void:
	if value: print("PASS: ", message)
	else:
		push_error(message)
		failures += 1
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var room := Interior.new()
	root.add_child(room)
	await process_frame
	var hero_panels := room.find_children("HeroPanel_*", "Node3D", true, false)
	var tablets := room.find_children("ConsoleTablet_*", "Node3D", true, false)
	check(hero_panels.size() == 4 and tablets.size() == 9, "Four hero panels and nine tabletop screens exist after static batching")
	var brand_found := false
	var obsolete_found := false
	for node in room.find_children("*", "Label3D", true, false):
		if node.text == Branding.title(): brand_found = true
		if "RED VEIL" in node.text.to_upper(): obsolete_found = true
	check(not obsolete_found, "Current interior labels contain no obsolete product name")
	check(brand_found, "Drum sign uses the shared product title")
	room.apply_mission_visuals({"solar_kw": 3.2, "habitat_kwh": 6.4, "suit_kwh": 0.5, "dose_msv": 0.72, "panel_dust": 0.42, "time_hours": 5.0, "event_active": true, "sheltered": true, "conserving": true})
	check("3.2 kW" in room._power_label.text and "6.4 kWh" in room._power_label.text, "Power panel uses live energy snapshot")
	check("42%" in room._dust_label.text and "05.0 h" in room._dust_label.text, "Mission panel uses live elapsed time and panel dust")
	check("0.72 mSv" in room._crew_label.text and "REFUGE ACTIVE" in room._crew_label.text, "Life-support panel uses actual crew dose and refuge state")
	check("EVENT ACTIVE" in room._forecast_label.text and "18%" not in room._forecast_label.text, "Forecast reflects the scenario event without invented probability")
	check(room._tablet_labels[0].text == "3.2 kW" and room._tablet_labels[8].text == "SAVE", "Console tablets update from the same mission snapshot")
	room.apply_mission_visuals({"time_hours": 8.0})
	check("EVENT PASSED" in room._forecast_label.text, "Event presentation progresses after its scenario window")
	var network := room._mars.get_node_or_null("GeodesicHologram/GeodesicNodes") as MultiMeshInstance3D
	check(network != null and network.multimesh.instance_count == 162, "Triangular globe network retains its instanced animated nodes after batching")
	var angle: float = room._mars.rotation.y
	room._process(1.0)
	check(is_equal_approx(room._mars.rotation.y - angle, deg_to_rad(2.0)), "Globe rotates at the specified two degrees per second")
	room.queue_free()
	await process_frame
	quit(1 if failures else 0)
