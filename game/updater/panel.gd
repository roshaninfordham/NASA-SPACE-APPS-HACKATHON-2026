class_name VeilUpdatePanel
extends CanvasLayer
const Branding = preload("res://scripts/branding.gd")
## Presentation only. Main game owns safe entry/exit and the update notification.
signal closed
var client: VeilUpdateClient
var art: VeilArtProfile
var interface_theme: Theme
var content: VBoxContainer
var description: Label
var progress_bar: ProgressBar
var check_button: Button
var install_button: Button
var cancel_button: Button
var restart_button: Button
var releases_button: Button
var repair_button: Button
var back_button: Button
var _confirming_restart := false
var _confirming_repair := false

func _ready() -> void:
	layer = 11
	var background := ColorRect.new()
	background.color = art.structure_color.darkened(0.55) if art else Color("101f2c")
	if interface_theme: background.theme = interface_theme
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]: margin.add_theme_constant_override("margin_" + side, 32)
	background.add_child(margin)
	var scroll := ScrollContainer.new()
	margin.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 18)
	scroll.add_child(content)
	_label("YOUR NEXT ADVENTURE", 34)
	_label("You’re playing " + Branding.title() + " " + client.current_version, 20)
	description = _label("", 24)
	progress_bar = ProgressBar.new()
	progress_bar.max_value = 1.0
	progress_bar.custom_minimum_size.y = 28
	content.add_child(progress_bar)
	check_button = _button("CHECK FOR UPDATES", func(): client.check_for_updates(true))
	install_button = _button("DOWNLOAD AND INSTALL", func(): client.install_update())
	cancel_button = _button("CANCEL DOWNLOAD", func(): client.cancel_download())
	restart_button = _button("RESTART TO PLAY UPDATE", confirm_restart)
	releases_button = _button("WHAT’S NEW ON GITHUB", func(): OS.shell_open(client.release_url()))
	repair_button = _button("REPAIR AN INTERRUPTED UPDATE…", confirm_repair)
	back_button = _button("BACK TO THE OUTPOST", close)
	client.changed.connect(refresh)
	refresh()
	back_button.grab_focus()

func _label(value: String, size: int) -> Label:
	var item := Label.new()
	item.text = value
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item.add_theme_font_size_override("font_size", size)
	if art:
		item.add_theme_color_override("font_color", art.interface_text)
		if art.interface_font: item.add_theme_font_override("font", art.interface_font)
	content.add_child(item)
	return item

func _button(value: String, callback: Callable) -> Button:
	var item := Button.new()
	item.text = value
	item.custom_minimum_size.y = 54
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item.add_theme_font_size_override("font_size", 21)
	if art:
		item.add_theme_color_override("font_color", art.interface_text)
		if art.interface_font: item.add_theme_font_override("font", art.interface_font)
	item.pressed.connect(callback)
	content.add_child(item)
	return item

func refresh() -> void:
	if _confirming_restart or _confirming_repair: return
	description.text = client.message
	progress_bar.visible = client.status in ["downloading", "verifying"]
	progress_bar.value = client.progress
	check_button.visible = not client.ready_to_restart
	check_button.disabled = client.busy
	install_button.visible = client.can_install()
	cancel_button.visible = client.busy and client.status == "downloading"
	restart_button.visible = client.ready_to_restart
	releases_button.visible = not client.available_version.is_empty() or not client.busy
	releases_button.text = "VIEW DOWNLOADS ON GITHUB" if client.manual_update_required else "WHAT’S NEW ON GITHUB"
	repair_button.visible = client.repair_available and not client.busy
	back_button.text = "LATER — KEEP PLAYING" if client.ready_to_restart or client.busy else "BACK TO THE OUTPOST"

func confirm_restart() -> void:
	if not client.ready_to_restart: return
	_confirming_restart = true
	description.text = "Restart the game now? Your local academy progress stays saved. The current game will close and reopen."
	check_button.hide()
	install_button.hide()
	cancel_button.hide()
	releases_button.hide()
	repair_button.hide()
	restart_button.text = "YES — RESTART NOW"
	restart_button.pressed.disconnect(confirm_restart)
	restart_button.pressed.connect(_restart_confirmed)
	back_button.text = "NOT YET — KEEP PLAYING"
	back_button.grab_focus()

func _restart_confirmed() -> void:
	if not client.restart_game():
		_confirming_restart = false
		restart_button.pressed.disconnect(_restart_confirmed)
		restart_button.pressed.connect(confirm_restart)
		restart_button.text = "RESTART TO PLAY UPDATE"
		refresh()

func confirm_repair() -> void:
	if not client.repair_available or client.busy: return
	_confirming_repair = true
	description.text = "First close every other game window. Then repair the interrupted update here. This does not erase your academy progress or replace your current game."
	check_button.hide()
	install_button.hide()
	cancel_button.hide()
	restart_button.hide()
	releases_button.hide()
	repair_button.text = "OTHER WINDOWS ARE CLOSED — REPAIR"
	repair_button.pressed.disconnect(confirm_repair)
	repair_button.pressed.connect(_repair_confirmed)
	back_button.text = "NOT NOW — BACK TO THE OUTPOST"
	back_button.grab_focus()

func _repair_confirmed() -> void:
	_confirming_repair = false
	repair_button.pressed.disconnect(_repair_confirmed)
	repair_button.pressed.connect(confirm_repair)
	repair_button.text = "REPAIR AN INTERRUPTED UPDATE…"
	client.repair_interrupted_update()
	refresh()

func close() -> void:
	closed.emit()
	queue_free()
