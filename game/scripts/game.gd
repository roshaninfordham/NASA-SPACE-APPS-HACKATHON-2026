extends Node3D
const Branding = preload("res://scripts/branding.gd")
const Player = preload("res://scripts/player.gd")
const World = preload("res://scripts/world.gd")
const Mission = preload("res://scripts/mission.gd")
const Learning = preload("res://scripts/learning.gd")
const Academy = preload("res://scripts/academy.gd")
const HabitatInspector = preload("res://scripts/habitat_inspector.gd")
var exhibit: Control
const UpdateClient = preload("res://updater/client.gd")
const UpdatePanel = preload("res://updater/panel.gd")
var update_client
var update_panel
var update_notice: PanelContainer
var update_notice_label: Label
var dismissed_update_version := ""
var update_recovery_notice := ""
var recovery_notice_dismissed := false
var learning: VeilLearning
var academy: VeilAcademy
@export var art: VeilArtProfile = preload("res://art/default_art.tres")
@export var interface_theme: Theme
@export var hud_scene: PackedScene
var mission: VeilMission
var player: VeilPlayer
var world: VeilWorld
var running := false
var exploring := false
var title_camera: Camera3D
var paused := true
var ended := false
var accumulator := 0.0
var last_radio := ""
var nearby := ""
var touch_interact := false
var hud: Control
var menu: Control
var overlay: ColorRect
var objective: Label
var metrics: Label
var radio: Label
var prompt: Label
var clock: Label
var visor: ColorRect
var finish_panel: Control
var action_audio: AudioStreamPlayer
var touch_controls: Control
var sound_on := true
var tick := 0.0
var mission_events: Array[Dictionary] = []

func _ready() -> void:
	DisplayServer.window_set_title(Branding.display_name())
	Engine.max_fps = art.maximum_fps
	setup_inputs()
	learning = Learning.new()
	sound_on = not AudioServer.is_bus_mute(0)
	mission = Mission.new()
	world = World.new()
	world.art = art
	add_child(world)
	player = Player.new()
	player.art = art
	player.position = Vector3(0, 0.2, 14)
	add_child(player)
	if art.interior_scene:
		title_camera = Camera3D.new()
		title_camera.position = Vector3(-6, 3.4, 10)
		title_camera.fov = 45
		add_child(title_camera)
		title_camera.look_at(Vector3(0, 3, -16))
		title_camera.current = true
		player.hide()
	action_audio = AudioStreamPlayer.new()
	action_audio.stream = load("res://assets/audio/coin.ogg")
	action_audio.volume_db = -18
	add_child(action_audio)
	create_interface()
	world.update_weather(mission)
	setup_updates()
	get_tree().auto_accept_quit = true
	await get_tree().process_frame
	await get_tree().process_frame
	var bootstrap := get_node_or_null("/root/Updates")
	if bootstrap:
		bootstrap.mark_healthy()
		update_recovery_notice = bootstrap.startup_notice
		refresh_update_notice()
	if "--smoke-test" in OS.get_cmdline_user_args():
		begin()
		await get_tree().process_frame
		print("RED_VEIL_SCENE_READY version=", update_client.current_version if is_instance_valid(update_client) else "unknown", " nodes=", get_tree().get_node_count(), " HUD=", hud.size, " meters=", metrics.get_parent().global_position)
		get_tree().quit()
		return
	if DisplayServer.get_name() != "headless" and is_instance_valid(update_client):
		update_client.check_for_updates.call_deferred(false)

func setup_inputs() -> void:
	var keys := {"forward": KEY_W, "back": KEY_S, "left": KEY_A, "right": KEY_D, "interact": KEY_E, "visor": KEY_Q, "jump": KEY_SPACE, "pause": KEY_ESCAPE, "guide": KEY_F1, "plan": KEY_P}
	for action in keys:
		if not InputMap.has_action(action): InputMap.add_action(action)
		var key := InputEventKey.new()
		key.physical_keycode = keys[action]
		if not InputMap.action_has_event(action, key): InputMap.action_add_event(action, key)
	for mapping in [["forward", JOY_AXIS_LEFT_Y, -1.0], ["back", JOY_AXIS_LEFT_Y, 1.0], ["left", JOY_AXIS_LEFT_X, -1.0], ["right", JOY_AXIS_LEFT_X, 1.0]]:
		var axis := InputEventJoypadMotion.new()
		axis.axis = mapping[1]
		axis.axis_value = mapping[2]
		if not InputMap.action_has_event(mapping[0], axis): InputMap.action_add_event(mapping[0], axis)
	for mapping in [["jump", JOY_BUTTON_A], ["interact", JOY_BUTTON_X], ["visor", JOY_BUTTON_Y], ["pause", JOY_BUTTON_START]]:
		var button := InputEventJoypadButton.new()
		button.button_index = mapping[1]
		if not InputMap.action_has_event(mapping[0], button): InputMap.action_add_event(mapping[0], button)

func text(parent: Control, value: String, pos: Vector2, size: int = 20, color: Color = Color("eee4ce"), width: float = 500) -> Label:
	var label := Label.new()
	label.text = value
	label.position = pos
	label.size.x = width
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", art.interface_text if color == Color("eee4ce") else color)
	if art.interface_font: label.add_theme_font_override("font", art.interface_font)
	label.add_theme_color_override("font_shadow_color", Color(0.04, 0.06, 0.08, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func button(parent: Control, value: String, pos: Vector2, width: float, callback: Callable) -> Button:
	var result := Button.new()
	result.text = value
	result.position = pos
	result.size = Vector2(width, 52)
	result.add_theme_font_size_override("font_size", 19)
	var normal := StyleBoxFlat.new()
	normal.bg_color = art.interface_accent
	normal.set_corner_radius_all(6)
	normal.content_margin_left = 20
	normal.content_margin_right = 20
	result.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = art.interface_accent.lightened(0.12)
	result.add_theme_stylebox_override("hover", hover)
	result.add_theme_color_override("font_color", art.interface_button_text)
	result.add_theme_color_override("font_hover_color", art.interface_button_text)
	result.pressed.connect(callback)
	parent.add_child(result)
	return result

func panel(parent: Control, pos: Vector2, size: Vector2, color: Color) -> Panel:
	var node := Panel.new()
	node.position = pos
	node.size = size
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(8)
	node.add_theme_stylebox_override("panel", style)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

func create_interface() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	if hud_scene:
		bind_custom_interface(canvas)
		return
	var root := Control.new()
	if interface_theme: root.theme = interface_theme
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(root)
	visor = ColorRect.new()
	visor.color = Color(0.55, 0.3, 0.12, 0.04)
	visor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(visor)
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud)
	panel(hud, Vector2(24, 24), Vector2(440, 122), Color(0.04, 0.09, 0.12, 0.70))
	text(hud, Branding.title() + "    /    ELYSIUM OUTPOST", Vector2(42, 36), 15, Color("e3bd83"))
	objective = text(hud, "Walk to the solar array", Vector2(42, 66), 23)
	clock = text(hud, "SOL 018  •  00:00 / 12:00", Vector2(42, 109), 14, Color("bdcfcc"))
	var meters := panel(hud, Vector2(-340, 24), Vector2(316, 124), Color(0.04, 0.09, 0.12, 0.70))
	meters.set_anchors_preset(Control.PRESET_TOP_RIGHT, true)
	metrics = text(meters, "", Vector2(18, 12), 18, Color("d8e4d5"), 285)
	var reticle := text(hud, "+", Vector2(-8, -16), 24, Color(1, 1, 1, 0.7), 20)
	reticle.set_anchors_preset(Control.PRESET_CENTER, true)
	var radio_panel := panel(hud, Vector2(24, -115), Vector2(800, 90), Color(0.04, 0.09, 0.12, 0.78))
	radio_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT, true)
	text(radio_panel, "MIRA  /  CREW RADIO", Vector2(18, 10), 12, Color("91d6c3"))
	radio = text(radio_panel, "", Vector2(18, 30), 19, Color("e8e5d4"), 765)
	radio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt = text(hud, "", Vector2(-340, 115), 20, Color("ffdf9e"), 680)
	prompt.set_anchors_preset(Control.PRESET_CENTER, true)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var help := text(hud, "WASD move  •  Mouse look  •  E use  •  Q visor  •  Esc pause", Vector2(-445, -24), 12, Color("ddd8cd"), 440)
	help.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT, true)
	menu = Control.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(menu)
	overlay = ColorRect.new()
	overlay.color = Color(0.025, 0.04, 0.06, 0.55)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(overlay)
	text(menu, "YOUR FIRST MISSION ON MARS", Vector2(72, 110), 17, Color("e5bd82"))
	var title := text(menu, Branding.title(), Vector2(65, 150), 72)
	if art.title_font: title.add_theme_font_override("font", art.title_font)
	text(menu, Branding.subtitle(), Vector2(72, 246), 20, art.instrument_color)
	text(menu, "Be the astronaut.\nFind your way through the storm.", Vector2(72, 280), 30)
	text(menu, "Your crewmate Mira needs you at the solar array.\nExplore the outpost, protect your suit, and keep\nenough energy to bring everyone home.", Vector2(74, 375), 20)
	button(menu, "BEGIN YOUR MISSION", Vector2(72, 490), 330, begin)
	button(menu, "FIELD GUIDE", Vector2(420, 490), 190, show_guide)
	button(menu, "SOUND: ON" if sound_on else "SOUND: OFF", Vector2(72, 555), 200, toggle_sound)
	button(menu, "MIRA’S FIELD ACADEMY", Vector2(290, 555), 320, show_academy)
	button(menu, "UPDATES", Vector2(630, 555), 190, show_updates)
	text(menu, "4 MINUTES  /  AGES 7–12  /  KEYBOARD · CONTROLLER · TOUCH", Vector2(74, 635), 13, Color("d4cab7"))
	text(menu, "Educational prototype • Fictional limits • Local practice only • No accounts", Vector2(74, 665), 12, Color("c4bdad"))
	hud.hide()
	create_touch_controls(root)

func create_touch_controls(root: Control) -> void:
	touch_controls = Control.new()
	touch_controls.name = "TouchControls"
	touch_controls.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	touch_controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(touch_controls)
	var controls: Array[Button] = []
	for spec in [["↑", Vector2(0, -1)], ["↓", Vector2(0, 1)], ["←", Vector2(-1, 0)], ["→", Vector2(1, 0)]]:
		var b := button(touch_controls, spec[0], Vector2.ZERO, 48, func(): pass)
		b.button_down.connect(func(): player.touch_move = spec[1])
		b.button_up.connect(func(): player.touch_move = Vector2.ZERO)
		controls.append(b)
	var use_button := button(touch_controls, "USE", Vector2.ZERO, 98, func(): interact())
	use_button.button_down.connect(func(): touch_interact = true)
	use_button.button_up.connect(func(): touch_interact = false)
	controls.append(use_button)
	controls.append(button(touch_controls, "VISOR", Vector2.ZERO, 98, toggle_visor))
	controls.append(button(touch_controls, "PAUSE", Vector2.ZERO, 98, toggle_pause))
	var radio_panel := radio.get_parent() as Control
	if radio_panel is BoxContainer: radio_panel = radio_panel.get_parent() as Control
	var initial_radio_rect := radio_panel.get_rect()
	var arrange := func():
		if not is_instance_valid(touch_controls) or not touch_controls.visible: return
		var bounds := touch_controls.size
		var scale_factor := maxf(1.0, bounds.x / maxf(1.0, get_window().size.x))
		var inset := Vector2(16, 16) * scale_factor
		var top := bounds.y - inset.y - 152.0 * scale_factor
		var positions := [Vector2(52, 0), Vector2(52, 104), Vector2(0, 52), Vector2(104, 52)]
		for index in range(controls.size()):
			var control := controls[index]
			control.add_theme_font_size_override("font_size", roundi(16.0 * scale_factor))
			for state in ["font_focus_color", "font_pressed_color"]: control.add_theme_color_override(state, art.interface_button_text)
			control.custom_minimum_size = Vector2(48, 48) * scale_factor
			control.size = Vector2(48 if index < 4 else 98, 48) * scale_factor
			control.position = Vector2(inset.x, top) + positions[index] * scale_factor if index < 4 else Vector2(bounds.x - inset.x - 98.0 * scale_factor, top + (index - 4) * 52.0 * scale_factor)
		# Reserve a real touch band. Radio stays readable above it in portrait,
		# or between the left/right controls in landscape, never under buttons.
		var portrait := bounds.y > bounds.x
		var radio_x := inset.x if portrait else 184.0 * scale_factor
		var radio_width := bounds.x - inset.x * 2 if portrait else bounds.x - 314.0 * scale_factor
		radio_panel.size.x = maxf(100.0 * scale_factor, radio_width)
		var radio_height := maxf(86.0 * scale_factor, radio_panel.get_combined_minimum_size().y)
		radio_panel.size.y = radio_height
		radio_panel.position = Vector2(radio_x, top - 12.0 * scale_factor - radio_height if portrait else bounds.y - inset.y - radio_height)
	touch_controls.resized.connect(func(): arrange.call_deferred())
	radio_panel.minimum_size_changed.connect(func(): arrange.call_deferred())
	touch_controls.visibility_changed.connect(func():
		if touch_controls.visible:
			arrange.call_deferred()
		else:
			player.touch_move = Vector2.ZERO
			touch_interact = false
			if root.has_method("_schedule_layout"): root.call("_schedule_layout")
			else:
				radio_panel.position = initial_radio_rect.position
				radio_panel.size = initial_radio_rect.size
	)
	touch_controls.visible = false

func show_academy() -> void:
	if is_instance_valid(academy) or is_instance_valid(update_panel) or is_instance_valid(exhibit): return
	var should_resume := running and not ended and not paused
	paused = true
	player.enabled = false
	touch_controls.hide()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	academy = Academy.new()
	academy.learning = learning
	academy.art = art
	academy.interface_theme = interface_theme
	if ended: academy.suggested_index = learning.mission_recommendation(mission.status)
	academy.closed.connect(func():
		if should_resume: resume()
	)
	add_child(academy)
	refresh_update_notice()
	academy.closed.connect(func():
		academy = null
		refresh_update_notice()
	)

func begin() -> void:
	if is_instance_valid(update_panel) or is_instance_valid(academy) or is_instance_valid(exhibit): return
	if ended: get_tree().reload_current_scene(); return
	menu.hide()
	player.show()
	player.camera.current = true
	hud.show()
	running = true
	paused = false
	player.enabled = true
	touch_controls.visible = DisplayServer.is_touchscreen_available()
	refresh_update_notice()
	if not DisplayServer.is_touchscreen_available(): Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	say("Follow the lights to the solar array on your right. I’ll stay on the radio.")

func explore_habitat() -> void:
	if is_instance_valid(update_panel) or is_instance_valid(academy) or is_instance_valid(exhibit): return
	begin()
	exploring = true
	player.position = Vector3(-3, 0.2, -11)
	player.rotation.y = -0.54
	player.head.rotation.x = 0.08
	say("Welcome to mission control. Explore freely; the mission clock is stopped. Press E at the consoles to try the power controls.")
	update_hud()

func toggle_sound() -> void:
	sound_on = not sound_on
	AudioServer.set_bus_mute(0, not sound_on)
	for child in menu.find_children("*", "Button", true, false):
		if child is Button and child.text.begins_with("SOUND:"): child.text = "SOUND: ON" if sound_on else "SOUND: OFF"

func say(message: String) -> void:
	if message == last_radio: return
	last_radio = message
	radio.text = message
	mission_events.append({"hours": mission.time, "message": message})

func toggle_pause() -> void:
	if not running or ended or is_instance_valid(academy) or is_instance_valid(update_panel) or is_instance_valid(exhibit): return
	paused = not paused
	player.enabled = not paused
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED
	if paused:
		show_modal("TAKE A BREATH", "Your mission is paused. Nothing uses energy while you think.\n\nWASD / left stick: walk    Mouse / right stick: look\nE / X: use equipment    Q / Y: clean visor\nSpace / A: a small Mars hop", "BACK TO MARS", resume, "EXPLORER SUIT LAB", func():
			if is_instance_valid(finish_panel):
				finish_panel.queue_free()
				finish_panel = null
			# Opening from pause returns to that paused state on close.
			show_suit_lab()
		, "COMPARE MISSION PLANS", show_planner)
	else: resume()

func resume() -> void:
	if is_instance_valid(finish_panel): finish_panel.queue_free()
	paused = false
	player.enabled = true
	touch_controls.visible = DisplayServer.is_touchscreen_available()
	if not DisplayServer.is_touchscreen_available(): Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func show_modal(title: String, body: String, action: String, callback: Callable, secondary_action: String = "", secondary_callback: Callable = Callable(), tertiary_action: String = "", tertiary_callback: Callable = Callable()) -> void:
	if is_instance_valid(finish_panel): finish_panel.queue_free()
	touch_controls.hide()
	finish_panel = ColorRect.new()
	finish_panel.name = "MissionDialog"
	finish_panel.color = Color(0.025, 0.02, 0.035, 0.72)
	finish_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	finish_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	menu.get_parent().add_child(finish_panel)
	var dialog := PanelContainer.new()
	dialog.name = "DialogShell"
	var style := StyleBoxFlat.new()
	style.bg_color = art.structure_color.darkened(0.45)
	style.border_color = Color(art.instrument_color, 0.55)
	style.set_border_width_all(1)
	style.set_corner_radius_all(16)
	dialog.add_theme_stylebox_override("panel", style)
	finish_panel.add_child(dialog)
	var column := VBoxContainer.new()
	dialog.add_child(column)
	var heading := Label.new()
	heading.name = "Heading"
	heading.text = title
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.add_theme_color_override("font_color", art.interface_text)
	if art.interface_font: heading.add_theme_font_override("font", art.interface_font)
	column.add_child(heading)
	var scroll := ScrollContainer.new()
	scroll.name = "BodyScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	scroll.get_v_scroll_bar().focus_mode = Control.FOCUS_ALL
	column.add_child(scroll)
	var description := Label.new()
	description.name = "Description"
	description.text = body
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	description.add_theme_color_override("font_color", art.interface_text)
	if art.interface_font: description.add_theme_font_override("font", art.interface_font)
	scroll.add_child(description)
	var actions := VBoxContainer.new()
	actions.name = "Actions"
	column.add_child(actions)
	var primary := button(actions, action, Vector2.ZERO, 0, callback)
	primary.name = "Primary"
	primary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var buttons: Array[Button] = [primary]
	if not secondary_action.is_empty() and secondary_callback.is_valid():
		var secondary := button(actions, secondary_action, Vector2.ZERO, 0, secondary_callback)
		secondary.name = "Secondary"
		secondary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		buttons.append(secondary)
	if not tertiary_action.is_empty() and tertiary_callback.is_valid():
		var tertiary := button(actions, tertiary_action, Vector2.ZERO, 0, tertiary_callback)
		tertiary.name = "Tertiary"
		tertiary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		buttons.append(tertiary)
	var backdrop := finish_panel
	var arrange := func():
		if not is_instance_valid(backdrop): return
		var bounds := backdrop.size
		var scale_factor := maxf(1.0, bounds.x / maxf(1.0, get_window().size.x))
		var compact := get_window().size.y < 520
		var margin := 16.0 * scale_factor
		var dialog_size := Vector2(minf(780.0 * scale_factor, bounds.x - margin * 2), minf(600.0 * scale_factor, bounds.y - margin * 2))
		for side in ["left", "top", "right", "bottom"]: style.set("content_margin_" + side, 20.0 * scale_factor)
		style.set_corner_radius_all(roundi(16.0 * scale_factor))
		column.add_theme_constant_override("separation", roundi(12.0 * scale_factor))
		actions.add_theme_constant_override("separation", roundi(8.0 * scale_factor))
		heading.add_theme_font_size_override("font_size", roundi((24.0 if compact else 30.0) * scale_factor))
		description.add_theme_font_size_override("font_size", roundi(18.0 * scale_factor))
		scroll.custom_minimum_size.y = 50.0 * scale_factor
		for control in buttons:
			control.add_theme_font_size_override("font_size", roundi(17.0 * scale_factor))
			for state in ["font_focus_color", "font_pressed_color"]: control.add_theme_color_override(state, art.interface_button_text)
			control.custom_minimum_size.y = 48.0 * scale_factor
		dialog.size = dialog_size
		dialog.position = (bounds - dialog.size) * 0.5
		var focus_order: Array[Control] = []
		if scroll.get_v_scroll_bar().visible: focus_order.append(scroll.get_v_scroll_bar())
		for control in buttons: focus_order.append(control)
		for index in range(focus_order.size()):
			var control := focus_order[index]
			control.focus_next = control.get_path_to(focus_order[(index + 1) % focus_order.size()])
			control.focus_previous = control.get_path_to(focus_order[(index - 1 + focus_order.size()) % focus_order.size()])
	backdrop.resized.connect(func(): arrange.call_deferred())
	dialog.minimum_size_changed.connect(func(): arrange.call_deferred())
	arrange.call_deferred()
	primary.grab_focus.call_deferred()

func show_guide() -> void:
	if is_instance_valid(academy) or is_instance_valid(update_panel) or is_instance_valid(exhibit): return
	var was_running := running
	paused = true
	player.enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	show_modal("YOUR MARS FIELD GUIDE", "ENERGY: Sunlight makes power. The battery stores what is left.\nDUST: Cleaning removes surface dust, never dust in the sky.\nVISOR: Clear sight helps inspection. It uses your suit battery.\nSHELTER: Installed shielding lowers exposure without power.\n\nNASA Curiosity reference: 0.67 mSv/day (2012–2013).\nLoads, storm timing and dose limits are fictional teaching values.\nThis is not certified astronaut training.\n\nSources and asset credits are included with every download.", "BACK TO THE MISSION" if was_running else "BACK", func():
		if is_instance_valid(finish_panel): finish_panel.queue_free()
		if was_running: resume()
	)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"): toggle_pause()
	if event.is_action_pressed("guide"): show_guide()
	if event.is_action_pressed("plan"): show_planner()
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_I and exploring: show_habitat_inspector()
	if not running or paused or ended: return
	if event.is_action_pressed("interact"): interact()
	if event.is_action_pressed("visor"): toggle_visor()

func interact() -> void:
	if not running or paused or ended: return
	if nearby == "power" or nearby == "control":
		mission.conserving = not mission.conserving
		say("Essentials stay on. Extra experiments are paused." if mission.conserving else "Experiments are running again. Watch the battery.")
		play_action()
	elif nearby == "array" and mission.inspection >= 1.0:
		mission.cleaning = not mission.cleaning
		say("Panel cleaning is on. It uses habitat power, not your suit battery." if mission.cleaning else "Panel cleaning is off. We are saving that power.")
		play_action()
	elif nearby == "remote":
		mission.cleaning = not mission.cleaning
		say("Remote panel cleaning is on." if mission.cleaning else "Remote panel cleaning is off. The sky still needs to clear.")
		play_action()

func toggle_visor() -> void:
	if not running or paused or ended or mission.shelter: return
	mission.visor_cleaning = not mission.visor_cleaning
	say("Visor cleaner on. Clear sight helps you inspect. It uses your suit battery." if mission.visor_cleaning else "Visor cleaner off. Keep an eye on your view.")

func _process(delta: float) -> void:
	if not running or paused or ended: return
	tick += delta
	var pos := player.global_position
	var was_sheltered := mission.shelter
	mission.shelter = absf(pos.x - World.SHELTER_POSITION.x) < 3.3 and absf(pos.z - World.SHELTER_POSITION.z) < 3.5
	if mission.shelter and not was_sheltered:
		mission.visor_cleaning = false
		say("You made it inside. This material shields us. No power switch needed.")
	nearby = ""
	if pos.distance_to(World.ARRAY_POSITION + Vector3(0, 0, 2.3)) < 4.5: nearby = "array"
	if pos.distance_to(World.POWER_POSITION) < 3.2: nearby = "power"
	if art.interior_scene and pos.distance_to(Vector3(0, 0, -12)) < 5.5: nearby = "control"
	if mission.shelter and pos.distance_to(World.SHELTER_POSITION + Vector3(0, 0, -2.7)) < 3: nearby = "remote"
	var inspecting := nearby == "array" and mission.inspection < 1.0 and (Input.is_action_pressed("interact") or touch_interact)
	var old_inspection := mission.inspection
	if not exploring: accumulator += minf(delta, 0.25) * Mission.HOURS_PER_SECOND
	while accumulator >= Mission.STEP_HOURS and mission.status == "running":
		mission.step(Mission.STEP_HOURS, inspecting)
		accumulator -= Mission.STEP_HOURS
	if old_inspection < 1 and mission.inspection >= 1:
		play_action()
		say("Inspection complete! Full array capacity restored. E now switches panel cleaning.")
	if mission.time > 3.2 and mission.time < 3.3: say("Particle warning! Follow the REFUGE sign on the left. Walk inside before the event.")
	if mission.time > 4.6 and mission.time < 4.7: say("Dust is blocking the sky. Cleaning cannot bring sunlight through the atmosphere.")
	if mission.time > 7.1 and mission.time < 7.2: say("The particle event has passed. The sky will brighten. Plan our recovery.")
	if mission.time > 9.2 and mission.time < 9.3: say("Sunlight is returning. Dirty panels may be worth cleaning now.")
	if mission.suit_energy < 0.16 and not mission.shelter: say("Your suit battery is low. Return to the refuge while you still have power.")
	if tick > 0.1:
		world.update_weather(mission)
		update_hud()
		tick = 0
	if mission.status != "running": finish()

func update_hud() -> void:
	var env := mission.environment()
	metrics.text = "HABITAT  %.1f / 12 kWh\nSUIT          %.2f / 0.90 kWh\nDOSE       %.2f / 4 mSv*" % [mission.energy, mission.suit_energy, mission.dose]
	clock.text = "SOL 018  •  %02d:%02d / 12:00  •  %s" % [int(mission.time), int(fmod(mission.time * 60, 60)), "SHELTERED" if mission.shelter else "OUTSIDE"]
	visor.color.a = mission.visor_dust * 0.22 if not mission.shelter else 0.0
	if mission.inspection < 1: objective.text = "Inspect the solar array  %d%%" % int(mission.inspection * 100)
	elif mission.time < 3.2: objective.text = "Visit the power control kiosk"
	elif env.event or mission.time < 4: objective.text = "Reach the shielded refuge"
	elif mission.time < 8: objective.text = "Protect the recovery reserve"
	else: objective.text = "Recover the outpost"
	prompt.text = ""
	if nearby == "array": prompt.text = "HOLD E / X  •  Inspect array  %d%%" % int(mission.inspection * 100) if mission.inspection < 1 else "E / X  •  Panel cleaning: " + ("ON" if mission.cleaning else "OFF")
	if nearby == "power": prompt.text = "E / X  •  Save power: " + ("ON" if mission.conserving else "OFF")
	if nearby == "remote": prompt.text = "E / X  •  Remote panel cleaning: " + ("ON" if mission.cleaning else "OFF")
	if nearby == "control": prompt.text = "E / X  •  Mission control — save power: " + ("ON" if mission.conserving else "OFF")
	if exploring:
		objective.text = "Explore the habitat · I for field notes"
		clock.text = "MISSION CLOCK STOPPED  •  ESC TO PAUSE"
	if mission.visor_cleaning: prompt.text += "\nVISOR CLEANING  •  Q / Y to stop"

func finish() -> void:
	ended = true
	player.enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	touch_controls.hide()
	var baseline := Mission.fixed_baseline()
	var title := "YOU BROUGHT US HOME" if mission.status == "success" else "EVERY EXPLORER LEARNS"
	var reason := "Crew protected. Recovery energy preserved. Your decisions made the difference."
	if mission.status == "dose-abort": reason = "Mission paused for crew safety. Next time, reach the refuge before the particle event."
	if mission.status == "power-abort": reason = "The habitat battery ran out. Save power early and clean when sunlight is available."
	if mission.status == "suit-abort": reason = "Your suit battery ran low. Visor cleaning shares that battery with life support."
	if mission.status == "partial": reason = "You reached the end, but the outpost needs more energy to recover."
	var body := "%s\n\nBattery left: %.1f kWh   •   Crew dose: %.2f mSv\nInspection: %d%%   •   Time survived: %.1f hours\n\nWHAT IF EVERYTHING STAYED ON?\nA fixed sheltered, cleaning-on, normal-power strategy\nended after %.1f hours: %s. Same weather, no inspection.\n\nWhat did you change when the sky became dark?" % [reason, mission.energy, mission.dose, int(mission.inspection * 100), mission.time, baseline.time_hours, baseline.status]
	show_modal(title, body, "TRY ANOTHER PLAN", func(): get_tree().reload_current_scene(), "PRACTISE WITH MIRA", show_academy)
	refresh_update_notice()
	var report := {"version": update_client.current_version if is_instance_valid(update_client) else ProjectSettings.get_setting("application/config/version", "development"), "model": "red-veil-first-person", "result": mission.summary(), "baseline": baseline, "events": mission_events}
	var file := FileAccess.open("user://last-mission.json", FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(report, "  "))

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and running and not paused and not ended: toggle_pause()

func _exit_tree() -> void:
	if is_instance_valid(action_audio): action_audio.stop()

func play_action() -> void:
	if not action_audio.playing: action_audio.play()

func bind_custom_interface(canvas: CanvasLayer) -> void:
	# A design-owned HUD can replace the fallback without altering the mission loop.
	var root := hud_scene.instantiate() as Control
	assert(root != null, "Custom HUD root must be Control")
	canvas.add_child(root)
	hud = root.get_node("%HUD")
	menu = root.get_node("%Menu")
	objective = root.get_node("%Objective")
	metrics = root.get_node("%Metrics")
	radio = root.get_node("%Radio")
	prompt = root.get_node("%Prompt")
	clock = root.get_node("%Clock")
	visor = root.get_node("%Visor")
	root.get_node("%Begin").pressed.connect(begin)
	var explore_button := root.get_node_or_null("%Explore")
	if explore_button: explore_button.pressed.connect(explore_habitat)
	root.get_node("%Guide").pressed.connect(show_guide)
	root.get_node("%Sound").pressed.connect(toggle_sound)
	root.get_node("%Sound").text = "SOUND: ON" if sound_on else "SOUND: OFF"
	var academy_button := root.get_node_or_null("%Academy")
	if academy_button: academy_button.pressed.connect(show_academy)
	var suit_button := root.get_node_or_null("%SuitLab")
	if suit_button: suit_button.pressed.connect(show_suit_lab)
	var habitat_button := root.get_node_or_null("%HabitatNotes")
	if habitat_button: habitat_button.pressed.connect(show_habitat_inspector)
	var updates_button := root.get_node_or_null("%Updates")
	if updates_button: updates_button.pressed.connect(show_updates)
	hud.hide()
	menu.show()
	create_touch_controls(root)

func setup_updates() -> void:
	var bootstrap := get_node_or_null("/root/Updates")
	if bootstrap == null: return
	update_recovery_notice = bootstrap.startup_notice
	update_client = bootstrap.get_node_or_null("Client")
	if update_client == null:
		update_client = UpdateClient.new()
		update_client.name = "Client"
		update_client.configure(bootstrap.store, bootstrap.running_version, bootstrap.store.root_dir.path_join("incoming"))
		bootstrap.add_child(update_client)
	update_client.changed.connect(refresh_update_notice)
	update_notice = PanelContainer.new()
	update_notice.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	update_notice.position = Vector2(-420, 24)
	update_notice.custom_minimum_size = Vector2(396, 140)
	var style := StyleBoxFlat.new()
	style.bg_color = art.structure_color.darkened(0.4)
	style.border_color = art.interface_accent
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	for side in ["left", "top", "right", "bottom"]: style.set("content_margin_" + side, 14)
	update_notice.add_theme_stylebox_override("panel", style)
	menu.get_parent().add_child(update_notice)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	update_notice.add_child(column)
	update_notice_label = Label.new()
	update_notice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	update_notice_label.add_theme_font_size_override("font_size", 18)
	update_notice_label.add_theme_color_override("font_color", art.interface_text)
	if art.interface_font: update_notice_label.add_theme_font_override("font", art.interface_font)
	column.add_child(update_notice_label)
	var row := HBoxContainer.new()
	column.add_child(row)
	var review := Button.new()
	review.text = "VIEW UPDATE"
	review.custom_minimum_size = Vector2(180, 44)
	review.pressed.connect(show_updates)
	row.add_child(review)
	var later := Button.new()
	later.text = "LATER"
	later.custom_minimum_size = Vector2(160, 44)
	later.pressed.connect(func():
		dismissed_update_version = update_client.available_version
		recovery_notice_dismissed = true
		refresh_update_notice()
	)
	row.add_child(later)
	refresh_update_notice()

func refresh_update_notice() -> void:
	if not is_instance_valid(update_notice) or not is_instance_valid(update_client): return
	var available: String = update_client.available_version
	update_notice_label.text = "%s %s IS AVAILABLE" % [Branding.display_name(), available]
	if update_client.ready_to_restart: update_notice_label.text = "YOUR UPDATE IS READY TO RESTART"
	var show_recovery := not update_recovery_notice.is_empty() and not recovery_notice_dismissed
	if show_recovery: update_notice_label.text = update_recovery_notice
	var show_available := not available.is_empty() and available != dismissed_update_version
	update_notice.visible = (show_available or show_recovery) and (not running or ended) and not is_instance_valid(academy) and not is_instance_valid(update_panel) and not is_instance_valid(exhibit)

func show_updates() -> void:
	# Installation is offered between missions, never over an active mission.
	if running and not ended: return
	if is_instance_valid(exhibit) or is_instance_valid(academy): return
	if OS.has_feature("web") and JavaScriptBridge.eval("Boolean(window.RedVeilWebUpdates)"):
		JavaScriptBridge.eval("window.RedVeilWebUpdates.open()")
		return
	if not is_instance_valid(update_client) or is_instance_valid(update_panel) or is_instance_valid(academy) or is_instance_valid(exhibit): return
	player.enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	update_panel = UpdatePanel.new()
	update_panel.client = update_client
	update_panel.art = art
	update_panel.interface_theme = interface_theme
	update_panel.closed.connect(func():
		update_panel = null
		refresh_update_notice()
	)
	add_child(update_panel)
	refresh_update_notice()

func show_suit_lab() -> void:
	if is_instance_valid(exhibit) or is_instance_valid(academy) or is_instance_valid(update_panel): return
	var scene_script = load("res://scripts/suit_lab.gd")
	if scene_script == null: return
	_open_exhibit(scene_script.new(), false)

func show_habitat_inspector() -> void:
	if is_instance_valid(exhibit) or is_instance_valid(academy) or is_instance_valid(update_panel): return
	var anchor := world.get_node_or_null("HabitatAnchor")
	if anchor == null or anchor.get_child_count() == 0: return
	var habitat := anchor.get_child(0)
	if not habitat.has_method("get_inspection_points"): return
	var inspector := HabitatInspector.new()
	inspector.points = habitat.get_inspection_points()
	inspector.camera = title_camera
	_open_exhibit(inspector, true)

func _open_exhibit(view: Control, overview: bool) -> void:
	var was_paused := paused
	var was_menu := menu.visible
	var was_hud := hud.visible
	var previous_camera := get_viewport().get_camera_3d()
	var focused := get_viewport().gui_get_focus_owner()
	var previous_focus: WeakRef = weakref(focused) if focused else null
	paused = true
	player.enabled = false
	player.touch_move = Vector2.ZERO
	touch_interact = false
	touch_controls.hide()
	menu.hide()
	hud.hide()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if overview and is_instance_valid(title_camera): title_camera.make_current()
	exhibit = view
	# Opaque exhibits own their presentation. Skip the fully obscured world.
	var host_viewport := get_viewport()
	var previous_3d_disabled := host_viewport.disable_3d
	if not overview:
		host_viewport.disable_3d = true
		view.tree_exiting.connect(func(): host_viewport.disable_3d = previous_3d_disabled)
	view.closed.connect(func():
		exhibit = null
		menu.visible = was_menu
		hud.visible = was_hud
		if is_instance_valid(previous_camera): previous_camera.make_current()
		if running and not ended:
			if not was_paused: resume()
			else:
				paused = false
				toggle_pause()
		if previous_focus != null and is_instance_valid(previous_focus.get_ref()): previous_focus.get_ref().grab_focus.call_deferred()
		refresh_update_notice()
	)
	menu.get_parent().add_child(view)
	refresh_update_notice()

func show_planner() -> void:
	if not running or ended or is_instance_valid(exhibit) or is_instance_valid(academy) or is_instance_valid(update_panel): return
	var adviser = load("res://scripts/mission_adviser.gd")
	var planner_script = load("res://scripts/mission_planner.gd")
	if adviser == null or planner_script == null or not adviser.can_instantiate() or not planner_script.can_instantiate(): return
	if is_instance_valid(finish_panel):
		finish_panel.queue_free()
		finish_panel = null
	var planner = planner_script.new()
	planner.report = adviser.analyze(mission)
	planner.allow_apply = mission.status == "running"
	planner.plan_selected.connect(func(conserving: bool, cleaning: bool):
		if not running or ended or mission.status != "running": return
		mission.conserving = conserving
		mission.cleaning = cleaning
		say("Your plan: %s; panel cleaning %s. Keep watching the sky and your suit battery." % ["save nonessential power" if conserving else "normal lab work", "on" if cleaning else "off"])
		world.update_weather(mission)
	)
	_open_exhibit(planner, false)
