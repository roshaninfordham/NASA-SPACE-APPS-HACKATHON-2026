extends SceneTree
## External-project-compatible harness: no production script changes.
## Memory runs NEVER request mesh arrays, MultiMesh transforms, bounds or images.
var folder := ""
var purpose := "memory"
var game
func _initialize() -> void: call_deferred("run")
func frames(count: int = 8) -> void:
	for index in range(count): await process_frame
func save_json(name: String, value: Dictionary) -> void:
	var path := folder.path_join(name + ".json")
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	file.store_string(JSON.stringify(value, "  ") + "\n")
	file.close()
	DirAccess.rename_absolute(path + ".tmp", path)
func checkpoint(name: String, extra: Dictionary = {}) -> void:
	var data := {"phase":name,"tree_nodes":get_node_count(),"objects":Performance.get_monitor(Performance.OBJECT_COUNT),"engine":Engine.get_version_info().string,"display":DisplayServer.get_name(),"viewport":[root.size.x,root.size.y]}
	data.merge(extra)
	save_json("checkpoint_" + name, data)
	# Parent samples /proc while no resource inventory or image readback occurs.
	var deadline := Time.get_ticks_msec() + 30000
	while not FileAccess.file_exists(folder.path_join("ack_" + name)):
		if Time.get_ticks_msec() > deadline:
			push_error("Parent did not acknowledge RSS checkpoint")
			quit(1)
			return
		await process_frame
func inventory() -> Dictionary:
	var pending: Array[Node] = [game]
	var meshes: Dictionary = {}
	var rows: Array = []
	var count := 0
	var geometry_nodes := 0
	var possible_triangles := 0
	var visible_triangles := 0
	var channels_bytes := 0
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		count += 1
		for child in node.get_children(): pending.append(child)
		var mesh: Mesh
		var instances := 1
		var visible_instances := 1
		if node is MeshInstance3D: mesh = node.mesh
		elif node is MultiMeshInstance3D and node.multimesh:
			mesh = node.multimesh.mesh
			instances = node.multimesh.instance_count
			visible_instances = instances if node.multimesh.visible_instance_count < 0 else node.multimesh.visible_instance_count
		else: continue
		if mesh == null: continue
		geometry_nodes += 1
		var id := mesh.get_instance_id()
		if not meshes.has(id):
			var triangles := 0
			var bytes := 0
			for surface in range(mesh.get_surface_count()):
				var arrays := mesh.surface_get_arrays(surface)
				var vertex_count: int = arrays[Mesh.ARRAY_VERTEX].size()
				var index_count: int = arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX] != null else 0
				var elements := index_count if index_count > 0 else vertex_count
				var primitive: int = mesh.surface_get_primitive_type(surface) if mesh is ArrayMesh else Mesh.PRIMITIVE_TRIANGLES
				if primitive == Mesh.PRIMITIVE_TRIANGLES: triangles += elements / 3
				elif primitive == Mesh.PRIMITIVE_TRIANGLE_STRIP: triangles += maxi(0,elements-2)
				for channel in arrays:
					match typeof(channel):
						TYPE_PACKED_VECTOR3_ARRAY: bytes += channel.size()*12
						TYPE_PACKED_VECTOR2_ARRAY: bytes += channel.size()*8
						TYPE_PACKED_COLOR_ARRAY: bytes += channel.size()*16
						TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_FLOAT32_ARRAY: bytes += channel.size()*4
						TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT64_ARRAY: bytes += channel.size()*8
						TYPE_PACKED_BYTE_ARRAY: bytes += channel.size()
			meshes[id] = {"triangles":triangles,"channel_bytes":bytes}
			channels_bytes += bytes
		var triangles: int = meshes[id].triangles * instances
		possible_triangles += triangles
		if node.is_visible_in_tree(): visible_triangles += meshes[id].triangles * visible_instances
		rows.append({"path":str(game.get_path_to(node)),"instances":instances,"potential_triangles":triangles,"visible":node.is_visible_in_tree()})
	rows.sort_custom(func(a,b):return a.potential_triangles>b.potential_triangles)
	return {"game_nodes":count,"geometry_nodes":geometry_nodes,"unique_meshes":meshes.size(),"unique_mesh_channel_bytes":channels_bytes,"potential_instanced_triangles":possible_triangles,"visible_instanced_triangles":visible_triangles,"largest_geometry":rows.slice(0,20),"scope":"Separate inventory process. Mesh channel payload estimates exclude allocator, textures, materials, driver and MultiMesh instance-buffer overhead. Triangle multiplicity is not rendered work. No MultiMesh transform/bounds readback."}
func capture(name: String) -> void:
	await frames()
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(folder.path_join(name+".png"))
	if error != OK: push_error("Capture failed: "+name)
func run() -> void:
	var args := OS.get_cmdline_user_args()
	for index in range(args.size()-1):
		if args[index]=="--output": folder=args[index+1]
		if args[index]=="--purpose": purpose=args[index+1]
	seed(20261115)
	Engine.time_scale=0.0
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	root.size=Vector2i(1280,720)
	var start := Time.get_ticks_usec()
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	# Suppress only the deferred external update query; the autoload client stays
	# allocated. This avoids network timing/state without changing runtime files.
	game.update_client=null
	game.set_process(false)
	game.player.set_physics_process(false)
	var construction_us := Time.get_ticks_usec()-start
	await frames()
	var ready_us := Time.get_ticks_usec()-start
	if purpose=="memory":
		await checkpoint("window",{"construction_us":construction_us,"ready_us":ready_us})
		var reveal_start:=Time.get_ticks_usec()
		game.world.set_window_presentation(false)
		var reveal_us:=Time.get_ticks_usec()-reveal_start
		await frames()
		await checkpoint("full_world",{"reveal_us":reveal_us})
		game.world.set_window_presentation(true)
		await frames()
		await checkpoint("window_return")
	elif purpose=="inventory":
		var report:Dictionary={"window":inventory()}
		game.world.set_window_presentation(false)
		await frames()
		report.full_world=inventory()
		game.world.set_window_presentation(true)
		await frames()
		report.window_return=inventory()
		save_json("inventory",report)
	elif purpose=="visual":
		game.begin()
		game.set_process(false)
		game.player.set_physics_process(false)
		await capture("window_initial")
		game.world.set_window_presentation(false)
		var camera:=Camera3D.new()
		game.add_child(camera)
		camera.position=Vector3(-6,3.4,10)
		camera.fov=45
		camera.look_at(Vector3(0,3,-16))
		camera.make_current()
		await capture("full_world")
		camera.queue_free()
		game.world.set_window_presentation(true)
		game.player.camera.make_current()
		await capture("window_return")
		game.apply_primary_action("power")
		game.apply_primary_action("shelter")
		var phases:Array=[]
		for index in range(100):
			game._process(0.25)
			if phases.is_empty() or phases[-1].phase!=game.rescue.phase:
				phases.append({"phase":game.rescue.phase,"rescue":game.rescue.snapshot(),"mission":game.mission.summary()})
			if game.rescue.protected():break
		var model_position:Vector3=game.rescue.position
		var visual_position:Vector3=game.world.get_node("CompanionAnchor").position
		save_json("route",{"phases":phases,"protected":game.rescue.protected(),"visual_matches_model":visual_position.distance_to(model_position)<0.00001,"scope":"Regular production controller steps after full-world reveal and return. Fixed time scale freezes ambient animation, not explicit controller steps; no actor position or shelter assignments."})
		if not game.rescue.protected() or visual_position.distance_to(model_position)>0.00001:
			push_error("Route did not preserve protected arrival")
			quit(1)
			return
		# A new title scene exercises Field Notes as the first demand-load entry.
		game.queue_free()
		await frames(2)
		seed(20261115)
		game=load("res://main.tscn").instantiate()
		root.add_child(game)
		game.update_client=null
		game.set_process(false)
		game.player.set_physics_process(false)
		await frames()
		var original_camera:Camera3D=root.get_camera_3d()
		var original_transform:Transform3D=original_camera.global_transform
		var original_fov:float=original_camera.fov
		game.show_habitat_inspector()
		await frames()
		var opened:bool=is_instance_valid(game.exhibit)
		if opened:game.exhibit.close()
		await frames()
		var restored:bool=root.get_camera_3d()==original_camera and original_camera.global_transform.is_equal_approx(original_transform) and is_equal_approx(original_camera.fov,original_fov)
		save_json("field_notes",{"opened":opened,"camera_exactly_restored":restored,"window_restored":game.world.is_window_presentation(),"title_visible":game.menu.visible,"scope":"Field Notes opened from a fresh title scene after other visual evidence; no manual camera restoration."})
		await capture("field_notes_return")
	else:
		push_error("Unknown profile purpose")
		quit(1)
		return
	game.queue_free()
	await frames(2)
	quit()
