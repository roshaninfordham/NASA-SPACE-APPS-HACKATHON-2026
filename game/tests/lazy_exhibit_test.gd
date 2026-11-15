extends SceneTree
## Optional field notes must demand-load the exterior and restore the window view.
var failures := 0
class EmptyInspection extends Node3D:
	func get_inspection_points() -> Array: return []
func check(ok: bool, label: String) -> void:
	if ok: print("PASS: ", label)
	else:
		push_error(label)
		failures += 1
func frames(count := 8) -> void:
	for i in range(count): await process_frame
func key(code: Key) -> void:
	for down in [true,false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		root.push_input(event)
	await frames()
func activate(button: Button) -> void:
	button.grab_focus()
	await frames()
	await key(KEY_ENTER)
func camera_state(camera: Camera3D) -> Dictionary:
	var result := {}
	for property in ["global_transform", "projection", "fov", "size", "near", "far", "keep_aspect", "h_offset", "v_offset", "frustum_offset"]:
		result[property] = camera.get(property)
	return result
func mission_state(game) -> Dictionary:
	var result := {"mission": {}, "crew": game.rescue.snapshot().duplicate(true), "waypoint": game.rescue.waypoint}
	for property in game.mission.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var value: Variant = game.mission.get(property.name)
			result.mission[property.name] = value.duplicate(true) if value is Dictionary or value is Array else value
	return result
func check_review_framing(game) -> void:
	var camera: Camera3D = game.exhibit.camera
	var anchor: Node3D = game.world.get_node("HabitatAnchor")
	check(camera == game.title_camera and camera.is_current(), "Field Notes borrows the overview camera")
	check(camera.global_position.is_equal_approx(anchor.to_global(Vector3(-6,3.4,26))) and camera.fov == 45, "Optional exhibit uses the established exterior review pose")
	var forward := -camera.global_basis.z
	var to_target := (anchor.to_global(Vector3(0,3,0)) - camera.global_position).normalized()
	check(forward.dot(to_target) > 0.99999, "Review camera faces the actual habitat anchor")
	var visible := 0
	var unobscured := 0
	for point in game.exhibit.points:
		var position: Vector3 = point.position
		var screen: Vector2 = camera.unproject_position(position)
		if not camera.is_position_behind(position) and Rect2(Vector2.ZERO, root.get_visible_rect().size).has_point(screen):
			visible += 1
			if not game.exhibit._card.get_global_rect().has_point(screen): unobscured += 1
	check(visible == game.exhibit.points.size() and visible > 0, "Actual inspection anchors are front-facing and within the review viewport")
	check(unobscured > 0, "At least one actual callout remains clear of the notes card")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1280,720)
	for paused_operator in [false,true]:
		var game = load("res://legacy_mission.tscn").instantiate()
		root.add_child(game)
		current_scene = game
		await frames()
		game.set_process(false)
		check(game.world.is_window_presentation() and not game.world.is_presentation_category_constructed("habitat"), "Fresh window startup does not construct optional habitat exterior")
		check(game.world.get_node("HabitatAnchor").get_child_count() == 0, "Stable habitat anchor starts empty")
		if paused_operator:
			game.begin()
			game.apply_primary_action("shelter")
			game._process(0.25)
			game.toggle_pause()
			await frames()
		var current: Camera3D = root.get_camera_3d()
		var title_before := camera_state(game.title_camera)
		var player_before := camera_state(game.player.camera)
		var state_before := mission_state(game)
		var menu_before: bool = game.menu.visible
		var hud_before: bool = game.hud.visible
		if paused_operator: game.show_habitat_inspector()
		else:
			await activate(game.interface_root.get_node("%More"))
			await activate(game.interface_root.get_node("%HabitatNotes"))
		await frames()
		check(is_instance_valid(game.exhibit), "Field Notes opens from a fresh lazy startup")
		if not is_instance_valid(game.exhibit):
			game.queue_free()
			await frames()
			continue
		check(game.world.is_presentation_category_constructed("habitat") and game.world.get_node("HabitatAnchor").get_child_count() > 0, "Opening notes demand-loads real exterior geometry")
		check(not game.world.is_window_presentation() and not root.disable_3d, "Explicit notes show the outdoor review presentation")
		check_review_framing(game)
		game._process(4)
		await frames()
		check(game.paused and not game.player.enabled and mission_state(game) == state_before, "Review freezes all mission and crew fields")
		# Simulate a future tour camera adjustment: close must restore full state.
		game.exhibit.camera.position += Vector3(1,2,3)
		game.exhibit.camera.fov = 67
		game.exhibit.camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		game.exhibit.camera.size = 8
		game.exhibit.camera.h_offset = 0.3
		await key(KEY_ESCAPE)
		check(not is_instance_valid(game.exhibit) and game.world.is_window_presentation(), "Closing notes restores the window presentation")
		check(root.get_camera_3d() == current and camera_state(game.title_camera) == title_before and camera_state(game.player.camera) == player_before, "Closing notes restores exact camera identity, transforms, projection and lens state")
		check(game.menu.visible == menu_before and game.hud.visible == hud_before and game.paused and not game.player.enabled, "Title or paused operator interface resumes its previous state")
		check(mission_state(game) == state_before, "Demand-load and close leave resources and companion unchanged")
		check(game.world.is_presentation_category_constructed("habitat"), "Loaded exterior is retained for later exhibits")
		# Unsupported artwork must not leave the player in the exterior mode.
		var anchor: Node3D = game.world.get_node("HabitatAnchor")
		var original := anchor.get_child(0)
		anchor.remove_child(original)
		for placeholder in [null, Node3D.new(), EmptyInspection.new()]:
			if placeholder: anchor.add_child(placeholder)
			for prior_mode in [true,false]:
				game.world.set_window_presentation(prior_mode)
				var prior_camera: Camera3D = root.get_camera_3d()
				game.show_habitat_inspector()
				check(not is_instance_valid(game.exhibit) and game.world.is_window_presentation() == prior_mode and root.get_camera_3d() == prior_camera and mission_state(game) == state_before, "Missing, unsupported or empty inspection points restore the previous mode without side effects")
			if placeholder:
				anchor.remove_child(placeholder)
				placeholder.free()
		anchor.add_child(original)
		game.queue_free()
		await frames()
	print("LAZY EXHIBIT FAILURES: ", failures)
	quit(1 if failures else 0)
