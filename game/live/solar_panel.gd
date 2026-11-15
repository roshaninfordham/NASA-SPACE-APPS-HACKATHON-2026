extends CanvasLayer
## Read-only NASA imagery viewer. It does not import or mutate a mission model.
## The controller owns opening, Escape handling, and automatic fetch policy.
const Style = preload("res://ui/journey_style.gd")
const NASA_DATA_PAGE := "https://sdo.gsfc.nasa.gov/data/"
const CREDIT := "Courtesy of NASA/SDO and the AIA, EVE, and HMI science teams."
signal closed
signal source_requested(url: String)
var client
var background: ColorRect
var image_view: TextureRect
var status_label: Label
var message_label: Label
var file_updated_label: Label
var successful_fetch_label: Label
var last_checked_label: Label
var age_label: Label
var back_button: Button
var refresh_button: Button
var source_button: Button
var info_scroll: ScrollContainer
var details_button: Button
var credit_label: Label
var _details: VBoxContainer
var _details_open := false
var _heading: Label
var _subtitle: Label
var _image_frame: Panel
var _image_caption: Label
var _empty: Label
var _info: VBoxContainer
var _previous_focus: WeakRef
var _closing := false
var current_snapshot: Dictionary = {}

func _ready() -> void:
	layer = 31
	var previous := get_viewport().gui_get_focus_owner()
	if previous: _previous_focus = weakref(previous)
	background = ColorRect.new()
	background.name = "SolarViewer"
	background.color = Style.FLOOR
	background.theme = Style.theme()
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	_heading = Style.label("The Sun, from NASA",34,Style.PEARL,"display")
	_heading.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	background.add_child(_heading)
	_subtitle = Style.label("Your mission works offline.",17,Style.MUTED)
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle.max_lines_visible = 2
	background.add_child(_subtitle)
	_image_frame = Panel.new()
	var image_box := Style.panel()
	image_box.bg_color = Color.BLACK
	image_box.set_corner_radius_all(12)
	_image_frame.add_theme_stylebox_override("panel",image_box)
	background.add_child(_image_frame)
	image_view = TextureRect.new()
	image_view.name = "LatestSolarImage"
	image_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image_view.accessibility_name = "NASA SDO AIA 193 angstrom image of the solar corona, shown in false colour."
	_image_frame.add_child(image_view)
	_empty = Style.label("No image available yet.",18,Style.MUTED)
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_image_frame.add_child(_empty)
	_image_caption = Style.label("Look for a bright loop and a darker patch in the Sun’s outer atmosphere.",14,Style.MUTED)
	_image_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_image_caption.max_lines_visible = 3
	background.add_child(_image_caption)
	info_scroll = ScrollContainer.new()
	info_scroll.name = "SolarImageDetails"
	info_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	info_scroll.follow_focus = true
	info_scroll.focus_mode = Control.FOCUS_ALL
	info_scroll.accessibility_name = "Solar image details. Use arrow keys or Page Up and Page Down to read."
	background.add_child(info_scroll)
	_info = VBoxContainer.new()
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info.add_theme_constant_override("separation",8)
	info_scroll.add_child(_info)
	# Status and credit are fixed outside the scrolling metadata. Reading a
	# timestamp must never hide whether this is live, cached or bundled imagery.
	status_label = Style.label("Checking image status…",19,Style.CYAN,"display")
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.max_lines_visible = 2
	background.add_child(status_label)
	credit_label = Style.label(CREDIT,13,Style.MUTED)
	credit_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	credit_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	background.add_child(credit_label)
	file_updated_label = _reading("File updated: unknown",14,Style.MUTED)
	successful_fetch_label = _reading("Fetched: not yet",14,Style.MUTED)
	details_button = Style.button("＋ Connection details")
	details_button.name = "SolarConnectionDetails"
	details_button.toggle_mode = true
	details_button.custom_minimum_size.y = 48
	details_button.toggled.connect(_toggle_details)
	_info.add_child(details_button)
	_details = VBoxContainer.new()
	_details.name = "ConnectionDetails"
	_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_details.add_theme_constant_override("separation",10)
	_details.hide()
	_info.add_child(_details)
	message_label = _reading("",16,Style.MUTED,"body",_details)
	last_checked_label = _reading("Last connection attempt: not yet",14,Style.MUTED,"body",_details)
	age_label = _reading("File age: unknown",14,Style.MUTED,"body",_details)
	_reading("The file date comes from NASA’s HTTP Last-Modified metadata. It is not a verified camera exposure time. This is a refreshed image, not a live video stream.",14,Style.MUTED,"body",_details)
	_reading("What am I seeing?",20,Style.PEARL,"display",_details)
	_reading("AIA sees extreme-ultraviolet light from the Sun’s hot outer atmosphere. The 193 Å image uses assigned colours to show light our eyes cannot see.",16,Style.PEARL,"body",_details)
	_reading("This image does not predict radiation on Mars or change your mission’s dose, storm deadline, battery or score.",16,Style.AMBER,"body",_details)
	back_button = Style.button("Back",true)
	back_button.name = "SolarBack"
	back_button.pressed.connect(close)
	refresh_button = Style.button("Refresh image")
	refresh_button.name = "SolarRefresh"
	refresh_button.pressed.connect(func():
		if is_instance_valid(client): client.refresh(true)
	)
	source_button = Style.button("Open NASA data")
	source_button.name = "SolarSource"
	source_button.tooltip_text = "Open NASA’s SDO data page in your device’s browser."
	source_button.pressed.connect(func(): source_requested.emit(NASA_DATA_PAGE))
	for button in [back_button,refresh_button,source_button]: background.add_child(button)
	background.resized.connect(_layout)
	if is_instance_valid(client) and client.has_signal("changed"): client.changed.connect(refresh)
	refresh()
	_layout()
	# Label wrapping can retain its pre-layout minimum height on the first
	# frame. Settle fixed credit/status bounds before the viewer is presented.
	_layout.call_deferred()
	back_button.grab_focus.call_deferred()

func _reading(text: String, pixels: int, tint: Color = Style.PEARL, face: String = "body", parent: VBoxContainer = null) -> Label:
	var label := Style.label(text,pixels,tint,face)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	(parent if parent != null else _info).add_child(label)
	return label

func _toggle_details(open: bool) -> void:
	_details_open = open
	_details.visible = open
	details_button.text = "− Hide connection details" if open else "＋ Connection details"
	details_button.accessibility_description = "Connection details expanded" if open else "Connection details collapsed"
	# Closing a long explanation restores the concise dates at the top.
	if not open: info_scroll.scroll_vertical = 0

static func describe_age(seconds: float) -> String:
	if not is_finite(seconds) or seconds < 0.0: return "unknown"
	if seconds < 60.0: return "under a minute"
	if seconds < 3600.0: return "%d min" % int(seconds/60.0)
	if seconds < 86400.0: return "%.1f hours" % (seconds/3600.0)
	return "%.1f days" % (seconds/86400.0)

func refresh() -> void:
	if not is_instance_valid(background): return
	var previous_snapshot := current_snapshot
	current_snapshot = client.snapshot().duplicate(true) if is_instance_valid(client) and client.has_method("snapshot") else {}
	var status := str(current_snapshot.get("status","fallback"))
	if status == "loading":
		# A loading event may contain only connection state. Keep the previous
		# image's own dates with it until a new response actually supplies them.
		for field in ["texture","source_kind","file_updated_utc","fetched_at_utc","last_success_utc","image_age_seconds","cache_age_seconds"]:
			if not current_snapshot.has(field) and previous_snapshot.has(field):
				current_snapshot[field] = previous_snapshot[field]
	var source_kind := str(current_snapshot.get("source_kind","bundled"))
	match status:
		"loading": status_label.text = "Checking NASA · keeping the current image"
		"live": status_label.text = "NASA connected · latest available"
		"stale": status_label.text = "Older NASA image · check its file date"
		"cached": status_label.text = "Offline · saved NASA image"
		_: status_label.text = "Offline · bundled example image" if source_kind == "bundled" else "Image unavailable"
	status_label.add_theme_color_override("font_color",Style.CYAN if status == "live" else Style.AMBER)
	message_label.text = str(current_snapshot.get("message", "You can still explore this science view without a connection.")).left(500).trim_prefix("NASA connected · latest available. ")
	var texture: Variant = current_snapshot.get("texture")
	if texture is Texture2D:
		image_view.texture = texture
	elif status != "loading":
		image_view.texture = null
	_empty.visible = image_view.texture == null
	if status == "loading" and _empty.visible: status_label.text = "Checking NASA · no image yet"
	var published := str(current_snapshot.get("file_updated_utc",""))
	var fetched := str(current_snapshot.get("fetched_at_utc",current_snapshot.get("last_success_utc","")))
	var checked := str(current_snapshot.get("last_checked_utc",""))
	file_updated_label.text = "File updated: " + (published if not published.is_empty() else "unknown")
	successful_fetch_label.text = "Fetched: " + (fetched if not fetched.is_empty() else "not yet on this device")
	last_checked_label.text = "Last connection attempt: " + (checked if not checked.is_empty() else "not yet")
	age_label.text = "NASA file age: " + describe_age(float(current_snapshot.get("image_age_seconds",-1.0)))
	if source_kind == "cache": age_label.text += " · saved copy age: " + describe_age(float(current_snapshot.get("cache_age_seconds",-1.0)))
	refresh_button.disabled = status == "loading" or not is_instance_valid(client)
	refresh_button.text = "Checking…" if status == "loading" else ("Refresh" if background.size.x < 700.0 else "Refresh image")
	refresh_button.accessibility_description = "Checking NASA; the current image remains visible" if status == "loading" else "Request the latest available NASA image"
	if refresh_button.has_focus() and refresh_button.disabled: back_button.grab_focus.call_deferred()
	background.accessibility_description = status_label.text + ". " + file_updated_label.text + ". " + successful_fetch_label.text

func _layout() -> void:
	if not is_instance_valid(background): return
	var view := background.size
	var narrow := view.x < 700.0
	var short := view.y < 500.0
	var margin := 12.0 if narrow or short else 20.0
	var width := maxf(200,view.x-margin*2)
	var header_height := 112.0 if narrow else (66.0 if short else 82.0)
	_heading.position = Vector2(margin,margin)
	_heading.size = Vector2(width if narrow else width*0.52,36 if narrow or short else 42)
	_heading.add_theme_font_size_override("font_size",28 if narrow or short else 34)
	_subtitle.position = Vector2(margin,margin+(38 if narrow or short else 46))
	_subtitle.size = Vector2(width if narrow else width*0.52,24)
	_subtitle.add_theme_font_size_override("font_size",15 if narrow or short else 17)
	status_label.position = Vector2(margin,margin+68) if narrow else Vector2(margin+width*0.55,margin+4)
	status_label.size = Vector2(width,40) if narrow else Vector2(width*0.45,52)
	status_label.add_theme_font_size_override("font_size",17 if narrow or short else 19)
	# Reserve two lines even before the font/wrapping layout settles.
	var credit_height := 40.0
	credit_label.position = Vector2(margin,view.y-margin-48-8-credit_height)
	credit_label.size = Vector2(width,credit_height)
	credit_label.add_theme_font_size_override("font_size",12 if narrow or short else 13)
	var top := margin+header_height
	var height := maxf(100,credit_label.position.y-10-top)
	var image_size := minf(width,maxf(96,height*0.58)) if narrow else minf(width*0.50,maxf(96,height-42))
	_image_frame.position = Vector2(margin+(width-image_size)*0.5 if narrow else margin,top)
	_image_frame.size = Vector2(image_size,image_size)
	image_view.position = Vector2(5,5)
	image_view.size = Vector2(image_size-10,image_size-10)
	_empty.position = Vector2(5,5)
	_empty.size = image_view.size
	_image_caption.position = Vector2(_image_frame.position.x,top+image_size+4)
	_image_caption.size = Vector2(image_size,38)
	_image_caption.add_theme_font_size_override("font_size",13 if narrow or short else 14)
	_image_caption.text = "Sun image · not a Mars forecast." if narrow or short else "Explore the Sun’s outer atmosphere. This image does not predict Mars radiation."
	if narrow:
		info_scroll.position = Vector2(margin,top+image_size+46)
		info_scroll.size = Vector2(width,maxf(48,height-image_size-46))
	else:
		info_scroll.position = Vector2(margin+image_size+24,top)
		info_scroll.size = Vector2(maxf(80,width-image_size-24),height)
	var button_width := (width-20)/3.0
	back_button.text = "Back"
	refresh_button.text = "Checking…" if current_snapshot.get("status") == "loading" else ("Refresh" if narrow else "Refresh image")
	source_button.text = "NASA data" if narrow else "Open NASA data"
	for index in range(3):
		var button: Button = [back_button,refresh_button,source_button][index]
		button.add_theme_font_size_override("font_size",16 if narrow or short else 18)
		for state in ["normal","hover","pressed","disabled"]:
			var style: StyleBoxFlat = button.get_theme_stylebox(state).duplicate()
			style.content_margin_left = 6 if narrow else 18
			style.content_margin_right = 6 if narrow else 18
			button.add_theme_stylebox_override(state,style)
		button.position = Vector2(margin+index*(button_width+10),view.y-margin-48)
		button.size = Vector2(button_width,48)

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if info_scroll.has_focus():
		if event.keycode == KEY_DOWN: info_scroll.scroll_vertical += 40
		elif event.keycode == KEY_UP: info_scroll.scroll_vertical -= 40
		elif event.keycode == KEY_PAGEDOWN: info_scroll.scroll_vertical += int(info_scroll.size.y*0.8)
		elif event.keycode == KEY_PAGEUP: info_scroll.scroll_vertical -= int(info_scroll.size.y*0.8)
		else: return
		get_viewport().set_input_as_handled()

func close() -> void:
	if _closing: return
	_closing = true
	closed.emit()
	if _previous_focus:
		var previous = _previous_focus.get_ref()
		if is_instance_valid(previous) and previous.is_inside_tree() and previous.is_visible_in_tree() and not previous.is_queued_for_deletion(): previous.grab_focus.call_deferred()
	queue_free()
