extends Node3D
const Player = preload("res://scripts/player.gd")
const World = preload("res://scripts/world.gd")
const Mission = preload("res://scripts/mission.gd")
const Learning = preload("res://scripts/learning.gd")
const Academy = preload("res://scripts/academy.gd")
var learning: VeilLearning
var academy: VeilAcademy
@export var art: VeilArtProfile = preload("res://art/default_art.tres")
@export var interface_theme: Theme
@export var hud_scene: PackedScene
var mission: VeilMission
var player: VeilPlayer
var world: VeilWorld
var running := false
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
	action_audio = AudioStreamPlayer.new()
	action_audio.stream = load("res://assets/audio/coin.ogg")
	action_audio.volume_db = -18
	add_child(action_audio)
	create_interface()
	get_tree().auto_accept_quit = true
	if "--smoke-test" in OS.get_cmdline_user_args():
		begin()
		await get_tree().process_frame
		print("RED_VEIL_SCENE_READY nodes=", get_tree().get_node_count(), " HUD=", hud.size, " meters=", metrics.get_parent().global_position)
		get_tree().quit()

func setup_inputs() -> void:
	var keys := {"forward": KEY_W, "back": KEY_S, "left": KEY_A, "right": KEY_D, "interact": KEY_E, "visor": KEY_Q, "jump": KEY_SPACE, "pause": KEY_ESCAPE, "guide": KEY_F1}
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
	text(hud, "RED VEIL    /    ELYSIUM OUTPOST", Vector2(42, 36), 15, Color("e3bd83"))
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
	var title := text(menu, "RED VEIL", Vector2(65, 150), 104)
	title.add_theme_font_override("font", art.title_font if art.title_font else load("res://assets/fonts/lilita_one_regular.ttf"))
	text(menu, "Be the astronaut.\nFind your way through the storm.", Vector2(72, 280), 30)
	text(menu, "Your crewmate Mira needs you at the solar array.\nExplore the outpost, protect your suit, and keep\nenough energy to bring everyone home.", Vector2(74, 375), 20)
	button(menu, "BEGIN YOUR MISSION", Vector2(72, 490), 330, begin)
	button(menu, "FIELD GUIDE", Vector2(420, 490), 190, show_guide)
	button(menu, "SOUND: ON" if sound_on else "SOUND: OFF", Vector2(72, 555), 200, toggle_sound)
	button(menu, "MIRA’S FIELD ACADEMY", Vector2(290, 555), 320, show_academy)
	text(menu, "4 MINUTES  /  AGES 7–12  /  KEYBOARD · CONTROLLER · TOUCH", Vector2(74, 635), 13, Color("d4cab7"))
	text(menu, "Educational prototype • Fictional limits • Local practice only • No accounts", Vector2(74, 665), 12, Color("c4bdad"))
	hud.hide()
	create_touch_controls(root)

func create_touch_controls(root: Control) -> void:
	touch_controls = Control.new()
	touch_controls.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	touch_controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(touch_controls)
	for spec in [["↑", Vector2(85, -260), Vector2(0, -1)], ["↓", Vector2(85, -145), Vector2(0, 1)], ["←", Vector2(24, -202), Vector2(-1, 0)], ["→", Vector2(146, -202), Vector2(1, 0)]]:
		var b := button(touch_controls, spec[0], spec[1], 56, func(): pass)
		b.set_anchors_preset(Control.PRESET_BOTTOM_LEFT, true)
		b.button_down.connect(func(): player.touch_move = spec[2])
		b.button_up.connect(func(): player.touch_move = Vector2.ZERO)
	var use_button := button(touch_controls, "USE", Vector2(-110, -210), 90, func(): interact())
	use_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT, true)
	use_button.button_down.connect(func(): touch_interact = true)
	use_button.button_up.connect(func(): touch_interact = false)
	var clean_button := button(touch_controls, "VISOR", Vector2(-110, -145), 90, toggle_visor)
	clean_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT, true)
	var pause_button := button(touch_controls, "Ⅱ", Vector2(-75, 160), 50, toggle_pause)
	pause_button.set_anchors_preset(Control.PRESET_TOP_RIGHT, true)
	touch_controls.visible = false

func show_academy() -> void:
	if is_instance_valid(academy): return
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

func begin() -> void:
	if ended: get_tree().reload_current_scene(); return
	menu.hide()
	hud.show()
	running = true
	paused = false
	player.enabled = true
	touch_controls.visible = DisplayServer.is_touchscreen_available()
	if not DisplayServer.is_touchscreen_available(): Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	say("Follow the lights to the solar array on your right. I’ll stay on the radio.")

func toggle_sound() -> void:
	sound_on = not sound_on
	AudioServer.set_bus_mute(0, not sound_on)
	for child in menu.get_children():
		if child is Button and child.text.begins_with("SOUND:"): child.text = "SOUND: ON" if sound_on else "SOUND: OFF"

func say(message: String) -> void:
	if message == last_radio: return
	last_radio = message
	radio.text = message
	mission_events.append({"hours": mission.time, "message": message})

func toggle_pause() -> void:
	if not running or ended or is_instance_valid(academy): return
	paused = not paused
	player.enabled = not paused
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED
	if paused:
		show_modal("TAKE A BREATH", "Your mission is paused. Nothing uses energy while you think.\n\nWASD / left stick: walk    Mouse / right stick: look\nE / X: use equipment    Q / Y: clean visor\nSpace / A: a small Mars hop", "BACK TO MARS", resume)
	else: resume()

func resume() -> void:
	if is_instance_valid(finish_panel): finish_panel.queue_free()
	paused = false
	player.enabled = true
	touch_controls.visible = DisplayServer.is_touchscreen_available()
	if not DisplayServer.is_touchscreen_available(): Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func show_modal(title: String, body: String, action: String, callback: Callable) -> void:
	if is_instance_valid(finish_panel): finish_panel.queue_free()
	finish_panel = Panel.new()
	finish_panel.size = Vector2(760, 490)
	finish_panel.position = Vector2(-380, -245)
	finish_panel.set_anchors_preset(Control.PRESET_CENTER, true)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("162630")
	style.set_corner_radius_all(14)
	finish_panel.add_theme_stylebox_override("panel", style)
	menu.get_parent().add_child(finish_panel)
	text(finish_panel, title, Vector2(35, 30), 38, Color("e6bb7f"), 690)
	var description := text(finish_panel, body, Vector2(35, 95), 20, Color("e5e4d7"), 690)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button(finish_panel, action, Vector2(35, 397), 290, callback)

func show_guide() -> void:
	if is_instance_valid(academy): return
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
	if not running or paused or ended: return
	if event.is_action_pressed("interact"): interact()
	if event.is_action_pressed("visor"): toggle_visor()

func interact() -> void:
	if not running or paused or ended: return
	if nearby == "power":
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
	if mission.shelter and pos.distance_to(World.SHELTER_POSITION + Vector3(0, 0, -2.7)) < 3: nearby = "remote"
	var inspecting := nearby == "array" and mission.inspection < 1.0 and (Input.is_action_pressed("interact") or touch_interact)
	var old_inspection := mission.inspection
	accumulator += minf(delta, 0.25) * Mission.HOURS_PER_SECOND
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
	show_modal(title, body, "TRY ANOTHER PLAN", func(): get_tree().reload_current_scene())
	button(finish_panel, "PRACTISE WITH MIRA", Vector2(345, 397), 375, show_academy)
	var report := {"version": ProjectSettings.get_setting("application/config/version", "development"), "model": "red-veil-first-person", "result": mission.summary(), "baseline": baseline, "events": mission_events}
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
	root.get_node("%Guide").pressed.connect(show_guide)
	root.get_node("%Sound").pressed.connect(toggle_sound)
	root.get_node("%Sound").text = "SOUND: ON" if sound_on else "SOUND: OFF"
	var academy_button := root.get_node_or_null("%Academy")
	if academy_button: academy_button.pressed.connect(show_academy)
	hud.hide()
	menu.show()
	create_touch_controls(root)
