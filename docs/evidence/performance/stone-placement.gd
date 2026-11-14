extends SceneTree
func _initialize(): call_deferred("run")
func run():
	var landscape = load("res://art/red_veil/landscape.gd").new()
	root.add_child(landscape)
	await process_frame
	var placements: Array[String] = []
	for child in landscape.get_children():
		if child is MultiMeshInstance3D and child.name.begins_with("Scattered"):
			for index in range(child.multimesh.instance_count):
				placements.append(str(child.multimesh.get_instance_transform(index)))
	placements.sort()
	var result := {"stone_instances": placements.size(), "sorted_transform_sha256": "\n".join(placements).sha256_text()}
	var output := FileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.WRITE)
	output.store_string(JSON.stringify(result, "  ") + "\n")
	print(JSON.stringify(result))
	quit()
