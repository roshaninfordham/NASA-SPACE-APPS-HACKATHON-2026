extends SceneTree
## Opt-in real NASA transport probe. No TLS bypass, secrets, or learner data.
class ProxyFeed extends "res://live/solar_feed.gd":
	func _make_request() -> HTTPRequest:
		var request := HTTPRequest.new()
		var proxy := OS.get_environment("KOMAKU_SOLAR_PROXY_HOST")
		if not proxy.is_empty(): request.set_https_proxy(proxy, int(OS.get_environment("KOMAKU_SOLAR_PROXY_PORT")))
		var ca_path := OS.get_environment("KOMAKU_SOLAR_CA_BUNDLE")
		if not ca_path.is_empty():
			var certificate := X509Certificate.new()
			if certificate.load(ca_path) != OK:
				push_error("The probe CA bundle could not be loaded; TLS verification remains enabled")
			else: request.set_tls_options(TLSOptions.client(certificate))
		return request
var feed: Node
var completed := false
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if OS.get_environment("KOMAKU_SOLAR_LIVE_PROBE") != "1" or OS.get_environment("XDG_DATA_HOME").is_empty():
		push_error("Explicit opt-in and isolated XDG_DATA_HOME required")
		quit(1)
		return
	feed = ProxyFeed.new("user://solar-live-probe")
	root.add_child(feed)
	feed.changed.connect(finished)
	feed.refresh(false)
	create_timer(16.0).timeout.connect(deadline, CONNECT_ONE_SHOT)
func deadline() -> void:
	if not completed:
		push_error("Live NASA probe did not finish in its bounded deadline")
		quit(1)
func finished() -> void:
	var state: Dictionary = feed.snapshot()
	if state.busy or state.status == "loading": return
	completed = true
	state.erase("texture")
	state["tls_verification"] = "enabled"
	state["transport"] = "Godot HTTPRequest to the fixed NASA HTTPS source"
	print("NASA_LIVE_PROBE=", JSON.stringify(state))
	var ok: bool = state.is_live and state.http_status == 200 and state.width == 512 and state.height == 512 and state.received_bytes > 0 and not state.last_success_utc.is_empty()
	feed.queue_free()
	await process_frame
	quit(0 if ok else 1)
