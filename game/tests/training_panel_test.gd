extends SceneTree
const SolarPanel = preload("res://art/red_veil/training_panel.gd")
const Model = preload("res://scripts/pace_mission.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if ok: print("PASS: ",message)
	else: failures += 1; push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var panel := SolarPanel.new()
	root.add_child(panel)
	await process_frame
	check(panel.get_child_count() < 24 and panel.get_node("TiltedArray").get_child_count() < 12,"Array uses a bounded geometry budget")
	var meshes := panel.find_children("*", "MeshInstance3D", true, false)
	var triangles := 0
	var in_bounds := true
	for instance: MeshInstance3D in meshes:
		var relative: Transform3D = panel.global_transform.affine_inverse()*instance.global_transform
		var bounds: AABB = relative*instance.get_aabb()
		in_bounds = in_bounds and bounds.position.x >= -1.233 and bounds.end.x <= 1.233 and bounds.position.y >= -0.001 and bounds.end.y <= 1.70 and bounds.position.z >= -0.81 and bounds.end.z <= 0.81
		for surface in range(instance.mesh.get_surface_count()):
			var arrays := instance.mesh.surface_get_arrays(surface)
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			triangles += (indices.size() if not indices.is_empty() else vertices.size())/3
	check(meshes.size() <= 28 and triangles <= 2000,"Refined array remains within 28 draw instances and 2000 triangles")
	check(in_bounds,"Refined trim and supports remain inside the original work-view footprint")
	var surface_node: MeshInstance3D = panel.get_node("TiltedArray/DustAndCells")
	check(is_equal_approx(panel._deck.position.y,1.08) and is_equal_approx(panel._deck.rotation.x,deg_to_rad(-35.0)) and is_equal_approx(surface_node.position.y,0.04),"The fixed brush contact plane and working angle remain unchanged")
	check(not panel.is_processing(),"Array never advances work through a visual clock")
	var original := {"cleaning":true,"sections_cleaned":1,"section_progress":0.5,"max_sections":4}
	var snapshot := original.duplicate(true)
	panel.refresh(snapshot)
	check(is_equal_approx(panel.clean_fraction,0.375),"Dust follows completed plus partial-section work continuously")
	check(float(panel._surface.get_shader_parameter("work_feedback")) == 0.0, "Loading a partly cleaned panel does not invent a work animation")
	check(snapshot == original,"Visual component does not mutate the model snapshot")
	check(is_equal_approx(float(panel._surface.get_shader_parameter("clean_fraction")),0.375),"Opaque surface receives the actual model progress")
	panel.refresh({"cleaning_progress":0.617,"cleaning":true})
	check(is_equal_approx(panel.clean_fraction,0.617),"Explicit cleaning-speed progress takes precedence without rounding to sections")
	check(float(panel._surface.get_shader_parameter("work_feedback")) == 1.0, "Genuine new work enables the modest clearing-edge feedback")
	panel.refresh({"cleaned_work":1.7,"max_sections":4,"sections_cleaned":1,"section_progress":0.7,"cleaning":true})
	check(is_equal_approx(panel.clean_fraction,0.425),"Current continuous work field controls the visible cleaned area")
	check(float(panel._surface.get_shader_parameter("work_feedback")) == 0.0, "Resetting progress cannot animate dust removal")
	panel.refresh({"cleaned_work":1.7,"max_sections":4,"cleaning":false,"phase":"airlock"})
	check(is_equal_approx(panel.clean_fraction,0.425) and not panel.cleaning,"Recall preserves the partly cleaned surface instead of restoring dust")
	var model := Model.new()
	panel.refresh(model.snapshot())
	model.advance(2.0)
	var actual := model.snapshot()
	panel.refresh(actual)
	check(panel.clean_fraction > 0.02 and is_equal_approx(panel.clean_fraction, actual.clean_fraction), "Within two normal play seconds, visible clearing follows actual model work")
	check(float(panel._surface.get_shader_parameter("work_feedback")) == 1.0, "The real two-second cleaning gain gets immediate visible feedback")
	panel.set_reduced_motion(true)
	check(float(panel._surface.get_shader_parameter("work_feedback")) == 0.0 and is_equal_approx(panel.clean_fraction, actual.clean_fraction), "Reduced motion removes decorative feedback but keeps truthful dust progress")
	model.advance(1.0)
	panel.refresh(model.snapshot())
	check(panel.clean_fraction > float(actual.clean_fraction) and float(panel._surface.get_shader_parameter("work_feedback")) == 0.0, "Accessible static presentation still displays ongoing cleaning")
	panel.set_reduced_motion(false)
	panel.refresh(model.snapshot())
	check(float(panel._surface.get_shader_parameter("work_feedback")) == 0.0, "A held or paused model snapshot cannot continue the work effect")
	panel.refresh({"clean_fraction":1.0, "cleaning":true})
	check(float(panel._surface.get_shader_parameter("work_feedback")) == 0.0, "A completely clean panel produces no more dust flecks")
	panel.refresh({"clean_fraction":4.0})
	check(panel.clean_fraction == 1.0,"Out-of-range visual progress is bounded")
	panel.refresh({"cleaning_progress":NAN})
	check(panel.clean_fraction == 0.0,"Invalid numeric input cannot reach the shader")
	var count := panel.get_child_count()
	for index in range(100): panel.refresh({"cleaning_progress":float(index)/100.0})
	check(panel.get_child_count() == count,"Refreshing never adds geometry or particle nodes")
	panel.queue_free()
	await process_frame
	print("TRAINING PANEL FAILURES: ",failures)
	quit(1 if failures else 0)
