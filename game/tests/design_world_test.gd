extends SceneTree
## Design integration: real capsule clearance, connected walking routes, and UI flow.
## Run only after the intended habitat/interior/HUD are assigned in the default scene.
const GRID_STEP := 0.5
const MIN_X := -44 # World x = -22 m.
const MAX_X := 44
const MIN_Z := -48 # World z = -24 m.
const MAX_Z := 36
const START := Vector2i(0, 28) # Outdoors at (0, 14).
const DESTINATIONS := {
	"mission control": Vector2i(-6, -22), # (-3, -11)
	"shielded refuge": Vector2i(-28, -14), # (-14, -7)
	"solar inspection": Vector2i(32, -11), # (16, -5.5)
}
const DIRECTIONS := [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]
var failures := 0

func check(condition: bool, message: String) -> void:
	if condition: print("PASS: ", message)
	else:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func point(cell: Vector2i) -> Vector3:
	# 1.7 m capsule, center y=.9: its bottom clears the flat ground by .05 m.
	return Vector3(cell.x * GRID_STEP, 0.9, cell.y * GRID_STEP)

func inside(cell: Vector2i) -> bool:
	return cell.x >= MIN_X and cell.x <= MAX_X and cell.y >= MIN_Z and cell.y <= MAX_Z

func clearance(space: PhysicsDirectSpaceState3D, query: PhysicsShapeQueryParameters3D, cell: Vector2i) -> bool:
	query.transform = Transform3D(Basis.IDENTITY, point(cell))
	query.motion = Vector3.ZERO
	return space.intersect_shape(query, 1).is_empty()

func clear_edge(space: PhysicsDirectSpaceState3D, query: PhysicsShapeQueryParameters3D, from: Vector2i, to: Vector2i) -> bool:
	query.transform = Transform3D(Basis.IDENTITY, point(from))
	query.motion = point(to) - point(from)
	var fraction := space.cast_motion(query)
	return fraction.size() == 2 and fraction[0] >= 0.9999

func obstacle_names(space: PhysicsDirectSpaceState3D, query: PhysicsShapeQueryParameters3D, cell: Vector2i) -> String:
	query.transform = Transform3D(Basis.IDENTITY, point(cell))
	query.motion = Vector3.ZERO
	var names: Array[String] = []
	for collision in space.intersect_shape(query, 8):
		var collider: Object = collision.collider
		names.append(str(collider.get_path()) if collider is Node else str(collider))
	return ", ".join(names) if not names.is_empty() else "target itself is clear"

func navigation(game: Node3D) -> void:
	var space := game.get_world_3d().direct_space_state
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.7
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.margin = 0.001
	query.collision_mask = game.player.collision_mask
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var excluded: Array[RID] = [game.player.get_rid()]
	query.exclude = excluded
	var blocked: Dictionary = {}
	for x in range(MIN_X, MAX_X + 1):
		for z in range(MIN_Z, MAX_Z + 1):
			var cell := Vector2i(x, z)
			if not clearance(space, query, cell): blocked[cell] = true
	var sample_count := (MAX_X - MIN_X + 1) * (MAX_Z - MIN_Z + 1)
	check(not blocked.is_empty() and blocked.size() < sample_count, "Physics scan detects real outpost obstacles and clear walking space")
	check(not blocked.has(START), "Outdoor starting position fits the walking capsule")
	if blocked.has(START):
		print("NAV_BLOCKED start: ", obstacle_names(space, query, START))
		return
	var queue: Array[Vector2i] = [START]
	var visited: Dictionary = {START: START}
	var cursor := 0
	while cursor < queue.size():
		var current: Vector2i = queue[cursor]
		cursor += 1
		for direction in DIRECTIONS:
			var next: Vector2i = current + direction
			if not inside(next) or blocked.has(next) or visited.has(next): continue
			# Sweeps prevent a thin wall or corner between grid samples from being skipped.
			if not clear_edge(space, query, current, next): continue
			visited[next] = current
			queue.append(next)
	for name in DESTINATIONS:
		var target: Vector2i = DESTINATIONS[name]
		check(visited.has(target), "Continuous capsule route from outdoors reaches " + str(name))
		if visited.has(target):
			var steps := 0
			var cell := target
			while cell != START:
				cell = visited[cell]
				steps += 1
			print("NAV_ROUTE ", name, " distance_m=", steps * GRID_STEP)
		else:
			var nearest := START
			for cell in visited:
				if Vector2(cell).distance_squared_to(Vector2(target)) < Vector2(nearest).distance_squared_to(Vector2(target)): nearest = cell
			print("NAV_BLOCKED ", name, " target=", point(target), " nearest_reachable=", point(nearest), " blockers=", obstacle_names(space, query, target))

func interface_root(game: Node3D) -> Control:
	for layer in game.get_children():
		if not layer is CanvasLayer: continue
		for child in layer.get_children():
			if child is Control and child.get_node_or_null("%HUD") == game.hud: return child
	return null

func run() -> void:
	root.size = Vector2i(1280, 720)
	var game = load("res://main.tscn").instantiate()
	var configured: bool = game.art != null and game.art.habitat_scene != null and game.art.interior_scene != null and game.hud_scene != null
	check(configured, "Default game binds the designed habitat, interior, and HUD instead of the fallback blockout")
	if not configured:
		game.free()
		quit(1)
		return
	root.add_child(game)
	game.set_process(false)
	game.player.set_physics_process(false)
	await physics_frame
	await physics_frame
	await process_frame
	var interior := game.world.get_node_or_null("InteriorAnchor") as Node3D
	var interior_loaded := interior != null and not interior.find_children("*", "GeometryInstance3D", true, false).is_empty() and not interior.find_children("*", "CollisionShape3D", true, false).is_empty()
	check(interior_loaded, "Bound interior actually instantiates visual geometry and collision shapes")
	if interior_loaded: navigation(game)
	var ui := interface_root(game)
	check(ui != null, "The live design HUD exposes its unique-node binding root")
	if ui != null:
		var required := {"HUD": "Control", "Menu": "Control", "Objective": "Label", "Metrics": "Label", "Radio": "Label", "Prompt": "Label", "Clock": "Label", "Visor": "ColorRect", "Begin": "Button", "Guide": "Button", "Sound": "Button", "Explore": "Button", "Academy": "Button", "Updates": "Button"}
		var missing: Array[String] = []
		for name in required:
			var control := ui.get_node_or_null("%" + str(name))
			if control == null or not control.is_class(required[name]): missing.append("%" + str(name) + " (" + required[name] + ")")
		check(missing.is_empty(), "Design HUD preserves required controls and labels: " + ("all present" if missing.is_empty() else ", ".join(missing)))
		var explore := ui.get_node_or_null("%Explore") as Button
		if explore and missing.is_empty():
			explore.pressed.emit()
			check(game.exploring and game.running and game.player.enabled, "Explore button starts untimed first-person control")
			var before_time: float = game.mission.time
			var before_energy: float = game.mission.energy
			var before_suit: float = game.mission.suit_energy
			var before_dose: float = game.mission.dose
			game.player.position = Vector3(16, 0.2, -5.5)
			game.mission.cleaning = true
			game.mission.visor_cleaning = true
			game.touch_interact = true
			for i in range(480): game._process(0.25)
			game.touch_interact = false
			check(game.mission.time == before_time and game.mission.energy == before_energy and game.mission.suit_energy == before_suit and game.mission.dose == before_dose, "Two minutes of Explore with equipment active consume no mission time, batteries, or dose budget")
			check(not game.ended, "Untimed exploration does not trigger a mission debrief")
			await process_frame
			var bounds := Rect2(Vector2.ZERO, Vector2(root.size)).grow(1.0)
			var meters: Rect2 = game.metrics.get_global_rect()
			check(game.metrics.is_visible_in_tree() and meters.has_area() and bounds.encloses(meters), "Live habitat/suit/dose metrics stay visible inside the viewport")
	game.action_audio.stop()
	game.player.footsteps.stop()
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
