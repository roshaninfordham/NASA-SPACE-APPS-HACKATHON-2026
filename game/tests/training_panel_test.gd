extends SceneTree
const SolarPanel = preload("res://art/red_veil/training_panel.gd")
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
	check(not panel.is_processing(),"Array never advances work through a visual clock")
	var original := {"cleaning":true,"sections_cleaned":1,"section_progress":0.5,"max_sections":4}
	var snapshot := original.duplicate(true)
	panel.refresh(snapshot)
	check(is_equal_approx(panel.clean_fraction,0.375),"Dust follows completed plus partial-section work continuously")
	check(snapshot == original,"Visual component does not mutate the model snapshot")
	check(is_equal_approx(float(panel._surface.get_shader_parameter("clean_fraction")),0.375),"Opaque surface receives the actual model progress")
	panel.refresh({"cleaning_progress":0.617,"cleaning":true})
	check(is_equal_approx(panel.clean_fraction,0.617),"Explicit cleaning-speed progress takes precedence without rounding to sections")
	panel.refresh({"cleaned_work":1.7,"max_sections":4,"sections_cleaned":1,"section_progress":0.7,"cleaning":true})
	check(is_equal_approx(panel.clean_fraction,0.425),"Current continuous work field controls the visible cleaned area")
	panel.refresh({"cleaned_work":1.7,"max_sections":4,"cleaning":false,"phase":"airlock"})
	check(is_equal_approx(panel.clean_fraction,0.425) and not panel.cleaning,"Recall preserves the partly cleaned surface instead of restoring dust")
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
