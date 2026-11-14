extends SceneTree
const World = preload("res://scripts/world.gd")
const Art = preload("res://scripts/art_profile.gd")
const Mission = preload("res://scripts/mission.gd")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var replacement := Node3D.new()
	replacement.name = "DesignerArray"
	var packed := PackedScene.new()
	assert(packed.pack(replacement) == OK)
	replacement.free()
	var profile := Art.new()
	profile.solar_array_scene = packed
	var world := World.new()
	world.art = profile
	root.add_child(world)
	world.set_window_presentation(false) # Assert the optional outdoor replacement slot.
	await process_frame
	assert(world.get_node_or_null("SolarArrayAnchor/DesignerArray") != null)
	var mission := Mission.new()
	var before := mission.summary()
	world.update_weather(mission)
	var snapshot := mission.visual_snapshot()
	snapshot.habitat_kwh = 0
	assert(mission.summary() == before)
	print("PASS: scene slot replacement and detached visual state preserve mission rules")
	world.queue_free()
	await process_frame
	quit()
