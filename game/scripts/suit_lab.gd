extends Control
## A single live 3D inspection stage with responsive camera controls and teaching tests.
## Caller owns pause/resume; no mission state is changed here.
signal closed
const VisualStyle = preload("res://scripts/visual_style.gd")
const Branding = preload("res://scripts/branding.gd")
const Astronaut = preload("res://art/red_veil/astronaut.gd")
const Experiments = preload("res://scripts/suit_experiments.gd")
var stage: SubViewport
var camera: Camera3D
var explorer: Node3D
var back_button: Button
var view_selector: OptionButton
var theme_selector: OptionButton
var test_selector: OptionButton
var slider: HSlider
var value_label: Label
var result_label: Label
var lesson_label: Label
var question_label: Label
var run_button: Button
var _content_margin: MarginContainer
var _body: BoxContainer
var _viewer: VBoxContainer
var _card_scroll: ScrollContainer
var _viewport_container: SubViewportContainer
var _completed: Dictionary = {}
var _progress: Label
var _closed := false
var _view := 0
var _rotation := 0.0
var _last_render := 0.0
var _scene: Node3D

func _ready() -> void:
	name = "SuitLab"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_style()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var background := ColorRect.new()
	background.color = VisualStyle.color("wine")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	_content_margin = margin
	margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	for edge in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+edge,12)
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation",10)
	margin.add_child(layout)
	var heading := HBoxContainer.new()
	layout.add_child(heading)
	var brand := _label(Branding.display_name()+"\nEXPLORER SUIT LAB",20)
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(brand)
	back_button = _button("Back",close)
	back_button.name = "Back"
	heading.add_child(back_button)
	_body = BoxContainer.new()
	_body.add_theme_constant_override("separation",14)
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(_body)
	_viewer = VBoxContainer.new()
	_viewer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_viewer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_viewer.size_flags_stretch_ratio = 1.5
	_body.add_child(_viewer)
	_viewport_container = SubViewportContainer.new()
	_viewport_container.stretch = true
	_viewport_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_viewport_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_viewport_container.custom_minimum_size = Vector2(160,180)
	_viewer.add_child(_viewport_container)
	stage = SubViewport.new()
	stage.name = "InspectionStage"
	stage.own_world_3d = true
	stage.transparent_bg = false
	stage.render_target_update_mode = SubViewport.UPDATE_ONCE
	stage.msaa_3d = Viewport.MSAA_2X
	_viewport_container.add_child(stage)
	_make_stage()
	var selectors := HBoxContainer.new()
	_viewer.add_child(selectors)
	view_selector = _option(["Front", "Back", "Helmet", "Obi / crane", "Boots"],selectors)
	view_selector.name = "View"
	view_selector.item_selected.connect(set_view)
	theme_selector = _option(["Original", "Cyan Pulse", "Midnight Wine", "Gold Crane"],selectors)
	theme_selector.name = "Theme"
	theme_selector.item_selected.connect(func(index: int): explorer.apply_theme(index))
	var rotation := HSlider.new()
	rotation.name = "Rotate"
	rotation.min_value = -180
	rotation.max_value = 180
	rotation.step = 1
	rotation.custom_minimum_size.y = 44
	rotation.tooltip_text = "Rotate the explorer"
	rotation.accessibility_name = "Rotate the explorer"
	rotation.value_changed.connect(func(degrees: float): _rotation = deg_to_rad(degrees); explorer.rotation.y = _rotation)
	_viewer.add_child(rotation)
	_card_scroll = ScrollContainer.new()
	_card_scroll.name = "CardScroll"
	_card_scroll.follow_focus = true
	_card_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_card_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_card_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(_card_scroll)
	var card := VBoxContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_constant_override("separation",12)
	_card_scroll.add_child(card)
	card.add_child(_label("MIRA · CREW EXPLORER",22))
	card.add_child(_label("Inspect the bubble helmet, kimono-inspired wrap, obi harness, crane and seigaiha wave details. Colours and embroidery are cosmetic.",16))
	test_selector = _option(["Radiation", "Dust cleaning", "Thermal balance", "Life support", "Pressure fit"],card)
	test_selector.name = "Experiment"
	test_selector.item_selected.connect(select_experiment)
	question_label = _label("",18)
	card.add_child(question_label)
	value_label = _label("",18)
	card.add_child(value_label)
	slider = HSlider.new()
	slider.name = "ExperimentSetting"
	slider.custom_minimum_size.y = 44
	slider.step = 1
	slider.value_changed.connect(_setting_changed)
	card.add_child(slider)
	run_button = _button("Run experiment",run_experiment)
	run_button.name = "RunExperiment"
	card.add_child(run_button)
	result_label = _label("",21)
	result_label.add_theme_color_override("font_color",VisualStyle.color("cyan"))
	card.add_child(result_label)
	lesson_label = _label("",16)
	card.add_child(lesson_label)
	_progress = _label("Experiments explored: 0 / 5",16)
	card.add_child(_progress)
	card.add_child(_label("Practice models · Change one setting, run again, and compare. These lab values do not alter the rescue mission or certify a real spacesuit.",14))
	select_experiment(0)
	set_view(0)
	resized.connect(func(): _responsive.call_deferred())
	get_window().size_changed.connect(func(): _responsive.call_deferred())
	_responsive.call_deferred()
	back_button.grab_focus()

func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.set_meta("base_font", font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",VisualStyle.color("white"))
	return label

func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 44
	button.pressed.connect(callback)
	return button

func _option(items: Array, parent: Node) -> OptionButton:
	var option := OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option.custom_minimum_size.y = 44
	option.fit_to_longest_item = false
	for item in items: option.add_item(item)
	parent.add_child(option)
	return option

func _make_stage() -> void:
	_scene = Node3D.new()
	stage.add_child(_scene)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("462a3d")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("ebc5da")
	environment.environment.ambient_light_energy = 0.65
	_scene.add_child(environment)
	for index in range(3):
		var light := DirectionalLight3D.new()
		light.light_color = [Color("ffe5e0"),Color("ff4a6a"),Color("4ed8e8")][index]
		light.light_energy = [1.7,0.8,0.6][index]
		light.rotation_degrees = [Vector3(-35,-25,0),Vector3(-15,160,0),Vector3(-30,90,0)][index]
		_scene.add_child(light)
	explorer = Astronaut.new()
	explorer.idle_amount = 0.25
	_scene.add_child(explorer)
	camera = Camera3D.new()
	camera.fov = 35
	_scene.add_child(camera)
	camera.current = true
	var floor_visual := MeshInstance3D.new()
	var floor_mesh := CylinderMesh.new()
	floor_mesh.top_radius = 1.1
	floor_mesh.bottom_radius = 1.15
	floor_mesh.height = 0.06
	floor_visual.mesh = floor_mesh
	floor_visual.position.y = -0.04
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("cba9bd")
	mat.metallic = 0.45
	mat.roughness = 0.23
	floor_visual.material_override = mat
	_scene.add_child(floor_visual)
	for height in [0.0,2.05,2.3]:
		var halo := MeshInstance3D.new()
		var ring := TorusMesh.new()
		ring.inner_radius = 1.10
		ring.outer_radius = 1.12
		ring.rings = 48
		ring.ring_segments = 5
		halo.mesh = ring
		halo.position.y = height
		var glow := StandardMaterial3D.new()
		glow.albedo_color = Color("f7839c")
		glow.emission_enabled = true
		glow.emission = Color("f7839c")
		glow.emission_energy_multiplier = 1.2
		halo.material_override = glow
		_scene.add_child(halo)

func set_view(index: int) -> void:
	_view = clampi(index,0,4)
	var positions := [Vector3(0.28,1.12,3.35),Vector3(-0.25,1.12,-3.35),Vector3(0.60,1.50,0.90),Vector3(-0.38,0.94,-0.85),Vector3(0.35,0.28,0.85)]
	var targets := [Vector3(0,0.83,0),Vector3(0,0.83,0),Vector3(0,1.40,0),Vector3(0.04,0.78,-0.14),Vector3(0,0.16,0.04)]
	camera.position = positions[_view]
	camera.look_at(targets[_view])
	stage.render_target_update_mode = SubViewport.UPDATE_ONCE

func select_experiment(index: int) -> void:
	index = clampi(index,0,4)
	test_selector.select(index)
	question_label.text = Experiments.QUESTIONS[index]
	var limits: Array = Experiments.RANGES[index]
	slider.min_value = limits[0]
	slider.max_value = limits[1]
	slider.value = limits[2]
	slider.accessibility_name = Experiments.UNITS[index]
	_setting_changed(slider.value)

func _setting_changed(value: float) -> void:
	value_label.text = "%d %s" % [value,Experiments.UNITS[test_selector.selected]]
	result_label.text = "Predict what will happen, then run."
	lesson_label.text = ""

func run_experiment() -> void:
	var result := Experiments.evaluate(test_selector.selected,slider.value)
	result_label.text = result.result
	lesson_label.text = result.why
	_completed[test_selector.selected] = true
	_progress.text = "Experiments explored: %d / 5" % _completed.size()
	if result.success: lesson_label.text += "\nGood choice for this practice challenge."

func _responsive() -> void:
	if not is_instance_valid(_body): return
	var ui_scale := maxf(1.0, size.x / maxf(1.0,get_window().size.x))
	_content_margin.scale = Vector2.ONE
	_content_margin.size = size
	for edge in ["left","right","top","bottom"]: _content_margin.add_theme_constant_override("margin_"+edge,roundi(12*ui_scale))
	for node in _content_margin.find_children("*","Control",true,false):
		if node is Label: node.add_theme_font_size_override("font_size",roundi(float(node.get_meta("base_font",16))*ui_scale))
		elif node is BaseButton:
			node.add_theme_font_size_override("font_size",roundi(16*ui_scale))
			node.custom_minimum_size.y = 44*ui_scale
		elif node is HSlider: node.custom_minimum_size.y = 44*ui_scale
	_body.add_theme_constant_override("separation",roundi(14*ui_scale))
	_viewport_container.stretch_shrink = maxi(1,roundi(ui_scale))
	var physical_size := size/ui_scale
	var narrow := physical_size.x < 700
	_body.vertical = narrow
	_viewer.custom_minimum_size = Vector2.ZERO
	_viewer.size_flags_vertical = Control.SIZE_SHRINK_BEGIN if narrow else Control.SIZE_EXPAND_FILL
	_viewport_container.custom_minimum_size.y = (minf(240,physical_size.y*0.27) if narrow else 150)*ui_scale
	_card_scroll.custom_minimum_size.x = 0 if narrow else 260*ui_scale

func _process(delta: float) -> void:
	# One stage, capped 24Hz updates; no six-camera rendering tax on small devices.
	_last_render += delta
	if _last_render >= 1.0/24.0:
		_last_render = 0
		stage.render_target_update_mode = SubViewport.UPDATE_ONCE

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close()

func close() -> void:
	if _closed: return
	_closed = true
	closed.emit()
	queue_free()

func _apply_style() -> void:
	theme = Theme.new()
	for kind in ["Button", "OptionButton"]:
		for state in ["normal", "hover", "pressed", "focus"]:
			var panel := StyleBoxFlat.new()
			panel.bg_color = Color("422a3b") if state == "normal" else Color("60384c")
			panel.border_color = Color("a86a80") if state == "normal" else Color("79dce6")
			panel.set_border_width_all(1 if state != "focus" else 2)
			panel.set_corner_radius_all(7)
			panel.content_margin_left = 12
			panel.content_margin_right = 12
			theme.set_stylebox(state,kind,panel)
		theme.set_color("font_color",kind,VisualStyle.color("white"))
