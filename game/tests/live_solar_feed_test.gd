extends SceneTree
const Feed = preload("res://live/solar_feed.gd")
var failures := 0
var assertions := 0
class ClockFeed extends "res://live/solar_feed.gd":
	var ticks := 1000000
	func _now_ticks() -> int: return ticks

func _initialize() -> void: call_deferred("run")
func check(condition: bool, label: String) -> void:
	assertions += 1
	if condition: print("PASS: ", label)
	else:
		failures += 1
		push_error(label)
func make_feed(directory: String) -> Node:
	var feed := Feed.new(directory)
	root.add_child(feed)
	return feed
func response(feed: Node, bytes: PackedByteArray, modified := "Sun, 15 Nov 2026 04:53:06 GMT") -> void:
	feed._last_checked = Feed._utc(Time.get_unix_time_from_system())
	feed._accept_response(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(["Content-Type: image/jpeg", "Last-Modified: " + modified]), bytes)
func write(path: String, bytes: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
func run() -> void:
	if OS.get_environment("XDG_DATA_HOME").is_empty() or DirAccess.dir_exists_absolute("user://solar-test-valid"):
		check(false, "A fresh isolated user-data directory is required")
		quit(1)
		return
	var feed := make_feed("user://solar-test-valid")
	var bundled: Dictionary = feed.snapshot()
	check(bundled.status == "fallback" and not bundled.is_live and bundled.texture != null and bundled.source_kind == "bundled", "Bundled NASA image is visible and explicitly not live")
	check(bundled.credit == "Courtesy of NASA/SDO and the AIA, EVE, and HMI science teams." and bundled.source_url == Feed.SOURCE_URL, "NASA credit and fixed HTTPS scientific source are retained")
	var bytes := FileAccess.get_file_as_bytes(Feed.FALLBACK)
	check(Feed.jpeg_dimensions(bytes) == Vector2i(512,512) and Feed.validated_image(bytes) != null, "The actual NASA browse image passes bounded JPEG header and decoder checks")
	check(Feed.validated_image("not a JPEG".to_utf8_buffer()) == null and Feed.validated_image(bytes.slice(0,bytes.size()-2)) == null, "Non-JPEG and truncated images are rejected before decode")
	var large := Image.create(513,512,false,Image.FORMAT_RGB8).save_jpg_to_buffer()
	check(Feed.validated_image(large) == null, "Decoded dimensions must be exactly the requested 512 by 512 pixels")
	var too_large := PackedByteArray()
	too_large.resize(Feed.MAX_BYTES+1)
	check(Feed.validated_image(too_large) == null, "Compressed image body is limited to two MiB")
	check(Feed.publication_time("Sun, 15 Nov 2026 04:53:06 GMT") > 0 and Feed.publication_time("Wed, 31 Feb 2026 12:00:00 GMT") == 0 and Feed.publication_time("now") == 0, "HTTP publication metadata is validated as a calendar time")
	response(feed,bytes)
	var live: Dictionary = feed.snapshot()
	check(live.is_live and live.source_kind == "network" and live.last_success_utc != "" and live.last_checked_utc != "", "A valid NASA response records distinct checked and successful-fetch timestamps")
	check(live.file_updated_utc == "Sun, 15 Nov 2026 04:53:06 GMT" and live.sha256 == Feed._sha256(bytes), "NASA publication time and exact returned-image digest are preserved")
	var saved := make_feed("user://solar-test-valid")
	var cached: Dictionary = saved.snapshot()
	check(cached.status == "cached" and not cached.is_live and cached.source_kind == "cache" and cached.sha256 == live.sha256 and cached.last_success_utc == live.last_success_utc, "A fresh client validates and displays cached bytes without claiming a live connection")
	check(cached.cache_age_seconds >= 0 and cached.texture.get_width() == 512, "Offline cache reports its successful-fetch age and bounded dimensions")
	feed._accept_response(HTTPRequest.RESULT_TIMEOUT,0,PackedStringArray(),PackedByteArray())
	var offline: Dictionary = feed.snapshot()
	check(offline.status == "cached" and not offline.is_live and offline.last_success_utc == live.last_success_utc and offline.sha256 == live.sha256, "Offline/timeout state keeps the last successful image and timestamp")
	feed._accept_response(HTTPRequest.RESULT_SUCCESS,302,PackedStringArray(["Location: https://example.com/evil.jpg"]),bytes)
	check(not feed.snapshot().is_live and feed.snapshot().sha256 == live.sha256, "Redirects never become a second-source live image")
	feed._accept_response(HTTPRequest.RESULT_SUCCESS,200,PackedStringArray(["Content-Type: text/html"]),bytes)
	check(not feed.snapshot().is_live and feed.snapshot().sha256 == live.sha256, "Wrong response content type cannot replace the last valid image")
	response(feed,bytes,"Mon, 01 Jan 2024 00:00:00 GMT")
	check(feed.snapshot().status == "stale" and feed.snapshot().stale and feed.snapshot().image_age_seconds > 86400, "A successful response with old publication metadata is explicitly stale")
	feed._last_attempt_ticks = Time.get_ticks_msec()
	feed.refresh(true)
	feed.refresh(false)
	check(not is_instance_valid(feed._request), "Immediate manual and automatic repeats are throttled without any network request")
	var timed := ClockFeed.new("user://solar-test-clock")
	root.add_child(timed)
	timed._last_attempt_ticks = timed.ticks - 61000
	timed.refresh(false)
	check(not is_instance_valid(timed._request), "Automatic polling remains throttled after the shorter manual interval")
	var record_path := "user://solar-test-valid/latest.json"
	var record: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(record_path))
	var image_path: String = "user://solar-test-valid/" + record.sha256 + ".jpg"
	write(image_path,"corrupted image".to_utf8_buffer())
	var corrupted := make_feed("user://solar-test-valid")
	check(corrupted.snapshot().status == "fallback" and not corrupted.snapshot().is_live, "Corrupt cached JPEG falls back to the bundled NASA image")
	record.sha256 = "../../outside"
	write(record_path,JSON.stringify(record).to_utf8_buffer())
	var traversal := make_feed("user://solar-test-valid")
	check(traversal.snapshot().status == "fallback", "Cache metadata cannot traverse to an arbitrary local file")
	response(feed,bytes)
	record = JSON.parse_string(FileAccess.get_file_as_string(record_path))
	record.fetched_unix = Time.get_unix_time_from_system()+86400
	write(record_path,JSON.stringify(record).to_utf8_buffer())
	var future := make_feed("user://solar-test-valid")
	check(future.snapshot().status == "fallback", "Future-dated cache fetch metadata is not trusted")
	var invalid_root := Feed.new("/tmp/untrusted-solar-cache")
	check(invalid_root._cache_root == "user://nasa-sdo", "Cache paths remain confined to a single app-owned user-data subdirectory")
	invalid_root.free()
	for node in [feed,saved,corrupted,traversal,future,timed]: node.queue_free()
	await process_frame
	print("LIVE SOLAR FEED ASSERTIONS: ", assertions, " FAILURES: ", failures)
	quit(1 if failures else 0)
