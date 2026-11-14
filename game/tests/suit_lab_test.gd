extends SceneTree
const Models = preload("res://scripts/suit_experiments.gd")
const Lab = preload("res://scripts/suit_lab.gd")
var failures := 0
func check(value: bool, note: String) -> void:
	if not value:
		push_error(note)
		failures += 1
	else: print("PASS ",note)
func _initialize() -> void: run.call_deferred()
func frames(count: int = 5) -> void:
	for index in range(count): await process_frame
func run() -> void:
	check(Models.evaluate(-1,30) == Models.evaluate(0,30),"Out of range experiment selector clamps consistently")
	check(is_equal_approx(Models.evaluate(0,60).value,1.8),"Radiation unit conversion: 60min at1.8mSv/h gives1.8mSv")
	check(is_equal_approx(Models.evaluate(0,30).value,0.9),"Half exposure time halves dose")
	check(is_equal_approx(Models.evaluate(1,2).value,36),"Dust cleaner removes fraction of remainder, not fixed points")
	check(Models.evaluate(2,60).value == 0,"Balanced heater conserves heat in toy model")
	check(Models.evaluate(2,0).value < 0 and Models.evaluate(2,120).value > 0,"Heat transfer signs show cooling/warming")
	check(Models.evaluate(3,1).value == 120 and Models.evaluate(3,6).value == 20,"Finite supply decreases duration with workload")
	check(Models.evaluate(4,50).success and not Models.evaluate(4,0).success and not Models.evaluate(4,100).success,"Mock fitting requires balanced setting")
	for viewport_size in [Vector2i(1280,720),Vector2i(390,844),Vector2i(844,390)]:
		root.size = viewport_size
		var lab = Lab.new()
		root.add_child(lab)
		await frames(10)
		check(Rect2(Vector2.ZERO,root.get_visible_rect().size).encloses(lab.back_button.get_global_rect()),"Back stays on screen " + str(viewport_size))
		check(lab.back_button.size.y >= 44,"Back touch target at least44px")
		check(lab._card_scroll.size.y >= 100,"Experiment card has scrolling space " + str(viewport_size))
		check(lab.stage.size.x > 100 and lab.stage.size.y > 100,"Live3D stage visible " + str(viewport_size))
		for view in range(5): lab.set_view(view)
		for theme in range(4): lab.explorer.apply_theme(theme)
		check(lab.explorer.get_meta("cosmetic_theme") == 3,"Live material preset changes without rebuilding character")
		for test in range(5):
			lab.select_experiment(test)
			lab.slider.value = [0,5,60,2,50][test]
			lab.run_button.pressed.emit()
			check(not lab.lesson_label.text.is_empty(),"Experiment produces explanation via UI action")
		check(lab._completed.size() == 5,"All five experiments recorded in lab only")
		lab.back_button.pressed.emit()
		await frames()
		check(not is_instance_valid(lab),"Back exits lab")
	print("SUIT LAB FAILURES: ",failures)
	quit(1 if failures else 0)
