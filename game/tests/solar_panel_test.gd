extends SceneTree
const SolarView = preload("res://live/solar_panel.gd")
var failures := 0
class FakeFeed extends Node:
	signal changed
	var requests: Array[bool] = []
	var value: Dictionary = {}
	func snapshot() -> Dictionary: return value.duplicate(true)
	func refresh(force: bool = false) -> void: requests.append(force)
func check(ok: bool, message: String) -> void:
	if ok: print("PASS: ",message)
	else: failures += 1; push_error(message)
func frames() -> void:
	for index in range(5): await process_frame
func press(button: Button) -> void:
	button.grab_focus()
	for down in [true,false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ENTER
		event.pressed = down
		root.push_input(event)
	await frames()
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var feed := FakeFeed.new()
	root.add_child(feed)
	var fixture_image := Image.create(32,32,false,Image.FORMAT_RGB8)
	fixture_image.fill(Color("bd7637"))
	var texture := ImageTexture.create_from_image(fixture_image)
	feed.value = {"status":"cached","source_kind":"cache","texture":texture,"message":"Using the last successfully saved image.","file_updated_utc":"Sun, 15 Nov 2026 04:53:06 GMT","fetched_at_utc":"2026-11-15 05:01:00 UTC","last_checked_utc":"2026-11-15 05:08:00 UTC","image_age_seconds":894.0,"cache_age_seconds":420.0}
	var view := SolarView.new()
	view.client = feed
	root.add_child(view)
	var sources: Array[String] = []
	view.source_requested.connect(func(url:String):sources.append(url))
	await frames()
	check(feed.requests.is_empty(),"Opening the UI never starts a hidden HTTP request")
	check(view.layer == 31,"Solar image viewer sits above journey and updater layers")
	check(view.image_view.texture == texture and view.image_view.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED,"Whole source image retains aspect ratio and embedded date pixels")
	check(view.credit_label.get_global_rect().end.y < view.back_button.get_global_rect().position.y,"NASA credit fits on first open, without requiring a resize")
	for dimensions in [Vector2i(1280,720),Vector2i(960,540),Vector2i(390,844),Vector2i(844,390),Vector2i(320,568),Vector2i(1280,720)]:
		root.size = dimensions
		await frames()
		var bounds := Rect2(Vector2.ZERO,root.get_visible_rect().size)
		for button in [view.back_button,view.refresh_button,view.source_button]:
			check(bounds.grow(1).encloses(button.get_global_rect()),str(button.name)+" fits "+str(dimensions))
			check(button.size.x >= 48 and button.size.y >= 48,str(button.name)+" has at least48px target")
		check(not view.back_button.get_global_rect().intersects(view.refresh_button.get_global_rect()) and not view.refresh_button.get_global_rect().intersects(view.source_button.get_global_rect()),"Footer actions never overlap after rotation")
		check(bounds.grow(1).encloses(view._image_frame.get_global_rect()),"Image remains in viewport")
		check(view.info_scroll.get_global_rect().end.y <= view.back_button.get_global_rect().position.y,"Image details scroll above persistent navigation")
		check(view._image_caption.get_global_rect().end.y <= view.back_button.get_global_rect().position.y,"Observation prompt remains separate from navigation")
		for fixed in [view.status_label,view.credit_label]:
			check(bounds.encloses(fixed.get_global_rect()) and fixed.get_minimum_size().y <= fixed.size.y+1,"Status and credit remain readable at " + str(dimensions))
		check(view.status_label.get_global_rect().end.y <= view._image_frame.get_global_rect().position.y,"Image starts below persistent source status")
		check(view.info_scroll.get_global_rect().end.y <= view.credit_label.get_global_rect().position.y,"Expanded metadata cannot cover the persistent NASA credit")
		check(view.credit_label.get_global_rect().end.y < view.back_button.get_global_rect().position.y,"NASA credit stays separate from navigation")
		check(view.details_button.custom_minimum_size.y >= 48,"Connection details has a child-sized48px touch target")
	check(not view._details.visible and not view.last_checked_label.is_visible_in_tree() and not view.message_label.is_visible_in_tree(),"Connection diagnostics start collapsed without hiding the image dates")
	check(view.file_updated_label.is_visible_in_tree() and view.successful_fetch_label.is_visible_in_tree(),"Publication and successful retrieval dates stay in the concise view")
	check(view.status_label.get_parent() == view.background and view.credit_label.get_parent() == view.background,"Scrolling explanations cannot move source status or credit out of view")
	await press(view.details_button)
	check(view._details.visible and view.last_checked_label.is_visible_in_tree() and view.age_label.is_visible_in_tree(),"Keyboard activation reveals connection history and age without opening a new screen")
	check(view.image_view.texture == texture and view.status_label.is_visible_in_tree() and view.credit_label.is_visible_in_tree(),"Opening connection details preserves the actual image and source identity")
	check("Offline" in view.status_label.text and "saved NASA" in view.status_label.text,"Saved image is explicitly distinguished from a live connection")
	check("04:53:06 GMT" in view.file_updated_label.text and "05:01:00 UTC" in view.successful_fetch_label.text and "05:08:00 UTC" in view.last_checked_label.text,"NASA file time, successful fetch, and latest attempt stay distinct")
	await press(view.refresh_button)
	check(feed.requests == [true],"Refresh is an explicit user-forced client request")
	await press(view.source_button)
	check(sources == ["https://sdo.gsfc.nasa.gov/data/"],"Source action emits only the fixed NASA data page")
	feed.value.status = "loading"
	feed.changed.emit()
	await frames()
	check(view.refresh_button.disabled and view.image_view.texture == texture,"Loading prevents duplicate refresh and preserves the last valid image")
	check(view.refresh_button.text == "Checking…" and view._details.visible,"Loading explains the disabled action without collapsing what the reader opened")
	var original_feed := feed.value.duplicate(true)
	feed.value = {"status":"loading"}
	feed.changed.emit()
	check(view.image_view.texture == texture and "04:53:06 GMT" in view.file_updated_label.text and "05:01:00 UTC" in view.successful_fetch_label.text,"A connection-only event retains the displayed image’s original dates")
	check(feed.value == {"status":"loading"},"The read-only viewer never fills fields back into the feed")
	feed.value = original_feed
	feed.value.status = "live"
	feed.value.source_kind = "network"
	feed.changed.emit()
	check("NASA connected" in view.status_label.text and "latest available" in view.status_label.text,"Live response is labeled latest available rather than real-time observation")
	feed.value.status = "stale"
	feed.value.image_age_seconds = 172800.0
	feed.changed.emit()
	check("Older NASA" in view.status_label.text and "2.0 days" in view.age_label.text,"Old published imagery remains visibly dated after a successful response")
	feed.value = {"status":"fallback","source_kind":"bundled","texture":texture}
	feed.changed.emit()
	check("bundled example" in view.status_label.text and "unknown" in view.file_updated_label.text and "not yet" in view.successful_fetch_label.text,"Bundled fallback has no invented publication or fetch timestamp")
	check(SolarView.describe_age(-1) == "unknown" and SolarView.describe_age(NAN) == "unknown","Unavailable age is not represented as fresh")
	root.size = Vector2i(320,568)
	await frames()
	view.info_scroll.grab_focus()
	await frames()
	var key := InputEventKey.new()
	key.keycode = KEY_PAGEDOWN
	key.pressed = true
	root.push_input(key)
	await frames()
	check(view.info_scroll.scroll_vertical > 0,"Keyboard readers can scroll the science and source details")
	await press(view.details_button)
	check(not view._details.visible and not view.last_checked_label.is_visible_in_tree(),"Keyboard activation can collapse diagnostics again")
	check(view.credit_label.text == SolarView.CREDIT and view.credit_label.is_visible_in_tree(),"The full NASA team credit stays visible after reading details")
	var closes: Array[bool] = []
	view.closed.connect(func():closes.append(true))
	view.close()
	view.close()
	check(closes.size() == 1,"Closing emits one intent even if Escape and Back arrive together")
	await frames()
	feed.queue_free()
	print("SOLAR PANEL FAILURES: ",failures)
	quit(1 if failures else 0)
