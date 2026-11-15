extends Node3D
## Coordinates screens, input and a deterministic model. Presentation never owns science.
const Branding = preload("res://scripts/branding.gd")
const Model = preload("res://scripts/pace_mission.gd")
const World = preload("res://scripts/world.gd")
const WindowWorkView = preload("res://scripts/window_work_view.gd")
const TrainingPanel = preload("res://art/red_veil/training_panel.gd")
const Shell = preload("res://ui/journey_shell.gd")
const Hud = preload("res://ui/training_hud.gd")
const Style = preload("res://ui/journey_style.gd")
const Audio = preload("res://scripts/journey_audio.gd")
const Navigation = preload("res://scripts/navigation_policy.gd")
const Progress = preload("res://scripts/journey_progress.gd")
const Guard = preload("res://scripts/journey_input_guard.gd")
const UpdateClient = preload("res://updater/client.gd")
const UpdatePanel = preload("res://updater/panel.gd")
const SolarFeed = preload("res://live/solar_feed.gd")
const SolarPanel = preload("res://live/solar_panel.gd")
const CREW_WORK_POSITION := Vector3(-0.7, 0, -8.8)
@export var online_sources_enabled := true
var model = Model.new()
var progress = Progress.new()
var shell: Control
var hud: Control
var audio: Node
var navigation: Node
var world: Node3D
var solar_panel: Node3D
var solar_feed: Node
var solar_data_panel: CanvasLayer
var camera: Camera3D
var interface: Control
var catalog: Array = []
var stage := "story"
var paused := true
var mission_started := false
var _warning_cooldown := 0.0
var focused := true
var modal: Control
var modal_kind := ""
var update_client
var update_panel
var update_banner: Button
var dismissed_update := ""
var _announced_update := ""
var _recovery_offered := false
var _recovery_dismissed := false
var legacy: Node3D
var legacy_back: Button
var _pending_result: Dictionary = {}
var _quiz: Dictionary = {}
var _warned := false
var _last_sections := 0
var _guard: Node
var _previous_focus: WeakRef
var _dialog_margin: MarginContainer

func _ready() -> void:
	DisplayServer.window_set_title(Branding.display_name())
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_tree().auto_accept_quit = false
	Engine.max_fps = 60
	progress.load_data()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/mission-concepts.json"))
	if parsed is Dictionary and parsed.get("concepts") is Array: catalog = parsed.concepts
	audio = Audio.new()
	add_child(audio)
	navigation = Navigation.new()
	add_child(navigation)
	solar_feed = SolarFeed.new()
	add_child(solar_feed)
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	interface = Control.new()
	interface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	interface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	interface.theme = Style.theme()
	layer.add_child(interface)
	hud = Hud.new()
	interface.add_child(hud)
	hud.hide()
	shell = Shell.new()
	interface.add_child(shell)
	shell.catalog = catalog
	shell.story_finished.connect(start_mission)
	shell.ready_requested.connect(begin_mission)
	shell.retry_requested.connect(start_mission)
	shell.home_requested.connect(request_home)
	shell.preferences_requested.connect(show_settings)
	shell.audio_cue.connect(audio.cue)
	shell.source_requested.connect(open_source)
	shell.live_data_requested.connect(show_live_sun)
	shell.concept_visibility_changed.connect(_concept_visibility)
	shell.quiz_answered.connect(func(record: Dictionary): _quiz = record.duplicate(true))
	hud.cleaning_speed_requested.connect(set_cleaning_speed)
	hud.start_requested.connect(launch_mission)
	hud.concept_requested.connect(open_concept)
	hud.notebook_requested.connect(show_notebook)
	hud.pause_requested.connect(show_pause)
	hud.work_view_changed.connect(_frame_work_view)
	_apply_preferences()
	shell.show_story(bool(progress.settings.reduced_motion))
	audio.set_context("story")
	get_viewport().disable_3d = true
	_install_guard.call_deferred()
	_setup_updates()
	await get_tree().process_frame
	await get_tree().process_frame
	var bootstrap := get_node_or_null("/root/Updates")
	if bootstrap: bootstrap.mark_healthy()
	if "--smoke-test" in OS.get_cmdline_user_args():
		start_mission()
		await get_tree().process_frame
		await get_tree().process_frame
		print("RED_VEIL_SCENE_READY version=", bootstrap.running_version if bootstrap else ProjectSettings.get_setting("application/config/version"), " nodes=", get_tree().get_node_count(), " journey=mission")
		get_tree().quit()
	elif online_sources_enabled and DisplayServer.get_name() != "headless" and is_instance_valid(update_client):
		update_client.check_for_updates.call_deferred(false)
	if online_sources_enabled and DisplayServer.get_name() != "headless" and not "--smoke-test" in OS.get_cmdline_user_args():
		solar_feed.refresh.call_deferred(false)

func _install_guard() -> void:
	_guard = Guard.new()
	_guard.controller = self
	get_tree().root.add_child(_guard)
	tree_exiting.connect(_guard.queue_free)

func _save_result() -> void:
	if _pending_result.is_empty(): return
	progress.record_result(_pending_result, _quiz)
	_pending_result.clear()
	_quiz.clear()

func show_preparation() -> void:
	_save_result()
	_close_modal()
	stage = "preparation"
	paused = true
	hud.hide()
	get_viewport().disable_3d = true
	shell.show_preparation(catalog, progress.reviewed_ids)
	audio.set_context("preparation")
	audio.set_paused(false)
	_refresh_updates()

func begin_mission() -> void:
	if stage != "preparation" or shell.concept_open: return
	progress.record_reviewed(shell.reviewed_ids)
	start_mission()

func start_mission() -> void:
	_save_result()
	_close_modal()
	model.reset()
	model.set_pace(float(progress.settings.pace))
	stage = "mission"
	paused = false
	mission_started = false
	_warning_cooldown = 0.0
	_warned = false
	_last_sections = 0
	shell.hide()
	get_viewport().disable_3d = false
	if not is_instance_valid(world):
		world = World.new()
		world.set_window_presentation(true)
		add_child(world)
		solar_panel = TrainingPanel.new()
		solar_panel.name = "TrainingSolarPanel"
		solar_panel.position = CREW_WORK_POSITION + Vector3(1.8, 0, 0)
		world.add_child(solar_panel)
		camera = Camera3D.new()
		camera.position = Vector3(0, 1.78, -12.6)
		camera.fov = 52
		add_child(camera)
		camera.look_at(camera.position + Vector3(0, 0, 10))
	world.show()
	world.process_mode = Node.PROCESS_MODE_DISABLED
	if is_instance_valid(world.dust_particles): world.dust_particles.emitting = not bool(progress.settings.reduced_motion)
	camera.current = true
	hud.show()
	hud.set_preflight(true)
	hud.refresh(model.snapshot())
	_frame_work_view.call_deferred()
	_sync_world(model.snapshot())
	audio.set_context("mission")
	audio.set_paused(false)
	_refresh_updates()

func launch_mission() -> void:
	if not _can_act() or mission_started: return
	mission_started = true
	hud.set_preflight(false)
	audio.cue("confirm")
	_sync_world(model.snapshot())

func _process(delta: float) -> void:
	if not is_instance_valid(navigation): return
	if navigation.poll_external_exit(): _pause_after_window_exit()
	if stage == "mission" and is_instance_valid(world):
		world.process_mode = Node.PROCESS_MODE_DISABLED if not mission_started or paused or not focused or shell.concept_open else Node.PROCESS_MODE_INHERIT
	if stage != "mission" or not mission_started or paused or not focused or shell.concept_open: return
	# Foreground active play only; a stalled/background frame cannot skip decisions.
	model.advance(minf(delta, 0.25))
	var snapshot: Dictionary = model.snapshot()
	hud.refresh(snapshot)
	_sync_world(snapshot)
	if int(snapshot.sections_cleaned) > _last_sections:
		_last_sections = int(snapshot.sections_cleaned)
		audio.cue("confirm")
	var remaining := float(snapshot.get("remaining_seconds", 90.0))
	_warning_cooldown -= minf(delta, 0.25)
	if remaining <= 30.0 and remaining > 0.0 and _warning_cooldown <= 0.0:
		# Real-time cadence remains understandable at every simulation setting.
		audio.cue("urgent" if remaining <= 8.0 else ("warning" if remaining <= 15.0 else "countdown"))
		_warning_cooldown = 1.05 if remaining <= 8.0 else (2.6 if remaining <= 15.0 else 5.1)
	if snapshot.status != "running": finish_mission()

func _sync_world(snapshot: Dictionary) -> void:
	if not is_instance_valid(world): return
	var anchor := world.get_node_or_null("CompanionAnchor") as Node3D
	if anchor:
		anchor.position = CREW_WORK_POSITION
		anchor.visible = not bool(snapshot.crew_sheltered)
		for character in anchor.get_children():
			if character.has_method("set_training_cleaning"):
				character.set_training_cleaning(mission_started and bool(snapshot.cleaning), float(snapshot.get("effective_multiplier", float(snapshot.get("cleaning_multiplier", 1.0)) * (1.0 - float(snapshot.get("fatigue", 0.0))))), bool(progress.settings.reduced_motion) or paused)
	if is_instance_valid(solar_panel): solar_panel.refresh(snapshot)
	var room_anchor := world.get_node_or_null("InteriorAnchor")
	if room_anchor:
		for room in room_anchor.get_children():
			if room.has_method("set_airlock_phase"):
				room.set_airlock_phase("complete" if snapshot.crew_sheltered else ("cycling" if snapshot.phase == "airlock" else "idle"))

func set_cleaning_speed(multiplier: float) -> void:
	if _can_act() and model.set_cleaning_speed(multiplier): audio.cue("confirm")
	hud.refresh(model.snapshot())
	_sync_world(model.snapshot())

func _can_act() -> bool:
	return stage == "mission" and not paused and focused and not shell.concept_open and not is_instance_valid(modal)

func finish_mission() -> void:
	paused = true
	stage = "debrief"
	_pending_result = model.result()
	hud.hide()
	get_viewport().disable_3d = true
	if is_instance_valid(world): world.process_mode = Node.PROCESS_MODE_DISABLED
	shell.show_debrief(_pending_result, catalog)
	audio.set_context("debrief")
	audio.set_paused(false)
	audio.cue("success" if _pending_result.status in ["win", "pass"] else "retry")
	_refresh_updates()

func open_concept(id: String) -> void:
	if stage != "mission" or shell.concept_open: return
	paused = true
	_close_modal()
	shell.show_live_concept(id, model.snapshot())

func _concept_visibility(open: bool) -> void:
	if stage == "preparation" and not open: progress.record_reviewed(shell.reviewed_ids)
	if stage == "mission":
		paused = true
		if not open:
			# Reading ends with an explicit resume, so a browser/focus return is safe.
			_ensure_pause_menu.call_deferred()
	audio.set_paused(open or (stage == "mission" and paused))
	_refresh_updates()

func open_source(url: String) -> void:
	var allowed := false
	for item: Dictionary in catalog:
		if item.get("source_url", "") == url and url.begins_with("https://"): allowed = true
	if not allowed: return
	if stage == "mission": paused = true
	var error := OS.shell_open(url)
	if error != OK: push_warning("Could not open science source in the system browser: " + str(error))

func handle_global_input(event: InputEvent) -> bool:
	if (event is InputEventKey and event.pressed) or (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed): audio.on_user_gesture()
	if navigation.handle_key(event):
		if event is InputEventKey and (event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE): _pause_after_window_exit()
		return true
	if not event is InputEventKey or not event.pressed or event.echo: return false
	var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	if key == KEY_TAB:
		var scope: Node = solar_data_panel if is_instance_valid(solar_data_panel) else (update_panel if is_instance_valid(update_panel) else modal)
		if is_instance_valid(scope):
			_cycle_focus_within(scope, event.shift_pressed)
			return true
	if stage == "legacy" and not is_instance_valid(modal): return false
	if key == KEY_ESCAPE:
		if is_instance_valid(solar_data_panel): solar_data_panel.close()
		elif is_instance_valid(update_panel): update_panel.close()
		elif shell.concept_open: shell.handle_back()
		elif is_instance_valid(modal):
			if modal_kind == "pause": resume_mission()
			elif stage == "mission": show_pause()
			elif stage == "home": show_home()
			else: _close_modal()
		elif stage == "mission": show_pause()
		else: shell.handle_back()
		return true
	if _can_act():
		if key == KEY_ENTER and not mission_started:
			launch_mission()
			return true
		if key in [KEY_1, KEY_3]:
			var current := float(model.snapshot().get("cleaning_multiplier", 1.0))
			set_cleaning_speed(clampf(current + (-0.25 if key == KEY_1 else 0.25), 0.25, 1.75))
			return true
	return false

func _pause_after_window_exit() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if stage == "mission":
		paused = true
		_ensure_pause_menu()
	elif stage == "legacy" and is_instance_valid(legacy) and legacy.running:
		legacy.control_mode = false
		if not legacy.paused: legacy.toggle_pause()
		legacy.paused = true
		legacy.player.enabled = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		focused = false
		if is_instance_valid(audio): audio.set_focused(false)
		if stage == "mission":
			paused = true
			_ensure_pause_menu.call_deferred()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		focused = true
		if is_instance_valid(audio): audio.set_focused(true)
	elif what == NOTIFICATION_WM_CLOSE_REQUEST and is_instance_valid(interface): show_quit()

func _close_modal() -> void:
	var focus = _previous_focus.get_ref() if _previous_focus else null
	if is_instance_valid(modal) and is_instance_valid(focus) and modal.is_ancestor_of(focus): focus = null
	if is_instance_valid(modal):
		modal.get_parent().remove_child(modal)
		modal.queue_free()
	modal = null
	modal_kind = ""
	if is_instance_valid(focus): _restore_focus.call_deferred(weakref(focus))

func _restore_focus(reference: WeakRef) -> void:
	var target = reference.get_ref()
	if is_instance_valid(solar_data_panel) and is_instance_valid(target) and not solar_data_panel.is_ancestor_of(target): return
	if is_instance_valid(update_panel) and is_instance_valid(target) and not update_panel.is_ancestor_of(target): return
	if is_instance_valid(modal) and is_instance_valid(target) and not modal.is_ancestor_of(target): return
	if is_instance_valid(target) and target.is_inside_tree() and target.is_visible_in_tree(): target.grab_focus()

func _cycle_focus_within(scope: Node, backwards: bool) -> void:
	var targets: Array[Control] = []
	_collect_focus(scope, targets)
	if targets.is_empty(): return
	var index := targets.find(get_viewport().gui_get_focus_owner())
	targets[posmod(index + (-1 if backwards else 1), targets.size())].grab_focus()

func _collect_focus(node: Node, targets: Array[Control]) -> void:
	if node is Control and node.is_visible_in_tree() and node.focus_mode == Control.FOCUS_ALL:
		if not node is BaseButton or not node.disabled: targets.append(node)
	for child in node.get_children(): _collect_focus(child, targets)

func _unhandled_key_input(_event: InputEvent) -> void:
	if is_instance_valid(modal): get_viewport().set_input_as_handled()

func _dialog(title: String, description: String, kind: String) -> VBoxContainer:
	_close_modal()
	var owner := get_viewport().gui_get_focus_owner()
	_previous_focus = weakref(owner) if owner else null
	modal_kind = kind
	modal = ColorRect.new()
	modal.color = Color(0.015, 0.035, 0.055, 0.95)
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	interface.add_child(modal)
	var margin := MarginContainer.new()
	_dialog_margin = margin
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 24)
	modal.add_child(margin)
	modal.resized.connect(_layout_dialog)
	_layout_dialog.call_deferred()
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	margin.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 14)
	scroll.add_child(column)
	var heading := Style.label(title, 30, Style.PEARL, "display")
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(heading)
	var detail := Style.label(description, 18, Style.MUTED)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(detail)
	_reset_dialog_scroll.call_deferred(weakref(scroll))
	return column

func _layout_dialog() -> void:
	if not is_instance_valid(modal) or not is_instance_valid(_dialog_margin): return
	var inset := maxi(24, int((modal.size.x - 700.0) / 2.0))
	_dialog_margin.add_theme_constant_override("margin_left", inset)
	_dialog_margin.add_theme_constant_override("margin_right", inset)

func _reset_dialog_scroll(reference: WeakRef) -> void:
	# One-shot signal bindings are released if the controller is freed while
	# replacing a scene; a suspended coroutine can otherwise retain its WeakRef.
	var callback := _finish_reset_dialog_scroll.bind(reference)
	if not get_tree().process_frame.is_connected(callback): get_tree().process_frame.connect(callback, CONNECT_ONE_SHOT)

func _finish_reset_dialog_scroll(reference: WeakRef) -> void:
	var scroll = reference.get_ref()
	if is_instance_valid(scroll) and scroll.is_inside_tree(): scroll.scroll_vertical = 0

func _button(column: VBoxContainer, label: String, callback: Callable, primary := false) -> Button:
	var button := Style.button(label, primary)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.pressed.connect(callback)
	column.add_child(button)
	if primary: _restore_focus.call_deferred(weakref(button))
	return button

func _ensure_pause_menu() -> void:
	if stage == "mission" and paused and not shell.concept_open and not is_instance_valid(modal) and not is_instance_valid(solar_data_panel) and not is_instance_valid(update_panel): show_pause()

func show_pause() -> void:
	if stage != "mission" or shell.concept_open: return
	paused = true
	audio.set_paused(true)
	var box := _dialog("Take your time.", "The mission clock is paused. Reading and breaks never cost mission time.", "pause")
	_button(box, "Resume mission", resume_mission, true)
	_button(box, "Mission book · explore the eight ideas", show_notebook)
	_button(box, "Live Sun · NASA observation", show_live_sun)
	_button(box, "Sound, motion & pace", show_settings)
	_button(box, "Restart this mission", confirm_restart)
	_button(box, "Home", request_home)
	_button(box, "Leave fullscreen" if navigation.is_fullscreen() else "Enter fullscreen · F11", func(): navigation.toggle_fullscreen())
	_button(box, "Quit game", show_quit)

func resume_mission() -> void:
	if stage != "mission" or not focused or shell.concept_open: return
	_close_modal()
	paused = false
	audio.set_paused(false)
	_restore_focus.call_deferred(weakref(hud.faster_button if mission_started else hud.start_button))

func show_notebook() -> void:
	if stage != "mission": return
	paused = true
	audio.set_paused(true)
	var box := _dialog("Your mission book", "Set a cleaning pace, then start. High effort builds game tiredness; a gentler pace restores it. Ren steps indoors when the countdown ends. Energy is stored in kWh. These are teaching scenarios, not health readings.", "notebook")
	_button(box, "Back to pause", show_pause, true)
	_button(box, "Live Sun · NASA observation", show_live_sun)
	for item: Dictionary in catalog:
		var id: String = item.id
		_button(box, str(item.title), func(): open_concept(id))

func _apply_preferences() -> void:
	audio.set_music_enabled(bool(progress.settings.music_enabled))
	audio.set_effects_enabled(bool(progress.settings.effects_enabled))
	audio.set_music_volume(float(progress.settings.music_volume))
	audio.set_effects_volume(float(progress.settings.effects_volume))
	if audio.has_method("set_soundtrack"): audio.set_soundtrack(str(progress.settings.get("soundtrack", "supplied")))
	shell.set_reduced_motion(bool(progress.settings.reduced_motion))
	hud.set_reduced_motion(bool(progress.settings.reduced_motion))
	if is_instance_valid(world) and is_instance_valid(world.dust_particles): world.dust_particles.emitting = not bool(progress.settings.reduced_motion)

func show_settings() -> void:
	if stage == "mission": paused = true
	audio.set_paused(stage == "mission")
	var box := _dialog("Make yourself at home.", "Music, sound effects and motion are yours to choose. Pace changes real play time; the same science equations still apply.", "settings")
	_button(box, "Back", func():
		if stage == "mission": show_pause()
		elif stage == "home": show_home()
		else: _close_modal()
	, true)
	for setting in ["music_enabled", "effects_enabled", "reduced_motion"]:
		var toggle := CheckButton.new()
		toggle.text = {"music_enabled": "Background music", "effects_enabled": "Sound effects", "reduced_motion": "Reduce motion"}[setting]
		toggle.custom_minimum_size.y = 48
		toggle.button_pressed = bool(progress.settings[setting])
		toggle.toggled.connect(func(value: bool): progress.set_setting(setting, value); _apply_preferences())
		box.add_child(toggle)
	for setting in ["music_volume", "effects_volume"]:
		box.add_child(Style.label("Music volume" if setting == "music_volume" else "Effects volume", 18))
		var slider := HSlider.new()
		slider.min_value = 0
		slider.max_value = 1
		slider.step = 0.05
		slider.value = float(progress.settings[setting])
		slider.custom_minimum_size.y = 48
		slider.value_changed.connect(func(value: float): progress.set_setting(setting, value); _apply_preferences())
		box.add_child(slider)
	var pace := OptionButton.new()
	pace.custom_minimum_size.y = 48
	for title in ["Relaxed · 3 minutes", "Standard · 90 seconds", "Quick practice · 45 seconds"]: pace.add_item(title)
	pace.select([0.5, 1.0, 2.0].find(float(progress.settings.pace)))
	pace.item_selected.connect(func(index: int):
		var value: float = [0.5, 1.0, 2.0][index]
		progress.set_setting("pace", value)
		if stage == "mission": model.set_pace(value); hud.refresh(model.snapshot())
	)
	box.add_child(pace)
	_button(box, "Use original ambient score" if str(progress.settings.get("soundtrack", "supplied")) == "supplied" else "Use team-supplied music", func():
		progress.set_setting("soundtrack", "original" if str(progress.settings.get("soundtrack", "supplied")) == "supplied" else "supplied")
		_apply_preferences()
		show_settings()
	)
	var music_credit := Style.label("Music: Minyo San Kyoku — Doug Maxwell / Zac Zinger; Floating Lanterns — The Mini Vandals. Team-supplied recordings. See AUDIO-CREDITS in the download.", 16, Style.MUTED)
	music_credit.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(music_credit)
	if not progress.last_error.is_empty(): box.add_child(Style.label("Settings work for this session, but local saving is unavailable.", 16, Style.AMBER))

func confirm_restart() -> void:
	var box := _dialog("Try a new plan?", "Restarting replaces this unfinished attempt. Your explored ideas stay saved.", "confirm")
	_button(box, "Keep this mission", show_pause, true)
	_button(box, "Restart mission", start_mission)

func request_home() -> void:
	if stage == "mission":
		paused = true
		var box := _dialog("Return home?", "This unfinished attempt will end. Your explored ideas stay saved.", "confirm")
		_button(box, "Keep this mission", show_pause, true)
		_button(box, "Leave mission", show_home)
	else: show_home()

func show_home() -> void:
	_save_result()
	stage = "home"
	paused = true
	hud.hide()
	shell.hide()
	get_viewport().disable_3d = true
	audio.set_context("home")
	audio.set_paused(false)
	var box := _dialog(Branding.title(), "A small Mars mission about looking after your crew. Explore eight ideas, make a plan, and bring Ren home.", "home")
	_button(box, "Enter the control room", start_mission, true)
	_button(box, "Explore the eight science ideas", show_preparation)
	_button(box, "Replay the story", func(): _close_modal(); stage = "story"; shell.show_story(bool(progress.settings.reduced_motion)); audio.set_context("story"))
	_button(box, "Sound, motion & pace", show_settings)
	_button(box, "Updates & downloads", show_updates)
	_button(box, "Live Sun · NASA observation", show_live_sun)
	_button(box, "Advanced lab · earlier mission", open_legacy)
	_button(box, "Quit game", show_quit)
	var credit := Style.label("Made with love by Team Roshan Xingbo at the NASA Space App Hackathon 2026, NYC", 16, Style.MUTED)
	credit.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(credit)
	_refresh_updates()

func show_quit() -> void:
	if is_instance_valid(solar_data_panel): solar_data_panel.close(); solar_data_panel = null
	if is_instance_valid(update_panel): update_panel.close(); update_panel = null
	if stage == "mission": paused = true
	if stage == "legacy": _pause_after_window_exit()
	var box := _dialog("See you among the stars.", "Quit the game? An unfinished mission will end. Explored ideas and settings stay on this device.", "quit")
	_button(box, "Stay here", func():
		if stage == "mission": show_pause()
		elif stage == "legacy": _close_modal()
		else: show_home()
	, true)
	_button(box, "Quit game", func(): _save_result(); get_tree().quit())

func open_legacy() -> void:
	_close_modal()
	stage = "legacy"
	shell.hide()
	audio.set_context("silent")
	if is_instance_valid(world): world.hide(); world.process_mode = Node.PROCESS_MODE_DISABLED
	get_viewport().disable_3d = false
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	get_tree().root.content_scale_size = Vector2i(1280, 720)
	legacy = load("res://legacy_mission.tscn").instantiate()
	add_child(legacy)
	get_tree().auto_accept_quit = false
	legacy_back = Style.button("← New journey")
	legacy_back.position = Vector2(12, 12)
	interface.add_child(legacy_back)
	legacy_back.pressed.connect(request_close_legacy)
	_refresh_updates()

func request_close_legacy() -> void:
	if is_instance_valid(legacy) and legacy.running and not legacy.ended:
		_pause_after_window_exit()
		var box := _dialog("Return to the new journey?", "Your unfinished advanced-lab attempt will end. Academy progress stays saved.", "legacy-confirm")
		_button(box, "Stay in the advanced lab", _close_modal, true)
		_button(box, "Return to the new journey", close_legacy)
	else: close_legacy()

func close_legacy() -> void:
	if not is_instance_valid(legacy): return
	legacy.queue_free()
	legacy = null
	legacy_back.queue_free()
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_tree().auto_accept_quit = false
	AudioServer.set_bus_mute(0, false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	show_home()

func _setup_updates() -> void:
	var bootstrap := get_node_or_null("/root/Updates")
	if bootstrap == null: return
	update_client = bootstrap.get_node_or_null("Client")
	if update_client == null:
		update_client = UpdateClient.new()
		update_client.name = "Client"
		update_client.configure(bootstrap.store, bootstrap.running_version, bootstrap.store.root_dir.path_join("incoming"))
		bootstrap.add_child(update_client)
	update_client.changed.connect(_refresh_updates)
	update_banner = Style.button("A new adventure is available · View update")
	update_banner.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	update_banner.offset_top = -54
	update_banner.offset_bottom = -6
	update_banner.offset_left = 12
	update_banner.offset_right = -12
	interface.add_child(update_banner)
	update_banner.pressed.connect(show_updates)
	_refresh_updates()

func _refresh_updates() -> void:
	if not is_instance_valid(update_banner): return
	var available: String = update_client.available_version
	update_banner.hide()
	var safe: bool = stage in ["preparation", "debrief"] and not shell.concept_open and not is_instance_valid(update_panel) and not is_instance_valid(solar_data_panel) and not is_instance_valid(modal)
	var bootstrap := get_node_or_null("/root/Updates")
	var recovery: String = bootstrap.startup_notice if bootstrap else ""
	if safe and not recovery.is_empty() and not _recovery_dismissed and not _recovery_offered:
		_recovery_offered = true
		_offer_recovery.call_deferred(recovery)
		return
	if safe and not available.is_empty() and available != dismissed_update and available != _announced_update:
		_announced_update = available
		_offer_update.call_deferred(available)

func _offer_recovery(message: String) -> void:
	if stage not in ["preparation", "debrief"] or shell.concept_open or is_instance_valid(modal) or is_instance_valid(update_panel) or is_instance_valid(solar_data_panel):
		_recovery_offered = false
		return
	var box := _dialog("Your game is ready to play.", message, "update-recovery")
	_button(box, "Continue", func(): _recovery_dismissed = true; _close_modal(), true)
	_button(box, "Review updates", func(): _recovery_dismissed = true; _close_modal(); show_updates())

func _offer_update(version: String) -> void:
	if stage not in ["preparation", "debrief"] or shell.concept_open or is_instance_valid(modal) or is_instance_valid(update_panel) or is_instance_valid(solar_data_panel) or version != update_client.available_version or version == dismissed_update:
		_announced_update = ""
		return
	var box := _dialog("A new adventure is ready.", "Version " + version + " is available. Review the update now, or keep playing and update from Home later.", "update-offer")
	_button(box, "View update", func(): _close_modal(); show_updates(), true)
	_button(box, "Later · keep playing", func(): dismissed_update = version; _close_modal())

func show_updates() -> void:
	if stage == "mission" or stage == "legacy" or is_instance_valid(update_panel) or is_instance_valid(solar_data_panel) or not is_instance_valid(update_client): return
	update_panel = UpdatePanel.new()
	update_panel.client = update_client
	update_panel.interface_theme = Style.theme()
	update_panel.closed.connect(func(): update_panel = null; dismissed_update = update_client.available_version; _refresh_updates())
	add_child(update_panel)
	update_panel.layer = 30
	_refresh_updates()

func show_live_sun() -> void:
	if stage == "legacy" or is_instance_valid(solar_data_panel) or is_instance_valid(update_panel): return
	if stage == "mission":
		paused = true
		audio.set_paused(true)
	solar_data_panel = SolarPanel.new()
	solar_data_panel.client = solar_feed
	solar_data_panel.closed.connect(func():
		solar_data_panel = null
		_ensure_pause_menu.call_deferred()
		_refresh_updates()
	)
	solar_data_panel.source_requested.connect(func(url: String):
		if url == "https://sdo.gsfc.nasa.gov/data/": OS.shell_open(url)
	)
	add_child(solar_data_panel)
	solar_data_panel.layer = 31
	if online_sources_enabled and DisplayServer.get_name() != "headless": solar_feed.refresh(false)
	_refresh_updates()

func _frame_work_view() -> void:
	if is_instance_valid(camera) and is_instance_valid(hud):
		WindowWorkView.frame(camera, CREW_WORK_POSITION, get_viewport().get_visible_rect().size, hud.get_work_view_rect())
